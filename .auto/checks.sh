#!/bin/bash
# Correctness backpressure: the suite must build and pass, and lint must stay clean.
# measure.sh already fails when the suite fails, so this focuses on lint and on guarding the metric
# against the obvious ways of gaming it.
set -euo pipefail

cd "$(dirname "$0")/.."

FAILED=0

LINT=$(swiftlint --quiet 2>&1 || true)
if [[ -n "$LINT" ]]; then
    echo "swiftlint is not clean:"
    printf '%s\n' "$LINT" | tail -30
    FAILED=1
fi

# Coverage must come from new tests, never from deleting library code.
if ! git diff --quiet --stat -- Sources; then
    DELETED=$(git diff --numstat -- Sources | awk '{added += $1; removed += $2} END {print removed - added}')
    if [[ "${DELETED:-0}" -gt 0 ]]; then
        echo "Sources lost $DELETED net lines. Coverage must come from new tests, not from deleting library code."
        git diff --numstat -- Sources
        FAILED=1
    fi
fi

# Golden references have to be looked at by a human (or an agent that actually viewed the image) before being
# committed, otherwise a wrong render gets enshrined as correct.
NEW_GOLDENS=$(git status --porcelain -- "Tests/MetalSprocketsTests/Golden Images" | grep -E '^\?\?|^A' || true)
if [[ -n "$NEW_GOLDENS" ]]; then
    echo "New golden reference images are staged:"
    printf '%s\n' "$NEW_GOLDENS"
    echo "Blessing a golden image requires viewing it first. See .auto/prompt.md."
    FAILED=1
fi

exit $FAILED
