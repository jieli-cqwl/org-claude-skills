#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/shared/hooks/registry.json"
WRAPPER="$ROOT/shared/hooks/managed/context_contract_validator.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

grep -Fq 'validate_context_contract.py' "$ROOT/tools/dev/validate-contracts.sh" \
  || fail "validate-contracts must call context validator"
grep -Fq '"id": "context-contract-validator"' "$REGISTRY" \
  || fail "hook registry missing context-contract-validator"
grep -Fq 'hooks/managed/context_contract_validator.sh' "$REGISTRY" \
  || fail "hook registry missing context validator wrapper"
[ -f "$WRAPPER" ] || fail "missing context contract validator wrapper"

bash "$WRAPPER" <<JSON >/tmp/context_hook_valid.out
{"cwd":"$ROOT"}
JSON
grep -Fq '"decision": "pass"' /tmp/context_hook_valid.out || {
  cat /tmp/context_hook_valid.out >&2
  fail "wrapper should pass valid fixture"
}

bash "$WRAPPER" <<JSON >/tmp/context_hook_skip.out
{"cwd":"$ROOT/tests/fixtures/context-contract"}
JSON
grep -Fq '"decision":"skip"' /tmp/context_hook_skip.out || {
  cat /tmp/context_hook_skip.out >&2
  fail "wrapper should skip roots without scope registry"
}

python3 "$ROOT/tools/community/render_hook_registry.py" codex-hooks \
  --registry "$REGISTRY" \
  --runtime-home /tmp/org-skills-runtime >/tmp/context_codex_hooks.json
grep -Fq 'context_contract_validator.sh' /tmp/context_codex_hooks.json \
  || fail "rendered Codex hooks missing context contract validator"
grep -Fq 'codex_stop_dispatch.py' /tmp/context_codex_hooks.json \
  || fail "rendered Codex hooks must keep stop dispatcher"

python3 "$ROOT/tools/community/render_hook_registry.py" claude-settings-fragment \
  --registry "$REGISTRY" \
  --runtime-home /tmp/org-skills-runtime >/tmp/context_claude_hooks.json
grep -Fq 'context_contract_validator.sh' /tmp/context_claude_hooks.json \
  || fail "rendered Claude hooks missing context contract validator"

printf '[PASS] context contract hook wiring\n'
