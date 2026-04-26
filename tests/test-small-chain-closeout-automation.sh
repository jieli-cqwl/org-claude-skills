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
  grep -Fq -- "$pattern" "$file" || fail "missing pattern in ${file}: $pattern"
}

assert_absent_path() {
  local path="$1"
  [ ! -e "$path" ] || fail "path should be absent: $path"
}

write_runtime_files() {
  local fixture="$1"
  mkdir -p "$fixture/tools/community" "$fixture/contracts"
  cp "$ROOT/tools/community/runtime_yaml.py" "$fixture/tools/community/runtime_yaml.py"
  cp "$ROOT/tools/community/check_task_plan_consistency.py" "$fixture/tools/community/check_task_plan_consistency.py"
  cp "$ROOT/tools/community/update_active_doc_scope.py" "$fixture/tools/community/update_active_doc_scope.py"
  cp "$ROOT/tools/community/validate_context_contract.py" "$fixture/tools/community/validate_context_contract.py"
  cp "$ROOT/tools/community/canonical_ref_resolver.py" "$fixture/tools/community/canonical_ref_resolver.py"
  cat >"$fixture/contracts/context-artifact-ownership.yaml" <<'YAML'
version: 1
repo_owners:
  context_registry_owner: runtime-maintainers
  context_contract_owner: runtime-maintainers
  context_validator_owner: runtime-maintainers
artifacts:
  - artifact_id: scope_registry
    path: contracts/active-doc-scope.yaml
    artifact_owner: context_registry_owner
    update_triggers: [bootstrap]
    mechanical_checks: [schema]
  - artifact_id: context_artifact_ownership
    path: contracts/context-artifact-ownership.yaml
    artifact_owner: context_contract_owner
    update_triggers: [owner_model_change]
    mechanical_checks: [schema]
  - artifact_id: context_validator
    path: tools/community/validate_context_contract.py
    artifact_owner: context_validator_owner
    update_triggers: [validator_rule_change]
    mechanical_checks: [schema]
waiver_approvers:
  scope_registry: context_registry_owner
  context_artifact_ownership: context_contract_owner
  context_validator: context_validator_owner
YAML
}

write_scope_registry() {
  local fixture="$1"
  cat >"$fixture/contracts/active-doc-scope.yaml" <<'YAML'
version: 2
context_contract_phase: bootstrap
record_contract:
  required: [feature_path, mode, management_status, layout, entry_ref, context_owner]
  bootstrap_compat_required: [status, owner, rollout_phase]
  enums:
    mode: [small-chain, standard-chain]
    management_status: [legacy, managed, migrated]
    status: [legacy, managed, migrated]
    layout: [dated-workset, phase-tree]
    context_contract_phase: [bootstrap, enforce, cleanup]
  conditional_required:
    dated-workset: [primary_workset_relpath]
    legacy: [archive_ref, archived_at]
  compatibility_map:
    status: management_status
    owner: context_owner
    primary_workset_relpath: bootstrap_dated_workset
scope_entries:
  - feature_path: docs/sample-feature
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-26-sample
    context_owner: feature-runtime-owner
    owner: feature-runtime-owner
YAML
}

write_workset() {
  local fixture="$1"
  local feature="$fixture/docs/sample-feature"
  local workset="$feature/2026-04-26-sample"
  mkdir -p "$workset"
  cat >"$feature/worklog.md" <<'MD'
# Sample Feature Worklog

## 2026-04-26 04:00

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: verify
- scope_ref: 2026-04-26-sample/verify-change-report.md
- handoff_status: done
- state_ref: 2026-04-26-sample/tasks.md#T1
- next: verify-change passed; closeout automation may create a PR.
- next_ref: 2026-04-26-sample/plan.md#T1
MD
  cat >"$feature/CHANGELOG.md" <<'MD'
# Changelog
MD
  cat >"$workset/design.md" <<'MD'
# Sample Design

## Why
Automate closeout safely.

## Scope
- In scope: deterministic closeout.
- Out of scope: model execution from hooks.
MD
  cat >"$workset/tasks.md" <<'MD'
# Tasks

## Acceptance Checklist
- [x] T1 Sample closeout
  - AC: Sample task is complete.
  - Traces: G1
  - Depends: -
  - Complexity: simple
MD
  cat >"$workset/plan.md" <<'MD'
# Sample Plan

### Task 1: Sample [T1]
Context: Sample task for closeout automation.

1. [T1] Run sample verification
MD
  cat >"$workset/verify-change-report.md" <<'MD'
# Verify Change Report

## Status
- PASS

## CRITICAL
- none

## WARNING
- none

## SUGGESTION
- none

## Evidence
- fixture
MD
}

write_fake_gh() {
  mkdir -p "$TMP_DIR/bin"
  cat >"$TMP_DIR/bin/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >>"${FAKE_GIT_LOG:?}"
if [ "$1 $2" = "branch --show-current" ]; then
  printf 'codex/sample-closeout\n'
  exit 0
fi
if [ "$1" = "push" ]; then
  exit 0
fi
printf 'unexpected git call: %s\n' "$*" >&2
exit 1
SH
  cat >"$TMP_DIR/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >>"${FAKE_GH_LOG:?}"
if [ "$1 $2" = "pr create" ]; then
  printf 'https://github.example/org/repo/pull/42\n'
  exit 0
fi
if [ "$1 $2" = "pr merge" ]; then
  exit 0
fi
if [ "$1 $2" = "pr view" ]; then
  printf '%s\n' "${FAKE_GH_STATE:-MERGED}"
  exit 0
fi
printf 'unexpected gh call: %s\n' "$*" >&2
exit 1
SH
  chmod +x "$TMP_DIR/bin/gh"
  chmod +x "$TMP_DIR/bin/git"
}

make_fixture() {
  local fixture="$1"
  mkdir -p "$fixture"
  write_runtime_files "$fixture"
  write_scope_registry "$fixture"
  write_workset "$fixture"
}

HELPER="$ROOT/tools/community/small_chain_closeout.py"
FIXTURE="$TMP_DIR/repo"
FAKE_GH_LOG="$TMP_DIR/gh.log"
FAKE_GIT_LOG="$TMP_DIR/git.log"
export FAKE_GH_LOG
export FAKE_GIT_LOG

make_fixture "$FIXTURE"
write_fake_gh

python3 "$HELPER" status --repo-root "$FIXTURE" --feature docs/sample-feature >"$TMP_DIR/status.out"
assert_present "decision: create_pr" "$TMP_DIR/status.out"

PATH="$TMP_DIR/bin:$PATH" python3 "$HELPER" create-pr --repo-root "$FIXTURE" --feature docs/sample-feature >"$TMP_DIR/create-pr.out"
assert_present "decision: wait_for_merge" "$TMP_DIR/create-pr.out"
assert_present "pr_url: https://github.example/org/repo/pull/42" "$TMP_DIR/create-pr.out"
assert_present "git push -u origin codex/sample-closeout" "$FAKE_GIT_LOG"
assert_present "gh pr create" "$FAKE_GH_LOG"
assert_present "--head codex/sample-closeout --base main" "$FAKE_GH_LOG"
assert_present "gh pr merge --auto --squash https://github.example/org/repo/pull/42" "$FAKE_GH_LOG"
test -f "$FIXTURE/docs/sample-feature/2026-04-26-sample/closeout-state.json" || fail "closeout state should be persisted"

cp "$FIXTURE/docs/sample-feature/2026-04-26-sample/tasks.md" "$FIXTURE/docs/sample-feature/2026-04-26-sample/tasks.md.bak"
python3 - "$FIXTURE/docs/sample-feature/2026-04-26-sample/tasks.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("- [x] T1", "- [ ] T1"), encoding="utf-8")
PY
if PATH="$TMP_DIR/bin:$PATH" python3 "$HELPER" create-pr --repo-root "$FIXTURE" --feature docs/sample-feature >"$TMP_DIR/incomplete.out" 2>&1; then
  cat "$TMP_DIR/incomplete.out" >&2
  fail "incomplete tasks should block create-pr"
fi
assert_present "decision: block" "$TMP_DIR/incomplete.out"
assert_present "reason: incomplete_tasks" "$TMP_DIR/incomplete.out"
mv "$FIXTURE/docs/sample-feature/2026-04-26-sample/tasks.md.bak" "$FIXTURE/docs/sample-feature/2026-04-26-sample/tasks.md"

FAKE_GH_STATE=OPEN PATH="$TMP_DIR/bin:$PATH" python3 "$HELPER" archive --repo-root "$FIXTURE" --feature docs/sample-feature >"$TMP_DIR/unmerged.out" 2>&1 && {
  cat "$TMP_DIR/unmerged.out" >&2
  fail "unmerged PR should block archive"
}
assert_present "decision: block" "$TMP_DIR/unmerged.out"
assert_present "reason: pr_not_merged" "$TMP_DIR/unmerged.out"

PATH="$TMP_DIR/bin:$PATH" python3 "$HELPER" archive --repo-root "$FIXTURE" --feature docs/sample-feature --merged >"$TMP_DIR/archive.out"
assert_present "decision: done" "$TMP_DIR/archive.out"
assert_present "archived_to: docs/archive/sample-feature/2026-04-26-sample" "$TMP_DIR/archive.out"
test -d "$FIXTURE/docs/archive/sample-feature/2026-04-26-sample" || fail "archive directory missing"
test -f "$FIXTURE/docs/archive/sample-feature/2026-04-26-sample/worklog.md" || fail "archived worklog missing"
assert_absent_path "$FIXTURE/docs/sample-feature/2026-04-26-sample"
assert_present "management_status: legacy" "$FIXTURE/contracts/active-doc-scope.yaml"
assert_present "archive_ref: docs/archive/sample-feature/2026-04-26-sample" "$FIXTURE/contracts/active-doc-scope.yaml"
assert_present "Small-chain closeout automation archived" "$FIXTURE/docs/sample-feature/CHANGELOG.md"
python3 "$FIXTURE/tools/community/validate_context_contract.py" --repo-root "$FIXTURE" >/dev/null

assert_present "tools/community/small_chain_closeout.py" "$ROOT/README.md"
assert_present "pr_auto_merge" "$ROOT/contracts/small-chain.yaml"
assert_present "ci_and_branch_protection" "$ROOT/contracts/superpowers-boundary.yaml"
assert_present "archive_after_merge" "$ROOT/contracts/small-chain.yaml"

echo "[PASS] small-chain closeout automation"
