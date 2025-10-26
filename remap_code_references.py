#!/usr/bin/env python3
"""
Remap issue references in source code files.
Finds references like #123 in comments and updates them to the new issue numbers.
"""

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Set


def load_mapping(mapping_file: str) -> Dict[int, int]:
    """Load the issue number mapping."""
    print(f"[INFO] Loading mapping from {mapping_file}...")
    with open(mapping_file, "r") as f:
        data = json.load(f)

    # Convert string keys to integers
    mappings = {int(k): v for k, v in data["mappings"].items()}
    print(f"[INFO] Loaded {len(mappings)} issue mappings")
    return mappings


def find_source_files(directory: str, extensions: List[str]) -> List[Path]:
    """Find all source files with given extensions."""
    files = []
    base_path = Path(directory)

    for ext in extensions:
        files.extend(base_path.rglob(f"*.{ext}"))

    return sorted(files)


def find_issue_references_in_line(line: str) -> Set[int]:
    """Find all issue references in a line of code."""
    references = set()

    # Match #123 pattern
    for match in re.finditer(r'#(\d+)\b', line):
        references.add(int(match.group(1)))

    return references


def remap_line(line: str, mapping: Dict[int, int]) -> Tuple[str, List[Tuple[int, int]]]:
    """
    Remap issue references in a line.
    Returns tuple of (updated_line, list of (old_num, new_num) changes made).
    """
    changes = []

    def replace_issue(match):
        old_num = int(match.group(1))
        # Only remap if this is a known UV issue number
        if old_num in mapping:
            new_num = mapping[old_num]
            # Only change if numbers are different
            if old_num != new_num:
                changes.append((old_num, new_num))
                return f"#{new_num}"
        return match.group(0)

    updated_line = re.sub(r'#(\d+)\b', replace_issue, line)

    return updated_line, changes


def process_file(file_path: Path, mapping: Dict[int, int], dry_run: bool = False) -> Tuple[bool, int]:
    """
    Process a single file and remap issue references.
    Returns (changed, num_changes).
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"[ERROR] Failed to read {file_path}: {e}")
        return False, 0

    new_lines = []
    total_changes = 0
    line_changes = []

    for line_num, line in enumerate(lines, 1):
        new_line, changes = remap_line(line, mapping)
        new_lines.append(new_line)

        if changes:
            total_changes += len(changes)
            line_changes.append((line_num, changes, line.rstrip(), new_line.rstrip()))

    if total_changes == 0:
        return False, 0

    # Print changes
    rel_path = file_path.relative_to(Path.cwd()) if file_path.is_relative_to(Path.cwd()) else file_path
    print(f"\n[UPDATE] {rel_path}")
    print(f"  Making {total_changes} change(s):")

    for line_num, changes, old_line, new_line in line_changes:
        for old_num, new_num in changes:
            print(f"    Line {line_num}: #{old_num} -> #{new_num}")
        if len(line_changes) <= 10:  # Only show diff for files with few changes
            print(f"      - {old_line}")
            print(f"      + {new_line}")

    # Write changes
    if not dry_run:
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            print(f"  ✓ Updated {rel_path}")
        except Exception as e:
            print(f"  ✗ Failed to write {rel_path}: {e}")
            return False, total_changes
    else:
        print(f"  [DRY RUN] Would update {rel_path}")

    return True, total_changes


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 remap_code_references.py <issue-mapping.json> [--dry-run]")
        print()
        print("Example:")
        print("  python3 remap_code_references.py issue-mapping.json")
        print("  python3 remap_code_references.py issue-mapping.json --dry-run")
        sys.exit(1)

    mapping_file = sys.argv[1]
    dry_run = "--dry-run" in sys.argv

    print("=" * 70)
    print("Source Code Issue Reference Remapper")
    print("=" * 70)

    if dry_run:
        print("[DRY RUN MODE] No files will be modified")
        print()

    # Load mapping
    mapping = load_mapping(mapping_file)

    # Find all source files
    print("\n[INFO] Finding source files...")
    source_files = find_source_files(".", ["swift"])

    # Filter out files that don't have issue references
    print(f"[INFO] Found {len(source_files)} Swift files")
    print("[INFO] Scanning for issue references...")

    files_with_refs = []
    for file_path in source_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                if re.search(r'#\d+\b', content):
                    files_with_refs.append(file_path)
        except Exception:
            continue

    print(f"[INFO] Found {len(files_with_refs)} files with issue references")

    # Process files
    total_files_changed = 0
    total_changes = 0

    for file_path in files_with_refs:
        changed, num_changes = process_file(file_path, mapping, dry_run)
        if changed:
            total_files_changed += 1
            total_changes += num_changes

    print("\n" + "=" * 70)
    print("Remapping Complete!")
    print("=" * 70)
    print(f"[SUMMARY] Files scanned: {len(files_with_refs)}")
    print(f"[SUMMARY] Files changed: {total_files_changed}")
    print(f"[SUMMARY] Total reference changes: {total_changes}")

    if dry_run:
        print()
        print("This was a dry run. Re-run without --dry-run to apply changes.")


if __name__ == "__main__":
    main()
