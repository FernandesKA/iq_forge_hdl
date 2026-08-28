#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

STATUS=0

for xdc in constraints/*.xdc; do
    PLATFORM="$(basename "$xdc" .xdc)"
    LOG="$(mktemp)"
    ./create_project.sh "$PLATFORM" >"$LOG" 2>&1 || true
    if grep -qE "^ERROR:|No (pins|cells|nets|ports) matched" "$LOG" || ! grep -q "Project created for platform" "$LOG"; then
        echo "FAIL: $PLATFORM" >&2
        cat "$LOG" >&2
        STATUS=1
    else
        echo "OK: $PLATFORM"
    fi
    rm -f "$LOG"
done

exit $STATUS
