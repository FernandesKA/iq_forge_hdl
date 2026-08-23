#!/usr/bin/env bash
# Usage: ./create_project.sh <platform>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <platform>" >&2
    echo "Available platforms: $(ls constraints)" >&2
    exit 1
fi

PLATFORM="$1"

if [ ! -d "constraints/$PLATFORM" ]; then
    echo "Unknown platform '$PLATFORM'. Available platforms: $(ls constraints)" >&2
    exit 1
fi

vivado -mode batch -source scripts/create_project.tcl -tclargs "$PLATFORM"
