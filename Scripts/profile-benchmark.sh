#!/bin/bash
# Builds ReconciliationBenchmark in Release, records it with the Time Profiler, and prints the hottest functions.
#
#   Scripts/profile-benchmark.sh                              # 1000 cubes, samples inside System.update
#   Scripts/profile-benchmark.sh --within processWorkload -- --scenario draws --counts 200
#
# Options before `--` go to profile_summary.py (--within, --top, --module). Arguments after `--` go to the benchmark.
# The .trace is kept in /tmp/metalsprockets-profile/ for opening in Instruments.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$(pwd)"
summary_args=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    summary_args+=("$1")
    shift
done
[ "${1:-}" = "--" ] && shift
benchmark_args=("$@")
if [ ${#benchmark_args[@]} -eq 0 ]; then
    benchmark_args=(--frames 60)
fi
if [ ${#summary_args[@]} -eq 0 ]; then
    summary_args=(--within System.update)
fi

output="/tmp/metalsprockets-profile"
mkdir -p "${output}"
trace="${output}/benchmark-$(date +%Y%m%d-%H%M%S).trace"

cd Experiments/ReconciliationBenchmark
xcb build ReconciliationBenchmark -c Release >&2
executable="$(xcb executable-path ReconciliationBenchmark -c Release 2>/dev/null | tail -1)"

xcrun xctrace record --template 'Time Profiler' --output "${trace}" --launch -- "${executable}" "${benchmark_args[@]}" >&2
xcrun xctrace export --input "${trace}" --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > "${trace}.xml"

echo "trace: ${trace}"
"${root}/Scripts/profile_summary.py" "${trace}.xml" "${summary_args[@]}"
