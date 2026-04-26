# Active Context Handoff Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build the Phase 1 active context handoff protocol so a new window can recover managed work from scope registry to worklog to true artifacts, with validator, hook, recovery, audit, and tests proving the contract.

**Architecture:** The scope registry remains the repository-level managed-feature index; root `worklog.md` remains the single feature handoff entry; small-chain and standard-chain artifacts remain the truth for actual progress. One context validator owns mechanical checks and is invoked by recovery, lifecycle tests, contract validation, hooks, and audit paths with mode-specific severity.

**Tech Stack:** Bash test harness, Python 3 standard library, YAML via existing `tools/community/runtime_yaml.py`, existing hook registry renderer, existing canonical artifact resolver, Markdown contract docs.

---

## File Boundary Map

Core landing files:
- Modify: `contracts/active-doc-scope.yaml`
- Modify: `contracts/small-chain.yaml`
- Modify: `contracts/standard-chain.yaml`
- Modify: `README.md`
- Create: `tools/community/validate_context_contract.py`
- Create: `tools/community/recover_context.py`
- Create: `tools/community/update_active_doc_scope.py`
- Create: `tests/fixtures/context-contract/`
- Create: `tests/test-context-contract-validator.sh`
- Create: `tests/test-context-recovery.sh`
- Create: `tests/test-active-doc-scope-lifecycle.sh`

Ownership, hook, and audit files:
- Create: `contracts/context-artifact-ownership.yaml`
- Create: `tools/dev/run-context-contract-audit.sh`
- Modify: `tools/dev/validate-contracts.sh`
- Modify: `tools/validate-contracts.sh`
- Modify: `shared/hooks/registry.json`
- Modify: `tools/community/render_hook_registry.py`
- Modify: `shared/hooks/managed/codex_stop_dispatch.py`
- Create: `tests/test-context-contract-audit.sh`

Consumer sync files:
- Modify: `community/superpowers/skills/brainstorming/SKILL.md`
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Modify: `community/superpowers/skills/using-git-worktrees/SKILL.md`
- Modify: `community/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `community/superpowers/skills/verification-before-completion/SKILL.md`
- Modify: `community/superpowers/skills/verify-change/SKILL.md`
- Modify: `community/superpowers/skills/finishing-a-development-branch/SKILL.md`
- Modify: `community/superpowers/skills/archive/SKILL.md`
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/fix/SKILL.md`
- Modify: `shared/skills/consistency-audit/SKILL.md`
- Modify: `docs/feature--doc-governance--context-recovery/worklog.md`

## Task 1: Bootstrap Scope Registry And Contract Wording [T1]

Context: This task lands the dual-read bootstrap contract before any validator enforces it. It keeps v1 compatibility fields visible while making `management_status`, `context_owner`, `entry_ref`, and `context_contract_phase` the target vocabulary.

Files:
- Modify: `contracts/active-doc-scope.yaml`
- Modify: `contracts/small-chain.yaml`
- Modify: `contracts/standard-chain.yaml`
- Modify: `README.md`
- Create or Modify: `tests/test-active-doc-scope-lifecycle.sh`

1. [T1] Write the failing lifecycle assertions for registry version 2 bootstrap.

Create `tests/test-active-doc-scope-lifecycle.sh` with this shape if it does not exist; extend it if it exists:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -Eq "$pattern" "$file" || fail "$label"
}

assert_present '^version: 2$' "$ROOT/contracts/active-doc-scope.yaml" "active scope registry must be version 2"
assert_present '^context_contract_phase: bootstrap$' "$ROOT/contracts/active-doc-scope.yaml" "registry must declare bootstrap phase"
assert_present 'management_status' "$ROOT/contracts/active-doc-scope.yaml" "target management_status field missing"
assert_present 'context_owner' "$ROOT/contracts/active-doc-scope.yaml" "target context_owner field missing"
assert_present 'entry_ref' "$ROOT/contracts/active-doc-scope.yaml" "target entry_ref field missing"
assert_present 'status.*compatibility|compatibility.*status|v1 compatibility' "$ROOT/contracts/active-doc-scope.yaml" "bootstrap compatibility wording missing"
assert_present 'scope registry|active-doc-scope' "$ROOT/README.md" "README must mention scope registry"
assert_present 'worklog.md' "$ROOT/contracts/small-chain.yaml" "small-chain contract must mention worklog entry"
assert_present 'canonical:' "$ROOT/contracts/standard-chain.yaml" "standard-chain contract must mention canonical active ref grammar"

printf '[PASS] active doc scope lifecycle bootstrap\n'
```

2. [T1] Run the test and record the expected failure.

Run: `bash tests/test-active-doc-scope-lifecycle.sh`

Expected: FAIL on `version: 2`, `context_contract_phase`, or target field assertions before the contract files are updated.

3. [T1] Update `contracts/active-doc-scope.yaml` to the bootstrap target shape.

Use this exact top-level structure and keep the current commented examples only if they use both target and compatibility fields:

```yaml
# 活跃文档受管作用域真源
#
# Scope registry contract:
# - Only entries with management_status in [managed, migrated] are active candidates.
# - `status`, `owner`, and `primary_workset_relpath` are bootstrap compatibility fields.
# - The registry records managed scope only; progress lives in worklog and true artifacts.

version: 2
context_contract_phase: bootstrap

record_contract:
  required:
    - feature_path
    - mode
    - management_status
    - layout
    - entry_ref
    - context_owner
  bootstrap_compatibility_required:
    - status
    - owner
    - primary_workset_relpath
  enums:
    mode: [small-chain, standard-chain]
    management_status: [legacy, managed, migrated]
    status: [legacy, managed, migrated]
    layout: [dated-workset, phase-tree]
    context_contract_phase: [bootstrap, enforce, cleanup]
```

4. [T1] Update `contracts/small-chain.yaml` so the entry contract names the scope registry and stage vocabulary.

Add or align these fields near the existing active scope block:

```yaml
active_scope:
  registry: contracts/active-doc-scope.yaml
  active_status_field: management_status
  bootstrap_compatibility_status_field: status
  active_status_values: [managed, migrated]
  entry_ref: worklog.md
  allowed_stages: [entry, plan, env, execute, verify-preflight, verify, integrate, finish, blocked]
  true_progress_artifacts: [design.md, tasks.md, plan.md]
```

5. [T1] Update `contracts/standard-chain.yaml` with the recovery contract note.

Add a concise contract block:

```yaml
active_context_handoff:
  registry: contracts/active-doc-scope.yaml
  entry_ref: worklog.md
  state_ref_grammar: canonical:{registry_relpath}::artifact://{artifact_type}/{artifact_id}@{version}#{anchor}
  stage_truth: delivery-state.current_stage
  active_artifact_truth: artifact-registry.active_revision_id
```

6. [T1] Update `README.md` with the same vocabulary.

Add a short section containing these exact terms: `scope registry`, `management_status`, `handoff_status`, `context_owner`, `artifact_owner`, `canonical:`.

7. [T1] Run the lifecycle test again.

Run: `bash tests/test-active-doc-scope-lifecycle.sh`

Expected: PASS with `[PASS] active doc scope lifecycle bootstrap`.

## Task 2: Context Contract Validator And Fixtures [T2]

Context: The validator is the single mechanical rules engine for registry, worklog, refs, task-plan mapping, standard-chain active refs, ownership contract shape, and failure output. It must not rewrite files.

Files:
- Create: `tools/community/validate_context_contract.py`
- Create: `tests/fixtures/context-contract/validator/`
- Create: `tests/test-context-contract-validator.sh`
- Read: `tools/community/runtime_yaml.py`
- Read: `tools/community/canonical_ref_resolver.py`
- Read: `tools/community/check_task_plan_consistency.py`

1. [T2] Create passing and failing fixture directories.

Create this fixture layout:

```text
tests/fixtures/context-contract/validator/
  valid-small-chain/
    contracts/active-doc-scope.yaml
    contracts/context-artifact-ownership.yaml
    docs/feature--context--small/worklog.md
    docs/feature--context--small/2026-04-25-demo/design.md
    docs/feature--context--small/2026-04-25-demo/tasks.md
    docs/feature--context--small/2026-04-25-demo/plan.md
  invalid-missing-worklog/
  invalid-duplicate-active/
  invalid-small-chain-task-plan-drift/
  invalid-standard-chain-control-ref/
  invalid-blocked-record/
  invalid-ownership-contract/
```

2. [T2] Write the validator CLI skeleton.

Create `tools/community/validate_context_contract.py` with these arguments and decision shape:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from runtime_yaml import load_yaml_file


ACTIVE_STATUSES = {"managed", "migrated"}
PHASES = {"bootstrap", "enforce", "cleanup"}
SMALL_CHAIN_STAGES = {"entry", "plan", "env", "execute", "verify-preflight", "verify", "integrate", "finish", "blocked"}
STANDARD_CHAIN_STAGES = {"PLANNING", "TASK_DISPATCH", "TASK_EXECUTION", "TASK_VERIFICATION", "PHASE_REVIEW", "PHASE_QA", "SIGNOFF_PENDING", "SIGNOFF_RECORDED", "CLOSED", "BLOCKED", "REPLAN_PENDING"}


@dataclass
class Finding:
    decision: str
    reason: str
    path: str
    expected: str
    actual: str = ""


def emit_findings(findings: list[Finding]) -> int:
    if findings:
        print(json.dumps({"decision": "block", "findings": [f.__dict__ for f in findings]}, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps({"decision": "pass", "findings": []}, ensure_ascii=False, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--mode", choices=["blocking", "audit"], default="blocking")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    findings: list[Finding] = []
    validate_repository(root, findings)
    return emit_findings(findings)


if __name__ == "__main__":
    raise SystemExit(main())
```

3. [T2] Implement registry validation.

Add `validate_repository`, `validate_registry`, and `active_entries` functions. Required behavior:

```python
def registry_status(entry: dict[str, Any]) -> str:
    return str(entry.get("management_status") or entry.get("status") or "")


def validate_registry(root: Path, findings: list[Finding]) -> list[dict[str, Any]]:
    registry_path = root / "contracts" / "active-doc-scope.yaml"
    if not registry_path.is_file():
        findings.append(Finding("block", "scope_registry_missing", str(registry_path), "contracts/active-doc-scope.yaml"))
        return []
    data = load_yaml_file(registry_path)
    if data.get("version") != 2:
        findings.append(Finding("block", "scope_registry_version_invalid", str(registry_path), "version: 2", str(data.get("version"))))
    if data.get("context_contract_phase") not in PHASES:
        findings.append(Finding("block", "context_contract_phase_invalid", str(registry_path), "bootstrap|enforce|cleanup", str(data.get("context_contract_phase"))))
    entries = data.get("scope_entries") or []
    active = [entry for entry in entries if registry_status(entry) in ACTIVE_STATUSES]
    seen: set[str] = set()
    for entry in active:
        feature_path = str(entry.get("feature_path") or "")
        if feature_path in seen:
            findings.append(Finding("block", "duplicate_active_feature", str(registry_path), "one active entry per feature_path", feature_path))
        seen.add(feature_path)
    return active
```

4. [T2] Implement worklog parsing and ref validation.

Parse the latest heading block only, require fields `actor`, `context_owner`, `mode`, `stage`, `scope_ref`, `handoff_status`, `state_ref`, `next`, `next_ref`, and validate reachable refs:

```python
RECORD_FIELD = re.compile(r"^- ([a-z_]+):\\s*(.*)$")


def parse_latest_worklog(path: Path, findings: list[Finding]) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    parts = re.split(r"^##\\s+", text, flags=re.MULTILINE)
    if len(parts) < 2:
        findings.append(Finding("block", "worklog_record_missing", str(path), "latest ## timestamp record"))
        return {}
    block = parts[1]
    values: dict[str, str] = {}
    for line in block.splitlines():
        match = RECORD_FIELD.match(line.strip())
        if match:
            values[match.group(1)] = match.group(2).strip()
    return values
```

5. [T2] Implement small-chain task/plan consistency by calling the existing checker.

Use `subprocess.run([sys.executable, str(root / "tools/community/check_task_plan_consistency.py"), str(tasks), str(plan)])` and convert non-zero exit to reason `small_chain_task_plan_drift`.

6. [T2] Implement standard-chain `canonical:` grammar checks.

Reject direct `phase-1/plan.json` style refs for standard-chain worklog records. Accept only:

```python
CANONICAL_REF = re.compile(r"^canonical:(?P<registry>[^:]+)::artifact://(?P<type>[^/]+)/(?P<id>[^@]+)@(?P<version>[^#]+)#(?P<anchor>.+)$")
```

7. [T2] Implement ownership contract checks.

Require `contracts/context-artifact-ownership.yaml` when present in a fixture or repository, and validate each artifact has `artifact_id`, `path`, `artifact_owner`, non-empty `update_triggers`, and non-empty `mechanical_checks`.

8. [T2] Write the shell test for pass and fail fixtures.

Create `tests/test-context-contract-validator.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/tools/community/validate_context_contract.py"
FIX="$ROOT/tests/fixtures/context-contract/validator"

python3 "$VALIDATOR" --root "$FIX/valid-small-chain" >/tmp/context_valid.out
grep -Fq '"decision": "pass"' /tmp/context_valid.out

for name in invalid-missing-worklog invalid-duplicate-active invalid-small-chain-task-plan-drift invalid-standard-chain-control-ref invalid-blocked-record invalid-ownership-contract; do
  if python3 "$VALIDATOR" --root "$FIX/$name" >/tmp/context_invalid.out 2>&1; then
    cat /tmp/context_invalid.out >&2
    exit 1
  fi
  grep -Fq '"decision": "block"' /tmp/context_invalid.out
done

printf '[PASS] context contract validator\n'
```

9. [T2] Run the validator test.

Run: `bash tests/test-context-contract-validator.sh`

Expected: PASS with `[PASS] context contract validator`.

## Task 3: Recovery And Lifecycle Commands [T3]

Context: Recovery is the user-facing proof that a new window can resume from repository files only. Lifecycle helper writes registry entries so manual edits do not become the normal path.

Files:
- Create: `tools/community/recover_context.py`
- Create: `tools/community/update_active_doc_scope.py`
- Create: `tests/fixtures/context-contract/recovery/`
- Create: `tests/test-context-recovery.sh`
- Modify: `tests/test-active-doc-scope-lifecycle.sh`

1. [T3] Create recovery fixtures with active and legacy entries.

Create a fixture root containing:

```text
tests/fixtures/context-contract/recovery/
  contracts/active-doc-scope.yaml
  docs/feature--context--small/worklog.md
  docs/feature--context--small/2026-04-25-demo/tasks.md
  docs/feature--context--small/2026-04-25-demo/plan.md
  docs/feature--context--standard/worklog.md
  docs/feature--context--standard/phase-1/artifact-registry.json
  docs/feature--context--standard/phase-1/delivery-state.json
  docs/archive/feature--context--legacy/worklog.md
```

2. [T3] Implement candidate listing in `recover_context.py`.

Use this output shape:

```python
{
  "decision": "candidates",
  "candidates": [
    {
      "feature_path": "docs/feature--context--small",
      "mode": "small-chain",
      "layout": "dated-workset",
      "context_owner": "feature-runtime-owner",
      "latest_worklog_at": "2026-04-25 10:30",
      "handoff_status": "doing",
      "state_ref": "2026-04-25-demo/tasks.md#T1",
      "next_ref": "2026-04-25-demo/plan.md#T1"
    }
  ]
}
```

3. [T3] Implement exact, basename, fuzzy, and archived selection.

Rules:
- exact `feature_path` selects one active entry.
- exact basename selects one active entry.
- fuzzy match prints candidates and exits non-zero with reason `multiple_candidates` or `ambiguous_candidate`.
- `--archived` enables `legacy` entries.
- active and archived match together returns both groups and exits non-zero.

4. [T3] Implement block output for unreachable refs.

Use the design failure structure:

```json
{
  "decision": "block",
  "reason": "state_ref_unreachable",
  "path": "docs/feature--context--small/worklog.md",
  "expected": "reachable state_ref",
  "actual": "2026-04-25-demo/missing.md"
}
```

5. [T3] Implement `update_active_doc_scope.py`.

Support these commands:

```bash
python3 tools/community/update_active_doc_scope.py bootstrap --root . --phase bootstrap
python3 tools/community/update_active_doc_scope.py adopt --root . --feature-path docs/feature--context--small --mode small-chain --layout dated-workset --workset 2026-04-25-demo --context-owner feature-runtime-owner
python3 tools/community/update_active_doc_scope.py archive --root . --feature-path docs/feature--context--small --archive-ref docs/archive/feature--context--small --archived-at 2026-04-26
python3 tools/community/update_active_doc_scope.py phase --root . --phase enforce
```

6. [T3] Write `tests/test-context-recovery.sh`.

Cover:
- candidate listing sorted by latest worklog time.
- exact feature path recovery.
- basename recovery.
- fuzzy candidate blocking.
- archived explicit lookup.
- active miss with legacy basename.
- active plus archived ambiguity.
- unreachable state ref failure.

7. [T3] Extend lifecycle tests for helper-driven adopt/archive/phase.

Add cases that run `update_active_doc_scope.py` against a temporary fixture and assert the registry state with Python or `grep`.

8. [T3] Run recovery and lifecycle tests.

Run: `bash tests/test-context-recovery.sh && bash tests/test-active-doc-scope-lifecycle.sh`

Expected: both PASS.

## Task 4: Ownership Contract And Audit [T4]

Context: Ownership is the difference between a navigation file and a maintainable handoff contract. Audit must surface long-term risks without mutating files or blocking normal work.

Files:
- Create: `contracts/context-artifact-ownership.yaml`
- Create: `tools/dev/run-context-contract-audit.sh`
- Create: `tests/fixtures/context-contract/audit/`
- Create: `tests/test-context-contract-audit.sh`
- Modify: `tools/community/validate_context_contract.py`

1. [T4] Add the ownership contract.

Create `contracts/context-artifact-ownership.yaml`:

```yaml
version: 1
repo_owners:
  context_registry_owner: runtime-maintainers
  context_contract_owner: runtime-maintainers
  context_validator_owner: runtime-maintainers
artifacts:
  - artifact_id: scope_registry
    path: contracts/active-doc-scope.yaml
    artifact_owner: context_registry_owner
    update_triggers: [bootstrap, adopt, archive, mode_layout_change, context_owner_change]
    mechanical_checks: [schema, path_exists, active_unique, archive_ref_valid]
  - artifact_id: context_artifact_ownership
    path: contracts/context-artifact-ownership.yaml
    artifact_owner: context_contract_owner
    update_triggers: [contract_change]
    mechanical_checks: [schema, owner_present, triggers_present, checks_present]
  - artifact_id: root_worklog
    path: docs/*/worklog.md
    artifact_owner: feature_context_owner
    update_triggers: [stage_change, scope_ref_change, handoff_status_change, state_ref_change, next_ref_change, context_owner_change]
    mechanical_checks: [block_format, required_fields, enum_values, refs_reachable, append_only]
waiver_namespaces:
  context:
    storage: docs/{feature}/contract-waivers.md
    may_cover: [temporary_ref_migration, legacy_field_compatibility, supporting_material_exception]
    must_not_cover: [authority_contract, active_revision_id, delivery_state_stage, sign_off_owner, business_risk_acceptance_owner]
  standard:
    storage: canonical waiver_entries
    may_cover: [business_acceptance, release_acceptance, authority_exception]
```

2. [T4] Extend the validator to check the ownership contract.

Fail with `ownership_contract_missing` when a managed repository lacks the file, and `ownership_artifact_invalid` when any artifact omits required fields.

3. [T4] Implement report-only audit script.

Create `tools/dev/run-context-contract-audit.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tools/community/validate_context_contract.py" --root "$ROOT" --mode audit
```

4. [T4] Implement audit-mode findings in the validator.

In `--mode audit`, keep structural blocking checks as JSON findings but return exit code 0 for stale, long-blocked, expired waiver, supporting material count, and legacy drift findings. Do not write files.

5. [T4] Write `tests/test-context-contract-audit.sh`.

Run the audit against fixtures, assert report-only findings, and prove no fixture changes:

```bash
before="$(git -C "$ROOT" diff -- tests/fixtures/context-contract/audit)"
bash "$ROOT/tools/dev/run-context-contract-audit.sh" >/tmp/context_audit.out
after="$(git -C "$ROOT" diff -- tests/fixtures/context-contract/audit)"
[ "$before" = "$after" ] || exit 1
grep -Fq '"mode": "audit"' /tmp/context_audit.out
printf '[PASS] context contract audit\n'
```

6. [T4] Run validator and audit tests.

Run: `bash tests/test-context-contract-validator.sh && bash tests/test-context-contract-audit.sh`

Expected: both PASS.

## Task 5: Contract Runner And Hook Wiring [T5]

Context: Hook and CI gates must call the same validator. This task wires the validator without copying rules into shell, renderer, or dispatch code.

Files:
- Modify: `tools/dev/validate-contracts.sh`
- Modify: `tools/validate-contracts.sh`
- Modify: `shared/hooks/registry.json`
- Modify: `tools/community/render_hook_registry.py`
- Modify: `shared/hooks/managed/codex_stop_dispatch.py`
- Modify or Create: tests that cover hook registry rendering

1. [T5] Add the validator call to `tools/dev/validate-contracts.sh`.

Add one step near existing contract validations:

```bash
run "context contract validation" python3 "$ROOT/tools/community/validate_context_contract.py" --root "$ROOT" --mode blocking
```

Use the existing `run` helper name and style in that script.

2. [T5] Make `tools/validate-contracts.sh` delegate consistently.

If the root wrapper already delegates to `tools/dev/validate-contracts.sh`, keep it. If it has its own list, add the same context validator command once.

3. [T5] Add a hook registry entry.

Add an entry to `shared/hooks/registry.json` with fields matching existing entries:

```json
{
  "id": "context-contract-validator",
  "phase": "stop",
  "command": "python3 tools/community/validate_context_contract.py --root . --mode blocking",
  "scope": "repository",
  "fail_closed": true,
  "reason": "Active context handoff refs and registry entries must remain mechanically recoverable."
}
```

4. [T5] Update hook rendering only if the registry schema requires a new field.

If `fail_closed` or `scope` already exists, no renderer logic change is needed. If not, extend `tools/community/render_hook_registry.py` to pass through the field and add a test assertion.

5. [T5] Update stop dispatch only for changed-file narrowing.

In `shared/hooks/managed/codex_stop_dispatch.py`, add context-contract validator dispatch only through the registry-generated path. If changed-file narrowing exists, include `contracts/active-doc-scope.yaml`, `contracts/context-artifact-ownership.yaml`, `docs/*/worklog.md`, and `docs/*/*/{design,tasks,plan}.md` as impacted files.

6. [T5] Add a fail-closed fixture proof to tests.

Add or extend a hook/contract test so breaking a fixture registry ref makes `tools/dev/validate-contracts.sh` fail.

7. [T5] Run gate wiring tests.

Run: `bash tests/test-context-contract-validator.sh && bash tests/test-active-doc-scope-lifecycle.sh && bash tests/test-context-contract-audit.sh && bash tools/dev/validate-contracts.sh`

Expected: all PASS on repository state.

## Task 6: Consumer Sync And Real Pilot Registration [T6]

Context: After validator and gates exist, the real feature can become the bootstrap pilot. Consumer skills must use the new vocabulary so future agents recover through the same path.

Files:
- Modify: listed small-chain skill files under `community/superpowers/skills/`
- Modify: listed standard-chain skill files under `shared/skills/`
- Modify: `contracts/active-doc-scope.yaml`
- Modify: `docs/feature--doc-governance--context-recovery/worklog.md`
- Modify: `tests/test-context-recovery.sh`

1. [T6] Update small-chain skill references.

For each small-chain skill, add a concise recovery note:

```markdown
## Active Context Handoff

When resuming a managed feature, recover context through:
`contracts/active-doc-scope.yaml -> docs/{feature}/worklog.md -> true small-chain artifacts`.

Use `management_status in [managed, migrated]` for active candidates. Use `worklog.handoff_status` only as the current handoff item state. For small-chain, `tasks.md` remains completion truth and `plan.md` remains execution truth.
```

2. [T6] Update standard-chain skill references.

For each standard-chain skill, add the standard-chain recovery note:

```markdown
## Active Context Handoff

When resuming a managed standard-chain feature, recover through the root `worklog.md`, then resolve `canonical:` refs through `artifact-registry.active_revision_id`. Do not treat direct `phase-{N}/plan.json` or `tasks.json` paths as active truth unless reached through the active artifact registry.
```

3. [T6] Register the real pilot in `contracts/active-doc-scope.yaml`.

Add this bootstrap entry:

```yaml
  - feature_path: docs/feature--doc-governance--context-recovery
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-active-context-handoff-phase-1
    context_owner: feature-runtime-owner
    owner: feature-runtime-owner
```

4. [T6] Prepend a new root worklog record.

Add a latest record above the existing one:

```markdown
## 2026-04-26 00:00

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: plan
- scope_ref: tasks.md#T1
- handoff_status: doing
- state_ref: 2026-04-25-active-context-handoff-phase-1/tasks.md#T1
- next: Execute T1 bootstrap registry contract work.
- next_ref: 2026-04-25-active-context-handoff-phase-1/plan.md#T1
```

Use the actual local timestamp if project convention requires it; keep the block fields and refs unchanged.

5. [T6] Extend recovery tests to cover the real pilot.

Add a case that runs:

```bash
python3 "$ROOT/tools/community/recover_context.py" --root "$ROOT" --feature docs/feature--doc-governance--context-recovery
```

Assert output contains:
- `"feature_path": "docs/feature--doc-governance--context-recovery"`
- `"state_ref": "2026-04-25-active-context-handoff-phase-1/tasks.md#T1"`
- `"next_ref": "2026-04-25-active-context-handoff-phase-1/plan.md#T1"`

6. [T6] Run the focused proof set.

Run:

```bash
bash tests/test-context-contract-validator.sh
bash tests/test-context-recovery.sh
bash tests/test-active-doc-scope-lifecycle.sh
bash tests/test-context-contract-audit.sh
bash tools/dev/validate-contracts.sh
```

Expected: all PASS.

7. [T6] Run the final quick regression before verify-change.

Run: `bash tests/run-all.sh --quick --profile`

Expected: PASS with `All tests passed`.

## Self-Review Notes

Spec coverage:
- G1 is covered by T1, T3, and T6 through registry candidates and real pilot recovery.
- G2 is covered by T2, T3, and T6 through root worklog parsing and real pilot refs.
- G3 is covered by T1, T2, T3, and T6 through true artifact routing and task/plan consistency.
- G4 is covered by T2, T4, and T6 through ownership contract checks and consumer vocabulary.
- G5 is covered by T1, T2, T4, and T5 through validator, tests, contract runner, and hook wiring.
- G6 is covered by T2, T3, T4, and T5 through fixed block output and fail-closed paths.

Dependency check:
- T2 depends on T1 because validator rules need the target registry vocabulary.
- T3 depends on T1 and T2 because recovery consumes registry vocabulary and validator parsing helpers.
- T4 depends on T2 because ownership checks live in the validator.
- T5 depends on T2 and T4 because gate wiring must call the complete validator.
- T6 depends on T1, T2, T3, and T5 because the real pilot must only register after validator and recovery paths exist.
