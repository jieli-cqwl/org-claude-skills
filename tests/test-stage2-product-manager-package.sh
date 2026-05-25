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

SCRIPT="$ROOT/tools/eval/scripts/validate_stage2_product_manager_package.py"
[ -f "$SCRIPT" ] || fail "missing Stage 2 product-manager package validator"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PACKAGE="$TMP_ROOT/product-manager-package.json"
python3 - "$ROOT" "$PACKAGE" <<'PY'
import copy
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/eval/scripts"))

from render_stage2_product_director_handoff import render
from validate_stage2_confirmed_brief_materials import build_package
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate


POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger", "delivery_confirmation"}


def digest(snapshot):
    raw = json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def strip_post_review(payload):
    clone = copy.deepcopy(payload)
    for field in POST_REVIEW_FIELDS:
        clone.pop(field, None)
    return clone


def bundle_digest(refs, payloads):
    bundle = [
        {"ref": ref, "payload": strip_post_review(payload)}
        for ref, payload in zip(refs, payloads)
    ]
    return digest(bundle)


def review_conclusion(reviewed_refs, reviewed_digest):
    return {
        "verdict": "PASS",
        "summary": "PM artifacts are closed for design consumption",
        "agent_team_review": {
            "mode": "agent_teams",
            "round": "R2",
            "reviewed_artifact_refs": reviewed_refs,
            "reviewed_bundle_digest": reviewed_digest,
            "reviewer_verdicts": [
                {
                    "perspective": perspective,
                    "round": "R2",
                    "verdict": "PASS",
                    "reviewer_output_ref": f"agent-team://{perspective}-reviewer/R2",
                    "artifact_refs": reviewed_refs,
                    "reviewed_bundle_digest": reviewed_digest,
                    "finding_refs": [],
                    "evidence_refs": evidence_refs,
                    "read_only": True,
                }
                for perspective, evidence_refs in [
                    ("product", ["brief.json#acceptance_criteria", "phase-1/phase-prd.json#business_flows"]),
                    ("architecture", ["phase-1/units/UNIT-1.json#integration_context"]),
                    ("test", ["phase-1/units/UNIT-1.json#verification_plan"]),
                ]
            ],
            "convergence_evidence": [
                {
                    "round": "R2",
                    "status": "CONFIRMATION",
                    "evidence_refs": [
                        "brief.json#review_conclusion.agent_team_review",
                        "phase-1/phase-prd.json#review_conclusion.agent_team_review",
                    ],
                }
            ],
        },
    }


def manager_ledger():
    steps = [
        "Handoff gate",
        "Evidence and AS-IS",
        "TO-BE product model",
        "Feature inventory and risk",
        "Pre-UNIT gate",
        "UNIT split",
        "AC",
        "Verification Plan",
        "Design handoff",
        "Self-check",
        "Review digest",
        "Agent review",
        "PM handoff gate",
        "Delivery",
    ]
    confirmations = []
    for index, step in enumerate(steps, start=1):
        checkpoint_id = "product-manager." + step.lower().replace(" ", "-").replace("/", "-")
        confirmations.append(
            {
                "checkpoint_id": checkpoint_id,
                "step": step,
                "subject_ref": f"product-manager.{step}",
                "confirmed_at": f"2026-05-14T00:{index:02d}:00Z",
                "decision_summary": f"{step} closed for qft-pai Stage 2 product-manager package",
                "source_refs": ["stage-2-product-director-confirmed-brief-package"],
                "output_refs": ["phase-1/phase-prd.json", "phase-1/units/UNIT-1.json"],
            }
        )
    return {
        "artifact_type": "co-creation-ledger",
        "schema_version": "1.0.0",
        "producer": "product-manager",
        "scope_ref": "stage-2/qft-pai/phase-1",
        "current_state": {
            "summary": "PM product facts are closed and ready for design handoff",
            "source_refs": ["stage-2-product-director-confirmed-brief-package"],
            "next_step": "handoff to design",
        },
        "latest_checkpoint_id": confirmations[-1]["checkpoint_id"],
        "confirmations": confirmations,
        "open_questions": [],
        "supersedes": [],
        "handoff_refs": ["brief.json", "phase-1/phase-prd.json", "phase-1/units/UNIT-1.json"],
        "finalization_basis": {
            "status": "confirmed",
            "confirmed_at": "2026-05-14T01:00:00Z",
            "summary": "PM handoff package accepted for design entry",
            "accepted_checkpoint_ids": [item["checkpoint_id"] for item in confirmations],
        },
    }


example_payload = load_json(root / DEFAULT_INTAKE.relative_to(root))
handoff, handoff_exit = render(make_real_candidate(example_payload), Path("real-stage2-intake-facts.json"))
if handoff_exit != 0:
    raise SystemExit(handoff)

confirmed_package = build_package(handoff)
brief = copy.deepcopy(confirmed_package["brief"])
phase_prd = copy.deepcopy(confirmed_package["phase_prd"])
unit = {
    "artifact_type": "unit-definition",
    "artifact_id": "qft-pai-stage2-phase1.unit-1",
    "schema_version": "1.0.0",
    "producer": "product",
    "produced_at": "2026-05-14T00:30:00Z",
    "chain_version": "standard-chain/v1",
    "chain_registry_digest": brief["chain_registry_digest"],
    "authority_scope": "artifact",
    "authoritative_fields": [
        "$.unit_id",
        "$.closure_definition",
        "$.trigger",
        "$.core_behavior",
        "$.observable_result",
        "$.feature_refs",
        "$.flow_refs",
        "$.risk_refs",
        "$.rule_refs",
        "$.integration_context",
        "$.acceptance_criteria",
        "$.verification_plan",
        "$.design_decision_candidates",
        "$.exclusions",
        "$.priority",
        "$.priority_basis",
        "$.dependencies",
    ],
    "unit_id": "UNIT-1",
    "closure_definition": "三方消息回调进入前置处理、上下文装配、agent 调度、建议响应生成，并以人工确认作为可观察闭环",
    "trigger": "三方平台推送单渠道文本消息",
    "core_behavior": "接收消息、装配上下文、调度 agent 并生成建议回复",
    "observable_result": "建议回复包进入人工确认状态，客服可查看上下文来源和失败原因，系统不自动外发",
    "feature_refs": ["FEAT-1"],
    "flow_refs": ["TOBE-1", "BPG-1"],
    "risk_refs": ["RISK-1"],
    "rule_refs": ["BR-1"],
    "acceptance_criteria": [
        {
            "ac_id": "AC-U1-01",
            "description": "收到单渠道文本消息回调后生成可人工确认的建议回复",
            "example_input": "三方平台推送一条客户文本消息，带有会话标识和租户标识",
            "expected_result": "系统形成建议回复、上下文来源和人工确认状态，不自动外发",
            "boundary_case": "缺少上下文时进入人工接管状态并暴露缺口原因",
            "failure_mode": "agent 调度失败时保留原始消息和失败原因，不能吞消息或自动回复",
        }
    ],
    "exclusions": ["语音/图片/附件消息", "多渠道统一接入", "自动外发客户消息"],
    "priority": "P0",
    "priority_basis": "没有消息闭环就无法验证后续上下文、调度和响应质量",
    "dependencies": [],
    "integration_context": {
        "business_modules": ["三方消息回调", "客服建议回复", "人工确认"],
        "protected_behaviors": ["Director 冻结的 Phase 1 范围、非目标和不自动外发约束不得变化"],
        "cross_unit_dependencies": [],
        "business_constraints": ["PM 只定义 WHAT 层闭环，不决定语言、架构或代码实现"],
    },
    "verification_plan": [
        {
            "verification_type": "functional",
            "business_operation": "输入一条真实结构的文本消息回调并观察建议回复包",
            "expected_observation": "建议回复包含上下文来源、调度结果和人工确认状态",
            "evidence_target": "AC-U1-01 and Stage 2 success metrics",
            "evidence_types": ["api_request_response", "data_before_after", "test_record"],
            "covers_refs": ["AC-U1-01", "RISK-1", "BR-1"],
        }
    ],
    "design_decision_candidates": [
        {
            "decision_name": "消息回调入口与人工确认状态的设计表达",
            "options": ["单入口状态机", "按消息来源分入口再汇聚"],
            "constraints": "必须保留人工确认、不自动外发、失败可接管",
            "impacted_units": ["UNIT-1"],
            "design_handoff": "design 决定用户/运营可观察状态和接口边界表达",
        }
    ],
}

brief["acceptance_criteria"] = ["单渠道文本消息能形成建议回复，且必须人工确认后才允许外发"]
brief["design_decisions"] = ["消息入口、人工确认状态和失败接管方式交由 design 收口"]
brief["non_functional_requirements"] = ["链路必须可观测，失败不能吞消息，响应处理必须可追溯"]
phase_prd["unit_index"] = ["UNIT-1"]
phase_prd["unit_priority_order"] = [
    {
        "unit_id": "UNIT-1",
        "priority": "P0",
        "priority_basis": "先证明消息闭环可被人工确认，后续才能扩展上下文和调度策略",
    }
]
phase_prd["evidence_sources"] = [
    {
        "evidence_id": "EV-1",
        "source_type": "director_baseline",
        "source_ref": "brief.json#director_confirmation.locked_fields",
        "status": "FACT",
        "supports": ["ASIS-1", "TOBE-1", "FEAT-1", "RISK-1"],
    }
]
phase_prd["as_is_flows"] = [
    {
        "flow_id": "ASIS-1",
        "evidence_refs": ["EV-1"],
        "actors": ["客服运营"],
        "trigger": "三方平台推送客户文本消息",
        "steps": ["接收消息", "人工查看上下文", "人工回复客户"],
        "observed_state": "消息、上下文和回复建议缺少统一闭环",
        "pain_points": ["失败原因和人工接管状态不可追溯"],
    }
]
phase_prd["to_be_flows"] = [
    {
        "flow_id": "TOBE-1",
        "goal_ref": "phase_goal",
        "actors": ["客服运营"],
        "trigger": "三方平台推送单渠道文本消息",
        "steps": ["接收回调", "装配上下文", "调度 agent", "生成建议回复", "等待人工确认"],
        "expected_outcome": "形成可人工确认的建议回复包且不自动外发",
        "branch_coverage": ["正常建议回复", "缺上下文人工接管", "agent 调度失败保留失败原因"],
    }
]
phase_prd["business_process_graphs"] = [
    {
        "graph_id": "BPG-1",
        "flow_ref": "TOBE-1",
        "nodes": [
            {"step_id": "S1", "label": "接收文本消息回调", "actor": "三方平台", "object_state": "message_received"},
            {"step_id": "S2", "label": "装配上下文并调度 agent", "actor": "系统", "object_state": "agent_processing"},
            {"step_id": "S3", "label": "生成建议回复并等待人工确认", "actor": "客服运营", "object_state": "human_confirmation_pending"},
        ],
        "edges": [
            {
                "from_step": "S1",
                "to_step": "S2",
                "condition": "消息包含会话标识和租户标识",
                "actor": "系统",
                "object_state_change": "message_received -> agent_processing",
                "risk_refs": ["RISK-1"],
            },
            {
                "from_step": "S2",
                "to_step": "S3",
                "condition": "agent 返回建议或失败原因",
                "actor": "客服运营",
                "object_state_change": "agent_processing -> human_confirmation_pending",
                "risk_refs": ["RISK-1"],
            },
        ],
    }
]
phase_prd["feature_inventory"] = [
    {
        "feature_id": "FEAT-1",
        "capability": "单渠道文本消息建议回复闭环",
        "business_goal_ref": "phase_goal",
        "actor_or_scenario": "客服运营处理三方文本消息",
        "entry_or_trigger": "三方消息回调",
        "core_behavior": "接收消息、装配上下文、调度 agent 并生成建议回复",
        "observable_result": "建议回复包进入人工确认状态，不自动外发",
        "scope_status": "IN_SCOPE",
        "unit_refs": ["UNIT-1"],
        "risk_refs": ["RISK-1"],
    }
]
phase_prd["module_capability_matrix"] = [
    {
        "module": "三方消息处理",
        "capability": "回调接收、上下文装配、建议回复和人工确认",
        "unit_refs": ["UNIT-1"],
        "protected_behaviors": ["不自动外发客户消息", "失败必须可人工接管"],
    }
]
phase_prd["entry_scene_inventory"] = [
    {
        "entry_id": "ENTRY-1",
        "entry_type": "api_callback",
        "scenario": "三方平台推送单渠道文本消息",
        "evidence_refs": ["EV-1"],
        "unit_refs": ["UNIT-1"],
    }
]
phase_prd["business_objects"] = [
    {
        "object_name": "客户消息",
        "definition": "三方平台推送并需要客服处理的文本消息",
        "key_fields": ["会话标识", "租户标识", "消息正文", "上下文来源"],
        "lifecycle_states": ["received", "processing", "human_confirmation_pending", "handoff_required"],
    }
]
phase_prd["state_transitions"] = [
    {
        "object_name": "客户消息",
        "from": "received",
        "trigger": "上下文装配和 agent 调度完成",
        "to": "human_confirmation_pending",
        "observable_result": "客服看到建议回复、上下文来源和人工确认状态",
        "rule_refs": ["BR-1"],
    }
]
phase_prd["role_permission_matrix"] = [
    {
        "role": "客服运营",
        "permissions": ["查看建议回复", "确认或接管客户消息"],
        "constraints": ["未人工确认前不得外发客户消息"],
        "unit_refs": ["UNIT-1"],
    }
]
phase_prd["risk_ledger"] = [
    {
        "risk_id": "RISK-1",
        "source": "Director baseline and AS-IS evidence",
        "risk_type": "handoff",
        "trigger_condition": "上下文缺失或 agent 调度失败",
        "affected_units": ["UNIT-1"],
        "impact": "建议回复无法安全交给客服确认",
        "pm_decision": "缺上下文或调度失败时进入人工接管，不自动外发",
        "mitigation_or_owner": "PM 写入 AC 和 Verification Plan",
        "verification_target": "UNIT-1.acceptance_criteria / UNIT-1.verification_plan",
        "status": "MITIGATED",
    }
]
phase_prd["coverage_matrix"] = [
    {
        "coverage_id": "COV-1",
        "scenario_ref": "TOBE-1",
        "business_type": "单渠道文本消息",
        "platform": "三方消息回调",
        "action_or_path": "消息回调 -> 建议回复 -> 人工确认",
        "support_status": "SUPPORTED",
        "unit_refs": ["UNIT-1"],
        "ac_refs": ["AC-U1-01"],
        "evidence_refs": ["EV-1"],
        "evidence_targets": ["接口请求 / 响应", "数据前后值", "测试执行记录"],
    }
]
phase_prd["technical_evidence_requirements"] = [
    {
        "requirement_id": "TECH-1",
        "domain": "api_contract",
        "business_invariant": "建议回复进入人工确认状态且不自动外发",
        "required_downstream_proof": "接口、状态数据和测试记录证明失败可接管且不会自动外发",
        "unit_refs": ["UNIT-1"],
        "risk_refs": ["RISK-1"],
        "status": "REQUIRED",
    }
]
phase_prd["release_readiness"] = {
    "supported_platforms": ["三方消息回调"],
    "conditional_platforms": [],
    "unsupported_platforms": [],
    "residual_risks": [],
}
phase_prd["pre_review_issue_ledger"] = []
phase_prd["business_flows"] = ["三方回调 -> 前置消息处理 -> 上下文装配 -> agent 调度 -> 建议响应 -> 人工确认"]
phase_prd["user_paths"] = ["客服在人工确认入口查看建议回复、上下文来源、失败原因和接管状态"]
phase_prd["rule_mappings"] = ["任何建议回复都不得自动外发；失败必须可接管；消息原文和上下文来源必须可追溯"]
phase_prd["design_decision_candidates"] = unit["design_decision_candidates"]

refs = ["brief.json", "phase-1/phase-prd.json", "phase-1/units/UNIT-1.json"]
reviewed_digest = bundle_digest(refs, [brief, phase_prd, unit])
review = review_conclusion(refs, reviewed_digest)
brief["review_conclusion"] = review
brief["issue_ledger"] = []
brief["delivery_confirmation"] = {"status": "confirmed", "confirmed_at": "2026-05-14T01:00:00Z"}
phase_prd["review_conclusion"] = review
phase_prd["issue_ledger"] = []

package = {
    "artifact_type": "stage-2-product-manager-prd-package",
    "status": "pass",
    "input_origin": "stage-2-product-director-confirmed-brief-package",
    "confirmed_brief_package": confirmed_package,
    "brief": brief,
    "phase_prd": phase_prd,
    "units": [unit],
    "product_manager_ledger": manager_ledger(),
    "decision_boundary": {
        "allowed_actions": [
            "business_flow_refinement",
            "user_path_refinement",
            "rule_mapping",
            "unit_decomposition",
            "acceptance_criteria_definition",
            "verification_plan_definition",
            "coverage_matrix_definition",
            "technical_evidence_requirement_definition",
            "release_readiness_definition",
            "design_handoff_preparation",
            "pm_owner_self_check",
            "agent_team_review",
            "delivery_confirmation",
        ],
        "blocked_actions": [
            "language_selection",
            "architecture_finalization",
            "code_changes",
            "commit",
            "deploy",
            "auto_send",
            "business_risk_acceptance",
        ],
    },
    "handoff_to": "design",
    "resume_condition": "design_stage2_ready",
}
Path(sys.argv[2]).write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$SCRIPT" --package "$PACKAGE" >"$TMP_ROOT/package-pass.json" \
  || fail "valid Stage 2 product-manager package should pass"
python3 - "$TMP_ROOT/package-pass.json" <<'PY' || fail "Stage 2 product-manager package output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "product_manager_prd_ready_for_design":
    raise SystemExit(payload)
if payload.get("next_standard_chain_role") != "design":
    raise SystemExit(payload)
expected = {
    "package_envelope",
    "confirmed_brief_binding",
    "director_lock_preservation",
    "pm_artifacts",
    "pm_review_closure",
    "product_manager_ledger",
    "authorization_boundary",
}
checks = {item.get("check") for item in payload.get("checks", [])}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
PY

BROKEN_UNIT="$TMP_ROOT/broken-unit.json"
python3 - "$PACKAGE" "$BROKEN_UNIT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["units"][0].pop("acceptance_criteria", None)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_UNIT" >"$TMP_ROOT/broken-unit-output.json"; then
  fail "product-manager package must reject UNIT without acceptance_criteria"
fi
rg -q "acceptance_criteria" "$TMP_ROOT/broken-unit-output.json" \
  || fail "UNIT acceptance_criteria failure should be explicit"

DRIFT="$TMP_ROOT/director-drift.json"
python3 - "$PACKAGE" "$DRIFT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["phase_prd"]["phase_goal"] = "PM illegally rewrote the Director phase goal"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$DRIFT" >"$TMP_ROOT/director-drift-output.json"; then
  fail "product-manager package must reject Director-owned phase drift"
fi
rg -q "Director|phase_goal" "$TMP_ROOT/director-drift-output.json" \
  || fail "Director drift failure should be explicit"

BAD_BOUNDARY="$TMP_ROOT/bad-boundary.json"
python3 - "$PACKAGE" "$BAD_BOUNDARY" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["decision_boundary"]["blocked_actions"] = [
    item for item in payload["decision_boundary"]["blocked_actions"] if item != "auto_send"
]
payload["decision_boundary"]["allowed_actions"].append("language_selection")
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BAD_BOUNDARY" >"$TMP_ROOT/bad-boundary-output.json"; then
  fail "product-manager package must reject authorization boundary drift"
fi
rg -q "auto_send|language_selection" "$TMP_ROOT/bad-boundary-output.json" \
  || fail "authorization boundary failure should be explicit"

BROKEN_LEDGER="$TMP_ROOT/broken-ledger.json"
python3 - "$PACKAGE" "$BROKEN_LEDGER" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["product_manager_ledger"]["confirmations"] = [
    item for item in payload["product_manager_ledger"]["confirmations"] if item["step"] != "Agent review"
]
payload["product_manager_ledger"]["latest_checkpoint_id"] = payload["product_manager_ledger"]["confirmations"][-1]["checkpoint_id"]
payload["product_manager_ledger"]["finalization_basis"]["accepted_checkpoint_ids"] = [
    item["checkpoint_id"] for item in payload["product_manager_ledger"]["confirmations"]
]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_LEDGER" >"$TMP_ROOT/broken-ledger-output.json"; then
  fail "product-manager package must reject ledger missing Agent review"
fi
rg -q "Agent review|ledger" "$TMP_ROOT/broken-ledger-output.json" \
  || fail "ledger failure should be explicit"

printf '[PASS] Stage 2 product-manager package gate\n'
