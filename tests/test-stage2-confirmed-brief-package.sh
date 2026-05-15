#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

HANDOFF_SCRIPT="$ROOT/tools/eval/scripts/render_stage2_product_director_handoff.py"
SCRIPT="$ROOT/tools/eval/scripts/validate_stage2_confirmed_brief_package.py"
EXAMPLE="$ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-facts.example.json"

[ -f "$HANDOFF_SCRIPT" ] || fail "missing Stage 2 product-director handoff renderer"
[ -f "$SCRIPT" ] || fail "missing Stage 2 confirmed brief package validator"
[ -f "$EXAMPLE" ] || fail "missing Stage 2 intake facts example"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

REAL_INTAKE="$TMP_ROOT/real-stage2-intake-facts.json"
python3 - "$EXAMPLE" "$REAL_INTAKE" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
source["intake_provenance"] = {
    "source_type": "human_business_owner_input",
    "filled_by": "产研负责人",
    "confirmed_by": "客服运营负责人",
    "confirmed_at": "2026-05-14",
    "confirmation_basis": "human/business owner 明确确认该文件用于 Stage 2 真实采证入口",
    "fact_source_refs": [
        "human://客服运营负责人/stage-2-intake-confirmation/2026-05-14",
        "doc://stage-2-intake-business-sample",
    ],
    "not_copied_from_example": True,
}
Path(sys.argv[2]).write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

HANDOFF="$TMP_ROOT/handoff.json"
python3 "$HANDOFF_SCRIPT" --intake "$REAL_INTAKE" >"$HANDOFF" \
  || fail "real Stage 2 intake should render product-director handoff"

PACKAGE="$TMP_ROOT/confirmed-brief-package.json"
python3 - "$HANDOFF" "$PACKAGE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path


def digest(snapshot):
    raw = json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


handoff = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
focus = handoff["director_focus"]
business_context = focus["business_context"]
metrics = focus["success_metrics"]
confirmed_at = "2026-05-14T00:00:00Z"
brief_lock = {
    "root_problem": focus["root_problem_input"],
    "user_profile": [
        {
            "who": business_context["real_user"],
            "scenario": business_context["scenario"],
            "current_workaround": "沿用旧 qft-pai 主流程，由人工在上下文不足、agent 失败或链路不可观测时兜底处理",
            "workaround_cost": "消息回调、上下文拼装、agent 调度和响应处理耦合，失败难定位，交付风险不可稳定证明",
        }
    ],
    "business_goals": [
        focus["target_outcome"],
        *[f"{item['name']}：{item['threshold']}" for item in metrics],
    ],
    "appetite": {
        "investment_scale": "Phase 1 只冻结单渠道文本消息建议回复闭环",
        "complexity_ceiling": "只允许真实采证和边界冻结，不做语言选型、架构定版、代码修改或上线",
        "trim_first": "附件/语音/图片、多渠道接入、复杂工单和自动外发",
    },
    "scope_boundaries": [
        focus["phase1_candidate_boundary"],
        "建议回复必须进入人工确认，不允许自动外发",
    ],
    "non_goals": [
        "不做语言选型",
        "不做代码修改",
        "不自动外发客户消息",
        "不替 human/business owner 接受业务风险",
    ],
    "feasibility_constraints": [
        {
            "type": "authorization",
            "constraint": focus["risk_acceptance_boundary"],
            "impact_scope": "phase-1",
            "handling": "handoff 的 blocked_actions 在 product-manager 之前继续生效",
        }
    ],
    "risks_and_unknowns": [
        {
            "item": "真实三方协议字段、SLA 和失败语义仍需 qft-pai 真实采证确认",
            "impact": "可能改变 Phase 1 范围和后续语言/架构选择",
            "mitigation": "product-director 先冻结 confirmed brief，再交给 product-manager 拆 PRD",
            "status": "OPEN",
        }
    ],
    "decision_rationale": [
        {
            "decision": "先冻结单渠道文本消息建议回复闭环",
            "choice": "以真实采证和 Phase 1 边界作为下一步，而不是直接重写",
            "rationale": "当前目标是验证一人 + agents 的真实交付链路，避免方案先行",
            "excluded_options": "未采证前语言选型、架构定版、代码修改、上线或自动外发",
        }
    ],
    "delivery_plan": [
        {
            "phase_id": "phase-1",
            "goal": focus["phase1_candidate_boundary"],
            "iteration_timebox_days": 14,
        }
    ],
}
phase_lock = {
    "phase_goal": focus["phase1_candidate_boundary"],
    "entry_conditions": [
        "Stage 2 intake facts 已通过 validator",
        "product-director handoff package 已生成",
        "blocked_actions 在 product-manager 之前继续生效",
    ],
    "exit_conditions": [
        *[f"{item['name']}：{item['threshold']}" for item in metrics],
        "不自动外发，失败可进入人工接管",
    ],
}
brief = {
    "artifact_type": "brief",
    "artifact_id": "qft-pai-stage2-phase1.brief",
    "schema_version": "1.0.0",
    "producer": "product",
    "produced_at": confirmed_at,
    "chain_version": "standard-chain/v1",
    "chain_registry_digest": "sha256:4c810553fe67ab70692a23ce9be83b2863d048936cc059a510df30fc56589dd0",
    "authority_scope": "artifact",
    "authoritative_fields": [
        "$.root_problem",
        "$.user_profile",
        "$.business_goals",
        "$.appetite",
        "$.scope_boundaries",
        "$.non_goals",
        "$.feasibility_constraints",
        "$.risks_and_unknowns",
        "$.decision_rationale",
        "$.delivery_plan",
        "$.director_confirmation",
    ],
    **brief_lock,
    "director_confirmation": {
        "status": "passed",
        "confirmed_at": confirmed_at,
        "locked_field_digest": digest(brief_lock),
        "locked_fields": brief_lock,
    },
}
phase_prd = {
    "artifact_type": "phase-prd",
    "artifact_id": "qft-pai-stage2-phase1.phase-1.prd",
    "schema_version": "1.0.0",
    "producer": "product",
    "produced_at": confirmed_at,
    "chain_version": "standard-chain/v1",
    "chain_registry_digest": "sha256:4c810553fe67ab70692a23ce9be83b2863d048936cc059a510df30fc56589dd0",
    "authority_scope": "phase",
    "authoritative_fields": [
        "$.phase_goal",
        "$.entry_conditions",
        "$.exit_conditions",
        "$.director_confirmation",
    ],
    **phase_lock,
    "unit_index": [],
    "director_confirmation": {
        "status": "passed",
        "confirmed_at": confirmed_at,
        "locked_field_digest": digest(phase_lock),
        "locked_fields": phase_lock,
    },
}
package = {
    "artifact_type": "stage-2-product-director-confirmed-brief-package",
    "status": "pass",
    "input_origin": "stage-2-product-director-handoff",
    "handoff": handoff,
    "brief": brief,
    "phase_prd": phase_prd,
    "decision_boundary": {
        "allowed_actions": handoff["discovery_boundary"]["allowed_actions"],
        "blocked_actions": handoff["discovery_boundary"]["blocked_actions"],
    },
    "handoff_to": "product-manager",
    "resume_condition": "product_manager_stage2_prd_ready",
}
Path(sys.argv[2]).write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$SCRIPT" --package "$PACKAGE" >"$TMP_ROOT/package-pass.json" \
  || fail "valid Stage 2 confirmed brief package should pass"
python3 - "$TMP_ROOT/package-pass.json" <<'PY' || fail "Stage 2 confirmed brief package output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "confirmed_brief_ready_for_product_manager":
    raise SystemExit(payload)
if payload.get("next_standard_chain_role") != "product-manager":
    raise SystemExit(payload)
checks = {item.get("check") for item in payload.get("checks", [])}
expected = {
    "package_envelope",
    "handoff_binding",
    "brief_alignment",
    "phase_prd_alignment",
    "director_lock",
    "authorization_boundary",
}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
PY

BROKEN="$TMP_ROOT/broken-code-change.json"
python3 - "$PACKAGE" "$BROKEN" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["decision_boundary"]["blocked_actions"] = [
    action for action in payload["decision_boundary"]["blocked_actions"] if action != "code_changes"
]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN" >"$TMP_ROOT/broken-code-change-output.json"; then
  fail "confirmed brief package must keep code_changes blocked"
fi
rg -q "code_changes" "$TMP_ROOT/broken-code-change-output.json" \
  || fail "missing code_changes block should be explicit"

DRIFT="$TMP_ROOT/drift-brief.json"
python3 - "$PACKAGE" "$DRIFT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["brief"]["root_problem"] = "偷偷改成另一个根问题"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$DRIFT" >"$TMP_ROOT/drift-output.json"; then
  fail "confirmed brief package must reject director lock drift"
fi
rg -q "Director-owned field drift|director lock" "$TMP_ROOT/drift-output.json" \
  || fail "director lock drift failure should be explicit"

MANAGER_FIELD="$TMP_ROOT/manager-field.json"
python3 - "$PACKAGE" "$MANAGER_FIELD" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["brief"]["acceptance_criteria"] = ["PM 才能写的验收标准"]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$MANAGER_FIELD" >"$TMP_ROOT/manager-field-output.json"; then
  fail "confirmed brief package must reject PM-owned fields"
fi
rg -q "PM-owned" "$TMP_ROOT/manager-field-output.json" \
  || fail "PM-owned field failure should be explicit"

printf '[PASS] Stage 2 confirmed brief package gate\n'
