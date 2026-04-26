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

write_registry() {
  local repo="$1"
  mkdir -p "$repo/contracts"
  cat >"$repo/contracts/active-doc-scope.yaml" <<'YAML'
version: 2
context_contract_phase: bootstrap
scope_entries:
  - feature_path: docs/sample
    mode: small-chain
    management_status: managed
    primary_workset_relpath: 2026-04-26-sample
YAML
}

write_multi_registry() {
  local repo="$1"
  mkdir -p "$repo/contracts"
  cat >"$repo/contracts/active-doc-scope.yaml" <<'YAML'
version: 2
context_contract_phase: bootstrap
scope_entries:
  - feature_path: docs/first
    mode: small-chain
    management_status: managed
    primary_workset_relpath: 2026-04-26-first
  - feature_path: docs/second
    mode: small-chain
    management_status: managed
    primary_workset_relpath: 2026-04-26-second
YAML
}

write_workset() {
  local repo="$1"
  local stage="$2"
  local mode="$3"
  local body="$4"
  write_feature_workset "$repo" sample 2026-04-26-sample "$stage" "$mode" "$body"
}

write_feature_workset() {
  local repo="$1"
  local feature_name="$2"
  local workset_name="$3"
  local stage="$4"
  local mode="$5"
  local body="$6"
  local feature="$repo/docs/$feature_name"
  local workset="$feature/$workset_name"
  mkdir -p "$workset"
  cat >"$feature/worklog.md" <<MD
# Sample Worklog

## 2026-04-26 08:00

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: $stage
- scope_ref: $workset_name/tasks.md
- handoff_status: doing
- state_ref: $workset_name/tasks.md
- next: route
- next_ref: $workset_name/execution-routing-input.json
MD
  cat >"$workset/tasks.md" <<'MD'
# Tasks

## Acceptance Checklist
- [ ] T1 Build auth service
  - AC: Auth service works.
  - Traces: G1
  - Depends: -
  - Complexity: simple
MD
  cat >"$workset/plan.md" <<'MD'
# Plan

### Task 1: Auth [T1]
Context: Auth service.

1. [T1] Run auth test
MD
  cat >"$workset/execution-routing-input.json" <<JSON
{
  "schema_version": 1,
  "requested_mode": "$mode",
  "tasks": $body
}
JSON
}

run_hook() {
  local repo="$1"
  local out="$2"
  python3 "$ROOT/shared/hooks/managed/small_chain_execution_router.py" <<JSON >"$out"
{"cwd":"$repo","stop_hook_active":true}
JSON
}

SERIAL_TASKS='[
  {
    "task_id": "T1",
    "depends": [],
    "exclusive_files": ["src/auth/login.py"],
    "shared_files": [],
    "proving_commands": ["pytest tests/auth/test_login.py"],
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
  }
]'

mkdir -p "$TMP_DIR/no-contract"
run_hook "$TMP_DIR/no-contract" "$TMP_DIR/no-contract.out"
assert_present "{}" "$TMP_DIR/no-contract.out"

repo="$TMP_DIR/non-plan"
write_registry "$repo"
write_workset "$repo" entry serial "$SERIAL_TASKS"
run_hook "$repo" "$TMP_DIR/non-plan.out"
assert_present "{}" "$TMP_DIR/non-plan.out"

repo="$TMP_DIR/serial"
write_registry "$repo"
write_workset "$repo" plan serial "$SERIAL_TASKS"
run_hook "$repo" "$TMP_DIR/serial.out"
assert_present '"continue": false' "$TMP_DIR/serial.out"
assert_present 'decision=serial' "$TMP_DIR/serial.out"
test -f "$repo/docs/sample/2026-04-26-sample/execution-route.json" || fail "route output missing"

repo="$TMP_DIR/blocked"
write_registry "$repo"
write_workset "$repo" plan parallel "$BLOCKED_TASKS"
run_hook "$repo" "$TMP_DIR/blocked.out"
assert_present '"continue": false' "$TMP_DIR/blocked.out"
assert_present 'routing blocked' "$TMP_DIR/blocked.out"
assert_present '"decision": "blocked"' "$repo/docs/sample/2026-04-26-sample/execution-route.json"

repo="$TMP_DIR/missing-input"
write_registry "$repo"
write_workset "$repo" plan serial "$SERIAL_TASKS"
rm "$repo/docs/sample/2026-04-26-sample/execution-routing-input.json"
run_hook "$repo" "$TMP_DIR/missing-input.out"
assert_present '"continue": false' "$TMP_DIR/missing-input.out"
assert_present 'routing blocked' "$TMP_DIR/missing-input.out"
assert_present '"decision": "blocked"' "$repo/docs/sample/2026-04-26-sample/execution-route.json"

repo="$TMP_DIR/multi-active"
write_multi_registry "$repo"
write_feature_workset "$repo" first 2026-04-26-first entry serial "$SERIAL_TASKS"
write_feature_workset "$repo" second 2026-04-26-second plan serial "$SERIAL_TASKS"
run_hook "$repo/docs/second" "$TMP_DIR/multi-active.out"
assert_present '"continue": false' "$TMP_DIR/multi-active.out"
assert_present 'docs/second/2026-04-26-second/execution-route.json' "$TMP_DIR/multi-active.out"
test -f "$repo/docs/second/2026-04-26-second/execution-route.json" || fail "second route output missing"
test ! -f "$repo/docs/first/2026-04-26-first/execution-route.json" || fail "first route should not be selected"

assert_present '"id": "small-chain-execution-router"' "$ROOT/shared/hooks/registry.json"
assert_present '"command_rel": "hooks/managed/small_chain_execution_router.py"' "$ROOT/shared/hooks/registry.json"

echo "[PASS] small-chain execution router hook"
