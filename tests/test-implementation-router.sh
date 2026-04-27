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

json_value() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data
for part in sys.argv[2].split("."):
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

write_workset() {
  local repo="$1"
  local mode="$2"
  local body="$3"
  local workset="$repo/docs/sample/2026-04-26-sample"
  mkdir -p "$workset" "$repo/contracts"
  cat >"$repo/contracts/active-doc-scope.yaml" <<'YAML'
version: 2
context_contract_phase: bootstrap
scope_entries:
  - feature_path: docs/sample
    mode: small-chain
    management_status: managed
    primary_workset_relpath: 2026-04-26-sample
YAML
  cat >"$workset/tasks.md" <<'MD'
# Tasks

## Acceptance Checklist
- [ ] T1 Build auth service
  - AC: Auth service works.
  - Traces: G1
  - Depends: -
  - Complexity: simple
- [ ] T2 Build login form
  - AC: Login form works.
  - Traces: G1
  - Depends: -
  - Complexity: simple
MD
  cat >"$workset/plan.md" <<'MD'
# Plan

### Task 1: Auth [T1]
Context: Auth service.

1. [T1] Run auth test

### Task 2: UI [T2]
Context: Login form.

1. [T2] Run UI test
MD
  cat >"$workset/execution-routing-input.json" <<JSON
{
  "schema_version": 1,
  "requested_mode": "$mode",
  "tasks": $body
}
JSON
}

run_router() {
  local repo="$1"
  shift
  python3 "$ROOT/tools/community/implementation_router.py" \
    --repo-root "$repo" \
    --feature-path docs/sample \
    --workset 2026-04-26-sample \
    "$@" >"$repo/router.out"
}

SERIAL_TASKS='[
  {
    "task_id": "T1",
    "depends": [],
    "exclusive_files": ["contracts/small-chain.yaml"],
    "shared_files": [],
    "proving_commands": ["bash tests/test-small-chain-boundary.sh"],
    "touches_contract_grade": true
  },
  {
    "task_id": "T2",
    "depends": ["T1"],
    "exclusive_files": ["docs/login-form.md"],
    "shared_files": [],
    "proving_commands": ["bash tests/test-small-chain-boundary.sh"],
    "touches_contract_grade": false
  }
]'

PARALLEL_TASKS='[
  {
    "task_id": "T1",
    "depends": [],
    "exclusive_files": ["src/auth/login.py"],
    "shared_files": [],
    "proving_commands": ["pytest tests/auth/test_login.py"],
    "touches_contract_grade": false
  },
  {
    "task_id": "T2",
    "depends": [],
    "exclusive_files": ["src/ui/login_form.py"],
    "shared_files": [],
    "proving_commands": ["pytest tests/ui/test_login_form.py"],
    "touches_contract_grade": false
  }
]'

BLOCKED_TASKS='[
  {
    "task_id": "T1",
    "depends": [],
    "exclusive_files": ["contracts/small-chain.yaml"],
    "shared_files": [],
    "proving_commands": ["bash tests/test-small-chain-boundary.sh"],
    "touches_contract_grade": true
  },
  {
    "task_id": "T2",
    "depends": [],
    "exclusive_files": ["src/ui/login_form.py"],
    "shared_files": ["README.md"],
    "proving_commands": ["pytest tests/ui/test_login_form.py"],
    "touches_contract_grade": false
  }
]'

CONTRACT_GRADE_TASKS='[
  {
    "task_id": "T1",
    "depends": [],
    "exclusive_files": ["src/auth/login.py"],
    "shared_files": [],
    "proving_commands": ["pytest tests/auth/test_login.py"],
    "touches_contract_grade": true
  },
  {
    "task_id": "T2",
    "depends": [],
    "exclusive_files": ["src/ui/login_form.py"],
    "shared_files": [],
    "proving_commands": ["pytest tests/ui/test_login_form.py"],
    "touches_contract_grade": false
  }
]'

UNKNOWN_TASKS='[
  {
    "task_id": "T99",
    "depends": [],
    "exclusive_files": ["src/auth/login.py"],
    "shared_files": [],
    "proving_commands": ["pytest tests/auth/test_login.py"],
    "touches_contract_grade": false
  }
]'

repo="$TMP_DIR/serial"
write_workset "$repo" serial "$SERIAL_TASKS"
run_router "$repo"
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision serial
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" worktree_policy single_feature_worktree

repo="$TMP_DIR/parallel"
write_workset "$repo" parallel "$PARALLEL_TASKS"
run_router "$repo"
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision parallel
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" worktree_policy per_task_worktree
perl -0pi -e 's/- \\[ \\] T1/- [x] T1/' "$repo/docs/sample/2026-04-26-sample/tasks.md"
run_router "$repo"
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision parallel

repo="$TMP_DIR/blocked"
write_workset "$repo" parallel "$BLOCKED_TASKS"
if run_router "$repo"; then
  fail "blocked route should return non-zero"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked
grep -Fq 'high_risk_common_surface' "$repo/docs/sample/2026-04-26-sample/execution-route.json" || fail "missing high-risk block"
grep -Fq 'shared_writes_present' "$repo/docs/sample/2026-04-26-sample/execution-route.json" || fail "missing shared write block"

repo="$TMP_DIR/contract-grade"
write_workset "$repo" parallel "$CONTRACT_GRADE_TASKS"
if run_router "$repo"; then
  fail "contract-grade route should return non-zero"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked
grep -Fq 'contract_grade_surface_present' "$repo/docs/sample/2026-04-26-sample/execution-route.json" || fail "missing contract-grade block"

repo="$TMP_DIR/missing-input"
write_workset "$repo" serial "$SERIAL_TASKS"
rm "$repo/docs/sample/2026-04-26-sample/execution-routing-input.json"
if run_router "$repo"; then
  fail "missing route input should return non-zero"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked

repo="$TMP_DIR/unknown-task"
write_workset "$repo" parallel "$UNKNOWN_TASKS"
if run_router "$repo"; then
  fail "unknown route task id should return non-zero"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked
grep -Fq 'unknown task ids' "$repo/docs/sample/2026-04-26-sample/execution-route.json" || fail "missing unknown task id block"

repo="$TMP_DIR/stale"
write_workset "$repo" parallel "$PARALLEL_TASKS"
run_router "$repo"
python3 - "$repo/docs/sample/2026-04-26-sample/execution-routing-input.json" <<'PY'
import json
import sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["tasks"][0]["exclusive_files"] = ["src/auth/changed_login.py"]
open(path, "w", encoding="utf-8").write(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
if run_router "$repo"; then
  fail "stale route should return non-zero"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked
grep -Fq 'routing_input_hash' "$repo/docs/sample/2026-04-26-sample/execution-route.json" || fail "missing stale routing input hash block"
if run_router "$repo"; then
  fail "stale route should remain blocked until force-refresh"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked

repo="$TMP_DIR/unreadable-route"
write_workset "$repo" parallel "$PARALLEL_TASKS"
printf '{' >"$repo/docs/sample/2026-04-26-sample/execution-route.json"
if run_router "$repo"; then
  fail "unreadable existing route should return non-zero"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked
grep -Fq 'existing_route_unreadable' "$repo/docs/sample/2026-04-26-sample/execution-route.json" || fail "missing unreadable route block"
if run_router "$repo"; then
  fail "unreadable route block should remain blocked until force-refresh"
fi
assert_json_value "$repo/docs/sample/2026-04-26-sample/execution-route.json" decision blocked

echo "[PASS] implementation router"
