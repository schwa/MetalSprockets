#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer"]
# ///
"""Summarise an xctrace Time Profiler export: signpost interval durations, and top functions by self and inclusive
samples, optionally limited to samples taken inside a signpost interval (a phase)."""

import bisect
import statistics
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

import typer


def shorten(name: str) -> str:
    return name.replace("MetalSprockets.", "").replace("Swift.", "")


class RefResolver:
    """xctrace exports each value once with an id and refers to it later with ref."""

    def __init__(self) -> None:
        self.by_id: dict[str, ET.Element] = {}

    def register(self, element: ET.Element) -> None:
        if element.get("id"):
            self.by_id[element.get("id")] = element

    def __call__(self, element: ET.Element | None) -> ET.Element | None:
        if element is None:
            return None
        ref = element.get("ref")
        return self.by_id[ref] if ref else element


def thread_id(thread: ET.Element | None, resolve: RefResolver) -> str:
    thread = resolve(thread)
    tid = resolve(thread.find("tid")) if thread is not None else None
    return tid.text if tid is not None else ""


def load_intervals(path: Path) -> dict[str, list[tuple[int, int, str]]]:
    """Signpost intervals by name: (start ns, end ns, thread id), paired by name and identifier."""
    resolve = RefResolver()
    open_intervals: dict[tuple[str, str], tuple[int, str]] = {}
    intervals: dict[str, list[tuple[int, int, str]]] = defaultdict(list)
    for _, element in ET.iterparse(path, events=("end",)):
        resolve.register(element)
        if element.tag != "row":
            continue
        fields = {child.tag: resolve(child) for child in element}
        event = fields.get("event-type")
        name = fields.get("signpost-name")
        identifier = fields.get("os-signpost-identifier")
        time = fields.get("event-time")
        if event is None or name is None or identifier is None or time is None:
            continue
        key = (name.text, identifier.text)
        if event.text == "Begin":
            open_intervals[key] = (int(time.text), thread_id(fields.get("thread"), resolve))
        elif event.text == "End" and key in open_intervals:
            start, tid = open_intervals.pop(key)
            intervals[name.text].append((start, int(time.text), tid))
    for spans in intervals.values():
        spans.sort()
    return intervals


def print_interval_stats(intervals: dict[str, list[tuple[int, int, str]]]) -> None:
    typer.echo("\n## Signpost intervals (ms)")
    typer.echo(f"{'name':<16} {'count':>6} {'median':>8} {'p95':>8} {'max':>8} {'total':>9}")
    for name, spans in sorted(intervals.items(), key=lambda item: -sum(end - start for start, end, _ in item[1])):
        durations = sorted((end - start) / 1e6 for start, end, _ in spans)
        p95 = durations[min(len(durations) - 1, int(len(durations) * 0.95))]
        typer.echo(f"{name:<16} {len(durations):>6} {statistics.median(durations):>8.3f} {p95:>8.3f} {durations[-1]:>8.3f} {sum(durations):>9.1f}")


def in_phase(spans: list[tuple[int, int, str]], starts: list[int], time: int, tid: str) -> bool:
    index = bisect.bisect_right(starts, time) - 1
    # Intervals of one name do not nest on a thread but may overlap across threads, so check a few earlier starts.
    for candidate in range(index, max(index - 8, -1), -1):
        start, end, span_tid = spans[candidate]
        if start <= time <= end and (not tid or span_tid == tid):
            return True
    return False


def main(
    export: Path = typer.Argument(..., help="XML from `xctrace export --xpath ...time-profile`"),
    signposts: Path | None = typer.Option(None, help="XML from `xctrace export --xpath ...os-signpost`"),
    phase: str = typer.Option("", help="Only count samples taken inside signpost intervals with this name (needs --signposts)"),
    top: int = typer.Option(25, help="Rows per table"),
    within: str = typer.Option("", help="Only count samples whose stack contains a frame with this text"),
    module: str = typer.Option("", help="Only show functions from binaries whose name contains this text"),
) -> None:
    intervals = load_intervals(signposts) if signposts else {}
    if intervals:
        print_interval_stats(intervals)
    if phase and phase not in intervals:
        typer.echo(f"No signpost intervals named {phase!r}.")
        raise typer.Exit(1)
    phase_spans = intervals.get(phase, [])
    phase_starts = [start for start, _, _ in phase_spans]

    resolve = RefResolver()
    self_counts: Counter[str] = Counter()
    inclusive_counts: Counter[str] = Counter()
    total = 0
    for _, element in ET.iterparse(export, events=("end",)):
        resolve.register(element)
        if element.tag != "row":
            continue
        fields = {child.tag: child for child in element}
        # Elements without children are falsy, so no `or` here.
        backtrace_element = fields.get("tagged-backtrace")
        if backtrace_element is None:
            backtrace_element = fields.get("backtrace")
        backtrace = resolve(backtrace_element)
        if backtrace is None:
            continue
        if phase:
            time = resolve(fields.get("sample-time"))
            if time is None or not in_phase(phase_spans, phase_starts, int(time.text), thread_id(fields.get("thread"), resolve)):
                continue
        frames = []
        for frame in backtrace.iter("frame"):
            frame = resolve(frame)
            binary = resolve(frame.find("binary"))
            frames.append((shorten(frame.get("name", "?")), binary.get("name", "") if binary is not None else ""))
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
