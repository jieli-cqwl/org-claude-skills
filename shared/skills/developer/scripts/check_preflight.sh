#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SC_PREFLIGHT_ROLE="${SC_PREFLIGHT_ROLE:-developer}"
exec "$SCRIPT_DIR/../../product-director/scripts/check_preflight.sh" "$@"
