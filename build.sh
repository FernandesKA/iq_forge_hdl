#!/usr/bin/env bash
# Usage: ./build.sh <platform> [jobs]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <platform> [jobs]" >&2
    echo "Available platforms: $(ls constraints | sed 's/\.xdc$//')" >&2
    exit 1
fi

PLATFORM="$1"
JOBS="${2:-4}"

if [ ! -f "vivado/$PLATFORM/iq_forge_hdl.xpr" ]; then
    echo "No project found at vivado/$PLATFORM/iq_forge_hdl.xpr. Run ./create_project.sh $PLATFORM first." >&2
    exit 1
fi

vivado -mode batch -source scripts/build_bitstream.tcl -tclargs "$PLATFORM" "$JOBS"
