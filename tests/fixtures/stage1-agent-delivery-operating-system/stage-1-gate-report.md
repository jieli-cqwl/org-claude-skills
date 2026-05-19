# Stage 1 Gate Report

日期：2026-05-14

## 结论

Stage 1 不能进入 Stage 2。

已经满足的是：18 个单角色 dry-run 全部形成原始输出、evaluator 输出和 decision；未发现 P0/P1；每个关键角色至少 2 个 case 为 `judgment=pass`；六个 `*-001` 守门 case 均通过；`TD-002` / `TL-002` / `DO-002` 和全组 `*-003` 已有可枚举 grader；typed gap、Task Packet、设计接口契约、signoff gate 和术语表已有 Stage 1 聚合结构校验；`E2E-RESUME-001` 已证明 synthetic resume package 可以把链路从 product-director 恢复到 delivery-owner 并合法停在授权边界；Stage 2 intake gate 已有模板、样例、validator、product-director handoff renderer、confirmed brief package gate、product-manager package gate、design package gate、test-design package gate 和 tech-lead package gate。

未满足的是：真实 `qft-pai` 的业务事实、代码事实、集成路径、灰度、回滚和授权均未验证；Stage 2 真实样板仍缺 human/业务 owner 裁决。

## Gate 状态

| gate | status | evidence | blocker |
| --- | --- | --- | --- |
| 六个关键角色有守门能力 | pass | `PD-001 / PM-001 / DES-001 / TD-001 / TL-001 / DO-001` | 无 |
| 每个角色至少 2 个 `judgment=pass` | pass | 18 个单角色 case 中 15 个 pass、3 个 warn/P2 | 无 |
| P0 全部关闭 | pass | 所有 evaluator 输出均无 P0 | 无 |
| P1 有 owner 和处理路径 | pass | 当前无 P1 | 无 |
| 可枚举检查外置 | pass | `TD-002 / TL-002 / DO-002 / PD-003 / PM-003 / DES-003 / TD-003 / TL-003 / DO-003` grader 已存在，并由 `run_stage1_dry_run_graders.py` 统一执行 | 无 |
| 核心 artifact 结构契约 | pass | `validate_stage1_artifact_contracts.py` 校验 typed gap、Task Packet、设计接口契约、signoff gate、术语表、schema 锚点和结构说明文档；`run_stage1_eval_checks.py` 作为 Stage 1 总入口 | 无 |
| 至少 1 条跨角色链路合法跑通或恢复 | pass | `E2E-RESUME-001` 使用 synthetic resume package 从 `product-director` 连续交接到 `delivery-owner`，并在真实执行/授权边界 `pass_to_pause` | 无 |
| Stage 2 intake gate 材料 | pass | `stage-2-intake-facts.template.json`、`stage-2-intake-facts.example.json`、`stage-2-intake-gate.md`、`validate_stage2_intake_gate.py`、product-director handoff materials、confirmed brief package materials、product-manager package materials、design package materials、test-design package materials 和 tech-lead package materials 已接入 `run_stage1_eval_checks.py`；总入口只校验材料，example 输出应为 `materials_verified_not_authorization`，confirmed brief materials 输出应为 `confirmed_brief_ready_for_product_manager`，PM materials 输出应为 `product_manager_prd_ready_for_design`，design materials 输出应为 `design_ready_for_test_design`，test-design materials 输出应为 `test_design_ready_for_tech_lead`，tech-lead materials 输出应为 `tech_lead_ready_for_delivery_owner` | 无 |
| Stage 2 真实样板入口 | blocked | 当前只有 Stage 1 synthetic/user_prompt dry-run | 缺真实业务样板、风险授权、qft-pai 采证 |
| 真实上线/提交授权 | blocked | `DO-003` 合法停在 signoff gate | 缺 human/business owner 授权 |

## Case 汇总

| case group | result |
| --- | --- |
| `*-001` 守门 case | 全部 `pass / pass_to_pause` |
| `*-002` 正向能力 case | `PM-002` pass/continue；`DES-002` pass/pass_to_pause；`TD-002` warn/continue/P2；`TL-002` warn/continue/P2；`DO-002` warn/continue/P2 |
| `*-003` 冲突/边界 case | `PD-003` pass/pass_to_pause；`PM-003` pass/pass_to_pause；`DES-003` pass/pass_to_pause；`TD-003` pass/pass_to_pause；`TL-003` pass/continue；`DO-003` pass/pass_to_pause |
| 跨角色恢复 case | `E2E-RESUME-001` pass/pass_to_pause；证明 synthetic 恢复包可驱动 `product-director -> product-manager -> design -> test-design -> tech-lead -> delivery-owner` 连续消费 |

## Stage 2 推进门禁

- Product-director 真实采证前：Human/老板/业务方补齐 Stage 1 到 Stage 2 的真实业务样板、验收人、指标阈值、投入边界和风险接受边界。
- Product-director 真实采证前：Human 填写真实 `stage-2-intake-facts` 文件，并通过 `validate_stage2_intake_gate.py`；`stage-2-intake-facts.example.json` 只能输出 `materials_verified_not_authorization`，不是当前授权，改名复制也不能作为真实 facts 过 gate；真实 facts 必须带 `fact_source_refs`。
- Product-director 真实采证前：真实 facts 通过后必须通过 `render_stage2_product_director_handoff.py` 生成 handoff package，只能路由到 `product-director`，先形成 confirmed brief 和 Phase 1 边界；不得直接进入语言选型、架构定版、代码修改、提交、上线或自动外发。
- Product-manager 继续前：confirmed brief package 必须通过 `validate_stage2_confirmed_brief_package.py`，只能路由到 `product-manager`；必须保留 canonical `brief/phase-prd` 的 Director lock、阻断 PM-owned 字段和 code changes 禁区。
- Design 继续前：product-manager package 必须通过 `validate_stage2_product_manager_package.py`，只能路由到 `design`；必须保留 Director lock、补齐业务流程、用户路径、规则映射、UNIT、AC、Verification Plan、PM ledger 和 review closure，并继续阻断语言选型、架构定版、代码修改、上线、自动外发和风险接受。
- Test-design 继续前：design package 必须通过 `validate_stage2_design_package.py`，只能路由到 `test-design`；必须补齐 canonical `design.json`、接口契约、质量属性、验证映射、UNIT 覆盖、review digest、reference integrity、design ledger 和 final confirmation，并继续阻断代码修改、提交、上线、自动外发和风险接受。
- Tech-lead 继续前：test-design package 必须通过 `validate_stage2_test_design_package.py`，只能路由到 `tech-lead`；必须补齐 canonical `test-cases.json`、traceability、AC 覆盖、正向/反向/边界用例、special triggers、QA handoff、review digest 和 typed gap 阻断，并继续阻断任务拆解越权、代码修改、提交、上线、QA 执行、自动外发和风险接受。
- Delivery-owner 接手前：tech-lead package 必须通过 `validate_stage2_tech_lead_package.py`，只能路由到 `delivery-owner`；必须补齐 canonical `plan.json`、`tasks.json`、artifact registry、planning preflight、standard-chain semantic integrity 和 delivery-owner intake，并继续阻断代码修改、提交、上线、QA 执行、自动外发和风险接受。
- Stage 2 真实样板必须形成真实 confirmed brief，而不是复用 synthetic resume package。
- PM 术语口径、Design 真实三方字段/SLA/自动外发/人工接管、Test-design blocking gap、Delivery-owner signoff gate 均有明确 owner 裁决。
- 持续用 `run_stage1_eval_checks.py` 守住 dry-run grader 和 artifact 结构契约；新增结构漂移必须先补 validator，再补文档。
- Stage 2 才允许围绕 `/Users/lijieli/project/qft-pai` 做真实采证、语言选型和重写方案；当前仍禁止。

## 下一步

优先让 human 填写真实 Stage 2 intake facts：真实业务样板、验收人、指标阈值、执行环境、灰度/回滚 owner 和风险接受边界。继续用 gate report 作为 Stage 2 前的单一状态入口，并用 `run_stage1_eval_checks.py` 作为结构、单角色 dry-run、跨角色恢复链路、Stage 2 intake gate、product-director handoff、confirmed brief package、product-manager package、design package、test-design package 和 tech-lead package 材料的总验收命令。
