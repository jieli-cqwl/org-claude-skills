# Runtime Layering Redesign Implementation Plan

> **For agentic workers:** REQUIRED NEXT STEP: run `implementation-router`. Implement only after `execution-route.json` chooses `serial` or `parallel`.

**Goal:** Turn the approved standard-chain runtime layering design into a mechanically checked developer pilot without changing the active registry or the `test-design` mainline.

**Architecture:** The implementation is contract first. A shared runtime-layering standard and migration audit define where truth lives; the developer report schema/template then carries the closed failure and fresh-proof contract; a deterministic validator and completion gate prove failure paths; finally the developer Skill, references, projections, evals, lifecycle evidence, and regression commands align to those mechanical checks.

**Tech Stack:** Markdown reference docs, JSON Schema draft 2020-12, Python 3 validators, Bash test gates, jq assertions, existing standard-chain fixtures, implementation-router route artifacts.

---

### Task 1: Runtime layering standard and migration audit contract [T1]

Context: The design must become a reusable standard before the developer pilot changes behavior. This task creates the shared rules and an auditable record of normative content movement so noise reduction cannot silently delete constraints.

Files:
- Create: `shared/reference/StandardChain运行面分层标准.md`
- Modify: `shared/reference/Skill质量标准.md`
- Create: `docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/developer-migration-audit.json`
- Create: `tests/test-standard-chain-runtime-layering-contract.sh`

1. [T1] Write the failing runtime-layering contract test.

```bash
bash tests/test-standard-chain-runtime-layering-contract.sh
```

Expected: FAIL because the shared runtime-layering standard and developer migration audit do not exist.

2. [T1] Create `tests/test-standard-chain-runtime-layering-contract.sh` with concrete doc and audit assertions.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/reference/StandardChain运行面分层标准.md"
QUALITY="$ROOT/shared/reference/Skill质量标准.md"
AUDIT="$ROOT/docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/developer-migration-audit.json"

require_pattern() {
  local pattern="$1" file="$2" label="$3"
  if ! rg -n "$pattern" "$file" >/dev/null 2>&1; then
    printf '[FAIL] %s\n' "$label" >&2
    exit 1
  fi
}

test -f "$STANDARD"
test -f "$AUDIT"

require_pattern '^## Main Runtime Layer$' "$STANDARD" "missing main runtime layer"
require_pattern '^## Runtime Integration Layer$' "$STANDARD" "missing runtime integration layer"
require_pattern '^## Governance And Evidence Layer$' "$STANDARD" "missing governance evidence layer"
require_pattern '唯一权威裁决源' "$STANDARD" "missing source-of-truth rule"
require_pattern '按需加载' "$STANDARD" "missing progressive disclosure rule"
require_pattern 'status.*failure_code.*safe_to_continue' "$STANDARD" "missing fixed failure shape"
require_pattern '命令字符串.*replay instruction' "$STANDARD" "missing fresh proof boundary"
require_pattern 'projection.*display' "$STANDARD" "missing projection display-only rule"
require_pattern 'StandardChain运行面分层标准\.md' "$QUALITY" "quality standard does not link runtime layering standard"

jq -e '
  type == "array"
  and length >= 8
  and all(.[]; has("source_ref") and has("content_type") and has("action") and has("destination_ref") and has("consumer") and has("verification_ref") and has("reason") and has("owner"))
  and all(.[]; .action as $action | ["keep","move","rewrite","archive","delete"] | index($action))
  and all(.[]; if .action == "delete" then .consumer == "none" else true end)
  and all(.[]; if (.destination_ref | test("shared/skills/developer/references/")) then (.content_type != "hard_gate" and .content_type != "protocol") else true end)
  and all(.[]; if (.content_type == "projection_display" or .content_type == "history") then (.consumer != "runtime") else true end)
' "$AUDIT" >/dev/null

printf '[PASS] standard-chain runtime layering contract\n'
```

3. [T1] Create `shared/reference/StandardChain运行面分层标准.md` with the exact reusable sections.

```markdown
# Standard Chain 运行面分层标准

## Main Runtime Layer

| Layer | Responsibility | Non-Responsibility |
| --- | --- | --- |
| SKILL.md | 触发、角色职责、主流程、硬门禁、输入输出、停机/路由、reference 触发条件 | 长方法论、历史背景、模板正文、机械校验逻辑 |
| references/ | 按需方法论、判断框架、复杂场景指南 | 隐藏 hard gate、定义 runtime truth、承载当前状态 |
| canonical schema | artifact shape、必填字段、枚举、基础结构约束 | 证明语义真实、证明 fresh proof 真的发生 |
| canonical template | artifact 初始骨架 | 字段语义真源、状态流转裁决、完成判定 |
| script | 稳定命令入口、参数解析、调用 validator/gate | 业务判断、设计判断、用户确认 |
| validator | schema、ref、字段、范围、证据结构等确定性校验 | 风险接受、业务取舍、设计方案裁决 |
| gate | 根据校验结果放行、阻断、路由 owner | 静默修复、替角色做决定 |
| projection/report template | 从 canonical artifact 派生的人类 display | runtime truth、机器状态源、反向规则定义 |
| archive/history | 历史追溯 | 当前执行输入，除非 active registry 或恢复流程明确引用 |

## Runtime Integration Layer

hooks 只拦截或提示运行风险，adapters 只转换 runtime payload，runtime catalog 只暴露可用入口，install exposure 只控制暴露范围。它们都不能覆盖 canonical contract。

## Governance And Evidence Layer

evals、examples、lifecycle-review、migration audit 和 regression pilot 只提供行为证据与维护证据，不能反向定义 runtime truth。

## Source Of Truth

每类运行事实只有一个唯一权威裁决源。projection、history、template、示例和自然语言总结可以引用、派生或解释，但不能反向定义规则。

## Progressive Disclosure

SKILL.md 提供主执行骨架和 reference 路由。reference 按需加载；触发条件必须可观察，读取后必须留下消费证据。无条件生效的 hard gate、字段合同、状态流转和完成判定必须进入 SKILL.md、canonical contract、schema、validator 或 gate。

## Fixed Failure Shape

失败输出至少包含 status、failure_code、reason、owner、safe_to_continue、next_action、evidence_refs、user_message。status 使用 BLOCKED、FAIL 或 PARTIAL；safe_to_continue 为 false 时不得进入下游执行。

## Fresh Proof Boundary

fresh proof 必须来自当前命令输出、当前测试或构建结果、当前执行日志，或由 gate/reviewer/closeout 重跑并捕获当前输出。命令字符串本身只是 replay instruction，不能单独证明当前执行已经发生。
```

4. [T1] Add a discoverability link from `shared/reference/Skill质量标准.md` to the new runtime-layering standard.

```markdown
运行面分层与 progressive disclosure 的职责边界以 `shared/reference/StandardChain运行面分层标准.md` 为准；本文件只评估 Skill artifact 质量，不替代 runtime truth、gate 或 canonical contract。
```

5. [T1] Create `developer-migration-audit.json` with concrete audit rows for the pilot.

```json
[
  {
    "source_ref": "shared/skills/developer/SKILL.md#HARD-GATE",
    "content_type": "hard_gate",
    "action": "keep",
    "destination_ref": "shared/skills/developer/SKILL.md#HARD-GATE",
    "consumer": "agent",
    "verification_ref": "bash tests/test-developer-runtime-layering-skill.sh",
    "reason": "Developer hard gates are unconditional runtime constraints and must stay in the main runtime path.",
    "owner": "developer"
  },
  {
    "source_ref": "shared/skills/developer/SKILL.md#前置条件",
    "content_type": "protocol",
    "action": "rewrite",
    "destination_ref": "shared/skills/developer/SKILL.md#Runtime-Preflight",
    "consumer": "agent",
    "verification_ref": "bash tests/test-developer-runtime-failure-matrix.sh",
    "reason": "Preflight must route missing or ambiguous inputs through a fixed failure contract before TDD starts.",
    "owner": "developer"
  },
  {
    "source_ref": "shared/skills/developer/references/execution-decomposition-guide.md",
    "content_type": "reference_methodology",
    "action": "keep",
    "destination_ref": "shared/skills/developer/references/execution-decomposition-guide.md",
    "consumer": "agent",
    "verification_ref": "bash tests/test-developer-runtime-layering-skill.sh",
    "reason": "Execution decomposition is triggered methodology; SKILL.md controls when it is loaded and what evidence it consumes.",
    "owner": "developer"
  },
  {
    "source_ref": "contracts/canonical/templates/runtime/developer-report.template.json",
    "content_type": "template_skeleton",
    "action": "rewrite",
    "destination_ref": "contracts/canonical/templates/runtime/developer-report.template.json",
    "consumer": "validator",
    "verification_ref": "bash tests/test-developer-runtime-proof-contract.sh",
    "reason": "Template must expose the fixed failure and fresh-proof fields while schema and validator remain authoritative.",
    "owner": "contract-owner"
  },
  {
    "source_ref": "shared/skills/developer/projections/developer-report-template.md",
    "content_type": "projection_display",
    "action": "rewrite",
    "destination_ref": "shared/skills/developer/projections/developer-report-template.md",
    "consumer": "human reviewer",
    "verification_ref": "bash tests/test-developer-runtime-layering-skill.sh",
    "reason": "Projection may display evidence but cannot be consumed as runtime truth.",
    "owner": "developer"
  },
  {
    "source_ref": "shared/skills/developer/scripts/completion_check.sh",
    "content_type": "script_check",
    "action": "rewrite",
    "destination_ref": "shared/skills/developer/scripts/completion_check.sh",
    "consumer": "gate",
    "verification_ref": "bash tests/test-developer-runtime-failure-matrix.sh",
    "reason": "Completion gate must call deterministic validation and fail closed on contract failures.",
    "owner": "developer"
  },
  {
    "source_ref": "shared/skills/developer/evals/evals.json",
    "content_type": "eval",
    "action": "rewrite",
    "destination_ref": "shared/skills/developer/evals/evals.json",
    "consumer": "eval",
    "verification_ref": "bash tests/test-developer-runtime-layering-evals.sh",
    "reason": "Eval set must cover positive, negative, triggered, and untriggered runtime paths.",
    "owner": "developer"
  },
  {
    "source_ref": "docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/design.md",
    "content_type": "history",
    "action": "archive",
    "destination_ref": "docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/design.md",
    "consumer": "human reviewer",
    "verification_ref": "bash tests/test-standard-chain-login-homepage-pilot.sh",
    "reason": "Older design remains historical evidence and regression context, not runtime truth for this redesign.",
    "owner": "standard-chain-runtime-owner"
  }
]
```

6. [T1] Run the runtime-layering contract test.

Run: `bash tests/test-standard-chain-runtime-layering-contract.sh`
Expected: `[PASS] standard-chain runtime layering contract`

### Task 2: Developer report failure and fresh-proof contract [T2]

Context: The developer report is the canonical handoff from implementation to verification. It must carry the fixed failure shape and make fresh proof auditable without claiming a command string alone proves execution.

Files:
- Modify: `contracts/canonical/schemas/runtime/developer-report.schema.json`
- Modify: `contracts/canonical/templates/runtime/developer-report.template.json`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json`
- Create: `tests/fixtures/developer-runtime-layering/verified-report.json`
- Create: `tests/fixtures/developer-runtime-layering/blocked-report.json`
- Create: `tests/test-developer-runtime-proof-contract.sh`

1. [T2] Write the failing proof-contract test.

```bash
bash tests/test-developer-runtime-proof-contract.sh
```

Expected: FAIL because the schema/template do not yet contain `failure_contract` or `fresh_proof`.

2. [T2] Create `tests/test-developer-runtime-proof-contract.sh` with schema and mutation checks.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALID="$ROOT/tests/fixtures/developer-runtime-layering/verified-report.json"
BLOCKED="$ROOT/tests/fixtures/developer-runtime-layering/blocked-report.json"

validate_report() {
  local report="$1"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-proof.XXXXXX")"
  jq -n --slurpfile artifact "$report" '{artifacts: [$artifact[0]]}' >"$tmp"
  python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$tmp" >/dev/null
  rm -f "$tmp"
}

validate_report "$VALID"
validate_report "$BLOCKED"

jq -e '.failure_contract.status == "BLOCKED" and .failure_contract.safe_to_continue == false' "$BLOCKED" >/dev/null
jq -e '.fresh_proof.current_evidence_refs | length > 0' "$VALID" >/dev/null
jq -e 'all(.fresh_proof.proving_commands[]; (.current_output_ref // "") | length > 0)' "$VALID" >/dev/null

BROKEN="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-proof-broken.XXXXXX")"
jq 'del(.fresh_proof.current_evidence_refs) | .fresh_proof.proving_commands[0].current_output_ref = ""' "$VALID" >"$BROKEN"
if validate_report "$BROKEN" >/dev/null 2>&1; then
  printf '[FAIL] verified report without current fresh proof evidence passed\n' >&2
  exit 1
fi
rm -f "$BROKEN"

BROKEN_BLOCKED="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-blocked-broken.XXXXXX")"
jq 'del(.failure_contract.owner)' "$BLOCKED" >"$BROKEN_BLOCKED"
if validate_report "$BROKEN_BLOCKED" >/dev/null 2>&1; then
  printf '[FAIL] blocked report without failure_contract.owner passed\n' >&2
  exit 1
fi
rm -f "$BROKEN_BLOCKED"

printf '[PASS] developer runtime proof contract\n'
```

3. [T2] Add `failure_contract` to `developer-report.schema.json`.

```json
{
  "failure_contract": {
    "type": "object",
    "required": [
      "status",
      "failure_code",
      "reason",
      "owner",
      "safe_to_continue",
      "next_action",
      "evidence_refs",
      "user_message"
    ],
    "properties": {
      "status": { "type": "string", "enum": ["BLOCKED", "FAIL", "PARTIAL"] },
      "failure_code": {
        "type": "string",
        "enum": [
          "MISSING_INPUT",
          "AMBIGUOUS_SCOPE",
          "UNRESOLVED_REF",
          "OWNER_MISMATCH",
          "SCHEMA_FAILURE",
          "GATE_FAILURE",
          "OUT_OF_SCOPE_CHANGE",
          "STALE_STATE_REPLAY",
          "FRESH_PROOF_GAP"
        ]
      },
      "reason": { "type": "string", "minLength": 1 },
      "owner": {
        "type": "string",
        "enum": [
          "delivery-owner",
          "developer",
          "design",
          "tech-lead",
          "product-manager",
          "test-design",
          "verify",
          "standard-chain-runtime-owner"
        ]
      },
      "safe_to_continue": { "type": "boolean", "const": false },
      "next_action": { "type": "string", "minLength": 1 },
      "evidence_refs": {
        "type": "array",
        "minItems": 1,
        "items": { "type": "string", "minLength": 1 }
      },
      "user_message": { "type": "string", "minLength": 1 }
    },
    "additionalProperties": false
  }
}
```

4. [T2] Add `fresh_proof` to `developer-report.schema.json`.

```json
{
  "fresh_proof": {
    "type": "object",
    "required": ["current_evidence_refs", "proving_commands"],
    "properties": {
      "current_evidence_refs": {
        "type": "array",
        "minItems": 1,
        "items": { "type": "string", "minLength": 1 }
      },
      "proving_commands": {
        "type": "array",
        "minItems": 1,
        "items": {
          "type": "object",
          "required": ["command", "current_output_ref", "result"],
          "properties": {
            "command": { "type": "string", "minLength": 1 },
            "current_output_ref": { "type": "string", "minLength": 1 },
            "result": { "type": "string", "enum": ["PASS", "FAIL", "BLOCKED", "PARTIAL"] }
          },
          "additionalProperties": true
        }
      }
    },
    "additionalProperties": true
  }
}
```

5. [T2] Require `fresh_proof` when `runtime_status` is `VERIFIED` and require `failure_contract` when `runtime_status` is `BLOCKED` or `PARTIAL`.

```json
{
  "if": { "properties": { "runtime_status": { "const": "VERIFIED" } } },
  "then": { "required": ["fresh_proof"] }
}
```

```json
{
  "if": { "properties": { "runtime_status": { "enum": ["BLOCKED", "PARTIAL"] } } },
  "then": { "required": ["failure_contract"] }
}
```

6. [T2] Update `developer-report.template.json`, `verified-report.json`, `blocked-report.json`, and the golden-pilot developer report with concrete values.

```json
{
  "fresh_proof": {
    "current_evidence_refs": [
      "artifact://evidence/sample-feature.phase-1.task-T1.log@ev-2#current-command-output"
    ],
    "proving_commands": [
      {
        "command": "bash tests/test-standard-chain-login-homepage-pilot.sh",
        "current_output_ref": "artifact://evidence/sample-feature.phase-1.task-T1.log@ev-2#login-regression-pass",
        "result": "PASS"
      }
    ]
  }
}
```

```json
{
  "failure_contract": {
    "status": "BLOCKED",
    "failure_code": "MISSING_INPUT",
    "reason": "canonical design.json is missing from the developer dispatch",
    "owner": "delivery-owner",
    "safe_to_continue": false,
    "next_action": "redispatch the task with work_dir, design.json, tasks.json, AC list, and file range",
    "evidence_refs": [
      "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#blocked"
    ],
    "user_message": "缺少 developer 前置输入，已阻断真实代码修改。"
  }
}
```

7. [T2] Run the proof-contract test.

Run: `bash tests/test-developer-runtime-proof-contract.sh`
Expected: `[PASS] developer runtime proof contract`

### Task 3: Developer deterministic validator and failure matrix [T3]

Context: The schema proves shape, but the runtime needs deterministic validation for refs, owner routing, stale replay, and fresh-proof evidence. This task creates the failure matrix and wires it into the completion gate.

Files:
- Create: `tools/community/validate_developer_runtime_contract.py`
- Modify: `shared/skills/developer/scripts/completion_check.sh`
- Modify: `shared/skills/developer/scripts/manifest.json`
- Create: `tests/fixtures/developer-runtime-layering/phase-1/unit-1/design.json`
- Create: `tests/fixtures/developer-runtime-layering/phase-1/unit-1/tasks.json`
- Create: `tests/fixtures/developer-runtime-layering/phase-1/unit-1/test-cases.json`
- Create: `tests/fixtures/developer-runtime-layering/phase-1/unit-1/tasks/T1/developer-report.json`
- Create: `tests/test-developer-runtime-failure-matrix.sh`

1. [T3] Write the failing failure-matrix test.

```bash
bash tests/test-developer-runtime-failure-matrix.sh
```

Expected: FAIL because the developer runtime validator does not exist and the completion gate cannot detect all declared failure rows.

2. [T3] Create `tests/test-developer-runtime-failure-matrix.sh` with positive, negative, and retry probes.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/tests/fixtures/developer-runtime-layering/phase-1/unit-1"
REPORT="$FIXTURE/tasks/T1/developer-report.json"

run_validator() {
  python3 "$ROOT/tools/community/validate_developer_runtime_contract.py" \
    --phase-dir "$FIXTURE" \
    --task-id T1 \
    --report "$REPORT"
}

run_validator >/dev/null

expect_block() {
  local label="$1" jq_filter="$2" expected_code="$3"
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/developer-runtime-matrix.XXXXXX")"
  cp -R "$FIXTURE" "$tmp/unit-1"
  jq "$jq_filter" "$REPORT" >"$tmp/unit-1/tasks/T1/developer-report.json"
  if python3 "$ROOT/tools/community/validate_developer_runtime_contract.py" --phase-dir "$tmp/unit-1" --task-id T1 --report "$tmp/unit-1/tasks/T1/developer-report.json" >"$tmp/out.json" 2>/dev/null; then
    printf '[FAIL] %s passed unexpectedly\n' "$label" >&2
    exit 1
  fi
  jq -e --arg code "$expected_code" '.failure_contract.failure_code == $code and .failure_contract.safe_to_continue == false' "$tmp/out.json" >/dev/null
  rm -rf "$tmp"
}

expect_block "missing input" 'del(.active_plan_version_ref)' "MISSING_INPUT"
expect_block "ambiguous scope" '.task_scope = [] | .runtime_status = "PARTIAL"' "AMBIGUOUS_SCOPE"
expect_block "unresolved ref" '.tdd_evidence_index[0].ac_refs = ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-UNKNOWN"]' "UNRESOLVED_REF"
expect_block "owner mismatch" '.failure_contract.owner = "developer" | .runtime_status = "BLOCKED"' "OWNER_MISMATCH"
expect_block "out of scope" '.file_changes = ["src/outside.ts"]' "OUT_OF_SCOPE_CHANGE"
expect_block "stale replay" '.active_plan_version_ref = "artifact://plan/sample-feature.phase-1.plan@old#plan-version"' "STALE_STATE_REPLAY"
expect_block "fresh proof gap" 'del(.fresh_proof.current_evidence_refs)' "FRESH_PROOF_GAP"

printf '[PASS] developer runtime failure matrix\n'
```

3. [T3] Implement `tools/community/validate_developer_runtime_contract.py` as a deterministic validator with a closed failure output.

```python
FAILURE_OWNER = {
    "MISSING_INPUT": "delivery-owner",
    "AMBIGUOUS_SCOPE": "delivery-owner",
    "UNRESOLVED_REF": "delivery-owner",
    "OWNER_MISMATCH": "delivery-owner",
    "SCHEMA_FAILURE": "developer",
    "GATE_FAILURE": "developer",
    "OUT_OF_SCOPE_CHANGE": "delivery-owner",
    "STALE_STATE_REPLAY": "standard-chain-runtime-owner",
    "FRESH_PROOF_GAP": "developer",
}

def failure(code: str, reason: str, evidence_refs: list[str]) -> dict:
    owner = FAILURE_OWNER[code]
    return {
        "runtime_status": "BLOCKED",
        "failure_contract": {
            "status": "BLOCKED",
            "failure_code": code,
            "reason": reason,
            "owner": owner,
            "safe_to_continue": False,
            "next_action": next_action_for(code, owner),
            "evidence_refs": evidence_refs,
            "user_message": user_message_for(code),
        },
    }
```

4. [T3] Add concrete deterministic checks to the validator.

```python
def validate_required_inputs(phase_dir: Path, report: dict) -> None:
    required_files = ["design.json", "tasks.json"]
    missing = [name for name in required_files if not (phase_dir / name).is_file()]
    required_fields = ["active_plan_version_ref", "active_tasks_version_ref", "task_id", "task_scope", "evidence_refs"]
    missing.extend(field for field in required_fields if not report.get(field))
    if missing:
        raise DeveloperRuntimeFailure("MISSING_INPUT", "missing developer runtime inputs: " + ", ".join(sorted(missing)))

def validate_scope(report: dict, task: dict) -> None:
    scope = set(report.get("task_scope", []))
    allowed = set(task.get("file_range", [])) | set(task.get("files", [])) | set(task.get("task_scope", []))
    if not scope or not allowed:
        raise DeveloperRuntimeFailure("AMBIGUOUS_SCOPE", "developer file scope is missing or ambiguous")
    outside = sorted(set(report.get("file_changes", [])) - allowed)
    if outside:
        raise DeveloperRuntimeFailure("OUT_OF_SCOPE_CHANGE", "developer report changes files outside dispatch scope: " + ", ".join(outside))

def validate_fresh_proof(report: dict) -> None:
    proof = report.get("fresh_proof") or {}
    if report.get("runtime_status") == "VERIFIED" and not proof.get("current_evidence_refs"):
        raise DeveloperRuntimeFailure("FRESH_PROOF_GAP", "verified developer report lacks current fresh proof evidence")
    for row in proof.get("proving_commands", []):
        if row.get("command") and not row.get("current_output_ref"):
            raise DeveloperRuntimeFailure("FRESH_PROOF_GAP", "proving command has no current output reference")
```

5. [T3] Wire `completion_check.sh` to call the validator after schema validation.

```bash
if ! python3 "$RUNTIME_ROOT/tools/community/validate_developer_runtime_contract.py" \
    --phase-dir "$(dirname "$(dirname "$report")")" \
    --task-id "$(basename "$(dirname "$report")")" \
    --report "$report" >"$semantic_out" 2>&1; then
    add_failure "developer runtime contract validation failed: $report"
    while IFS= read -r line; do
        [ -n "$line" ] && add_failure "$line"
    done < <(sed -n '1,6p' "$semantic_out")
fi
```

6. [T3] Update `shared/skills/developer/scripts/manifest.json` so `tools/community/validate_developer_runtime_contract.py` is declared as an allowed deterministic dependency and `bash tests/test-developer-runtime-failure-matrix.sh` is included in verification evidence.

```json
{
  "verification_command": "bash tests/test-developer-contract-alignment.sh && bash tests/test-developer-runtime-failure-matrix.sh"
}
```

7. [T3] Run the failure-matrix test and the existing developer gate alignment test.

Run: `bash tests/test-developer-runtime-failure-matrix.sh`
Expected: `[PASS] developer runtime failure matrix`

Run: `bash tests/test-developer-contract-alignment.sh`
Expected: existing developer contract assertions still pass.

### Task 4: Developer Skill runtime layering refactor [T4]

Context: Once the mechanical contract exists, the Skill body can be simplified around runtime protocol and triggered references. This task must not move unconditional gates into references or projections.

Files:
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/developer/references/execution-decomposition-guide.md`
- Modify: `shared/skills/developer/references/self-testing-methodology.md`
- Modify: `shared/skills/developer/references/self-review-methodology.md`
- Modify: `shared/skills/developer/projections/developer-report-template.md`
- Create: `tests/test-developer-runtime-layering-skill.sh`

1. [T4] Write the failing Skill layering test.

```bash
bash tests/test-developer-runtime-layering-skill.sh
```

Expected: FAIL because the developer Skill does not yet name the runtime layering contract, fixed failure shape, or fresh-proof boundary in a mechanically testable way.

2. [T4] Create `tests/test-developer-runtime-layering-skill.sh` with static layer assertions.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/developer/SKILL.md"
PROJECTION="$ROOT/shared/skills/developer/projections/developer-report-template.md"

require_pattern() {
  local label="$1" pattern="$2" file="$3"
  if ! rg -n "$pattern" "$file" >/dev/null 2>&1; then
    printf '[FAIL] %s\n' "$label" >&2
    exit 1
  fi
}

require_absent() {
  local label="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    printf '[FAIL] %s\n' "$label" >&2
    exit 1
  fi
}

require_pattern "developer names runtime layering standard" 'StandardChain运行面分层标准\.md' "$SKILL"
require_pattern "developer keeps hard gates" '^## HARD-GATE$' "$SKILL"
require_pattern "developer has runtime preflight" '^## Runtime Preflight$' "$SKILL"
require_pattern "developer has reference trigger table" '^## Reference Trigger Table$' "$SKILL"
require_pattern "developer has fixed failure shape" 'failure_contract.*failure_code.*safe_to_continue' "$SKILL"
require_pattern "developer has fresh proof boundary" 'fresh_proof.*current_evidence_refs' "$SKILL"
require_pattern "developer names BLOCKED owner routing" 'BLOCKED.*delivery-owner' "$SKILL"
require_pattern "projection says display only" 'display-only|展示层|不作为 runtime truth' "$PROJECTION"
require_absent "projection is not canonical output source" '作为 standard-chain 输出模板|runtime truth' "$PROJECTION"

for ref in "$ROOT"/shared/skills/developer/references/*.md; do
  require_absent "reference must not define hard gate: $ref" '^## HARD-GATE$|failure_contract.*safe_to_continue' "$ref"
done

printf '[PASS] developer runtime layering skill\n'
```

3. [T4] Add a compact runtime contract block to `shared/skills/developer/SKILL.md`.

```markdown
## Runtime Layering Contract

Developer follows `shared/reference/StandardChain运行面分层标准.md`.

- `SKILL.md` owns trigger, role boundary, hard gates, runtime preflight, stop/routing, reference triggers, output, and completion boundary.
- `references/` own triggered methodology only. When a trigger fires, read the reference and write a consumption artifact in the mini-plan, `self_testing`, self-review, or `developer-report.json`.
- `contracts/canonical` own developer-report shape. Projection files are display-only and never runtime truth.
- `scripts/` and validators own deterministic checks. They may block or route but may not accept risk on behalf of developer, verify, or delivery-owner.
```

4. [T4] Replace free-form missing-input handling with `Runtime Preflight`.

```markdown
## Runtime Preflight

Before RED, resolve:

- `work_dir` / `unit_work_dir`
- `{phase_dir}/design.json`
- `{phase_dir}/tasks.json`
- current Task AC list
- current Task `file_range`, `files`, or `task_scope`
- optional `{unit_work_dir}/test-cases.json`

If any required input is missing, ambiguous, unreadable, unresolved, owned by another role, or outside scope, output `runtime_status: "BLOCKED"` and `failure_contract` with `safe_to_continue: false`; do not modify code.
```

5. [T4] Add `Reference Trigger Table` to `SKILL.md`.

```markdown
## Reference Trigger Table

| Trigger | Read | Consume Into |
| --- | --- | --- |
| Before TDD planning | `references/execution-decomposition-guide.md` | mini-plan, risk notes, reuse decision, developer-report execution decomposition |
| After TDD loop | `references/self-testing-methodology.md` | `developer-report.json.self_testing` and fresh proof evidence refs |
| Before report output | `references/self-review-methodology.md` | `developer-report.json.evidence_refs` and `reviewable_anchor` |
```

6. [T4] Update the three developer reference files so each states its trigger and consumer while leaving hard gates in `SKILL.md`.

```markdown
> Triggered by `shared/skills/developer/SKILL.md#Reference-Trigger-Table`.
> Consumer: this methodology must leave evidence in `developer-report.json`; it is not a source of runtime truth.
```

7. [T4] Update the projection template display warning.

```markdown
> Display-only projection. The canonical runtime artifact is `{unit_work_dir}/tasks/{task_id}/developer-report.json`; verify and gates consume canonical JSON, not this Markdown projection.
```

8. [T4] Run the Skill layering test.

Run: `bash tests/test-developer-runtime-layering-skill.sh`
Expected: `[PASS] developer runtime layering skill`

### Task 5: Developer eval and lifecycle evidence upgrade [T5]

Context: The eval set must prove the intended AI behavior, including when references are not triggered and when failure paths block. Lifecycle evidence must cite commands, not confidence summaries.

Files:
- Modify: `shared/skills/developer/evals/evals.json`
- Modify: `shared/skills/developer/evals/lifecycle-review.json`
- Create: `tests/test-developer-runtime-layering-evals.sh`

1. [T5] Write the failing eval coverage test.

```bash
bash tests/test-developer-runtime-layering-evals.sh
```

Expected: FAIL because developer evals do not yet include the runtime-layering negative and progressive-disclosure cases.

2. [T5] Create `tests/test-developer-runtime-layering-evals.sh` with id and anchor checks.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVALS="$ROOT/shared/skills/developer/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/developer/evals/lifecycle-review.json"

jq -e '
  [.evals[].id] as $ids
  | [
      "runtime-layering-triggered-reference",
      "runtime-layering-untriggered-reference",
      "runtime-layering-missing-input-block",
      "runtime-layering-unresolved-ref-block",
      "runtime-layering-owner-mismatch-block",
      "runtime-layering-out-of-scope-block",
      "runtime-layering-stale-replay-block",
      "runtime-layering-fresh-proof-gap"
    ] as $required
  | all($required[]; $ids | index(.) != null)
  and ([.preference_anchors[].id] | index("PA-7") != null)
  and ([.preference_anchors[].id] | index("PA-8") != null)
' "$EVALS" >/dev/null

jq -e '
  (.runtime_layering_pilot.status == "planned")
  and (.runtime_layering_pilot.verification_commands | index("bash tests/test-developer-runtime-failure-matrix.sh") != null)
  and (.runtime_layering_pilot.verification_commands | index("bash tests/test-developer-runtime-layering-skill.sh") != null)
  and (.runtime_layering_pilot.verification_commands | index("bash tests/test-developer-runtime-proof-contract.sh") != null)
' "$LIFECYCLE" >/dev/null

printf '[PASS] developer runtime layering evals\n'
```

3. [T5] Add the runtime-layering eval IDs to `evals.json` with concrete prompts.

```json
{
  "id": "runtime-layering-fresh-proof-gap",
  "prompt": "Task T9 的 RED/GREEN 都写在 developer-report.json 摘要里，但 fresh_proof 只有命令字符串，没有 current_evidence_refs 或 current_output_ref。请按 developer skill 判断能否交付给 verify。",
  "expected_output": "必须阻断完成，输出 runtime_status BLOCKED 或 PARTIAL，并用 failure_contract.failure_code=FRESH_PROOF_GAP 说明命令字符串只是 replay instruction；要求补当前命令输出、当前测试结果或执行日志。",
  "files": [],
  "expectations": [
    "识别 fresh proof 缺少当前证据",
    "不把命令字符串当作完成证明",
    "输出固定 failure_contract",
    "不交付给 verify"
  ],
  "expected_anchors": ["PA-6", "PA-7", "PA-8"],
  "run_modes": ["with_skill", "without_skill"]
}
```

4. [T5] Add preference anchors for progressive disclosure and fixed failure routing.

```json
{
  "id": "PA-7",
  "anchor": "reference 按触发条件读取，并产生消费证据",
  "weight": 1
}
```

```json
{
  "id": "PA-8",
  "anchor": "缺输入、越界、ref 失败或 fresh proof 缺口必须输出固定 failure_contract 并阻断",
  "weight": 1
}
```

5. [T5] Add `runtime_layering_pilot` to lifecycle review.

```json
{
  "runtime_layering_pilot": {
    "status": "planned",
    "design_ref": "docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/design.md",
    "verification_commands": [
      "bash tests/test-standard-chain-runtime-layering-contract.sh",
      "bash tests/test-developer-runtime-proof-contract.sh",
      "bash tests/test-developer-runtime-failure-matrix.sh",
      "bash tests/test-developer-runtime-layering-skill.sh",
      "bash tests/test-developer-runtime-layering-evals.sh"
    ],
    "interpretation": "developer remains an optimize-state process-compliance pilot until runtime-layering evidence proves stable behavior in real standard-chain execution."
  }
}
```

6. [T5] Run the eval and existing skill-eval tests.

Run: `bash tests/test-developer-runtime-layering-evals.sh`
Expected: `[PASS] developer runtime layering evals`

Run: `bash tests/test-standard-chain-skill-evals.sh`
Expected: existing skill eval framework still passes.

### Task 6: Route, regression, and context closeout [T6]

Context: The implementation is not complete until the route, context contract, developer pilot commands, and existing login pilot regression all pass. This task also preserves the active registry boundary from the design.

Files:
- Modify: `docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/tasks.md`
- Modify: `docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/execution-route.json`
- Modify: `docs/standard-chain-flow-optimization/worklog.md`

1. [T6] Run task-plan consistency.

Run: `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/tasks.md docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/plan.md`
Expected: `[PASS] tasks-plan consistency`

2. [T6] Refresh the implementation route explicitly for this workset.

Run: `python3 tools/community/implementation_router.py --repo-root . --feature-path docs/standard-chain-flow-optimization --workset 2026-04-28-runtime-layering-redesign --force-refresh`
Expected: JSON with `"decision": "serial"` and `"workset": "2026-04-28-runtime-layering-redesign"`.

3. [T6] Run the context and contract validators without changing `contracts/active-doc-scope.yaml`.

Run: `python3 tools/community/validate_context_contract.py --repo-root .`
Expected: PASS output from the context contract validator.

Run: `bash tools/dev/validate-contracts.sh`
Expected: PASS output from the repository contract validator.

4. [T6] Run all task proving commands.

```bash
bash tests/test-standard-chain-runtime-layering-contract.sh
bash tests/test-developer-runtime-proof-contract.sh
bash tests/test-developer-runtime-failure-matrix.sh
bash tests/test-developer-runtime-layering-skill.sh
bash tests/test-developer-runtime-layering-evals.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-standard-chain-login-homepage-pilot.sh
```

Expected: every command exits 0; login homepage remains a regression sample and not the source of truth for the new design.

5. [T6] Mark each task checkbox in `tasks.md` only after its AC command passes.

Run: `rg -n '^- \\[ \\] T' docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/tasks.md`
Expected: no output after all AC commands have passed.

6. [T6] Append a worklog record only after route and validation pass.

```markdown
## 2026-04-28 HH:MM

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: verify
- scope_ref: 2026-04-28-runtime-layering-redesign/tasks.md
- handoff_status: done
- state_ref: 2026-04-28-runtime-layering-redesign/tasks.md
- next: Runtime layering developer pilot is implemented and verified; registry cutover remains excluded until explicit approval.
- next_ref: 2026-04-28-runtime-layering-redesign/execution-route.json
```

7. [T6] Confirm the active registry still points to the parallel workset.

Run: `rg -n 'primary_workset_relpath: 2026-04-28-test-design-governance' contracts/active-doc-scope.yaml`
Expected: one matching line under the `docs/standard-chain-flow-optimization` managed scope entry.
