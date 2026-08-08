#!/bin/bash
# Runs the test suite with coverage and reports how much of the library is covered.
set -euo pipefail

cd "$(dirname "$0")/.."

OUTPUT=$(xcb test --coverage-summary --coverage-sort-by-impact 2>&1)

# xcb prints e.g.:
#   Coverage: 87.4% lines (4997/5720), 74.4% functions (721/969)
SUMMARY=$(printf '%s\n' "$OUTPUT" | grep -E '^Coverage: ' | tail -1)

if [[ -z "$SUMMARY" ]]; then
    printf '%s\n' "$OUTPUT" | tail -40
    echo "ERROR: no coverage summary in xcb output (tests probably failed to build or run)"
    exit 1
fi

LINE_PCT=$(printf '%s' "$SUMMARY" | sed -E 's/^Coverage: ([0-9.]+)% lines.*/\1/')
LINES_COVERED=$(printf '%s' "$SUMMARY" | sed -E 's/.*lines \(([0-9]+)\/[0-9]+\).*/\1/')
LINES_TOTAL=$(printf '%s' "$SUMMARY" | sed -E 's/.*lines \([0-9]+\/([0-9]+)\).*/\1/')
FUNC_PCT=$(printf '%s' "$SUMMARY" | sed -E 's/.*, ([0-9.]+)% functions.*/\1/')
FUNCS_COVERED=$(printf '%s' "$SUMMARY" | sed -E 's/.*functions \(([0-9]+)\/[0-9]+\).*/\1/')

UNCOVERED=$((LINES_TOTAL - LINES_COVERED))

# Primary metric is the absolute number of covered lines, not the percentage: a percentage can be raised by
# deleting untested source, which is not what this session is for.
echo "METRIC covered_lines=$LINES_COVERED"
echo "METRIC uncovered_lines=$UNCOVERED"
echo "METRIC line_pct=$LINE_PCT"
echo "METRIC function_pct=$FUNC_PCT"
echo "METRIC covered_functions=$FUNCS_COVERED"
echo "METRIC total_lines=$LINES_TOTAL"

echo
echo "--- where the uncovered lines are ---"
printf '%s\n' "$OUTPUT" | grep -E 'uncovered' | head -20
