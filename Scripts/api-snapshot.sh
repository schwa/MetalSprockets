#!/bin/bash
# Regenerates or checks .public-api.yaml with a pinned swift-api-tool (#391).
#
# The snapshot depends on both the tool build and the Xcode version, so only one combination is trusted:
# swift-api-tool at the tag below, run under Xcode 27.
#
#   Scripts/api-snapshot.sh          # rewrite .public-api.yaml
#   Scripts/api-snapshot.sh --check  # fail if .public-api.yaml is out of date
set -euo pipefail

TOOL_TAG="0.2.3"
TOOL_ROOT="${HOME}/.cache/metalsprockets/swift-api-tool-${TOOL_TAG}"
TOOL="${TOOL_ROOT}/bin/swift-api-tool"

cd "$(dirname "$0")/.."

xcode_version="$(xcodebuild -version | head -1)"
case "${xcode_version}" in
    "Xcode 27"*) ;;
    *)
        echo "error: the API snapshot is generated with Xcode 27, but the selected Xcode is '${xcode_version}'." >&2
        exit 1
        ;;
esac

if [ ! -x "${TOOL}" ]; then
    echo "Installing swift-api-tool ${TOOL_TAG} into ${TOOL_ROOT}" >&2
    cargo install --quiet --git https://github.com/schwa/swift-api-tool --tag "${TOOL_TAG}" --locked --root "${TOOL_ROOT}"
fi

if [ "${1:-}" = "--check" ]; then
    generated="$(mktemp -t public-api)"
    trap 'rm -f "${generated}"' EXIT
    "${TOOL}" api . -o "${generated}" > /dev/null
    if ! diff -u .public-api.yaml "${generated}"; then
        echo "error: .public-api.yaml is out of date. Run Scripts/api-snapshot.sh and commit the result." >&2
        exit 1
    fi
else
    "${TOOL}" api . -o .public-api.yaml > /dev/null
fi
