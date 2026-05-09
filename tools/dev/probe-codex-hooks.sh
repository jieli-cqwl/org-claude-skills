#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
AUDITOR="$REPO_ROOT/tools/community/audit_codex_hook_trust.py"
AUDIT_CWD="${1:-$REPO_ROOT}"
AUDIT_RC=0

printf 'codex_home=%s\n' "$CODEX_HOME_DIR"
printf 'audit_cwd=%s\n' "$AUDIT_CWD"
printf 'codex_bin=%s\n' "$(command -v codex 2>/dev/null || echo unknown)"
printf 'codex_bin_real=%s\n' "$(python3 - <<'PY'
import os
import shutil

path = shutil.which("codex")
print(os.path.realpath(path) if path else "unknown")
PY
)"
printf 'hook_readiness=trust-status\n'

set +e
python3 "$AUDITOR" \
  --codex-home "$CODEX_HOME_DIR" \
  --cwd "$AUDIT_CWD" \
  --require-ready \
  --require-all-enabled \
  --expected-command "bash $CODEX_HOME_DIR/hooks/managed/block_dangerous.sh" \
  --expected-command "python3 $CODEX_HOME_DIR/hooks/managed/context_contract_validator.py" \
  --expected-command "python3 $CODEX_HOME_DIR/hooks/managed/codex_user_prompt_submit.py" \
  --expected-command "python3 $CODEX_HOME_DIR/hooks/managed/codex_stop_dispatch.py"
AUDIT_RC=$?
set -e

if [ "$AUDIT_RC" -ne 0 ]; then
  printf 'codex hooks trust audit failed (rc=%s)\n' "$AUDIT_RC" >&2
  exit "$AUDIT_RC"
fi
