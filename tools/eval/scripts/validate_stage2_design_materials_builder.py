"""Design package fixture builder for Stage 2 material checks."""

from __future__ import annotations

import copy
import hashlib
import json
from typing import Any


def digest(value: Any) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def reviewed_design_digest(payload: dict[str, Any]) -> str:
    reviewed_design = copy.deepcopy(payload)
    reviewed_design.pop("review_closure", None)
    reviewed_design.pop("final_confirmation", None)
    return digest(reviewed_design)


def co_creation_summary() -> list[dict[str, Any]]:
    rows = [
        ("stakeholders-and-concerns", "确认设计消费者和关注点"),
        (
            "architecture-significant-requirements",
            "确认 PM 冻结范围、不自动外发和失败可接管约束",
        ),
        ("current-state-evidence", "确认现有 qft-pai 主流程证据边界"),
        ("complexity-model", "确认先设计单渠道文本消息闭环"),
        ("decision-discovery", "确认消息建议回复包的输入输出和错误模式"),
        ("option-tradeoff", "确认单入口状态机优先于分入口汇聚"),
        ("design-synthesis", "确认可观测性、幂等、失败接管和 test-design 交接义务"),
    ]
    return [
        {
            "stage_id": stage_id,
            "confirmation_status": "CONFIRMED",
            "decision_refs": ["design.json#key_decisions[0].decision_id"],
            "evidence_refs": ["design.json#key_decisions[0].decision_id"],
        }
        for stage_id, focus in rows
    ]


def build_design_artifact(pm_package: dict[str, Any]) -> dict[str, Any]:
    brief = pm_package["brief"]
    unit = pm_package["units"][0]
    design: dict[str, Any] = {
        "artifact_type": "design",
        "artifact_id": "qft-pai-stage2-phase1.design",
        "schema_version": "1.0.0",
        "producer": "design",
        "produced_at": "2026-05-14T02:00:00Z",
        "chain_version": "standard-chain/v1",
        "chain_registry_digest": brief["chain_registry_digest"],
        "authority_scope": "phase",
        "authoritative_fields": [
            "$.input_analysis",
            "$.co_creation_summary",
            "$.key_decisions",
            "$.interfaces",
            "$.quality_attributes",
            "$.modules",
            "$.verification_mapping",
            "$.unit_coverage",
            "$.risk_response",
            "$.final_confirmation",
        ],
        "input_analysis": "承接 PM package：只设计三方文本消息回调到建议回复的单渠道闭环，不进入语言选型、代码实现或自动外发。",
        "key_decisions": [
            {
                "decision_id": "D-001",
                "decision_state": "已冻结",
                "option_ref": "OPT-001",
                "fact_refs": ["design.json#runtime_facts[0]"],
            }
        ],
        "option_analysis": [
            {
                "option_id": "OPT-001",
                "decision_ref": "D-001",
                "decision_status": "SELECTED",
                "evaluation": {"fit": "HIGH", "cost": "MEDIUM", "risk": "MEDIUM"},
                "fact_refs": ["design.json#runtime_facts[0]"],
            },
            {
                "option_id": "OPT-002",
                "decision_ref": "D-001",
                "decision_status": "REJECTED",
                "evaluation": {"fit": "MEDIUM", "cost": "HIGH", "risk": "HIGH"},
                "fact_refs": ["design.json#runtime_facts[0]"],
            },
        ],
        "runtime_facts": [
            "Stage 2 design fixture 基于真实 qft-pai intake facts 和 PM package 生成；evidence=stage-2-product-manager-prd-package；observed_at=2026-05-14T02:00:00Z"
        ],
        "interfaces": [
            {
                "interface_id": "IF-001",
                "owner": "MOD-001",
                "error_modes": [
                    "validation_error",
                    "context_missing",
                    "agent_dispatch_failed",
                ],
                "input_params": [
                    {
                        "name": "message_payload",
                        "type": "object",
                        "required": True,
                        "validation": "必须包含三方消息 id、文本内容、租户标识和会话标识",
                        "description": "承接 PM 定义的单渠道文本消息回调。",
                    }
                ],
                "output_params": [
                    {
                        "name": "suggested_reply_package",
                        "type": "object",
                        "description": "包含建议回复、上下文来源、trace_id 和人工确认状态。",
                    }
                ],
                "error_codes": [
                    {
                        "code": "CONTEXT_REQUIRED",
                        "condition": "缺少可用于生成建议回复的上下文",
                        "user_message": "需要人工接管并补充上下文",
                    }
                ],
                "boundary_behaviors": [
                    {
                        "behavior_type": "degraded_mode",
                        "trigger_ref": "design.json#interfaces[0].error_codes[0].code",
                        "expected_outcome": "BLOCK",
                        "verification_ref": "VP-001",
                    }
                ],
            }
        ],
        "interface_boundary": [
            "third_party_callback -> IF-001 -> MOD-001: 不自动外发，所有输出先进入人工确认。"
        ],
        "quality_attributes": [
            {
                "attribute": "operability",
                "priority": "P0",
                "scenario_refs": [
                    "客服需要定位任意建议回复来自哪条消息、哪些上下文和哪次 agent 调度"
                ],
                "target_metrics": [
                    {
                        "metric_id": "M-1",
                        "metric_name": "traceability",
                        "threshold": "trace_id and context source recorded",
                        "unit": "contract",
                    }
                ],
                "verification_refs": ["VP-001"],
            }
        ],
        "modules": [
            {
                "module_id": "MOD-001",
                "name": "MessageSuggestionOrchestrator",
                "responsibility": "串联前置消息处理、上下文装配、agent 调度和建议回复包生成。",
                "data_owner": "消息处理 trace、建议回复状态和人工确认状态",
                "unit_refs": [unit["unit_id"]],
            }
        ],
        "data_architecture": {
            "storage_decisions": [
                "保留原始回调摘要、上下文来源摘要、agent 调度结果和人工确认状态"
            ],
            "data_flows": [
                "third_party_callback -> MOD-001 -> manual_confirmation_queue"
            ],
            "consistency_strategy": "以 message_id 和 tenant_id 做幂等键，重复回调返回同一 trace 状态。",
        },
        "cross_cutting_concerns": [
            {
                "concern": "auth",
                "decision_ref": "design.json#key_decisions[0].decision_id",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
            {
                "concern": "error",
                "decision_ref": "design.json#key_decisions[0].decision_id",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
            {
                "concern": "log",
                "decision_ref": "design.json#key_decisions[0].decision_id",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
            {
                "concern": "config",
                "decision_ref": "design.json#key_decisions[0].decision_id",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
        ],
        "verification_mapping": [
            {
                "manager_vp_ref": "phase-prd.exit_conditions[0]",
                "evidence_ref": "VP-001",
            }
        ],
        "unit_coverage": [
            {
                "unit_id": unit["unit_id"],
                "ac_refs": ["AC-U1-01"],
                "design_refs": ["MOD-001", "IF-001"],
            }
        ],
        "impact_scope": [
            {
                "scope_item_id": "SCOPE-001",
                "affected_modules": ["MOD-001"],
                "impact_type": "CHANGE",
                "required_action": "VERIFY",
                "verification_refs": ["VP-001"],
            }
        ],
        "planning_constraints": [
            {
                "constraint_id": "PLAN-CON-001",
                "constraint_type": "sequencing",
                "constraint_rule": "ORDERING",
                "enforcement_type": "SEQUENCING",
                "owner": "tech-lead",
            }
        ],
        "product_handoff": {
            "status": "READY",
            "accepted_refs": [
                "brief.json#delivery_confirmation",
                "phase-prd.json#review_conclusion",
            ],
            "open_failures": [],
        },
        "risks": [
            {
                "risk_id": "R-001",
                "risk_type": "TECHNICAL",
                "severity": "MEDIUM",
                "source_ref": "phase-prd.json#exit_conditions",
            }
        ],
        "risk_response": [
            {
                "risk_id": "R-001",
                "response_type": "MITIGATE",
                "verification_refs": ["VP-001"],
            }
        ],
        "migration_plan": [
            "Stage 2 只定义设计包，不修改 qft-pai 代码；实现迁移由 tech-lead 后续拆解。"
        ],
        "verification_plan": [
            "test-design 使用 VP-001 派生成功、上下文缺失和调度失败用例。"
        ],
        "rollback_plan": [
            "实现阶段若 trace 或人工确认缺失，停止进入部署并回到 design 修正接口边界。"
        ],
        "co_creation_summary": co_creation_summary(),
        "constraint_inheritance_confirmation": {
            "status": "confirmed",
            "confirmed_at": "2026-05-14T02:10:00Z",
            "source_refs": [
                "brief.json#delivery_confirmation",
                "phase-prd.json#review_conclusion",
            ],
            "inherited_constraints": [
                "不自动外发",
                "失败可人工接管",
                "单渠道文本消息优先",
            ],
            "rejected_constraints": [
                "本阶段不承诺多渠道统一接入",
                "本阶段不进入代码实现",
            ],
        },
    }
    reviewed_digest = reviewed_design_digest(design)
    design["review_closure"] = {
        "reviewed_design_digest": reviewed_digest,
        "reviewed_at": "2026-05-14T02:20:00Z",
        "reviewers": [
            {
                "reviewer": "architecture",
                "verdict": "PASS",
                "reviewed_design_digest": reviewed_digest,
                "finding_refs": [],
            },
            {
                "reviewer": "product",
                "verdict": "PASS",
                "reviewed_design_digest": reviewed_digest,
                "finding_refs": [],
            },
            {
                "reviewer": "test",
                "verdict": "PASS",
                "reviewed_design_digest": reviewed_digest,
                "finding_refs": [],
            },
        ],
        "resolved_failures": [],
        "warn_followups": [],
    }
    design["final_confirmation"] = {
        "status": "confirmed",
        "confirmed_by": "design",
        "confirmed_at": "2026-05-14T02:25:00Z",
        "accepted_refs": [
            "design.json#key_decisions[0].decision_id",
            "design.json#interfaces[0].interface_id",
            "design.json#verification_mapping[0].evidence_ref",
        ],
    }
    return design
