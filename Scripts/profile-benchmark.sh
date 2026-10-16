#!/bin/bash
# Builds ReconciliationBenchmark in Release, records it with the Time Profiler, and prints the hottest functions.
#
#   Scripts/profile-benchmark.sh                              # 1000 cubes, samples inside the Update signposts
#   Scripts/profile-benchmark.sh --phase Workload -- --scenario draws --counts 200
#
# Options before `--` go to profile_summary.py (--phase, --within, --top, --module), except -c Debug|Release (default
# Release). The summary always starts with signpost interval statistics.
# Arguments after `--` go to the benchmark.
# The .trace is kept in /tmp/metalsprockets-profile/ for opening in Instruments.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$(pwd)"
summary_args=()
configuration="Release"
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    if [ "$1" = "-c" ]; then
        configuration="$2"
        shift 2
        continue
    fi
    summary_args+=("$1")
    shift
done
[ "${1:-}" = "--" ] && shift
benchmark_args=("$@")
if [ ${#benchmark_args[@]} -eq 0 ]; then
    benchmark_args=(--frames 60)
fi
if [ ${#summary_args[@]} -eq 0 ]; then
    summary_args=(--phase Update)
fi

output="/tmp/metalsprockets-profile"
mkdir -p "${output}"
trace="${output}/benchmark-${configuration}-$(date +%Y%m%d-%H%M%S).trace"

cd Experiments/ReconciliationBenchmark
xcb build ReconciliationBenchmark -c "${configuration}" >&2
executable="$(xcb executable-path ReconciliationBenchmark -c "${configuration}" 2>/dev/null | tail -1)"

xcrun xctrace record --template 'Time Profiler' --output "${trace}" --launch -- "${executable}" "${benchmark_args[@]}" >&2
xcrun xctrace export --input "${trace}" --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > "${trace}.xml"
xcrun xctrace export --input "${trace}" --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost" and @category="PointsOfInterest"]' > "${trace}.signposts.xml"

echo "trace: ${trace}"
"${root}/Scripts/profile_summary.py" "${trace}.xml" --signposts "${trace}.signposts.xml" "${summary_args[@]}"
