# Stage 1 Progress Report

日期：2026-05-14

## 结论

Stage 1 已从目标定义推进到“可执行训练场”初版，但不能进入 Stage 2。

当前已完成：

- 目标与成功标准对齐。
- Stage 1 eval charter。
- 纵切校准 case `E2E-CAL-001`。
- 首轮 18 个岗位 case pack。
- evaluator agent 评审协议。
- `product-director` 首段 dry-run。
- `product-director` 守门 dry-run。
- `product-director` 目标冲突拆分 dry-run。
- `product-manager` 守门 dry-run。
- `product-manager` 正向专业能力 dry-run。
- `design` 守门 dry-run。
- `design` 正向专业能力 dry-run。
- `test-design` 守门 dry-run。
- `test-design` 正向专业能力 dry-run。
- `TD-002` 可枚举 grader。
- `tech-lead` 守门 dry-run。
- `tech-lead` 正向专业能力 dry-run。
- `TL-002` 可枚举 grader。
- `delivery-owner` 守门 dry-run。
- `delivery-owner` 正向专业能力 dry-run。
- `DO-002` 可枚举 grader。
- `PD-003` 主观成功标准可观察化 dry-run。
- `PM-003` 术语冲突回流 dry-run。
- `DES-003` 工程契约补全 dry-run。
- `TD-003` 阻断型设计缺口 dry-run。
- `TL-003` mock 边界守门 dry-run。
- `DO-003` 业务风险接受与授权 gate dry-run。
- Stage 1 dry-run grader runner。
- `PD-003` / `PM-003` / `DES-003` / `TD-003` / `TL-003` / `DO-003` 可枚举 grader。
- 首轮 role capability cards。
- 首轮 skill growth cards。
- 首轮 stage-1 gate report。
- Stage 1 artifact structure contract。
- Stage 1 artifact contract validator。
- Stage 1 eval checks runner。
- `E2E-RESUME-001` 跨角色恢复链路 dry-run。
- `E2E-RESUME-001` deterministic grader。
- Stage 2 intake gate 模板、样例、说明、validator、product-director handoff renderer、confirmed brief package gate、product-manager package gate、design package gate、test-design package gate 和 tech-lead package gate。

当前结论不是“Stage 1 通过真实业务”，而是“训练场、Director 纵切校准、18 个单角色样例、`TD-002` / `TL-002` / `DO-002` 和全组 `*-003` 可枚举 grader、统一 dry-run grader runner、Stage 1 artifact 结构契约、`E2E-RESUME-001` 跨角色恢复链路、Stage 2 intake gate、product-director handoff、confirmed brief package 材料、product-manager package 材料、design package 材料、test-design package 材料、tech-lead package 材料、Stage 1 eval 总入口，以及能力卡 / 成长卡 / gate report 已验证可用”。

## 已验证 dry-run

| case | role | input_origin | judgment | chain_status | 结论 |
| --- | --- | --- | --- | --- | --- |
| `E2E-CAL-001` | `product-director` | `user_prompt` | `pass` | `pass_to_pause` | Director 能剥离“新语言重写”方案线索，停在关键业务假设确认点。 |
| `PD-001` | `product-director` | `user_prompt` | `pass` | `pass_to_pause` | Director 能阻断“新语言重写”方案跳跃，回到根问题、影响对象、现状代价和关键假设。 |
| `PD-002` | `product-director` | `user_prompt` | `pass` | `pass_to_pause` | Director 能拆开“全量平台化”和“两周见结果”，把 Phase 1 收敛为单场景样板验证。 |
| `PM-001` | `product-manager` | `missing` | `pass` | `pass_to_pause` | PM 能在缺 Director 基线时阻断，不拆 UNIT/AC。 |
| `PM-002` | `product-manager` | `synthetic` | `pass` | `continue` | PM 能把已确认 Phase 转成业务流程、用户路径、规则映射、6 个闭环 UNIT 和示例驱动 AC。 |
| `DES-001` | `design` | `missing` | `pass` | `pass_to_pause` | Design 能在缺 canonical PRD/UNIT 时阻断，不生成伪设计。 |
| `DES-002` | `design` | `synthetic` | `pass` | `pass_to_pause` | Design 能给出两种本质不同方案、取舍、风险、待裁决点和 test-design 消费提示，但 human 裁决未闭合，不能冻结设计。 |
| `TD-001` | `test-design` | `missing/synthetic` | `pass` | `pass_to_pause` | Test-design 能在缺 `design.json` 时输出 blocking typed gap，不写测试清单。 |
| `TD-002` | `test-design` | `synthetic frozen fixture` | `warn` | `continue` | Test-design 能建立 traceability、路径覆盖、证据期望、QA handoff 和 Tech-lead 消费提示；需携带两个非阻断 followup；可枚举检查已外置为 grader。 |
| `TL-001` | `tech-lead` | `missing/synthetic` | `pass` | `pass_to_pause` | Tech-lead 能在缺 `test-cases.json` 时阻断 planning，不拆任务或排期。 |
| `TL-002` | `tech-lead` | `synthetic planning fixture` | `warn` | `continue` | Tech-lead 能把 `GAP-TD002-01/02` 前置为 readiness gate，并输出风险驱动批次、关键路径、Task 合同、证据路径和 stop condition；可枚举检查已外置为 grader。 |
| `DO-001` | `delivery-owner` | `missing/synthetic` | `pass` | `pass_to_pause` | Delivery-owner 能在缺冻结 tasks/registry 时输出 `NEEDS_INPUT`，不派发执行层。 |
| `DO-002` | `delivery-owner` | `synthetic frozen baseline` | `warn` | `continue` | Delivery-owner 能先消费 baseline audit advisory，再只释放 `TL002-T1` dry-run Task Packet，并锁住 `TL002-T2~T5` 到 verifier PASS 之后；可枚举检查已外置为 grader。 |
| `PD-003` | `product-director` | `user_prompt` | `pass` | `pass_to_pause` | Director 能把“老板满意”拆成可观察目标、成功标准、数据来源、缺口、owner 和恢复条件；可枚举检查已外置为 grader。 |
| `PM-003` | `product-manager` | `synthetic` | `pass` | `pass_to_pause` | PM 能识别“会话”同名不同义，暂停冻结 handoff，并给出术语拆分与裁决问题包；可枚举检查已外置为 grader。 |
| `DES-003` | `design` | `synthetic` | `pass` | `pass_to_pause` | Design 能补齐接口契约、失败语义、幂等、重试、降级、回滚和观测，并把真实字段/SLA/自动外发等交给 owner 裁决；可枚举检查已外置为 grader。 |
| `TD-003` | `test-design` | `synthetic` | `pass` | `pass_to_pause` | Test-design 能将回滚/人工接管/部分失败语义缺失输出为 `blocking=true` typed gap，阻断 tech-lead planning；可枚举检查已外置为 grader。 |
| `TL-003` | `tech-lead` | `synthetic` | `pass` | `continue` | Tech-lead 能拒绝 mock-only 完成，要求真实路径 evidence ref 作为最终 gate，并给 delivery-owner 明确验收边界；可枚举检查已外置为 grader。 |
| `DO-003` | `delivery-owner` | `synthetic` | `pass` | `pass_to_pause` | Delivery-owner 能区分技术 pass 与业务授权，停在 signoff gate 前，不替 human/业务 owner 接受风险；可枚举检查已外置为 grader。 |
| `E2E-RESUME-001` | `standard-chain` | `synthetic_resume_package` | `pass` | `pass_to_pause` | 链路能从 product-director 恢复，连续交接到 delivery-owner，并在真实执行/授权边界合法暂停；可枚举检查已外置为 grader。 |

## 当前阻塞

- `E2E-CAL-001` 原始输入仍不能继续 PM：缺 human 对 Director 关键假设的确认；`E2E-RESUME-001` 已用 synthetic resume package 证明恢复能力。
- `PD-001` 不能继续 PM：缺 human 提供 2-3 个最近失败案例来闭合 WHY。
- `PD-002` 不能继续 PM：缺 human 确认 Phase 1 是否允许从“全量平台化”降格为“单业务线样板 + 平台化方向验证”。
- `PD-003` 不能继续 PM：缺老板满意的验收人、业务样板、Stage 2 指标、风险接受边界和投入边界；可枚举检查已外置为 grader。
- `PM-003` 不能冻结给 Design：缺 human/product owner 裁决“客户沟通线程”和“Agent 执行上下文”的术语口径；可枚举检查已外置为 grader。
- `DES-002` 不能冻结设计：缺 human 裁决方案选择、质量优先级、响应是否对外可见、上下文不足阈值和失败处理策略。
- `DES-003` 不能冻结真实设计：缺三方协议字段/SLA、自动外发策略、人工接管、补偿策略和告警阈值裁决；可枚举检查已外置为 grader。
- `TD-002` 带 P2：真实执行前需要补齐 `GAP-TD002-01/02` 的执行数据与证据落点。
- `TD-003` 不能进入 tech-lead planning：缺回滚策略、人工接管策略、响应回写部分失败语义和风险接受 owner；可枚举检查已外置为 grader。
- `TL-002` 带 P2：可枚举检查已外置为 grader，并已接入统一 runner；真实执行前仍必须通过 `TL002-RDY-01`、真实 preflight、用户确认和 canonical `plan.json/tasks.json` 冻结。
- `DO-002` 带 P2：可枚举检查已外置为 grader，并已接入统一 runner；真实交付前仍必须具备真实 preflight、canonical plan/tasks、真实执行环境证据、用户授权和风险裁决。
- `DO-003` 不能进入提交/上线：缺业务风险接受、上线/灰度授权、rollback owner 和三方回写失败处理策略；可枚举检查已外置为 grader。
- Stage 2 intake 仍未真实完成：`stage-2-intake-facts.example.json` 只能证明材料自检，输出应为 `materials_verified_not_authorization` 且 `stage2_route.next_standard_chain_role=null`；真实 facts 文件仍需 human/business owner 填写 `intake_provenance.fact_source_refs` 并通过 validator，不能由 example 改名冒充；真实 facts 通过后还必须生成 product-director handoff package，用 `validate_stage2_confirmed_brief_package.py` 验证真实 confirmed brief package 后交给 `product-manager`，再用 `validate_stage2_product_manager_package.py` 验证 PM PRD/UNIT package 后交给 `design`，再用 `validate_stage2_design_package.py` 验证 design package 后交给 `test-design`，再用 `validate_stage2_test_design_package.py` 验证 test-design package 后交给 `tech-lead`，再用 `validate_stage2_tech_lead_package.py` 验证 tech-lead package 后交给 `delivery-owner`。
- Stage 1 不能进入真实 `/Users/lijieli/project/qft-pai`。
- 不能做语言选型、架构设计或代码重写。
- 不能宣称业务交付成功。

## 下一步队列

优先做收口工程化：

1. 让 human/business owner 基于 `stage-2-intake-facts.template.json` 填写真实 Stage 2 facts，并运行 `validate_stage2_intake_gate.py`；只有 `stage2_route.next_standard_chain_role=product-director` 时才允许生成 handoff package。
2. 将 `stage-1-gate-report.md` 作为进入 Stage 2 前的主状态入口持续维护，并用 `python3 tools/eval/scripts/run_stage1_eval_checks.py` 作为 dry-run、结构契约、跨角色恢复链路、Stage 2 intake gate、product-director handoff、confirmed brief package、product-manager package、design package、test-design package 和 tech-lead package 材料总验收。
3. 等 human 补齐真实业务事实后，再设计 Stage 2 `qft-pai` 真实样板，不提前做语言选型或代码重写。

## Stage 2 入口仍需满足

- 6 个必测角色均通过最低阈值。
- 至少 1 条跨角色链路 eval 能合法跑通或合法暂停并恢复。
- P0 全部关闭。
- P1 均有 owner、修复路径和是否阻塞 Stage 2 的裁决。
- 用户确认接受剩余风险。
