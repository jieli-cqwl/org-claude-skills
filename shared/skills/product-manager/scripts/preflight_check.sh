#!/usr/bin/env bash
# Validate product-manager Director handoff inputs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/preflight_check.py" "$@"
