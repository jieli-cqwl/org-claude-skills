#!/usr/bin/env bash
# Validate a delivery-owner control decision before the next loop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/control_decision_check.py" "$@"
