#!/bin/bash
# Runs the test suite under the Metal layers that Xcode Debug runs turn on by default (#543):
# API validation, GPU frame capture, and both together.
#
# Metal reads these variables only when it creates the first device, so each configuration needs its own test
# process. See Tests/MetalSprocketsTests/Support/MetalDebugLayers.swift.
#
#   Scripts/test-metal-layers.sh
set -euo pipefail

cd "$(dirname "$0")/.."

configurations=(
    "MTL_DEBUG_LAYER=1"
    "MTL_CAPTURE_ENABLED=1"
    "MTL_DEBUG_LAYER=1 MTL_CAPTURE_ENABLED=1"
)

failed=()
for configuration in "${configurations[@]}"; do
    echo "==> ${configuration}"
    # shellcheck disable=SC2086 # each configuration is a list of NAME=value words
    if ! env ${configuration} swift test; then
        failed+=("${configuration}")
    fi
done

if ((${#failed[@]} > 0)); then
    echo "Failed under: ${failed[*]}" >&2
    exit 1
fi
