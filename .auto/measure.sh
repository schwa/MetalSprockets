#!/bin/bash
# Runs the test suite with coverage and reports how much of the library is covered.
#
# The suite is run several times and the median reported. Coverage here is not deterministic: the ViewHosting tests
# put a real SwiftUI view on screen, and whether the hosted RenderView gets a frame drawn depends on the run loop.
# That alone swings the total by ~70 lines, which is larger than a typical iteration's gain, so a single run cannot
# be compared against another.
set -euo pipefail

cd "$(dirname "$0")/.."

RUNS=${COVERAGE_RUNS:-3}

declare -a LINES_COVERED_SAMPLES=()
SUMMARY=""
OUTPUT=""

for _ in $(seq "$RUNS"); do
    OUTPUT=$(xcb test --coverage-summary --coverage-sort-by-impact 2>&1)

    # xcb prints e.g.:
    #   Coverage: 87.4% lines (4997/5720), 74.4% functions (721/969)
    SUMMARY=$(printf '%s\n' "$OUTPUT" | grep -E '^Coverage: ' | tail -1)

    if [[ -z "$SUMMARY" ]]; then
        printf '%s\n' "$OUTPUT" | tail -40
        echo "ERROR: no coverage summary in xcb output (tests probably failed to build or run)"
        exit 1
    fi

    LINES_COVERED_SAMPLES+=("$(printf '%s' "$SUMMARY" | sed -E 's/.*lines \(([0-9]+)\/[0-9]+\).*/\1/')")
done

# Median of the samples.
IFS=$'\n' SORTED=($(sort -n <<<"${LINES_COVERED_SAMPLES[*]}")); unset IFS
LINES_COVERED=${SORTED[$((RUNS / 2))]}

LINES_TOTAL=$(printf '%s' "$SUMMARY" | sed -E 's/.*lines \([0-9]+\/([0-9]+)\).*/\1/')
FUNC_PCT=$(printf '%s' "$SUMMARY" | sed -E 's/.*, ([0-9.]+)% functions.*/\1/')
FUNCS_COVERED=$(printf '%s' "$SUMMARY" | sed -E 's/.*functions \(([0-9]+)\/[0-9]+\).*/\1/')

UNCOVERED=$((LINES_TOTAL - LINES_COVERED))
LINE_PCT=$(awk -v c="$LINES_COVERED" -v t="$LINES_TOTAL" 'BEGIN { printf "%.2f", (c / t) * 100 }')
SPREAD=$((SORTED[RUNS - 1] - SORTED[0]))

# Primary metric is the absolute number of covered lines, not the percentage: a percentage can be raised by
# deleting untested source, which is not what this session is for.
echo "METRIC covered_lines=$LINES_COVERED"
echo "METRIC uncovered_lines=$UNCOVERED"
echo "METRIC line_pct=$LINE_PCT"
echo "METRIC function_pct=$FUNC_PCT"
echo "METRIC covered_functions=$FUNCS_COVERED"
echo "METRIC total_lines=$LINES_TOTAL"
echo "METRIC sample_spread=$SPREAD"

echo
echo "samples: ${LINES_COVERED_SAMPLES[*]} (median $LINES_COVERED, spread $SPREAD)"
echo
echo "--- where the uncovered lines are (last run) ---"
printf '%s\n' "$OUTPUT" | grep -E 'uncovered' | head -20
