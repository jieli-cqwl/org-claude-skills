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
    steps = ["M-S1", "M-S2", "M-S3", "M-S4", "M-S5", "M-S5.5", "M-S6", "M-S7", "M-S8", "M-G1", "M-S9"]
    confirmations = []
    for index, step in enumerate(steps, start=1):
        checkpoint_id = f"PM-CHK-{index:02d}"
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
    item for item in payload["product_manager_ledger"]["confirmations"] if item["step"] != "M-S8"
]
payload["product_manager_ledger"]["latest_checkpoint_id"] = payload["product_manager_ledger"]["confirmations"][-1]["checkpoint_id"]
payload["product_manager_ledger"]["finalization_basis"]["accepted_checkpoint_ids"] = [
    item["checkpoint_id"] for item in payload["product_manager_ledger"]["confirmations"]
]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_LEDGER" >"$TMP_ROOT/broken-ledger-output.json"; then
  fail "product-manager package must reject ledger missing M-S8"
fi
rg -q "M-S8|ledger" "$TMP_ROOT/broken-ledger-output.json" \
  || fail "ledger failure should be explicit"

printf '[PASS] Stage 2 product-manager package gate\n'
