# Stage 1 Artifact Structure Contract

日期：2026-05-14

## 结论

Stage 1 现在有一条可复验的结构契约线：单角色 dry-run 能力由 grader 验收，核心交付结构由 artifact contract validator 验收。

这不代表可以进入 Stage 2，也不代表可以开始 `qft-pai` 语言选型或重写。明确结论：仅凭本契约通过，仍然不能进入 Stage 2。它只证明：训练场里最容易漂移的 typed gap、Task Packet、设计接口契约、signoff gate 和术语表，已经有确定性检查兜底。

## 契约映射

| 结构 | 业务含义 | 确定性载体 | 当前校验 |
| --- | --- | --- | --- |
| typed gap | Test-design 发现缺口时必须给出类型、owner、阻断引用、下一步和是否 blocking，不能写成散文提醒。 | `shared/skills/test-design/contracts/test-cases.schema.json` | `validate_stage1_artifact_contracts.py` 校验 `design_gap_report.gaps[*]` 必填字段、gap type、owner 枚举和禁止未知字段。 |
| Task Packet | Delivery-owner 给 developer 的派发包必须有任务边界、依赖、证据目标、真实依赖说明和 mock 边界，不能靠口头解释。 | `shared/skills/tech-lead/contracts/tasks.schema.json` + `shared/skills/delivery-owner/scripts/task_packet_check.py` | 校验 task 必填字段、`task_packet_check.validate(packet)` 入口和 `DISPATCH_READY` 门禁。 |
| 设计接口契约 | Design 不能只写方案描述，必须把输入、输出、错误语义、质量属性、验证映射、回滚和影响面交给下游消费。 | `shared/skills/design/contracts/design.schema.json` | 校验 `interfaces[*]` 的输入/输出/错误码结构，以及验证、回滚、迁移、影响面等执行支撑字段。 |
| signoff gate | Delivery-owner 不能替人接受业务风险，技术 pass 与业务签核必须分开。 | `shared/skills/delivery-owner/contracts/signoff-package.schema.json` + `shared-core.schema.json` + `vocabulary-registry.yaml` | 校验 signoff 必填字段，以及 release/signoff/risk acceptance 术语枚举一致。 |
| 术语表 | standard-chain 的状态、决策、优先级、风险接受等枚举必须统一，避免每个角色各说一套。 | `contracts/canonical/vocabulary-registry.yaml` | 校验核心枚举 key 存在、非空、无重复。 |

## 总入口

Stage 1 当前总验收命令：

```bash
python3 tools/eval/scripts/run_stage1_eval_checks.py
```

该命令同时覆盖：

- `run_stage1_dry_run_graders.py`：角色 dry-run 可枚举能力检查。
- `grade_e2e_resume001_chain.py`：跨角色恢复链路检查。
- `validate_stage1_artifact_contracts.py`：核心 artifact 结构契约检查。
- `validate_stage2_intake_gate.py`：Stage 2 intake gate 材料检查。
- `validate_stage2_product_director_handoff_materials.py`：Stage 2 facts 到 product-director handoff 的材料检查，证明 example 被阻断、真实 candidate 只能路由到 product-director。
- `validate_stage2_confirmed_brief_materials.py`：product-director handoff 到 confirmed brief package 的材料检查，证明 canonical `brief/phase-prd` 对齐 handoff、保留 Director lock、阻断 PM-owned 字段和 code changes 禁区。
- `validate_stage2_product_manager_materials.py`：confirmed brief package 到 product-manager PRD package 的材料检查，证明 PM 能补齐业务流程、用户路径、规则映射、UNIT、AC、Verification Plan、PM ledger 和 review closure，并只能路由到 design。
- `validate_stage2_design_materials.py`：product-manager PRD package 到 design package 的材料检查，证明 Design 能补齐 canonical `design.json`、review digest、reference integrity、design ledger 和实现禁区，并只能路由到 test-design。
- `validate_stage2_test_design_materials.py`：design package 到 test-design package 的材料检查，证明 Test-design 能补齐 canonical `test-cases.json`、traceability、AC 覆盖、special triggers、QA handoff、review digest 和 typed gap 阻断，并只能路由到 tech-lead。
- `validate_stage2_tech_lead_package.py` / `validate_stage2_tech_lead_materials.py`：test-design package 到 tech-lead package 的门禁和材料检查，证明 Tech-lead 能补齐 canonical `plan.json`、`tasks.json`、artifact registry、planning preflight、standard-chain semantic integrity 和 delivery-owner intake，并只能路由到 delivery-owner。

## 边界

通过这条门禁，只能说明 Stage 1 训练场的结构质量进入可控状态。

仍然不能说明：

- product-director 到 delivery-owner 的完整跨角色链路已经恢复。
- human/老板/业务 owner 已经补齐真实业务事实和风险授权。
- `qft-pai` 已经完成真实采证、语言选型或重写方案。
- 真实上线、提交、灰度和回滚已经具备授权。

Stage 2 前仍必须由 human 输入真实业务样板、验收人、指标阈值、投入边界和风险接受边界。
