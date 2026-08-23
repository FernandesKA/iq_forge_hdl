#!/usr/bin/env bash
# Usage: ./build.sh <platform> [jobs]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <platform> [jobs]" >&2
    echo "Available platforms: $(ls constraints)" >&2
    exit 1
fi

PLATFORM="$1"
JOBS="${2:-4}"

if [ ! -f "vivado/$PLATFORM/dds_tx_chain.xpr" ]; then
    echo "No project found at vivado/$PLATFORM/dds_tx_chain.xpr. Run ./create_project.sh $PLATFORM first." >&2
    exit 1
fi

vivado -mode batch -source scripts/build_bitstream.tcl -tclargs "$PLATFORM" "$JOBS"
