#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SC_COMPLETION_ROLE="${SC_COMPLETION_ROLE:-tech-lead}"
exec "$SCRIPT_DIR/../../product-director/scripts/check_completion.sh" "$@"
