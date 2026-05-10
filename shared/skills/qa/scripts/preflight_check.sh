#!/usr/bin/env bash
# Validate qa intake inputs before QA executes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/preflight_check.py" "$@"
