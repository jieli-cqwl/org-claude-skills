#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${1:-$REPO_ROOT}"
python3 "$REPO_ROOT/tools/community/validate_context_contract.py" --root "$TARGET_ROOT" --mode audit
