#!/usr/bin/env bash
set -euo pipefail
DEV=${1:-/dev/sr0}
eject "$DEV"
echo "EJECTED $DEV"