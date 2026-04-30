#!/usr/bin/env bash
# Validate delivery-owner intake inputs for a frozen tech-lead plan.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/intake_preflight_check.py" "$@"
