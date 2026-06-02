"""UNIT fixture builder for Stage 2 product-manager material checks."""

from __future__ import annotations

from typing import Any


def build_unit(brief: dict[str, Any]) -> dict[str, Any]:
    return {
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
                "source_refs": ["brief.json#acceptance_criteria[0]"],
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
                "covers_refs": ["AC-U1-01", "RISK-1", "BR-1"],
                "evidence_types": ["log", "test_record"],
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
