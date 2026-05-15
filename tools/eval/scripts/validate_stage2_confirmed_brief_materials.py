#!/usr/bin/env python3
"""Validate Stage 2 confirmed brief materials without entering qft-pai."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from render_stage2_product_director_handoff import ROOT, render
from validate_stage2_confirmed_brief_package import BLOCKED_ACTIONS, validate
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate


def digest(snapshot: dict[str, Any]) -> str:
    raw = json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def build_package(handoff: dict[str, Any]) -> dict[str, Any]:
    focus = handoff["director_focus"]
    context = focus["business_context"]
    metrics = focus["success_metrics"]
    metric_goals = [f"{metric['name']}：{metric['threshold']}" for metric in metrics]
    confirmed_at = "2026-05-14T00:00:00Z"
    brief_lock = {
        "root_problem": focus["root_problem_input"],
        "user_profile": [
            {
                "who": context["real_user"],
                "scenario": context["scenario"],
                "current_workaround": "沿用旧 qft-pai 主流程，由人工在上下文不足、agent 失败或链路不可观测时兜底处理",
                "workaround_cost": "消息回调、上下文拼装、agent 调度和响应处理耦合，失败难定位",
            }
        ],
        "business_goals": [focus["target_outcome"], *metric_goals],
        "appetite": {
            "investment_scale": "Phase 1 只冻结单渠道文本消息建议回复闭环",
            "complexity_ceiling": "只允许真实采证和边界冻结，不做语言选型、架构定版、代码修改或上线",
            "trim_first": "附件/语音/图片、多渠道接入、复杂工单和自动外发",
        },
        "scope_boundaries": [focus["phase1_candidate_boundary"], "建议回复必须进入人工确认，不允许自动外发"],
        "non_goals": ["不做语言选型", "不做代码修改", "不自动外发客户消息", "不替 human/business owner 接受业务风险"],
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
        "delivery_plan": [{"phase_id": "phase-1", "goal": focus["phase1_candidate_boundary"], "iteration_timebox_days": 14}],
    }
    phase_lock = {
        "phase_goal": focus["phase1_candidate_boundary"],
        "entry_conditions": [
            "Stage 2 intake facts 已通过 validator",
            "product-director handoff package 已生成",
            "blocked_actions 在 product-manager 之前继续生效",
        ],
        "exit_conditions": [*metric_goals, "不自动外发，失败可进入人工接管"],
    }
    base = {
        "schema_version": "1.0.0",
        "producer": "product",
        "produced_at": confirmed_at,
        "chain_version": "standard-chain/v1",
        "chain_registry_digest": "sha256:4c810553fe67ab70692a23ce9be83b2863d048936cc059a510df30fc56589dd0",
    }
    brief = {
        **base,
        "artifact_type": "brief",
        "artifact_id": "qft-pai-stage2-phase1.brief",
        "authority_scope": "artifact",
        "authoritative_fields": ["$.root_problem", "$.user_profile", "$.business_goals", "$.appetite", "$.scope_boundaries", "$.non_goals", "$.feasibility_constraints", "$.risks_and_unknowns", "$.decision_rationale", "$.delivery_plan", "$.director_confirmation"],
        **brief_lock,
        "director_confirmation": {"status": "passed", "confirmed_at": confirmed_at, "locked_field_digest": digest(brief_lock), "locked_fields": brief_lock},
    }
    phase_prd = {
        **base,
        "artifact_type": "phase-prd",
        "artifact_id": "qft-pai-stage2-phase1.phase-1.prd",
        "authority_scope": "phase",
        "authoritative_fields": ["$.phase_goal", "$.entry_conditions", "$.exit_conditions", "$.director_confirmation"],
        **phase_lock,
        "unit_index": [],
        "director_confirmation": {"status": "passed", "confirmed_at": confirmed_at, "locked_field_digest": digest(phase_lock), "locked_fields": phase_lock},
    }
    return {
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


def validate_materials(repo_root: Path) -> dict[str, Any]:
    example_payload = load_json(repo_root / DEFAULT_INTAKE.relative_to(ROOT))
    handoff, handoff_exit = render(make_real_candidate(example_payload), Path("real-stage2-intake-facts.json"))
    failures: list[str] = []
    if handoff_exit != 0:
        failures.append("real intake candidate did not render product-director handoff")
        package_result: dict[str, Any] = {"status": "fail", "failed_checks": failures}
    else:
        package = build_package(handoff)
        package_result = validate(package)
        if package_result["status"] != "pass":
            failures.append("valid confirmed brief package did not pass")
        broken = copy.deepcopy(package)
        broken["decision_boundary"]["blocked_actions"] = [
            action for action in broken["decision_boundary"]["blocked_actions"] if action != "code_changes"
        ]
        broken_result = validate(broken)
        if broken_result["status"] == "pass":
            failures.append("confirmed brief package did not enforce code_changes block")

    return {
        "status": "fail" if failures else "pass",
        "stage2_readiness": package_result.get("stage2_readiness"),
        "next_standard_chain_role": package_result.get("next_standard_chain_role"),
        "validated_blocked_actions": BLOCKED_ACTIONS,
        "failed_checks": failures,
        "package_checks": package_result.get("checks", []),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root.")
    args = parser.parse_args()

    payload = validate_materials(args.repo_root.resolve())
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
