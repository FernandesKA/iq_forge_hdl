#!/usr/bin/env bash
# Usage: ./dump_project.sh <platform>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <platform>" >&2
    echo "Available platforms: $(ls constraints)" >&2
    exit 1
fi

PLATFORM="$1"

if [ ! -f "vivado/$PLATFORM/dds_tx_chain.xpr" ]; then
    echo "No project found at vivado/$PLATFORM/dds_tx_chain.xpr. Run ./create_project.sh $PLATFORM first." >&2
    exit 1
fi

vivado -mode batch -source scripts/dump_project.tcl -tclargs "$PLATFORM"

echo
echo "Now review the diff and manually merge over anything new:"
echo "  diff scripts/create_project.tcl dumps/$PLATFORM.tcl"
