#!/usr/bin/env python3
"""Validate Director->PM chain output against the move-in PRD golden rubric."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
FIXTURE_DIR = ROOT / "tests/fixtures/product-director-manager-move-in-chain"
DEFAULT_RUBRIC = FIXTURE_DIR / "golden-rubric.json"
POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger", "delivery_confirmation"}

sys.path.insert(0, str(ROOT / "tools/eval/scripts"))
sys.path.insert(0, str(ROOT / "tools/community"))

from validate_co_creation_ledger import validate as validate_ledger  # noqa: E402
from validate_stage2_confirmed_brief_package import validate as validate_director_package  # noqa: E402
from validate_stage2_product_manager_package import validate as validate_pm_package  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def digest(value: Any) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def strip_post_review(payload: dict[str, Any]) -> dict[str, Any]:
    clone = copy.deepcopy(payload)
    for field in POST_REVIEW_FIELDS:
        clone.pop(field, None)
    return clone


def bundle_digest(refs: list[str], artifacts: list[dict[str, Any]]) -> str:
    return digest(
        [
            {"ref": ref, "payload": strip_post_review(artifact)}
            for ref, artifact in zip(refs, artifacts)
        ]
    )


def with_director_lock(payload: dict[str, Any], fields: list[str], confirmed_at: str) -> dict[str, Any]:
    locked = {field: payload[field] for field in fields}
    payload["director_confirmation"] = {
        "status": "passed",
        "confirmed_at": confirmed_at,
        "locked_field_digest": digest(locked),
        "locked_fields": locked,
    }
    return payload


def review_conclusion(refs: list[str], reviewed_digest: str) -> dict[str, Any]:
    perspectives = [
        ("product", ["phase-1/phase-prd.json#coverage_matrix", "phase-1/units/UNIT-1.json#acceptance_criteria"]),
        ("architecture", ["phase-1/phase-prd.json#technical_evidence_requirements"]),
        ("test", ["phase-1/units/UNIT-1.json#verification_plan", "phase-1/units/UNIT-2.json#verification_plan"]),
    ]
    return {
        "verdict": "PASS",
        "summary": "Move-in PM artifacts cover the accepted PRD rubric and are ready for design",
        "agent_team_review": {
            "mode": "agent_teams",
            "round": "R2",
            "reviewed_artifact_refs": refs,
            "reviewed_bundle_digest": reviewed_digest,
            "reviewer_verdicts": [
                {
                    "perspective": perspective,
                    "round": "R2",
                    "verdict": "PASS",
                    "reviewer_output_ref": f"agent-team://move-in-{perspective}-reviewer/R2",
                    "artifact_refs": refs,
                    "reviewed_bundle_digest": reviewed_digest,
                    "finding_refs": [],
                    "evidence_refs": evidence_refs,
                    "read_only": True,
                }
                for perspective, evidence_refs in perspectives
            ],
            "convergence_evidence": [
                {"round": "R2", "status": "CONFIRMATION", "evidence_refs": ["golden-rubric.json#core_thesis"]}
            ],
        },
    }


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
            "allowed_actions": ["real_qft_pai_discovery", "confirmed_brief_drafting", "phase1_boundary_freeze"],
            "blocked_actions": ["language_selection", "architecture_finalization", "code_changes", "commit", "deploy", "auto_send", "business_risk_acceptance"],
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
                {"name": "当前在租零污染", "threshold": "保存将搬入后当前房态、租客、账务、统计和权益前后值不变"},
                {"name": "办理入住唯一激活", "threshold": "前任释放且最早有效将搬入合同满足材料后才激活"},
                {"name": "端范围不虚报", "threshold": "H5 / HarmonyOS 未独立验收不得声明支持"},
            ],
            "acceptance_owner": {"name": "租务运营负责人", "role": "business owner", "decision_authority": "确认发布范围和风险接受", "acceptance_method": "PRD rubric review"},
            "risk_acceptance_boundary": "残余风险必须有 owner、处理时点和证据目标，不能由 PM 替业务接受。",
        },
        "required_product_director_steps": ["D-S1", "D-S2", "D-S3", "D-S4", "D-S5", "D-S5.5", "D-S6", "D-G1"],
        "product_director_must_not_do": ["code_changes", "architecture_finalization", "auto_send"],
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
        "authoritative_fields": ["$.root_problem", "$.user_profile", "$.business_goals", "$.appetite", "$.scope_boundaries", "$.non_goals", "$.feasibility_constraints", "$.risks_and_unknowns", "$.decision_rationale", "$.delivery_plan", "$.director_confirmation"],
        "root_problem": handoff["director_focus"]["root_problem_input"],
        "user_profile": [{"who": "租务运营", "scenario": "已租房间登记下一任租客，并在前任释放后办理入住", "current_workaround": "等前任退房后再新建租客或线下记录未来租约", "workaround_cost": "签署、收款、授权和入住准备无法提前闭环，且容易误改当前在租"}],
        "business_goals": [handoff["director_focus"]["target_outcome"], "当前在租零污染", "办理入住唯一激活", "端范围不虚报", "已租房登记下一任租客时当前在租不变", "办理入住后才激活为当前租客", "作废释放未来租期并保留财务事实", "未入住不获得正式租客身份"],
        "appetite": {"investment_scale": "single focused phase", "complexity_ceiling": "复用现有登记租客、合同、账款、权限和审计能力", "trim_first": "不扩展新的游客账号体系，不自动退款冲红，不声明未独立验收端支持"},
        "scope_boundaries": ["已租房登记下一任租客", "将搬入管理", "办理入住", "作废", "查看跳转", "当前在租不变", "小程序未入住身份边界"],
        "non_goals": ["不替代当前在租生命周期", "不自动退款或冲红", "不新增游客账号体系", "不把 H5 / HarmonyOS 当作已发布端", "不做语言选型", "不做代码修改", "不自动外发", "不替业务 owner 接受风险"],
        "feasibility_constraints": [{"type": "business", "constraint": "当前在租、未来租约和正式租客身份必须隔离", "impact_scope": "phase-1", "handling": "PM 只能细化 WHAT 和证据目标，技术方案后续证明实现边界"}],
        "risks_and_unknowns": [{"item": "H5 / HarmonyOS 端需要独立验收", "impact": "未验收时不能声明支持", "mitigation": "release_readiness 标为 CONDITIONAL", "status": "RESOLVED"}],
        "decision_rationale": [{"decision": "先交付将搬入闭环", "choice": "登记、管理、办理入住、作废和身份边界在同一 Phase", "rationale": "这些能力共同保护当前在租零污染和未来租约可激活", "excluded_options": "只放开已租房校验或直接复用当前入住保存"}],
        "delivery_plan": [{"phase_id": "phase-1", "goal": handoff["director_focus"]["phase1_candidate_boundary"], "iteration_timebox_days": 14}],
    }
    with_director_lock(brief, ["root_problem", "user_profile", "business_goals", "appetite", "scope_boundaries", "non_goals", "feasibility_constraints", "risks_and_unknowns", "decision_rationale", "delivery_plan"], confirmed_at)
    phase = {
        **base,
        "artifact_type": "phase-prd",
        "artifact_id": "move-in-next-tenant.phase-1.prd",
        "authority_scope": "phase",
        "authoritative_fields": ["$.phase_goal", "$.entry_conditions", "$.exit_conditions", "$.director_confirmation"],
        "phase_goal": handoff["director_focus"]["phase1_candidate_boundary"],
        "entry_conditions": ["当前房间已租但可创建下一任租客", "用户有对应权限", "未来租期不与当前在租或有效将搬入冲突"],
        "exit_conditions": ["当前在租零污染", "办理入住唯一激活", "端范围不虚报", "PC 和 App 可登记并管理将搬入", "保存将搬入不改变当前在租", "办理入住后才激活", "作废释放未来租期", "未入住不获得正式租客身份"],
        "unit_index": [],
    }
    with_director_lock(phase, ["phase_goal", "entry_conditions", "exit_conditions"], confirmed_at)
    return {"artifact_type": "stage-2-product-director-confirmed-brief-package", "status": "pass", "input_origin": "stage-2-product-director-handoff", "handoff": handoff, "brief": brief, "phase_prd": phase, "decision_boundary": handoff["discovery_boundary"], "handoff_to": "product-manager", "resume_condition": "product_manager_stage2_prd_ready"}


def build_units(chain_digest: str) -> list[dict[str, Any]]:
    common = {"schema_version": "1.0.0", "producer": "product", "produced_at": "2026-05-24T12:30:00Z", "chain_version": "standard-chain/v1", "chain_registry_digest": chain_digest, "authority_scope": "artifact"}
    auth = ["$.unit_id", "$.closure_definition", "$.trigger", "$.core_behavior", "$.observable_result", "$.feature_refs", "$.flow_refs", "$.risk_refs", "$.rule_refs", "$.integration_context", "$.acceptance_criteria", "$.verification_plan", "$.design_decision_candidates", "$.exclusions", "$.priority", "$.priority_basis", "$.dependencies"]
    return [
        {**common, "artifact_type": "unit-definition", "artifact_id": "move-in.phase-1.unit-1", "authoritative_fields": auth, "unit_id": "UNIT-1", "closure_definition": "登记下一任租客并进入将搬入管理，当前在租保持不变", "trigger": "运营从已租房行操作或租客合同入口点击登记租客", "core_behavior": "创建未来租约、合同和未来收款对象，不改当前在租状态", "observable_result": "将搬入记录可筛选查看，当前房态、当前租客、账款、统计和权益前后值不变", "feature_refs": ["FEAT-REGISTER", "FEAT-LIST"], "flow_refs": ["TOBE-REGISTER", "BPG-MOVE-IN"], "risk_refs": ["RISK-CURRENT-TENANT"], "rule_refs": ["BR-CURRENT-ZERO"], "acceptance_criteria": [{"ac_id": "AC1", "description": "PC 和 App 已租房可登记下一任租客", "example_input": "已租房间行操作点击登记租客并保存未来租期", "expected_result": "生成将搬入记录并进入将搬入管理", "boundary_case": "房间冻结或无权限时阻断", "failure_mode": "提交失败保留已填信息并提示具体原因"}, {"ac_id": "AC2", "description": "保存将搬入后当前在租不变", "example_input": "保存下一任租客合同", "expected_result": "当前房态、当前租客、账务、统计、设备、水电、门锁和小程序权益前后值完全不变", "boundary_case": "当前租客仍在租时仍允许保存将搬入", "failure_mode": "任何当前在租字段变化均为失败"}, {"ac_id": "AC3", "description": "未来租期互斥", "example_input": "提交与当前在租或有效将搬入重叠的租期", "expected_result": "前端提示且服务端拒绝，不占用未来租期", "boundary_case": "多个未来合同只保留互斥顺序", "failure_mode": "重复或重叠租期写入为失败"}, {"ac_id": "AC4", "description": "将搬入列表可筛选识别", "example_input": "合同管理筛选将搬入", "expected_result": "列表展示将搬入记录、状态和允许动作", "boundary_case": "无查看权限隐藏或提示无权限", "failure_mode": "出现当前在租动作或状态混淆为失败"}, {"ac_id": "AC5", "description": "查看与跳转不误作用当前租客", "example_input": "点击物业地址和合同预览", "expected_result": "能定位房间和合同；房间详情当前租客动作不作用到未来租客", "boundary_case": "无权限时禁用或提示", "failure_mode": "续约、退房、换房误作用未来租客为失败"}], "exclusions": ["自动退款", "正式租客身份生成"], "priority": "P0", "priority_basis": "当前在租零污染是全部后续能力的安全前提", "dependencies": [], "integration_context": {"business_modules": ["房间列表", "合同管理", "将搬入管理"], "protected_behaviors": ["当前在租生命周期不得提前变化"], "cross_unit_dependencies": [], "business_constraints": ["服务端必须按状态拒绝绕过前端调用"]}, "verification_plan": [{"verification_type": "functional", "business_operation": "保存将搬入并比对当前在租前后值", "expected_observation": "将搬入写入成功且当前在租全量字段不变", "evidence_target": "AC1-AC5", "evidence_types": ["screenshot", "api_request_response", "data_before_after", "audit_log", "test_record"], "covers_refs": ["AC1", "AC2", "AC3", "AC4", "AC5", "RISK-CURRENT-TENANT"]}], "design_decision_candidates": []},
        {**common, "artifact_type": "unit-definition", "artifact_id": "move-in.phase-1.unit-2", "authoritative_fields": auth, "unit_id": "UNIT-2", "closure_definition": "办理入住和作废关闭未来租约终态", "trigger": "运营在将搬入列表点击办理入住或作废", "core_behavior": "办理入住唯一激活当前租客；作废释放未来租期并保留账款事实", "observable_result": "入住、作废、账款和审计状态可追踪", "feature_refs": ["FEAT-CHECKIN", "FEAT-VOID", "FEAT-FINANCE"], "flow_refs": ["TOBE-CHECKIN", "TOBE-VOID", "BPG-MOVE-IN"], "risk_refs": ["RISK-ORDER", "RISK-FINANCE"], "rule_refs": ["BR-EARLIEST", "BR-FINANCE"], "acceptance_criteria": [{"ac_id": "AC6", "description": "前任释放且材料满足时办理入住成功", "example_input": "最早有效将搬入合同点击办理入住", "expected_result": "将搬入激活为当前在租租客", "boundary_case": "前任未退房、房间未释放、材料缺失时阻断", "failure_mode": "半成功或下游失败不可追踪为失败"}, {"ac_id": "AC7", "description": "未入住将搬入可作废", "example_input": "未入住将搬入记录填写原因后作废", "expected_result": "释放未来租期并退出活跃经营口径，保留审计", "boundary_case": "支付中、挂账、来源未闭合时阻断", "failure_mode": "删除流水或自动退款冲红为失败"}, {"ac_id": "AC8", "description": "账款分层处理", "example_input": "未收、部分收、已收、支付中、挂账和来源未闭合分别作废", "expected_result": "按规则保留、坏账留痕或阻断", "boundary_case": "支付中和来源未闭合必须先处理来源业务", "failure_mode": "已收流水被自动抹除为失败"}], "exclusions": ["自动退款", "自动冲红"], "priority": "P0", "priority_basis": "入住和作废决定未来租约终态，必须服务端兜底", "dependencies": ["UNIT-1"], "integration_context": {"business_modules": ["将搬入管理", "账款", "审计"], "protected_behaviors": ["多个未来租约顺序和财务事实不得丢失"], "cross_unit_dependencies": ["UNIT-1"], "business_constraints": ["并发办理入住只能产生一个有效终态"]}, "verification_plan": [{"verification_type": "business_state", "business_operation": "执行办理入住、作废和账款矩阵", "expected_observation": "服务端状态、账款和审计符合 AC6-AC8", "evidence_target": "AC6-AC8", "evidence_types": ["api_request_response", "data_before_after", "audit_log", "test_record"], "covers_refs": ["AC6", "AC7", "AC8", "RISK-ORDER", "RISK-FINANCE"]}], "design_decision_candidates": [{"decision_name": "办理入住失败后的用户可见补偿状态", "options": ["列表状态提示", "详情页补偿任务"], "constraints": "核心成功但下游失败必须可追踪、可补偿或可重试", "impacted_units": ["UNIT-2"], "design_handoff": "design 决定用户可见状态表达"}]},
        {**common, "artifact_type": "unit-definition", "artifact_id": "move-in.phase-1.unit-3", "authoritative_fields": auth, "unit_id": "UNIT-3", "closure_definition": "多端和小程序身份边界按发布口径验收", "trigger": "移动端、小程序或 H5/HarmonyOS 访问相关入口", "core_behavior": "PC/App 主流程发布，小程序未入住身份拒绝正式权益，H5/HarmonyOS 独立验证后才声明支持", "observable_result": "端支持声明和身份权益边界可被证据证明", "feature_refs": ["FEAT-IDENTITY", "FEAT-PLATFORM"], "flow_refs": ["TOBE-IDENTITY"], "risk_refs": ["RISK-IDENTITY", "RISK-PLATFORM", "RISK-ASYNC"], "rule_refs": ["BR-IDENTITY", "BR-PLATFORM"], "acceptance_criteria": [{"ac_id": "AC9", "description": "小程序未入住身份边界", "example_input": "未入住手机号登录小程序并访问合同、账单、门锁、水电和设备", "expected_result": "不生成正式租客 token，不开放当前入住权益", "boundary_case": "办理入住后按正式租客规则放行", "failure_mode": "未入住获得正式权益为失败"}, {"ac_id": "AC10", "description": "多端范围声明", "example_input": "PC、App、H5、HarmonyOS 分别验证入口和流程", "expected_result": "PC/App 主流程通过；H5/HarmonyOS 未独立验收不得声明支持", "boundary_case": "HarmonyOS 独立失败时仅保留条件支持", "failure_mode": "用 App 结果代验 H5/HarmonyOS 为失败"}], "exclusions": ["新增游客账号体系"], "priority": "P1", "priority_basis": "身份与端范围决定发布声明可信度", "dependencies": ["UNIT-1", "UNIT-2"], "integration_context": {"business_modules": ["小程序身份", "多端入口", "异步任务"], "protected_behaviors": ["未入住不获得正式租客身份", "端范围不得虚报"], "cross_unit_dependencies": ["UNIT-1", "UNIT-2"], "business_constraints": ["ES、MQ、Canal、定时任务和设备权益消费者必须按状态过滤"]}, "verification_plan": [{"verification_type": "release_scope", "business_operation": "验证小程序身份和各端入口状态", "expected_observation": "身份、权益和发布声明符合 AC9-AC10", "evidence_target": "AC9-AC10", "evidence_types": ["screen_recording", "api_request_response", "data_before_after", "audit_log", "test_record"], "covers_refs": ["AC9", "AC10", "RISK-IDENTITY", "RISK-PLATFORM", "RISK-ASYNC"]}], "design_decision_candidates": []},
    ]


def build_pm_package(confirmed: dict[str, Any]) -> dict[str, Any]:
    brief = copy.deepcopy(confirmed["brief"])
    phase = copy.deepcopy(confirmed["phase_prd"])
    units = build_units(brief["chain_registry_digest"])
    brief["acceptance_criteria"] = ["AC1-AC10 覆盖已租房登记、当前在租不变、办理入住、作废、账款、小程序身份和多端范围"]
    brief["design_decisions"] = ["下游设计只选择可见状态和失败补偿表达，不改变 PM 锁定业务边界"]
    brief["non_functional_requirements"] = ["高风险操作必须有服务端拒绝、traceId、审计和数据前后值证据"]
    phase.update(build_phase_manager_fields())
    phase["unit_index"] = [unit["unit_id"] for unit in units]
    phase["unit_priority_order"] = [{"unit_id": "UNIT-1", "priority": "P0", "priority_basis": "先保护当前在租零污染"}, {"unit_id": "UNIT-2", "priority": "P0", "priority_basis": "再关闭入住和作废终态"}, {"unit_id": "UNIT-3", "priority": "P1", "priority_basis": "最后锁身份与端发布口径"}]
    refs = ["brief.json", "phase-1/phase-prd.json", *[f"phase-1/units/{unit['unit_id']}.json" for unit in units]]
    reviewed_digest = bundle_digest(refs, [brief, phase, *units])
    review = review_conclusion(refs, reviewed_digest)
    brief["review_conclusion"] = review
    brief["issue_ledger"] = []
    brief["delivery_confirmation"] = {"status": "confirmed", "confirmed_at": "2026-05-24T13:00:00Z"}
    phase["review_conclusion"] = review
    phase["issue_ledger"] = []
    return {"artifact_type": "stage-2-product-manager-prd-package", "status": "pass", "input_origin": "stage-2-product-director-confirmed-brief-package", "confirmed_brief_package": confirmed, "brief": brief, "phase_prd": phase, "units": units, "product_manager_ledger": manager_ledger(), "decision_boundary": {"allowed_actions": ["business_flow_refinement", "user_path_refinement", "rule_mapping", "unit_decomposition", "acceptance_criteria_definition", "verification_plan_definition", "coverage_matrix_definition", "technical_evidence_requirement_definition", "release_readiness_definition", "design_handoff_preparation", "pm_owner_self_check", "agent_team_review", "delivery_confirmation"], "blocked_actions": ["language_selection", "architecture_finalization", "code_changes", "commit", "deploy", "auto_send", "business_risk_acceptance"]}, "handoff_to": "design", "resume_condition": "design_stage2_ready"}


def build_phase_manager_fields() -> dict[str, Any]:
    evidence_types = ["screenshot", "screen_recording", "api_request_response", "data_before_after", "audit_log", "test_record"]
    evidence = [{"evidence_id": f"EV-{index}", "source_type": source_type, "source_ref": f"move-in-evidence#{source_type}", "status": "FACT", "supports": ["AC1", "AC2", "coverage_matrix"]} for index, source_type in enumerate(evidence_types, start=1)]
    evidence[0].update({"screenshot_ref": "assets/move-in-entry.png", "captured_at": "2026-05-24T12:20:00Z", "entry_ref": "room-list.row-action"})
    coverage_rows = [("COV-1", "整租", "PC", "登记租客"), ("COV-2", "合租", "App", "办理入住"), ("COV-3", "集中", "PC", "合同动作"), ("COV-4", "通用", "PC", "将搬入管理"), ("COV-5", "通用", "H5", "查看跳转"), ("COV-6", "通用", "HarmonyOS", "作废"), ("COV-7", "身份", "小程序", "小程序身份边界")]
    tech_domains = ["api_contract", "data_model_state_machine", "business_type_difference", "transaction_boundary", "idempotency_concurrency", "permission_audit", "tenant_identity", "async_offline_task", "release_rollback"]
    return {
        "evidence_sources": evidence,
        "as_is_flows": [{"flow_id": "ASIS-1", "evidence_refs": ["EV-1"], "actors": ["租务运营"], "trigger": "当前租客未退房但需要登记下一任", "steps": ["线下记录", "等待退房", "再登记"], "observed_state": "未来租约缺少系统承载", "pain_points": ["入住准备无法提前闭环", "容易误改当前在租"]}],
        "to_be_flows": [{"flow_id": "TOBE-REGISTER", "goal_ref": "phase_goal", "actors": ["租务运营"], "trigger": "登记下一任租客", "steps": ["创建将搬入", "合同动作", "将搬入管理"], "expected_outcome": "当前在租不变且未来租约可管理", "branch_coverage": ["成功", "无权限", "租期冲突"]}, {"flow_id": "TOBE-CHECKIN", "goal_ref": "phase_goal", "actors": ["租务运营"], "trigger": "办理入住", "steps": ["重读校验", "唯一激活", "同步权益"], "expected_outcome": "将搬入成为当前租客", "branch_coverage": ["前任未退房", "非最早合同", "并发重复"]}, {"flow_id": "TOBE-IDENTITY", "goal_ref": "phase_goal", "actors": ["下一任租客"], "trigger": "小程序登录", "steps": ["身份过滤", "权益拦截", "入住后放行"], "expected_outcome": "未入住不获得正式权益", "branch_coverage": ["未入住", "已入住"]}],
        "business_process_graphs": [{"graph_id": "BPG-MOVE-IN", "flow_ref": "TOBE-REGISTER", "nodes": [{"step_id": "S1", "label": "登记将搬入", "actor": "租务运营", "object_state": "future_contract_created"}, {"step_id": "S2", "label": "办理入住", "actor": "租务运营", "object_state": "current_tenant_activated"}, {"step_id": "S3", "label": "作废将搬入", "actor": "租务运营", "object_state": "future_contract_voided"}], "edges": [{"from_step": "S1", "to_step": "S2", "condition": "前任释放且材料满足且为最早有效合同", "object_state_change": "future_contract_created -> current_tenant_activated", "risk_refs": ["RISK-ORDER"]}, {"from_step": "S1", "to_step": "S3", "condition": "未入住且账款状态允许作废", "object_state_change": "future_contract_created -> future_contract_voided", "risk_refs": ["RISK-FINANCE"]}]}],
        "feature_inventory": [{"feature_id": f"FEAT-{name}", "capability": name, "business_goal_ref": "phase_goal", "actor_or_scenario": "租务运营", "entry_or_trigger": name, "core_behavior": name, "observable_result": "有证据可验", "scope_status": "IN_SCOPE", "unit_refs": ["UNIT-1"], "risk_refs": ["RISK-CURRENT-TENANT"]} for name in ["REGISTER", "LIST", "CHECKIN", "VOID", "IDENTITY", "PLATFORM"]],
        "module_capability_matrix": [{"module": "租务", "capability": "将搬入管理", "unit_refs": ["UNIT-1", "UNIT-2", "UNIT-3"], "protected_behaviors": ["当前在租不变", "未入住无正式权益"]}],
        "entry_scene_inventory": [{"entry_id": f"ENTRY-{i}", "entry_type": platform, "scenario": action, "evidence_refs": ["EV-1"], "unit_refs": ["UNIT-1"]} for i, (_, _, platform, action) in enumerate(coverage_rows, start=1)],
        "business_objects": [{"object_name": "当前在租", "definition": "已办理入住租客生命周期", "key_fields": ["房态", "租客", "权益"], "lifecycle_states": ["active"]}, {"object_name": "将搬入", "definition": "下一任租客未来租约承载", "key_fields": ["租期", "合同", "状态"], "lifecycle_states": ["pending", "checked_in", "voided"]}],
        "state_transitions": [{"object_name": "将搬入", "from": "pending", "trigger": "办理入住", "to": "checked_in", "observable_result": "激活为当前在租", "rule_refs": ["BR-EARLIEST"]}, {"object_name": "将搬入", "from": "pending", "trigger": "作废", "to": "voided", "observable_result": "释放未来租期", "rule_refs": ["BR-FINANCE"]}],
        "role_permission_matrix": [{"role": "租务运营", "permissions": ["登记租客", "办理入住", "作废", "查看"], "constraints": ["服务端按状态和权限拒绝绕过调用"], "unit_refs": ["UNIT-1", "UNIT-2"]}],
        "risk_ledger": [{"risk_id": f"RISK-{i}", "source": "accepted PRD rubric", "risk_type": "business", "trigger_condition": term, "affected_units": ["UNIT-1", "UNIT-2", "UNIT-3"], "impact": term, "pm_decision": f"用 AC 和证据保护 {term}", "mitigation_or_owner": "PM AC / Verification Plan / downstream evidence", "verification_target": "coverage_matrix / verification_plan", "status": "MITIGATED"} for i, term in enumerate(["当前在租污染", "状态混淆", "未来租约顺序", "财务流水误删", "正式租客身份提前开放", "端范围虚报", "异步任务误消费未来租约"], start=1)],
        "coverage_matrix": [{"coverage_id": cid, "scenario_ref": "TOBE-REGISTER", "business_type": bt, "platform": platform, "action_or_path": action, "support_status": "CONDITIONAL" if platform in {"H5", "HarmonyOS"} else "SUPPORTED", "unit_refs": ["UNIT-1", "UNIT-2", "UNIT-3"], "ac_refs": ["AC1", "AC2", "AC6", "AC9", "AC10"], "evidence_refs": ["EV-1", "EV-3", "EV-4", "EV-5", "EV-6"], "evidence_targets": evidence_types, "decision_or_boundary_ref": "release_readiness"} for cid, bt, platform, action in coverage_rows],
        "technical_evidence_requirements": [{"requirement_id": f"TER-{i}", "domain": domain, "business_invariant": f"{domain} 必须证明当前在租不变、将搬入状态独立、服务端拒绝非法状态", "required_downstream_proof": "design/test-design/tech-lead 必须给出可复验接口、状态、事务、审计或回滚证据", "unit_refs": ["UNIT-1", "UNIT-2", "UNIT-3"], "risk_refs": ["RISK-CURRENT-TENANT"], "status": "REQUIRED"} for i, domain in enumerate(tech_domains, start=1)],
        "release_readiness": {"supported_platforms": ["PC", "App", "小程序身份边界"], "conditional_platforms": ["H5", "HarmonyOS"], "unsupported_platforms": [], "residual_risks": [{"risk_id": "RISK-H5-HMOS", "description": "H5 / HarmonyOS 需独立验收后才声明支持", "owner": "test-design", "target_resolution": "发布准入前", "status": "TRANSFERRED"}]},
        "business_flows": ["登记租客 -> 将搬入管理 -> 合同动作 -> 办理入住 / 作废 -> 发布验收"],
        "user_paths": ["运营从已租房行登记下一任，当前租客动作仍只作用当前在租"],
        "rule_mappings": ["AC1-AC10 映射入口、状态、权限、账款、身份、多端和证据要求"],
        "design_decision_candidates": [{"decision_name": "将搬入状态和当前在租状态的界面区分", "options": ["列表标签", "详情分区"], "constraints": "不得混淆当前租客动作和将搬入动作", "impacted_units": ["UNIT-1"], "design_handoff": "design 决定视觉表达"}],
    }


def manager_ledger() -> dict[str, Any]:
    steps = ["Handoff gate", "Evidence and AS-IS", "TO-BE product model", "Feature inventory and risk", "Pre-UNIT gate", "UNIT split", "AC", "Verification Plan", "Design handoff", "Self-check", "Review digest", "Agent review", "PM handoff gate", "Delivery"]
    confirmations = [{"checkpoint_id": "move-in-pm-" + str(i), "step": step, "subject_ref": f"product-manager.{step}", "confirmed_at": f"2026-05-24T12:{i:02d}:00Z", "decision_summary": f"{step} closed for move-in chain eval", "source_refs": ["golden-rubric.json"], "output_refs": ["phase-1/phase-prd.json", "phase-1/units/UNIT-1.json"]} for i, step in enumerate(steps, start=1)]
    return {"artifact_type": "co-creation-ledger", "schema_version": "1.0.0", "producer": "product-manager", "scope_ref": "move-in/phase-1", "current_state": {"summary": "PM move-in artifacts ready for design", "source_refs": ["golden-rubric.json"], "next_step": "handoff to design"}, "latest_checkpoint_id": confirmations[-1]["checkpoint_id"], "confirmations": confirmations, "open_questions": [], "supersedes": [], "handoff_refs": ["brief.json", "phase-1/phase-prd.json", "phase-1/units/UNIT-1.json", "phase-1/units/UNIT-2.json", "phase-1/units/UNIT-3.json"], "finalization_basis": {"status": "confirmed", "confirmed_at": "2026-05-24T13:00:00Z", "summary": "Move-in PM package accepted for design", "accepted_checkpoint_ids": [item["checkpoint_id"] for item in confirmations]}}


def build_package(rubric: dict[str, Any]) -> dict[str, Any]:
    confirmed = build_confirmed_package(rubric)
    return {"artifact_type": "product-director-manager-move-in-chain-package", "status": "pass", "source_demand": {"source_ref": rubric["source_demand_ref"], "not_copied_from_golden_prd": True}, "golden_prd_ref": rubric["source_prd"], "rubric": rubric, "confirmed_brief_package": confirmed, "product_manager_package": build_pm_package(confirmed)}


def add_failure(failures: list[str], field: str, reason: str) -> None:
    failures.append(f"{field}: {reason}")


def make_check(name: str, failures: list[str]) -> dict[str, Any]:
    return {"check": name, "status": "fail" if failures else "pass", "failures": failures}


def text_blob(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def check_package_envelope(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    if package.get("artifact_type") != "product-director-manager-move-in-chain-package":
        add_failure(failures, "artifact_type", "must be product-director-manager-move-in-chain-package")
    if package.get("source_demand", {}).get("not_copied_from_golden_prd") is not True:
        add_failure(failures, "source_demand.not_copied_from_golden_prd", "must be true")
    return make_check("package_envelope", failures)


def check_director_boundary(package: dict[str, Any], rubric: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    confirmed = package.get("confirmed_brief_package") or {}
    result = validate_director_package(confirmed)
    if result.get("status") != "pass":
        add_failure(failures, "confirmed_brief_package", str(result.get("failed_checks")))
    director_text = text_blob(confirmed.get("brief")) + text_blob(confirmed.get("phase_prd"))
    for term in rubric.get("director_must_include_terms", []):
        if term not in director_text:
            add_failure(failures, "director_boundary", f"missing term: {term}")
    return make_check("director_boundary", failures)


def check_product_manager_package(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    pm_package = package.get("product_manager_package")
    if not isinstance(pm_package, dict):
        return make_check("product_manager_package", ["product_manager_package: must be object"])
    result = validate_pm_package(pm_package)
    if result.get("status") != "pass":
        add_failure(failures, "product_manager_package", str(result.get("failed_checks")))
    try:
        validate_ledger(pm_package.get("product_manager_ledger", {}), "product-manager", require_finalized=True)
    except ValueError as exc:
        add_failure(failures, "product_manager_ledger", str(exc))
    return make_check("product_manager_package", failures)


def check_golden_prd_rubric(package: dict[str, Any], rubric: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    phase = package.get("product_manager_package", {}).get("phase_prd", {})
    units = package.get("product_manager_package", {}).get("units", [])
    coverage = phase.get("coverage_matrix", [])
    tech = phase.get("technical_evidence_requirements", [])
    evidence = phase.get("evidence_sources", [])
    business_types = {item.get("business_type") for item in coverage if isinstance(item, dict)}
    platforms = {item.get("platform") for item in coverage if isinstance(item, dict)}
    actions = {item.get("action_or_path") for item in coverage if isinstance(item, dict)}
    domains = {item.get("domain") for item in tech if isinstance(item, dict)}
    source_types = {item.get("source_type") for item in evidence if isinstance(item, dict)}
    ac_ids = {criterion.get("ac_id") for unit in units for criterion in unit.get("acceptance_criteria", []) if isinstance(criterion, dict)}
    for term in rubric["required_business_types"]:
        if term not in business_types:
            add_failure(failures, "coverage_matrix.business_type", f"missing {term}")
    for term in rubric["required_platforms"]:
        if term not in platforms:
            add_failure(failures, "coverage_matrix.platform", f"missing {term}")
    for term in rubric["required_actions"]:
        if term not in actions:
            add_failure(failures, "coverage_matrix.action_or_path", f"missing {term}")
    for term in rubric["required_technical_domains"]:
        if term not in domains:
            add_failure(failures, "technical_evidence_requirements.domain", f"missing {term}")
    for term in rubric["required_evidence_source_types"]:
        if term not in source_types:
            add_failure(failures, "evidence_sources.source_type", f"missing {term}")
    for term in rubric["required_ac_refs"]:
        if term not in ac_ids:
            add_failure(failures, "acceptance_criteria", f"missing {term}")
    risk_text = text_blob(phase.get("risk_ledger"))
    for term in rubric["required_risk_terms"]:
        if term not in risk_text:
            add_failure(failures, "risk_ledger", f"missing {term}")
    release = phase.get("release_readiness", {})
    for platform in rubric["conditional_platforms"]:
        if platform not in release.get("conditional_platforms", []):
            add_failure(failures, "release_readiness.conditional_platforms", f"missing {platform}")
    return make_check("golden_prd_rubric", failures)


def check_downstream_consumability(package: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    pm_package = package.get("product_manager_package", {})
    phase = pm_package.get("phase_prd", {})
    if not phase.get("design_decision_candidates"):
        add_failure(failures, "phase_prd.design_decision_candidates", "must be non-empty")
    for unit in pm_package.get("units", []):
        for item in unit.get("verification_plan", []):
            if not item.get("evidence_types") or not item.get("covers_refs"):
                add_failure(failures, f"{unit.get('unit_id')}.verification_plan", "must carry evidence_types and covers_refs")
    for item in phase.get("coverage_matrix", []):
        if not item.get("evidence_targets"):
            add_failure(failures, "coverage_matrix.evidence_targets", f"missing for {item.get('coverage_id')}")
    return make_check("downstream_consumability", failures)


def validate_package(package: dict[str, Any], rubric: dict[str, Any]) -> dict[str, Any]:
    checks = [
        check_package_envelope(package),
        check_director_boundary(package, rubric),
        check_product_manager_package(package),
        check_golden_prd_rubric(package, rubric),
        check_downstream_consumability(package),
    ]
    failed = [failure for check in checks for failure in check["failures"]]
    return {"status": "pass" if not failed else "fail", "stage2_readiness": "director_manager_chain_meets_move_in_prd_rubric" if not failed else "blocked", "failed_checks": failed, "checks": checks, "rubric_summary": {"coverage": "complete" if not failed else "incomplete"}}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--rubric", type=Path, default=DEFAULT_RUBRIC)
    parser.add_argument("--emit-package", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rubric = load_json(args.rubric)
    if args.emit_package:
        print(json.dumps(build_package(rubric), ensure_ascii=False, indent=2, sort_keys=True))
        return 0
    if args.package is None:
        raise SystemExit("--package is required unless --emit-package is used")
    result = validate_package(load_json(args.package), rubric)
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if result["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
