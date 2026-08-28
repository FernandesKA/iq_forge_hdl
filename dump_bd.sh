#!/usr/bin/env bash
# Usage: ./dump_bd.sh <platform>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <platform>" >&2
    exit 1
fi

PLATFORM="$1"

if [ ! -f "vivado/$PLATFORM/iq_forge_hdl.xpr" ]; then
    echo "No project found at vivado/$PLATFORM/iq_forge_hdl.xpr. Run ./create_project.sh $PLATFORM first." >&2
    exit 1
fi

vivado -mode batch -source scripts/dump_bd.tcl -tclargs "$PLATFORM"

RAW="dumps/${PLATFORM}_bd_raw.tcl"
OUT="platforms/$PLATFORM/bd.tcl"

awk '/^# End of create_root_design/{exit} /^proc create_root_design/{flag=1} flag{print}' "$RAW" > "$OUT"
echo "# End of create_root_design()" >> "$OUT"

if ! grep -q "^proc create_root_design" "$OUT"; then
    echo "Failed to extract create_root_design from $RAW - check it manually." >&2
    exit 1
fi

echo "Wrote $OUT ($(wc -l < "$OUT") lines)."
echo "Review it: git diff $OUT"
