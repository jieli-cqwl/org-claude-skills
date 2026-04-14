# Standard Chain Contract Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 把标准链路从 `process md` 控制面切到 `canonical JSON + evidence refs + HTML`，交付可验证、可回放、可切换的 v1 contract foundation。

**Architecture:** 先在 `contracts/canonical/` 冻结 registry bundle、shared core schema、artifact template 与 runtime catalog，再在 `tools/community/` 按 `normalizer -> schema -> rule -> evidence -> projection` 分层落地 validator stack，并补齐 runtime state、artifact registry、`user-decision writer`、projection/replay CLI。最后把标准链路角色与 gate tests 切到 canonical-only，新 `feature-phase` 只允许消费 active registry 与 canonical artifacts，失败只能走 `freeze + quarantine`。

**Tech Stack:** YAML registries, JSON Schema, Python CLIs under `tools/community/`, Markdown skill docs/templates, shell contract tests under `tests/`, JSON fixtures and generated HTML/projection manifests.

---

## Canonical Workspace Layout

- `docs/{feature}/brief.json`
- `docs/{feature}/phase-{N}/phase-prd.json`
- `docs/{feature}/phase-{N}/units/UNIT-{N}.json`
- `docs/{feature}/phase-{N}/design.json`
- `docs/{feature}/phase-{N}/plan.json`
- `docs/{feature}/phase-{N}/tasks.json`
- `docs/{feature}/phase-{N}/unit-{N}/test-cases.json`
- `docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json`
- `docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json`
- `docs/{feature}/phase-{N}/code-review-result.json`
- `docs/{feature}/phase-{N}/qa-result.json`
- `docs/{feature}/phase-{N}/delivery-state.json`
- `docs/{feature}/phase-{N}/artifact-registry.json`
- `docs/{feature}/phase-{N}/signoff-package.json`
- `docs/{feature}/phase-{N}/user-decision.json`
- `docs/{feature}/phase-{N}/views/phase-operational.html`
- `docs/{feature}/phase-{N}/views/phase-operational.projection-manifest.json`
- `docs/{feature}/phase-{N}/replay/phase-operational.replay-oracle.json`

## Execution Order

- `T1` foundation registry, schema, template, catalog
- `T2` runtime state, artifact registry, task lineage
- `T3` validator stack and fail-closed gates
- `T4` user decision authority channel
- `T5` projection, replay, golden pilot
- `T6` role cutover, legacy consumer replacement, readiness gate

`T6` 开始前必须确保 `T1` 到 `T5` 的独立测试已经全部通过；不满足时禁止切换标准链路输出。

### Task 1: Foundation registries, schemas, templates, and runtime catalog [T1]

Files:
- Create: `contracts/canonical/registry-bundle.yaml`
- Create: `contracts/canonical/vocabulary-registry.yaml`
- Create: `contracts/canonical/authority-registry.yaml`
- Create: `contracts/canonical/stage-registry.yaml`
- Create: `contracts/canonical/compatibility-matrix.yaml`
- Create: `contracts/canonical/schemas/shared-core.schema.json`
- Create: `contracts/canonical/schemas/planning/`
- Create: `contracts/canonical/schemas/runtime/`
- Create: `contracts/canonical/schemas/projection/projection-manifest.schema.json`
- Create: `contracts/canonical/templates/planning/`
- Create: `contracts/canonical/templates/runtime/`
- Create: `contracts/canonical/templates/projection/projection-manifest.template.json`
- Create: `tools/community/build_standard_chain_catalog.py`
- Create: `shared/runtime/standard-chain-catalog.json`
- Modify: `tests/test-chain-completeness.sh`
- Create: `tests/test-standard-chain-foundation-registry.sh`

1. [T1] 创建 canonical contract tree，并把 v1 must-have artifact 的文件名一次性冻结。

```text
contracts/canonical/
  registry-bundle.yaml
  vocabulary-registry.yaml
  authority-registry.yaml
  stage-registry.yaml
  compatibility-matrix.yaml
  schemas/
    shared-core.schema.json
    planning/
      brief.schema.json
      phase-prd.schema.json
      unit-definition.schema.json
      design.schema.json
      test-cases.schema.json
      plan.schema.json
      tasks.schema.json
    runtime/
      developer-report.schema.json
      verify-result.schema.json
      code-review-result.schema.json
      qa-result.schema.json
      delivery-state.schema.json
      signoff-package.schema.json
      user-decision.schema.json
      artifact-registry.schema.json
    projection/
      projection-manifest.schema.json
  templates/
    planning/
      brief.template.json
      phase-prd.template.json
      unit-definition.template.json
      design.template.json
      test-cases.template.json
      plan.template.json
      tasks.template.json
    runtime/
      developer-report.template.json
      verify-result.template.json
      code-review-result.template.json
      qa-result.template.json
      delivery-state.template.json
      signoff-package.template.json
      user-decision.template.json
      artifact-registry.template.json
    projection/
      projection-manifest.template.json
```

2. [T1] 实现 `tools/community/build_standard_chain_catalog.py`，基于 bundle 真源和被 bundle 引用的 registry 内容计算唯一 digest，并生成 `shared/runtime/standard-chain-catalog.json`。

```python
from __future__ import annotations

import hashlib
import json
from pathlib import Path

def load_registry_bundle(root: Path) -> dict:
    import yaml

    bundle_path = root / "contracts/canonical/registry-bundle.yaml"
    bundle = yaml.safe_load(bundle_path.read_text(encoding="utf-8"))
    return {"path": str(bundle_path.relative_to(root)), "bundle": bundle}

def build_chain_registry_digest(root: Path) -> str:
    bundle_payload = load_registry_bundle(root)
    files = [
        bundle_payload["bundle"]["vocabulary_registry"],
        bundle_payload["bundle"]["authority_registry"],
        bundle_payload["bundle"]["stage_registry"],
        bundle_payload["bundle"]["compatibility_matrix"],
    ]
    normalized = {
        "bundle_path": bundle_payload["path"],
        "bundle": bundle_payload["bundle"],
        "registries": {
            rel: (root / rel).read_text(encoding="utf-8")
            for rel in files
        },
    }
    joined = json.dumps(normalized, ensure_ascii=False, sort_keys=True)
    return "sha256:" + hashlib.sha256(joined.encode("utf-8")).hexdigest()

def write_catalog(root: Path, catalog: dict) -> None:
    target = root / "shared/runtime/standard-chain-catalog.json"
    target.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
```

3. [T1] 写 foundation registries，覆盖 design 冻结的枚举、authority、stage 与 compatibility matrix。

```yaml
# contracts/canonical/registry-bundle.yaml
chain_version: standard-chain/v1
vocabulary_registry: contracts/canonical/vocabulary-registry.yaml
authority_registry: contracts/canonical/authority-registry.yaml
stage_registry: contracts/canonical/stage-registry.yaml
compatibility_matrix: contracts/canonical/compatibility-matrix.yaml
```

```yaml
# contracts/canonical/vocabulary-registry.yaml
status: [PENDING, IN_PROGRESS, PASS, FAIL, BLOCKED, N_A, CLOSED]
gate_result: [PASS, FAIL, CONDITIONAL, NOT_RUN, N_A]
release_recommendation: [ALLOW, CONDITIONAL_ALLOW, BLOCK, DEFER]
control_action: [CONTINUE, ESCALATE, REPLAN, BLOCK, REQUEST_DECISION, CLOSE]
decision: [APPROVE, REJECT, ACCEPT_RISK, REQUEST_CHANGES, ACKNOWLEDGED]
runtime_status: [PENDING, READY, IN_PROGRESS, BLOCKED, VERIFIED, FAILED, CLOSED]
sign_off_status: [PENDING, SIGNED_OFF, REJECTED, SUPERSEDED]
business_risk_acceptance_status: [NOT_REQUIRED, PENDING, ACCEPTED, REJECTED, SUPERSEDED]
goal_closure_result: [MET, PARTIAL, NOT_MET, N_A]
```

4. [T1] 写 shared core schema 和 artifact schemas；planning/runtime/projection 每个 schema 都从 shared core 继承共同字段，再追加自己专有字段。

```json
{
  "$id": "contracts/canonical/schemas/shared-core.schema.json",
  "type": "object",
  "required": [
    "artifact_type",
    "artifact_id",
    "schema_version",
    "producer",
    "produced_at",
    "chain_version",
    "chain_registry_digest",
    "authority_scope",
    "authoritative_fields"
  ],
  "properties": {
    "artifact_type": { "type": "string" },
    "artifact_id": { "type": "string" },
    "schema_version": { "type": "string" },
    "producer": { "type": "string" },
    "produced_at": { "type": "string" },
    "chain_version": { "type": "string" },
    "chain_registry_digest": { "type": "string" },
    "authority_scope": { "type": "string" },
    "authoritative_fields": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "additionalProperties": true
}
```

5. [T1] 为每个 artifact 写 template，并把默认输出路径写进 `shared/runtime/standard-chain-catalog.json`；其中 task-scope 工件必须冻结到 task 级目录。

```python
def build_plan_template(produced_at: str, chain_registry_digest: str) -> dict:
    return {
        "artifact_type": "plan",
        "artifact_id": "sample-feature.phase-1.plan",
        "schema_version": "1.0.0",
        "producer": "tech-lead",
        "produced_at": produced_at,
        "chain_version": "standard-chain/v1",
        "chain_registry_digest": chain_registry_digest,
        "authority_scope": "phase",
        "authoritative_fields": ["baseline_plan_version_ref", "execution_basis_refs"],
        "baseline_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v1#plan-version",
        "baseline_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@plan-v1#task-registry",
        "goal_source_refs": [],
        "constraint_source_refs": [],
        "obligation_source_refs": [],
        "execution_basis_refs": [],
        "evidence_refs": [],
    }

def build_task_scoped_paths(task_id: str) -> dict:
    return {
        "developer-report": f"docs/{{feature}}/phase-{{N}}/unit-{{N}}/tasks/{task_id}/developer-report.json",
        "verify-result": f"docs/{{feature}}/phase-{{N}}/unit-{{N}}/tasks/{task_id}/verify-result.json",
    }
```

6. [T1] 补 foundation tests，让它们验证 bundle drift、registry digest、schema/template 成对存在、v1 artifact 覆盖和 task-scope 路径映射。

```bash
test -f "$ROOT/contracts/canonical/registry-bundle.yaml" || fail "missing registry bundle"
test -f "$ROOT/shared/runtime/standard-chain-catalog.json" || fail "missing standard chain catalog"
python3 "$ROOT/tools/community/build_standard_chain_catalog.py" --check || fail "catalog drift"
python3 - <<'PY' "$ROOT/shared/runtime/standard-chain-catalog.json"
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
required = {
    "brief", "phase-prd", "unit-definition", "design", "test-cases", "plan", "tasks",
    "developer-report", "verify-result", "code-review-result", "qa-result",
    "delivery-state", "signoff-package", "user-decision", "artifact-registry",
    "projection-manifest"
}
assert required.issubset(data["artifacts"])
assert data["artifacts"]["developer-report"]["default_path"].endswith("/tasks/{task_id}/developer-report.json")
assert data["artifacts"]["verify-result"]["default_path"].endswith("/tasks/{task_id}/verify-result.json")
PY

python3 "$ROOT/tools/community/build_standard_chain_catalog.py" \
  --bundle-drift-probe contracts/canonical/registry-bundle.yaml \
  || fail "bundle drift must invalidate digest"
```

7. [T1] 运行 foundation 验证。

Run: `bash tests/test-standard-chain-foundation-registry.sh`
Expected: PASS

Run: `bash tests/test-chain-completeness.sh`
Expected: PASS

8. [T1] 提交 foundation slice。

Run: `git add contracts/canonical tools/community/build_standard_chain_catalog.py shared/runtime/standard-chain-catalog.json tests/test-standard-chain-foundation-registry.sh tests/test-chain-completeness.sh && git commit -m "feat: add standard chain foundation registries"`
Expected: commit created

### Task 2: Runtime state, artifact registry, task lineage, and recovery flows [T2]

Files:
- Create: `tools/community/canonical_ref_resolver.py`
- Create: `tools/community/manage_artifact_registry.py`
- Create: `tools/community/update_delivery_state.py`
- Create: `tests/fixtures/standard-chain-foundation/runtime/`
- Create: `tests/test-standard-chain-runtime-state.sh`

1. [T2] 冻结 runtime fixture layout，确保 baseline、blocked、quarantine、replan 四类样本路径从一开始就稳定。

```text
tests/fixtures/standard-chain-foundation/runtime/
  baseline/
    brief.json
    phase-prd.json
    design.json
    plan.json
    tasks.json
    delivery-state.json
    artifact-registry.json
  blocked/
    enter-blocked.json
    leave-blocked.json
  quarantine/
    artifact-registry.json
    restore-request.json
  replan/
    plan-v1.json
    plan-v2.json
    tasks-v1.json
    tasks-v2.json
    delivery-state.json
```

2. [T2] 实现 `tools/community/canonical_ref_resolver.py`，只允许通过 active revision 中 `FINALIZED` 的 active entry 解析 canonical ref。

```python
from __future__ import annotations

import json
from pathlib import Path

def resolve_artifact_ref(ref: str, registry_path: Path) -> Path:
    data = json.loads(registry_path.read_text(encoding="utf-8"))
    active_revision = next(
        item for item in data["revisions"]
        if item["revision_id"] == data["active_revision_id"]
    )
    for entry in active_revision["entries"]:
        if not entry["active_for_consumption"]:
            continue
        if entry["lifecycle_state"] != "FINALIZED":
            raise ValueError(f"active entry must be FINALIZED: {entry['artifact_id']}")
        candidate = f"artifact://{entry['artifact_type']}/{entry['artifact_id']}@{entry['version']}"
        if ref.startswith(candidate):
            return Path(entry["artifact_path"])
    raise FileNotFoundError(ref)
```

3. [T2] 实现 `tools/community/manage_artifact_registry.py`，把 active uniqueness、append-only revision、quarantine 和 restore 做成显式写操作，并冻结 revision snapshot 存储模型。

```python
def assert_active_uniqueness(entries: list[dict]) -> None:
    seen: set[tuple[str, str]] = set()
    for entry in entries:
        if not entry["active_for_consumption"]:
            continue
        if entry["lifecycle_state"] != "FINALIZED":
            raise ValueError(f"active entry must be FINALIZED: {entry['artifact_id']}")
        key = (entry["artifact_type"], entry["scope_ref"])
        if key in seen:
            raise ValueError(f"duplicate active entry: {key}")
        seen.add(key)

def append_revision(registry: dict, new_entries: list[dict], appended_at: str) -> dict:
    next_revision_id = f"rev-{len(registry['revisions']) + 1}"
    assert_active_uniqueness(new_entries)
    snapshot = {
        "revision_id": next_revision_id,
        "parent_revision_id": registry["active_revision_id"],
        "appended_at": appended_at,
        "entries": new_entries,
    }
    registry["revisions"].append(snapshot)
    registry["active_revision_id"] = next_revision_id
    return registry

def restore_quarantined_entries(
    registry: dict,
    restored_entries: list[dict],
    restore_basis_refs: list[str],
    appended_at: str,
) -> dict:
    for entry in restored_entries:
        entry["lifecycle_state"] = "FINALIZED"
        entry["restore_basis_refs"] = restore_basis_refs
    return append_revision(registry, restored_entries, appended_at)
```

4. [T2] 实现 `tools/community/update_delivery_state.py`，把 `tasks` runtime state、`BLOCKED` 进入/退出字段和 `REPLAN` 后 active version 切换写实。

```python
def enter_blocked(state: dict, blocker: dict) -> dict:
    state["current_stage"] = "BLOCKED"
    state["blocker_id"] = blocker["blocker_id"]
    state["blocked_from_stage"] = blocker["blocked_from_stage"]
    state["resume_stage"] = blocker["resume_stage"]
    state["blocker_reason_code"] = blocker["blocker_reason_code"]
    state["blocker_opened_at"] = blocker["blocker_opened_at"]
    state["blocker_basis_refs"] = blocker["blocker_basis_refs"]
    return state

def leave_blocked(state: dict, resolution: dict) -> dict:
    state["current_stage"] = resolution["resume_stage"]
    state["blocker_resolution_evidence_refs"] = resolution["blocker_resolution_evidence_refs"]
    state["unblocked_by_ref"] = resolution["unblocked_by_ref"]
    state["unblocked_at"] = resolution["unblocked_at"]
    return state

def switch_active_baseline(state: dict, plan_ref: str, tasks_ref: str) -> dict:
    state["active_plan_version_ref"] = plan_ref
    state["active_tasks_version_ref"] = tasks_ref
    return state
```

5. [T2] 用 fixtures 和测试覆盖 active discovery、task lineage、`BLOCKED -> 恢复`、quarantine/restore、active FINALIZED 断言和 replan version switch。

```bash
python3 "$ROOT/tools/community/manage_artifact_registry.py" --fixture "$ROOT/tests/fixtures/standard-chain-foundation/runtime/quarantine/artifact-registry.json" --check-active
python3 "$ROOT/tools/community/manage_artifact_registry.py" --fixture "$ROOT/tests/fixtures/standard-chain-foundation/runtime/quarantine/artifact-registry.json" --check-append-only
python3 "$ROOT/tools/community/manage_artifact_registry.py" --fixture "$ROOT/tests/fixtures/standard-chain-foundation/runtime/quarantine/restore-request.json" --check-restore
python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$ROOT/tests/fixtures/standard-chain-foundation/runtime/blocked/enter-blocked.json" --check-enter-blocked
python3 "$ROOT/tools/community/update_delivery_state.py" --fixture "$ROOT/tests/fixtures/standard-chain-foundation/runtime/blocked/leave-blocked.json" --check-leave-blocked
python3 "$ROOT/tools/community/canonical_ref_resolver.py" --registry "$ROOT/tests/fixtures/standard-chain-foundation/runtime/baseline/artifact-registry.json" --ref "artifact://plan/sample-feature.phase-1.plan@plan-v1#plan-version"
```

6. [T2] 运行 runtime state 验证。

Run: `bash tests/test-standard-chain-runtime-state.sh`
Expected: PASS

7. [T2] 提交 runtime state slice。

Run: `git add tools/community/canonical_ref_resolver.py tools/community/manage_artifact_registry.py tools/community/update_delivery_state.py tests/fixtures/standard-chain-foundation/runtime tests/test-standard-chain-runtime-state.sh && git commit -m "feat: add standard chain runtime state tooling"`
Expected: commit created

### Task 3: Validator stack and fail-closed contract enforcement [T3]

Files:
- Create: `tools/community/normalize_canonical_artifact.py`
- Create: `tools/community/validate_canonical_schema.py`
- Create: `tools/community/validate_canonical_rules.py`
- Create: `tools/community/resolve_evidence_refs.py`
- Create: `tools/community/validate_projection_manifest.py`
- Create: `tools/community/validate_standard_chain_phase.py`
- Create: `tests/fixtures/standard-chain-foundation/negative/`
- Create: `tests/test-standard-chain-validator-stack.sh`
- Modify: `tests/test-runtime-integrity.sh`

1. [T3] 创建 validator stack 文件边界，保持 orchestration 和规则实现分层。

```text
tools/community/
  normalize_canonical_artifact.py
  validate_canonical_schema.py
  validate_canonical_rules.py
  resolve_evidence_refs.py
  validate_projection_manifest.py
  validate_standard_chain_phase.py
tests/fixtures/standard-chain-foundation/negative/
  missing-anchor.json
  illegal-transition.json
  mixed-version.json
  stale-evidence.json
  authority-mismatch.json
  closure-break.json
```

2. [T3] 实现 normalizer 与 schema validator，确保 normalizer 不补语义默认值，schema validator 只做结构检查。

```python
def normalize_artifact(payload: dict) -> dict:
    normalized = dict(payload)
    if "artifact_type" in normalized:
        normalized["artifact_type"] = str(normalized["artifact_type"]).strip()
    if "producer" in normalized:
        normalized["producer"] = str(normalized["producer"]).strip()
    return normalized

def validate_schema(instance: dict, schema_path: Path) -> None:
    import json
    import jsonschema
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    jsonschema.validate(instance=instance, schema=schema)
```

3. [T3] 实现 rule validator，覆盖 stage transition、producer authority、version compatibility、task lineage 与 upstream closure。

```python
def assert_transition_allowed(current_stage: str, next_stage: str, matrix: dict[str, set[str]]) -> None:
    if next_stage not in matrix.get(current_stage, set()):
        raise ValueError(f"illegal transition: {current_stage} -> {next_stage}")

def assert_active_versions(payload: dict) -> None:
    if payload.get("artifact_type") in {"delivery-state", "signoff-package", "user-decision"}:
        if not payload.get("active_plan_version_ref") or not payload.get("active_tasks_version_ref"):
            raise ValueError("missing active baseline refs")

def assert_upstream_closure(rows: list[dict]) -> None:
    keys = [row["source_ref"] for row in rows]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate upstream closure rows")

def assert_registry_entry_consumable(entry: dict) -> None:
    if entry["active_for_consumption"] and entry["lifecycle_state"] != "FINALIZED":
        raise ValueError("active entry must be FINALIZED")
```

4. [T3] 实现 evidence resolver 和 freshness comparator，禁止 stale evidence、superseded evidence 与缺 anchor 的 active evidence。

```python
def assert_evidence_fresh(evidence: dict, active_plan_ref: str, produced_at: str) -> None:
    if evidence.get("superseded_by_ref"):
        raise ValueError("superseded evidence cannot stay active")
    if evidence.get("ref_target") == active_plan_ref and evidence.get("observed_at", "") > produced_at:
        return
    if evidence.get("valid_until") and evidence["valid_until"] < produced_at:
        raise ValueError("stale evidence")

def assert_anchor_exists(target_path: Path, anchor: str) -> None:
    text = target_path.read_text(encoding="utf-8")
    if anchor not in text:
        raise ValueError(f"missing anchor: {anchor}")
```

5. [T3] 实现 projection validator 和 phase-level orchestrator，让外部 gate 只调用一个入口但仍保留失败来源分层。

```python
import subprocess
import sys

PIPELINE = [
    "normalize_canonical_artifact.py",
    "validate_canonical_schema.py",
    "validate_canonical_rules.py",
    "resolve_evidence_refs.py",
    "validate_projection_manifest.py",
]

def run_phase_validation(phase_dir: Path) -> None:
    # Phase gate must execute every validator CLI in order and fail-close on the
    # first non-zero exit; checking file existence alone is not sufficient.
    tools_dir = Path(__file__).resolve().parent
    for script_name in PIPELINE:
        script = tools_dir / script_name
        if not script.is_file():
            raise FileNotFoundError(script_name)
        subprocess.run(
            [sys.executable, str(script), "--phase-dir", str(phase_dir)],
            check=True,
        )
```

6. [T3] 运行 validator stack 验证。

Run: `bash tests/test-standard-chain-validator-stack.sh`
Expected: PASS

Run: `bash tests/test-runtime-integrity.sh`
Expected: PASS

7. [T3] 提交 validator stack slice。

Run: `git add tools/community/normalize_canonical_artifact.py tools/community/validate_canonical_schema.py tools/community/validate_canonical_rules.py tools/community/resolve_evidence_refs.py tools/community/validate_projection_manifest.py tools/community/validate_standard_chain_phase.py tests/fixtures/standard-chain-foundation/negative tests/test-standard-chain-validator-stack.sh tests/test-runtime-integrity.sh && git commit -m "feat: add standard chain validator stack"`
Expected: commit created

### Task 4: User decision writer and authority proof enforcement [T4]

Files:
- Create: `tools/community/authority_proof.py`
- Create: `tools/community/write_user_decision.py`
- Create: `tests/fixtures/standard-chain-foundation/user-decision/`
- Create: `tests/test-standard-chain-user-decision.sh`
- Modify: `tools/community/validate_canonical_rules.py`

1. [T4] 冻结 user decision fixtures，让 approve、reject、accept-risk、supersede、authority-conflict 都有独立样本。

```text
tests/fixtures/standard-chain-foundation/user-decision/
  approve.json
  reject.json
  accept-risk.json
  request-changes.json
  superseded.json
  authority-conflict.json
  missing-proof.json
  digest-mismatch.json
  expired-proof.json
  script-source.json
  stale-baseline.json
```

2. [T4] 实现 authority proof verifier，直接从 authority registry 解出 actor、channel、proof type、freshness 与 payload digest 绑定。

```python
def verify_authority_proof(
    proof: dict,
    decision_payload: dict,
    payload_digest: str,
    registry: dict,
    runtime_state: dict,
) -> dict:
    rule = registry["decision_sources"][decision_payload["decision_source"]]
    if proof["proof_type"] != rule["required_proof_type"]:
        raise ValueError("proof_type does not match decision_source")
    if proof["decision_payload_digest"] != payload_digest:
        raise ValueError("payload digest mismatch")
    if decision_payload["actor_id"] != proof["verified_actor_id"]:
        raise ValueError("actor must match verified actor")
    if proof["verified_channel"] not in rule["allowed_channels"]:
        raise ValueError("channel not allowed for source")
    if proof["verified_at"] > decision_payload["produced_at"]:
        raise ValueError("proof was not yet valid when decision was produced")
    if proof["verified_until"] < decision_payload["produced_at"]:
        raise ValueError("expired proof")
    if runtime_state["active_plan_version_ref"] != decision_payload["active_plan_version_ref"]:
        raise ValueError("stale decision after replan")
    if runtime_state["active_tasks_version_ref"] != decision_payload["active_tasks_version_ref"]:
        raise ValueError("stale task baseline after replan")
    return {
        "verified_actor_id": proof["verified_actor_id"],
        "verified_channel": proof["verified_channel"],
        "proof_type": proof["proof_type"],
    }
```

3. [T4] 实现 `tools/community/write_user_decision.py`，把 decision payload digest、proof refs、basis refs 和 supersede 重认证固化成唯一写入入口。

```python
from __future__ import annotations

import hashlib
import json

def build_decision_payload(payload: dict) -> dict:
    serial = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    digest = "sha256:" + hashlib.sha256(serial.encode("utf-8")).hexdigest()
    payload["decision_payload_digest"] = digest
    if payload.get("supersedes_decision_ref") and not payload.get("authority_proof_refs"):
        raise ValueError("supersede requires fresh authority proof")
    return payload
```

4. [T4] 更新 `tools/community/validate_canonical_rules.py`，对 `user-decision.json` 与 `signoff-package.json` 强制 baseline/active 成对一致，并拒绝 stale decision 在 replan 后继续 active consumption。

```python
def assert_decision_baselines(payload: dict, runtime_state: dict) -> None:
    required = [
        "baseline_plan_version_ref",
        "baseline_tasks_version_ref",
        "active_plan_version_ref",
        "active_tasks_version_ref",
        "authority_proof_refs",
        "decision_basis_refs",
        "decision_payload_digest",
    ]
    for key in required:
        if not payload.get(key):
            raise ValueError(f"missing decision field: {key}")
    if payload.get("decision_source") == "SCRIPT":
        raise ValueError("SCRIPT cannot produce finalized user decision")
    superseded = (
        payload.get("sign_off_status") == "SUPERSEDED"
        or payload.get("business_risk_acceptance_status") == "SUPERSEDED"
    )
    if not superseded:
        if payload["baseline_plan_version_ref"] != payload["active_plan_version_ref"]:
            raise ValueError("baseline plan ref must equal active plan ref")
        if payload["baseline_tasks_version_ref"] != payload["active_tasks_version_ref"]:
            raise ValueError("baseline tasks ref must equal active tasks ref")
    if payload["active_plan_version_ref"] != runtime_state["active_plan_version_ref"]:
        raise ValueError("decision active plan baseline is stale")
    if payload["active_tasks_version_ref"] != runtime_state["active_tasks_version_ref"]:
        raise ValueError("decision active tasks baseline is stale")
```

5. [T4] 运行 authority 与 decision 验证。

Run: `bash tests/test-standard-chain-user-decision.sh`
Expected: PASS

6. [T4] 提交 user decision slice。

Run: `git add tools/community/authority_proof.py tools/community/write_user_decision.py tools/community/validate_canonical_rules.py tests/fixtures/standard-chain-foundation/user-decision tests/test-standard-chain-user-decision.sh && git commit -m "feat: add standard chain user decision writer"`
Expected: commit created

### Task 5: Projection provenance, replay oracle, and golden pilot [T5]

Files:
- Create: `tools/community/materialize_canonical_html.py`
- Create: `tools/community/replay_canonical_phase.py`
- Create: `shared/runtime/projection-views.json`
- Create: `shared/runtime/replay-profiles.json`
- Create: `tests/fixtures/standard-chain-foundation/golden-pilot/`
- Create: `tests/test-standard-chain-projection-replay.sh`

1. [T5] 冻结 projection view config，让 operational HTML 的 section-source map 可被验证器消费。

```json
{
  "views": [
    {
      "view_id": "phase-operational",
      "output_path": "docs/{feature}/phase-{N}/views/phase-operational.html",
      "manifest_path": "docs/{feature}/phase-{N}/views/phase-operational.projection-manifest.json",
      "required_sections": [
        "phase-summary",
        "task-runtime",
        "gate-verdicts",
        "blocked-state",
        "signoff-status"
      ],
      "section_sources": {
        "phase-summary": {
          "source_artifact_refs": ["artifact://delivery-state/{feature}.phase-{N}.delivery-state@active#phase-summary"],
          "json_pointers": ["/summary_text", "/current_stage", "/control_action"]
        },
        "task-runtime": {
          "source_artifact_refs": ["artifact://delivery-state/{feature}.phase-{N}.delivery-state@active#tasks"],
          "json_pointers": ["/tasks"]
        },
        "gate-verdicts": {
          "source_artifact_refs": [
            "artifact://qa-result/{feature}.phase-{N}.qa@active#gate-result",
            "artifact://signoff-package/{feature}.phase-{N}.signoff@active#release-recommendation"
          ],
          "json_pointers": ["/gate_result", "/release_recommendation"]
        },
        "blocked-state": {
          "source_artifact_refs": ["artifact://delivery-state/{feature}.phase-{N}.delivery-state@active#blocked-state"],
          "json_pointers": ["/blocker_id", "/resume_stage", "/blocker_resolution_evidence_refs"]
        },
        "signoff-status": {
          "source_artifact_refs": ["artifact://user-decision/{feature}.phase-{N}.decision@active#signoff-status"],
          "json_pointers": ["/sign_off_status", "/business_risk_acceptance_status"]
        }
      }
    }
  ]
}
```

2. [T5] 实现 `tools/community/materialize_canonical_html.py`，只从 catalog、active registry 和 canonical JSON 渲染 HTML 与 manifest。

```python
def build_projection_manifest(
    view_id: str,
    html_ref: str,
    content_digest: str,
    section_source_map: dict,
    generated_at: str,
) -> dict:
    return {
        "view_id": view_id,
        "source_artifact_refs": sorted(
            {
                ref
                for section in section_source_map.values()
                for ref in section["source_artifact_refs"]
            }
        ),
        "section_source_map": section_source_map,
        "generated_at": generated_at,
        "renderer_version": "1.0.0",
        "rendered_artifact_ref": html_ref,
        "rendered_content_digest": content_digest,
    }
```

3. [T5] 先冻结 `shared/runtime/replay-profiles.json`，再实现 `tools/community/replay_canonical_phase.py` 只负责加载与执行 profile。

```json
{
  "profiles": {
    "shared": {
      "must_match": ["artifact_id", "schema_version", "chain_version", "chain_registry_digest"],
      "may_differ": ["produced_at", "generated_at", "renderer_version"],
      "must_not_exist": ["undeclared_active_refs", "quarantined_inputs", "stale_active_evidence"]
    },
    "blocked-resume": {
      "extra_must_match": ["blocker_id", "blocked_from_stage", "resume_stage", "blocker_resolution_evidence_refs", "unblocked_by_ref"]
    },
    "conditional-allow": {
      "extra_must_match": ["release_recommendation", "waiver_entries"]
    },
    "partial-goal-closure": {
      "extra_must_match": ["goal_closure[].result"],
      "one_of": [
        ["goal_closure[].remaining_gap_text"],
        ["waiver_entries[].waiver_id"]
      ]
    },
    "not-applicable": {
      "extra_must_match": ["goal_closure[].reason_code"]
    },
    "authority-conflict": {
      "extra_must_match": ["verified_actor_id", "verified_channel", "proof_type"]
    },
    "quarantined-restore": {
      "extra_must_match": ["restore_basis_refs", "restore_entry_tuples"]
    },
    "ref-break": {
      "must_fail_with": "missing canonical ref target"
    },
    "mixed-version": {
      "must_fail_with": "schema/chain/version mismatch"
    }
  }
}
```

```python
def load_replay_profiles(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))["profiles"]
```

4. [T5] 搭建 golden pilot fixture 和 replay 输出，覆盖 v1 最小闭环。

```text
tests/fixtures/standard-chain-foundation/golden-pilot/
  sample-feature/
    brief.json
    phase-1/
      phase-prd.json
      design.json
      plan.json
      tasks.json
      code-review-result.json
      qa-result.json
      delivery-state.json
      artifact-registry.json
      signoff-package.json
      user-decision.json
      units/
        UNIT-1.json
      unit-1/
        test-cases.json
        tasks/
          T1/
            developer-report.json
            verify-result.json
      views/
        phase-operational.html
        phase-operational.projection-manifest.json
      replay/
        phase-operational.replay-oracle.json
```

5. [T5] 运行 projection 和 replay 验证。

Run: `bash tests/test-standard-chain-projection-replay.sh`
Expected: PASS

6. [T5] 提交 projection and replay slice。

Run: `git add tools/community/materialize_canonical_html.py tools/community/replay_canonical_phase.py shared/runtime/projection-views.json shared/runtime/replay-profiles.json tests/fixtures/standard-chain-foundation/golden-pilot tests/test-standard-chain-projection-replay.sh && git commit -m "feat: add standard chain projection and replay"`
Expected: commit created

### Task 6: Standard-chain cutover, legacy consumer replacement, and canonical-only readiness gate [T6]

Files:
- Modify: `contracts/skill-chain.yaml`
- Modify: `shared/protocols/phase-selection-protocol.md`
- Modify: `shared/skills/product/references/phase-splitting-guide.md`
- Modify: `shared/skills/product/SKILL.md`
- Modify: `shared/skills/product/references/templates/brief-template.md`
- Modify: `shared/skills/product/references/templates/phase-prd-template.md`
- Modify: `shared/skills/product/scripts/completion_check.sh`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/references/templates/design-template.md`
- Modify: `shared/skills/design/scripts/completion_check.sh`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/test-design/references/templates/test-cases-template.md`
- Modify: `shared/skills/test-design/scripts/completion_check.sh`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/tech-lead/references/templates/plan-template.md`
- Modify: `shared/skills/tech-lead/scripts/completion_check.sh`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/developer/references/templates/developer-report-template.md`
- Modify: `shared/skills/developer/scripts/completion_check.sh`
- Modify: `shared/skills/review/SKILL.md`
- Modify: `shared/skills/review/references/templates/code-review-report-template.md`
- Modify: `shared/skills/review/scripts/completion_check.sh`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/verify/references/templates/verify-report-template.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/qa/references/templates/qa-report-template.md`
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/code-review-report-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/waivers-template.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/agents/code-reviewer.md`
- Modify: `shared/agents/designer.md`
- Modify: `shared/agents/developer.md`
- Modify: `shared/agents/qa.md`
- Modify: `shared/agents/tech-lead.md`
- Modify: `shared/agents/test-designer.md`
- Modify: `shared/agents/verifier.md`
- Modify: `tests/test-phase-context-resolution.sh`
- Modify: `tests/test-chain-completeness.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`
- Modify: `tests/test-constraint-closure-contract.sh`
- Modify: `tests/test-review-convergence-gates.sh`
- Modify: `tests/test-qa-browser-gate-contract.sh`
- Create: `tools/community/validate_standard_chain_readiness.py`
- Create: `tests/fixtures/standard-chain-foundation/cutover/`
- Create: `tests/test-standard-chain-cutover.sh`
- Create: `tests/test-standard-chain-readiness-gate.sh`

1. [T6] 先把 `contracts/skill-chain.yaml`、`phase-selection-protocol.md` 与 `phase-splitting-guide.md` 切到 canonical artifact 名称和默认物理路径，保证角色边界与 `shared/runtime/standard-chain-catalog.json` 对齐，同时不在 `shared/skills` 里复制 schema 真源。

```yaml
chain:
  - name: product
    outputs:
      - artifact: brief.json
      - artifact: "phase-{N}/phase-prd.json"
      - artifact: "phase-{N}/units/UNIT-{N}.json"
  - name: design
    outputs:
      - artifact: "phase-{N}/design.json"
  - name: test-design
    outputs:
      - artifact: "phase-{N}/unit-{N}/test-cases.json"
  - name: tech-lead
    outputs:
      - artifact: "phase-{N}/plan.json"
      - artifact: "phase-{N}/tasks.json"
  - name: developer
    outputs:
      - artifact: "phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json"
  - name: verify
    outputs:
      - artifact: "phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json"
  - name: qa
    outputs:
      - artifact: "phase-{N}/qa-result.json"
```

2. [T6] 更新 planning skills、template docs 与 shared agents，让 product、design、test-design、tech-lead 输出 canonical JSON，但 `shared/skills/*` 只引用 canonical template，不再内嵌结构真源。

```markdown
标准链路 planning artifact 真源：

- `contracts/canonical/templates/planning/brief.template.json`
- `contracts/canonical/templates/planning/phase-prd.template.json`
- `contracts/canonical/templates/planning/design.template.json`
- `contracts/canonical/templates/planning/test-cases.template.json`
- `contracts/canonical/templates/planning/plan.template.json`
- `contracts/canonical/templates/planning/tasks.template.json`

shared skill 文档只保留：

- 输出文件路径
- 何时使用哪份 canonical template
- 需要补充的业务语义字段
- 调用 `tools/community/validate_standard_chain_phase.py` 的命令
```

3. [T6] 更新 execution/delivery skills、template docs、shared agents 和 completion checks，让 developer、review、verify、qa、delivery-owner 只消费 active registry 与 canonical JSON；其中 `verify` 明确走标准链路 validator 入口，而不是假定已有独立 completion check。

```bash
python3 tools/community/validate_standard_chain_phase.py \
  --catalog shared/runtime/standard-chain-catalog.json \
  --phase-dir "$PHASE_DIR" \
  --enforce-canonical-only

python3 tools/community/validate_standard_chain_readiness.py \
  --catalog shared/runtime/standard-chain-catalog.json \
  --profiles shared/runtime/replay-profiles.json \
  --phase-dir "$PHASE_DIR"

python3 tools/community/canonical_ref_resolver.py \
  --registry "$PHASE_DIR/artifact-registry.json" \
  --ref "$ACTIVE_PLAN_REF"
```

4. [T6] 把 legacy gate 从标题/关键词匹配迁到 validator stack，并明确 mixed mode、failed cutover 与 rollback 的 fail-close 行为，同时补齐真实 runtime consumers。

```bash
if test -f "$PHASE_DIR/qa-report.md"; then
  fail "canonical-only phase must not keep qa-report.md as runtime source"
fi

python3 tools/community/manage_artifact_registry.py \
  --registry "$PHASE_DIR/artifact-registry.json" \
  --assert-no-mixed-mode

python3 tools/community/validate_standard_chain_readiness.py \
  --fixture "$ROOT/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json" \
  --expect-freeze-quarantine
```

5. [T6] 添加 cutover test，并把所有声明修改的 gate surface 一起跑完。

Run: `bash tests/test-standard-chain-cutover.sh`
Expected: PASS

Run: `bash tests/test-standard-chain-readiness-gate.sh`
Expected: PASS

Run: `bash tests/test-chain-completeness.sh`
Expected: PASS

Run: `bash tests/test-runtime-integrity.sh`
Expected: PASS

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: PASS

Run: `bash tests/test-phase-context-resolution.sh`
Expected: PASS

Run: `bash tests/test-delivery-owner-phase3-contract.sh`
Expected: PASS

Run: `bash tests/test-constraint-closure-contract.sh`
Expected: PASS

Run: `bash tests/test-review-convergence-gates.sh`
Expected: PASS

Run: `bash tests/test-qa-browser-gate-contract.sh`
Expected: PASS

6. [T6] 提交 cutover slice。

Run: `git add contracts/skill-chain.yaml shared/protocols/phase-selection-protocol.md shared/skills/product/references/phase-splitting-guide.md shared/skills/product shared/skills/design shared/skills/test-design shared/skills/tech-lead shared/skills/developer shared/skills/review shared/skills/verify shared/skills/qa shared/skills/delivery-owner shared/agents/code-reviewer.md shared/agents/designer.md shared/agents/developer.md shared/agents/qa.md shared/agents/tech-lead.md shared/agents/test-designer.md shared/agents/verifier.md tools/community/validate_standard_chain_readiness.py tests/test-phase-context-resolution.sh tests/test-chain-completeness.sh tests/test-runtime-integrity.sh tests/test-skill-output-and-gate-contract.sh tests/test-delivery-owner-phase3-contract.sh tests/test-constraint-closure-contract.sh tests/test-review-convergence-gates.sh tests/test-qa-browser-gate-contract.sh tests/test-standard-chain-cutover.sh tests/test-standard-chain-readiness-gate.sh && git commit -m "feat: cut standard chain over to canonical json"`
Expected: commit created
