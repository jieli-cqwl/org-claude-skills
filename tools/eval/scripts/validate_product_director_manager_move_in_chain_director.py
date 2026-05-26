"""Director handoff and confirmed brief builders for the move-in eval."""

from __future__ import annotations

from typing import Any

from validate_product_director_manager_move_in_chain_common import with_director_lock  # noqa: E402


def build_director_handoff(rubric: dict[str, Any]) -> dict[str, Any]:
    return {
        "status": "pass",
        "artifact_type": "stage-2-product-director-handoff",
        "handoff_owner_role": "product-director",
        "input_origin": "move-in-source-demand",
        "intake_owner": "product-review-dogfood",
        "source_refs": [rubric["source_demand_ref"], rubric["source_prd"]],
        "stage2_readiness": "intake_complete_for_discovery",
        "next_required_action": "start_product_director_confirmed_brief",
        "handoff_input": "move-in source demand and accepted PRD rubric",
        "discovery_boundary": {
            "allowed_actions": [
                "real_qft_pai_discovery",
                "confirmed_brief_drafting",
                "phase1_boundary_freeze",
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
            "qft_pai_repo_path": "/Users/lijieli/project/qft-tenants",
        },
        "director_focus": {
            "business_context": {
                "sample_name": "move-in-next-tenant",
                "business_owner": "租务运营负责人",
                "real_user": "租务运营",
                "scenario": "已租房间登记下一任租客，并在前任释放后办理入住",
            },
            "root_problem_input": "已租房间需要提前登记下一任租客，但不能污染当前在租生命周期、账款、统计、设备、水电、门锁和小程序权益。",
            "target_outcome": "下一任租客提前完成签署、材料、授权和收款准备；办理入住后才激活为当前租客。",
            "phase1_candidate_boundary": "支持登记将搬入、管理将搬入、办理入住、作废和查看跳转，同时保护当前在租不变。",
            "success_metrics": [
                {
                    "name": "当前在租零污染",
                    "threshold": "保存将搬入后当前房态、租客、账务、统计和权益前后值不变",
                },
                {
                    "name": "办理入住唯一激活",
                    "threshold": "前任释放且最早有效将搬入合同满足材料后才激活",
                },
                {
                    "name": "端范围不虚报",
                    "threshold": "H5 / HarmonyOS 未独立验收不得声明支持",
                },
            ],
            "acceptance_owner": {
                "name": "租务运营负责人",
                "role": "business owner",
                "decision_authority": "确认发布范围和风险接受",
                "acceptance_method": "PRD rubric review",
            },
            "risk_acceptance_boundary": "残余风险必须有 owner、处理时点和证据目标，不能由 PM 替业务接受。",
        },
        "required_product_director_steps": [
            "D-S1",
            "D-S2",
            "D-S3",
            "D-S4",
            "D-S5",
            "D-S5.5",
            "D-S6",
            "D-G1",
        ],
        "product_director_must_not_do": [
            "code_changes",
            "architecture_finalization",
            "auto_send",
        ],
        "resume_condition": "product_director_confirmed_brief_and_phase1_boundary",
    }


def build_confirmed_package(rubric: dict[str, Any]) -> dict[str, Any]:
    confirmed_at = "2026-05-24T12:00:00Z"
    handoff = build_director_handoff(rubric)
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
        "artifact_id": "move-in-next-tenant.brief",
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
        "root_problem": handoff["director_focus"]["root_problem_input"],
        "user_profile": [
            {
                "who": "租务运营",
                "scenario": "已租房间登记下一任租客，并在前任释放后办理入住",
                "current_workaround": "等前任退房后再新建租客或线下记录未来租约",
                "workaround_cost": "签署、收款、授权和入住准备无法提前闭环，且容易误改当前在租",
            }
        ],
        "business_goals": [
            handoff["director_focus"]["target_outcome"],
            "当前在租零污染",
            "办理入住唯一激活",
            "端范围不虚报",
            "已租房登记下一任租客时当前在租不变",
            "办理入住后才激活为当前租客",
            "作废释放未来租期并保留财务事实",
            "未入住不获得正式租客身份",
        ],
        "appetite": {
            "investment_scale": "single focused phase",
            "complexity_ceiling": "复用现有登记租客、合同、账款、权限和审计能力",
            "trim_first": "不扩展新的游客账号体系，不自动退款冲红，不声明未独立验收端支持",
        },
        "scope_boundaries": [
            "已租房登记下一任租客",
            "将搬入管理",
            "办理入住",
            "作废",
            "查看跳转",
            "当前在租不变",
            "小程序未入住身份边界",
        ],
        "non_goals": [
            "不替代当前在租生命周期",
            "不自动退款或冲红",
            "不新增游客账号体系",
            "不把 H5 / HarmonyOS 当作已发布端",
            "不做语言选型",
            "不做代码修改",
            "不自动外发",
            "不替业务 owner 接受风险",
        ],
        "feasibility_constraints": [
            {
                "type": "business",
                "constraint": "当前在租、未来租约和正式租客身份必须隔离",
                "impact_scope": "phase-1",
                "handling": "PM 只能细化 WHAT 和证据目标，技术方案后续证明实现边界",
            }
        ],
        "risks_and_unknowns": [
            {
                "item": "H5 / HarmonyOS 端需要独立验收",
                "impact": "未验收时不能声明支持",
                "mitigation": "release_readiness 标为 CONDITIONAL",
                "status": "RESOLVED",
            }
        ],
        "decision_rationale": [
            {
                "decision": "先交付将搬入闭环",
                "choice": "登记、管理、办理入住、作废和身份边界在同一 Phase",
                "rationale": "这些能力共同保护当前在租零污染和未来租约可激活",
                "excluded_options": "只放开已租房校验或直接复用当前入住保存",
            }
        ],
        "delivery_plan": [
            {
                "phase_id": "phase-1",
                "goal": handoff["director_focus"]["phase1_candidate_boundary"],
                "iteration_timebox_days": 14,
            }
        ],
    }
    with_director_lock(
        brief,
        [
            "root_problem",
            "user_profile",
            "business_goals",
            "appetite",
            "scope_boundaries",
            "non_goals",
            "feasibility_constraints",
            "risks_and_unknowns",
            "decision_rationale",
            "delivery_plan",
        ],
        confirmed_at,
    )
    phase = {
        **base,
        "artifact_type": "phase-prd",
        "artifact_id": "move-in-next-tenant.phase-1.prd",
        "authority_scope": "phase",
        "authoritative_fields": [
            "$.phase_goal",
            "$.entry_conditions",
            "$.exit_conditions",
            "$.director_confirmation",
        ],
        "phase_goal": handoff["director_focus"]["phase1_candidate_boundary"],
        "entry_conditions": [
            "当前房间已租但可创建下一任租客",
            "用户有对应权限",
            "未来租期不与当前在租或有效将搬入冲突",
        ],
        "exit_conditions": [
            "当前在租零污染",
            "办理入住唯一激活",
            "端范围不虚报",
            "PC 和 App 可登记并管理将搬入",
            "保存将搬入不改变当前在租",
            "办理入住后才激活",
            "作废释放未来租期",
            "未入住不获得正式租客身份",
        ],
        "unit_index": [],
    }
    with_director_lock(
        phase, ["phase_goal", "entry_conditions", "exit_conditions"], confirmed_at
    )
    return {
        "artifact_type": "stage-2-product-director-confirmed-brief-package",
        "status": "pass",
        "input_origin": "stage-2-product-director-handoff",
        "handoff": handoff,
        "brief": brief,
        "phase_prd": phase,
        "decision_boundary": handoff["discovery_boundary"],
        "handoff_to": "product-manager",
        "resume_condition": "product_manager_stage2_prd_ready",
    }
