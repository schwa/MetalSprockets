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

# This repo is a jj workspace and has no .git directory, so the guards below speak jj when git is unavailable.
# "Uncovered ground" is everything since the last recorded iteration, which is what an experiment changed.
if [[ -d .git ]]; then
    diff_stat() { git diff --numstat -- "$@"; }
    added_paths() { git status --porcelain -- "$@" | grep -E '^\?\?|^A' || true; }
else
    # `jj diff -r @` is the working-copy change, which is the git-`git diff` equivalent here.
    diff_stat() { jj diff --git -r @ -- "$@" | awk '/^\+\+\+ /{f=$2} /^\+[^+]/{a[f]++} /^-[^-]/{r[f]++} END {for (k in a) print a[k], r[k]+0, k; for (k in r) if (!(k in a)) print 0, r[k], k}'; }
    added_paths() { jj diff --summary -r @ -- "$@" | grep -E '^A ' || true; }
fi

# Coverage must come from new tests, never from deleting library code.
DELETED=$(diff_stat Sources | awk '{added += $1; removed += $2} END {print removed - added}')
if [[ "${DELETED:-0}" -gt 0 ]]; then
    echo "Sources lost $DELETED net lines. Coverage must come from new tests, not from deleting library code."
    diff_stat Sources
    FAILED=1
fi

# Golden references have to be looked at by a human (or an agent that actually viewed the image) before being
# committed, otherwise a wrong render gets enshrined as correct.
NEW_GOLDENS=$(added_paths "Tests/MetalSprocketsTests/Golden Images")
if [[ -n "$NEW_GOLDENS" ]]; then
    echo "New golden reference images are staged:"
    printf '%s\n' "$NEW_GOLDENS"
    echo "Blessing a golden image requires viewing it first. See .auto/prompt.md."
    FAILED=1
fi

exit $FAILED
