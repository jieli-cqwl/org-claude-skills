#!/usr/bin/env python3
"""Validate Stage 2 design materials without entering qft-pai."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from render_stage2_product_director_handoff import render
from validate_stage2_confirmed_brief_materials import (
    build_package as build_confirmed_package,
)
from validate_stage2_design_package import (
    DESIGN_ALLOWED_ACTIONS,
    DESIGN_BLOCKED_ACTIONS,
    ROOT,
    validate,
)
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate
from validate_stage2_product_manager_materials import build_pm_package


def digest(value: Any) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def reviewed_design_digest(payload: dict[str, Any]) -> str:
    reviewed_design = copy.deepcopy(payload)
    reviewed_design.pop("review_closure", None)
    reviewed_design.pop("final_confirmation", None)
    return digest(reviewed_design)


def design_stage_confirmations() -> list[dict[str, Any]]:
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
            "confirmation_focus": focus,
            "user_confirmation_summary": f"{focus} 已基于 PM package 确认",
            "design_refs": ["design.json#key_decisions[0].decision_id"],
        }
        for stage_id, focus in rows
    ]


def build_design_artifact(pm_package: dict[str, Any]) -> dict[str, Any]:
    brief = pm_package["brief"]
    phase_prd = pm_package["phase_prd"]
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
                "summary": "采用单入口消息编排模块承接回调、上下文装配、agent 调度和建议回复生成。",
                "decision_state": "已冻结",
                "verdict": "selected",
                "option_ref": "OPT-001",
                "fact_refs": ["design.json#runtime_facts[0]"],
                "user_confirmation": "PM 已确认 P0 先证明单渠道文本消息闭环，设计只冻结边界和验证义务。",
            }
        ],
        "option_analysis": [
            {
                "option_id": "OPT-001",
                "decision_ref": "D-001",
                "summary": "单入口状态机：统一接收回调并在一个编排模块内暴露状态、trace 和人工确认。",
                "tradeoff": "收益是链路可观测且易验收；成本是初期只覆盖单渠道文本消息；失败条件是无法保留 trace。",
                "verdict": "selected",
                "fact_refs": ["design.json#runtime_facts[0]"],
            },
            {
                "option_id": "OPT-002",
                "decision_ref": "D-001",
                "summary": "按消息来源分入口再汇聚：每个渠道先做独立处理后再进入统一调度。",
                "tradeoff": "收益是未来多渠道扩展更直接；成本是 Stage 2 范围过大且会削弱单闭环验收焦点。",
                "verdict": "rejected",
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
                "contract_summary": "输入三方文本消息回调和租户/会话标识，输出建议回复包、trace_id、上下文摘要和人工确认状态。",
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
                        "scenario": "上下文不足、重复回调或 agent 调度失败时不得自动外发。",
                        "expected_behavior": "返回同一 trace 状态或进入人工接管，并保留建议回复包不可外发状态。",
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
                "key_scenarios": [
                    "客服需要定位任意建议回复来自哪条消息、哪些上下文和哪次 agent 调度"
                ],
                "target_metrics": ["每次处理必须生成 trace_id 并保留上下文来源摘要"],
                "tradeoff_points": ["暂不追求多渠道吞吐，优先保证单闭环可观测"],
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
            "summary": "单闭环围绕 message_id、tenant_id、conversation_id 和 trace_id 建立状态记录；建议回复只作为待确认数据。",
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
                "decision": "按租户隔离消息处理和人工确认视图。",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
            {
                "concern": "error",
                "decision": "上下文不足或调度失败必须进入人工接管。",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
            {
                "concern": "log",
                "decision": "每次处理输出 trace_id、上下文来源和调度结果摘要。",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
            {
                "concern": "config",
                "decision": "自动外发开关在本阶段固定关闭。",
                "owner": "MOD-001",
                "verification_refs": ["VP-001"],
            },
        ],
        "verification_mapping": [
            {
                "manager_vp_ref": "phase-prd.exit_conditions[0]",
                "design_validation": "输入单条文本回调后必须形成建议回复包和人工确认状态。",
                "test_obligation": "test-design 必须覆盖成功、上下文缺失和 agent 调度失败三类路径。",
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
                "impact": "新增消息建议回复编排边界，保护不自动外发和失败接管。",
                "verification_refs": ["VP-001"],
            }
        ],
        "planning_constraints": [
            {
                "constraint_id": "PLAN-CON-001",
                "constraint_type": "sequencing",
                "description": "test-design 先验收设计义务，再由 tech-lead 拆实现任务。",
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
            "warn_followups": [],
        },
        "risks": [
            {
                "risk_id": "R-001",
                "description": "上下文不足时建议回复可能误导客服。",
                "severity": "medium",
                "source_ref": "phase-prd.json#exit_conditions",
            }
        ],
        "risk_response": [
            {
                "risk_id": "R-001",
                "architecture_response": "上下文不足时不生成自动外发结果，只生成接管原因和补充上下文提示。",
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
        "design_stage_confirmations": design_stage_confirmations(),
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
            "confirmation_summary": "PM 冻结的 WHAT 和非目标全部继承，design 只冻结 HOW 边界。",
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
        "summary": "设计包已冻结，可交给 test-design 生成测试义务和用例。",
        "accepted_refs": [
            "design.json#key_decisions[0].decision_id",
            "design.json#interfaces[0].interface_id",
            "design.json#verification_mapping[0].evidence_ref",
        ],
    }
    return design


def build_design_package(pm_package: dict[str, Any]) -> dict[str, Any]:
    return {
        "artifact_type": "stage-2-design-package",
        "status": "pass",
        "input_origin": "stage-2-product-manager-prd-package",
        "product_manager_package": pm_package,
        "design": build_design_artifact(pm_package),
        "decision_boundary": {
            "allowed_actions": DESIGN_ALLOWED_ACTIONS,
            "blocked_actions": DESIGN_BLOCKED_ACTIONS,
        },
        "handoff_to": "test-design",
        "resume_condition": "test_design_stage2_ready",
    }


def validate_materials(repo_root: Path) -> dict[str, Any]:
    example_payload = load_json(repo_root / DEFAULT_INTAKE.relative_to(ROOT))
    handoff, handoff_exit = render(
        make_real_candidate(example_payload), Path("real-stage2-intake-facts.json")
    )
    failures: list[str] = []
    if handoff_exit != 0:
        return {
            "status": "fail",
            "failed_checks": [
                "real intake candidate did not render product-director handoff"
            ],
        }

    pm_package = build_pm_package(build_confirmed_package(handoff))
    package = build_design_package(pm_package)
    package_result = validate(package)
    if package_result["status"] != "pass":
        failures.append("valid design package did not pass")

    broken = copy.deepcopy(package)
    broken["decision_boundary"]["blocked_actions"] = [
        action
        for action in broken["decision_boundary"]["blocked_actions"]
        if action != "code_changes"
    ]
    broken["decision_boundary"]["allowed_actions"].append("code_changes")
    if validate(broken)["status"] == "pass":
        failures.append("design package did not enforce implementation boundary")

    broken_coverage = copy.deepcopy(package)
    broken_coverage["design"]["unit_coverage"] = []
    if validate(broken_coverage)["status"] == "pass":
        failures.append("design package did not enforce UNIT coverage")

    return {
        "status": "fail" if failures else "pass",
        "stage2_readiness": package_result.get("stage2_readiness"),
        "next_standard_chain_role": package_result.get("next_standard_chain_role"),
        "validated_blocked_actions": DESIGN_BLOCKED_ACTIONS,
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
