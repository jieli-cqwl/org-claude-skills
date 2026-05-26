"""PM package fixture builder for Stage 2 product-manager material checks."""

from __future__ import annotations

import copy
from typing import Any

from validate_stage2_product_manager_materials_common import (  # noqa: E402
    bundle_digest,
    review_conclusion,
)
from validate_stage2_product_manager_materials_unit import build_unit  # noqa: E402
from validate_stage2_product_manager_package import BLOCKED_ACTIONS  # noqa: E402


def build_pm_package(confirmed_package: dict[str, Any]) -> dict[str, Any]:
    brief = copy.deepcopy(confirmed_package["brief"])
    phase_prd = copy.deepcopy(confirmed_package["phase_prd"])
    unit = build_unit(brief)
    brief["acceptance_criteria"] = ["单渠道文本消息能形成建议回复，且必须人工确认后才允许外发"]
    brief["design_decisions"] = ["消息入口、人工确认状态和失败接管方式交由 design 收口"]
    brief["non_functional_requirements"] = ["链路必须可观测，失败不能吞消息，响应处理必须可追溯"]
    phase_prd["unit_index"] = ["UNIT-1"]
    phase_prd["unit_priority_order"] = [{"unit_id": "UNIT-1", "priority": "P0", "priority_basis": "先证明消息闭环可被人工确认"}]
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
            "business_type": "single_channel_text_message",
            "platform": "third_party_callback",
            "action_or_path": "receive callback -> assemble context -> dispatch agent -> generate suggested reply -> wait for human confirmation",
            "support_status": "SUPPORTED",
            "unit_refs": ["UNIT-1"],
            "ac_refs": ["AC-U1-01"],
            "evidence_refs": ["EV-1"],
            "evidence_targets": ["log", "test_record"],
            "decision_or_boundary_ref": "brief.json#design_decisions",
        }
    ]
    phase_prd["technical_evidence_requirements"] = [
        {
            "requirement_id": "TER-1",
            "domain": "api_contract",
            "business_invariant": "三方消息回调必须保留租户、会话、消息正文、上下文来源、trace 和人工确认状态；未确认前不得自动外发。",
            "required_downstream_proof": "design/test-design 需证明成功、上下文缺失、agent 调度失败三类路径都有可追踪记录和人工接管状态。",
            "unit_refs": ["UNIT-1"],
            "risk_refs": ["RISK-1"],
            "status": "REQUIRED",
        }
    ]
    phase_prd["release_readiness"] = {
        "supported_platforms": ["third_party_callback"],
        "conditional_platforms": [],
        "unsupported_platforms": ["multi_channel_unified_entry", "auto_send"],
        "residual_risks": [
            {
                "risk_id": "RISK-1",
                "description": "上下文缺失或 agent 调度失败时，建议回复不能进入自动外发路径。",
                "owner": "design",
                "target_resolution": "test-design handoff before implementation planning",
                "status": "CLOSED",
            }
        ],
    }
    phase_prd["pre_review_issue_ledger"] = []
    phase_prd["business_flows"] = ["三方回调 -> 前置消息处理 -> 上下文装配 -> agent 调度 -> 建议响应 -> 人工确认"]
    phase_prd["user_paths"] = ["客服在人工确认入口查看建议回复、上下文来源、失败原因和接管状态"]
    phase_prd["rule_mappings"] = ["任何建议回复都不得自动外发；失败必须可接管；消息原文和上下文来源必须可追溯"]
    phase_prd["design_decision_candidates"] = unit["design_decision_candidates"]
    review = review_conclusion(bundle_digest([brief, phase_prd, unit]))
    brief["review_conclusion"] = review
    brief["issue_ledger"] = []
    brief["delivery_confirmation"] = {"status": "confirmed", "confirmed_at": "2026-05-14T01:00:00Z"}
    phase_prd["review_conclusion"] = review
    phase_prd["issue_ledger"] = []
    return {
        "artifact_type": "stage-2-product-manager-prd-package",
        "status": "pass",
        "input_origin": "stage-2-product-director-confirmed-brief-package",
        "confirmed_brief_package": confirmed_package,
        "brief": brief,
        "phase_prd": phase_prd,
        "units": [unit],
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
            "blocked_actions": BLOCKED_ACTIONS,
        },
        "handoff_to": "design",
        "resume_condition": "design_stage2_ready",
    }
