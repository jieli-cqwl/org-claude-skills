#!/usr/bin/env bash
# Claude wrapper that delegates to the shared managed dangerous-command blocker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "$SCRIPT_DIR/managed/block_dangerous.sh"
