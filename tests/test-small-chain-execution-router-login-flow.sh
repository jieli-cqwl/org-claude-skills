#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Fq "$pattern" "$file" || {
    cat "$file" >&2
    fail "expected pattern missing: $pattern"
  }
}

json_value() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data
for part in sys.argv[2].split("."):
    if isinstance(value, list):
        value = value[int(part)]
    else:
        value = value[part]
print(value)
PY
}

assert_json_value() {
  local file="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$(json_value "$file" "$key")"
  [ "$actual" = "$expected" ] || fail "expected $key=$expected, got $actual"
}

repo="$TMP_DIR/repo"
feature="$repo/docs/login-fixture"
workset="$feature/2026-04-26-login"
mkdir -p "$workset" "$repo/contracts"

cat >"$repo/contracts/active-doc-scope.yaml" <<'YAML'
version: 2
context_contract_phase: bootstrap
scope_entries:
  - feature_path: docs/login-fixture
    mode: small-chain
    management_status: managed
    primary_workset_relpath: 2026-04-26-login
YAML

cat >"$feature/worklog.md" <<'MD'
# Login Fixture Worklog

## 2026-04-26 09:00

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: plan
- scope_ref: 2026-04-26-login/tasks.md
- handoff_status: doing
- state_ref: 2026-04-26-login/tasks.md
- next: route login fixture
- next_ref: 2026-04-26-login/execution-routing-input.json
MD

cp "$ROOT/tests/fixtures/small-chain-execution-router/login/design.md" "$workset/design.md"
cp "$ROOT/tests/fixtures/small-chain-execution-router/login/tasks.md" "$workset/tasks.md"
cp "$ROOT/tests/fixtures/small-chain-execution-router/login/plan.md" "$workset/plan.md"
cp "$ROOT/tests/fixtures/small-chain-execution-router/login/execution-routing-input.json" "$workset/execution-routing-input.json"

python3 "$ROOT/shared/hooks/managed/small_chain_execution_router.py" <<JSON >"$TMP_DIR/hook.out"
{"cwd":"$repo","stop_hook_active":true}
JSON

assert_present '"continue": false' "$TMP_DIR/hook.out"
assert_present 'decision=parallel' "$TMP_DIR/hook.out"

route="$workset/execution-route.json"
test -f "$route" || fail "execution-route.json missing"
assert_json_value "$route" decision parallel
assert_json_value "$route" worktree_policy per_task_worktree
assert_json_value "$route" parallel_groups.0.0 T1
assert_json_value "$route" parallel_groups.1.0 T2

python3 - "$workset/execution-routing-input.json" <<'PY'
import json
import sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["tasks"][1]["exclusive_files"].append("app/ui/login_totp_prompt.py")
open(path, "w", encoding="utf-8").write(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

if python3 "$ROOT/tools/community/small_chain_execution_router.py" \
  --repo-root "$repo" \
  --feature-path docs/login-fixture \
  --workset 2026-04-26-login >"$TMP_DIR/stale.out"; then
  fail "mutated route input should block stale route reuse"
fi

assert_json_value "$route" decision blocked
assert_present 'stale_existing_execution_route' "$route"
assert_present 'routing_input_hash' "$route"

echo "[PASS] small-chain execution router login flow"
