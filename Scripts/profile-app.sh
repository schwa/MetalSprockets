#!/bin/bash
# Profiles the Example app's Render demo under load (#507): builds it, launches it frontmost with a set cube count,
# records it with xctrace, and summarises the signpost intervals and hottest functions per phase.
#
#   Scripts/profile-app.sh                          # 1000 cubes, one Draw per cube, Release, 10 s
#   Scripts/profile-app.sh --cubes 5000 --instanced --seconds 5
#   Scripts/profile-app.sh --template 'System Trace'   # shows blocked time too (larger trace)
#   Scripts/profile-app.sh -- --phase Update --top 40  # arguments after -- go to profile_summary.py
#
# The app is launched with `open` so its window is in front (hidden windows are throttled), warmed up for 3 s, then
# recorded by attaching to its process. The cube count and instancing are @AppStorage values, set with `defaults`;
# the previous values are restored afterwards. The trace is kept in /tmp/metalsprockets-profile/.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$(pwd)"

cubes=1000
instanced=false
seconds=10
configuration=Release
template="Time Profiler"
summary_args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --cubes) cubes="$2"; shift 2;;
        --instanced) instanced=true; shift;;
        --seconds) seconds="$2"; shift 2;;
        -c) configuration="$2"; shift 2;;
        --template) template="$2"; shift 2;;
        --) shift; summary_args=("$@"); break;;
        *) echo "Unknown argument $1" >&2; exit 2;;
    esac
done
if [ ${#summary_args[@]} -eq 0 ]; then
    summary_args=(--phase Workload)
fi

xcb build MetalSprockets-Example -c "${configuration}" >&2
executable="$(xcb executable-path MetalSprockets-Example -c "${configuration}" 2>/dev/null | tail -1)"
app="$(dirname "$(dirname "$(dirname "${executable}")")")"
bundle_id="$(defaults read "${app}/Contents/Info" CFBundleIdentifier)"

# Set the demo's @AppStorage values, restoring the user's own afterwards.
previous_cubes="$(defaults read "${bundle_id}" cubeCount 2>/dev/null || true)"
previous_instanced="$(defaults read "${bundle_id}" instanced 2>/dev/null || true)"
restore() {
    osascript -e "tell application id \"${bundle_id}\" to quit" >/dev/null 2>&1 || pkill -f "${executable}" || true
    if [ -n "${previous_cubes}" ]; then defaults write "${bundle_id}" cubeCount -int "${previous_cubes}"; else defaults delete "${bundle_id}" cubeCount 2>/dev/null || true; fi
    if [ -n "${previous_instanced}" ]; then defaults write "${bundle_id}" instanced -bool "${previous_instanced}"; else defaults delete "${bundle_id}" instanced 2>/dev/null || true; fi
}
trap restore EXIT
defaults write "${bundle_id}" cubeCount -int "${cubes}"
defaults write "${bundle_id}" instanced -bool "${instanced}"

pkill -f "${executable}" 2>/dev/null || true
open -n "${app}"
sleep 3
pid="$(pgrep -f "${executable}" | head -1)"
[ -n "${pid}" ] || { echo "The app did not start." >&2; exit 1; }

output="/tmp/metalsprockets-profile"
mkdir -p "${output}"
trace="${output}/app-${configuration}-${cubes}-$(date +%Y%m%d-%H%M%S).trace"
xcrun xctrace record --template "${template}" --attach "${pid}" --time-limit "${seconds}s" --output "${trace}" >&2
xcrun xctrace export --input "${trace}" --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > "${trace}.xml"
xcrun xctrace export --input "${trace}" --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost" and @category="PointsOfInterest"]' > "${trace}.signposts.xml"

echo "trace: ${trace}"
echo "cubes: ${cubes}, instanced: ${instanced}, ${configuration}, ${seconds} s"
"${root}/Scripts/profile_summary.py" "${trace}.xml" --signposts "${trace}.signposts.xml" "${summary_args[@]}"
