#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer"]
# ///
"""Summarise an xctrace Time Profiler export: top functions by self and inclusive samples."""

import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

import typer


def demangle_light(name: str) -> str:
    # xctrace already demangles Swift symbols; shorten the noisiest generic noise.
    return name.replace("MetalSprockets.", "").replace("Swift.", "")


def main(
    export: Path = typer.Argument(..., help="XML from `xctrace export --xpath ...time-profile`"),
    top: int = typer.Option(25, help="Rows per table"),
    within: str = typer.Option("", help="Only count samples whose stack contains a frame with this text"),
    module: str = typer.Option("", help="Only show functions from binaries whose name contains this text"),
) -> None:
    by_id: dict[str, ET.Element] = {}
    self_counts: Counter[str] = Counter()
    inclusive_counts: Counter[str] = Counter()
    total = 0

    def resolve(element: ET.Element) -> ET.Element:
        ref = element.get("ref")
        return by_id[ref] if ref else element

    # Register every element with an id so later refs resolve, in document order.
    for _, element in ET.iterparse(export, events=("end",)):
        if element.get("id"):
            by_id[element.get("id")] = element
        if element.tag != "row":
            continue
        backtrace = next((child for child in element if child.tag in ("tagged-backtrace", "backtrace")), None)
        if backtrace is None:
            continue
        backtrace = resolve(backtrace)
        frames = []
        for frame in backtrace.iter("frame"):
            frame = resolve(frame)
            binary = frame.find("binary")
            binary_name = resolve(binary).get("name", "") if binary is not None else ""
            frames.append((demangle_light(frame.get("name", "?")), binary_name))
        if not frames:
            continue
        if within and not any(within in name for name, _ in frames):
            continue
        total += 1
        leaf_name, leaf_binary = frames[0]
        if not module or module in leaf_binary:
            self_counts[leaf_name] += 1
        for name in {name for name, binary in frames if not module or module in binary}:
            inclusive_counts[name] += 1

    if total == 0:
        typer.echo("No matching samples.")
        raise typer.Exit(1)

    def table(title: str, counts: Counter[str]) -> None:
        typer.echo(f"\n## {title} ({total} samples)")
        for name, count in counts.most_common(top):
            typer.echo(f"{100 * count / total:6.1f}%  {count:6d}  {name[:160]}")

    table("Self", self_counts)
    table("Inclusive", inclusive_counts)


if __name__ == "__main__":
    typer.run(main)
