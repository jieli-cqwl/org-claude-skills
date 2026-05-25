# Stage 2 Intake Gate

日期：2026-05-14

## 结论

Stage 2 不能靠“我们想开始重写”进入，必须先有一份真实事实包。

`stage-2-intake-facts.template.json` 是 human/business owner 需要补齐的事实模板；未填写的模板必须被 validator 阻断。`stage-2-intake-facts.example.json` 只是 validator 的完整样例，不是当前真实授权。

## 必填事实

进入 `qft-pai` Stage 2 前必须补齐：

- 真实业务样板：样板名称、业务 owner、真实用户、当前痛点、目标结果。
- 事实来源：必须声明由 human/business owner 填写和确认，提供 `fact_source_refs`，不能把 example 改名当作真实 facts。
- 验收 owner：谁有权判断 Phase 1 是否成功，如何验收。
- 成功指标：指标名称、阈值、测量来源、owner。
- 执行环境：`/Users/lijieli/project/qft-pai` 是否可用于真实采证，外部依赖有哪些。
- Phase 1 范围：哪些流程进入，哪些明确排除。
- 集成边界：三方回调、数据源、人工交接、自动外发策略。
- 灰度与回滚：灰度 owner、回滚 owner、停止条件。
- 风险接受：业务 owner、授权级别、禁止动作。

## 材料自检命令

```bash
python3 tools/eval/scripts/validate_stage2_intake_gate.py --intake docs/feature--agent-delivery-operating-system/stage-2-intake-facts.example.json
```

这条命令只能证明 validator、example 和字段结构可用。输出必须是 `stage2_readiness=materials_verified_not_authorization`，不能被解释为真实 Stage 2 ready。

## 真实 facts 校验命令

真实进入 Stage 2 时，必须把 `--intake` 指向 human/business owner 填好的真实 facts 文件：

```bash
python3 tools/eval/scripts/validate_stage2_intake_gate.py --intake <real-stage-2-intake-facts.json>
```

只有真实 facts 文件输出 `stage2_readiness=intake_complete_for_discovery` 且 `stage2_discovery_entry_allowed=true`，才允许进入真实采证和 Phase 1 冻结。

真实 facts 文件还必须满足 `intake_provenance.source_type=human_business_owner_input`、`intake_provenance.not_copied_from_example=true`，且 `intake_provenance.fact_source_refs` 至少包含一个 `human://`、`meeting://`、`ticket://`、`doc://`、`evidence://` 或 `repo://` 来源。`fixture://` 和 `example` 来源只能出现在样例里，不能出现在真实 facts 里。

这不是证明事实绝对真实，而是把“谁输入、谁确认、基于什么确认、事实从哪里来”的责任显式化，防止样例换名越过 Stage 2 gate。

## 路由输出

validator 会输出 `stage2_route`，用于阻断“facts 通过后直接改代码”的流程漂移。

材料样例通过时：

- `next_standard_chain_role`: `null`
- `required_owner_action`: `fill_real_stage2_intake_facts`
- `blocked_actions`: 必须包含 `language_selection`、`architecture_finalization`、`code_changes`、`commit`、`deploy`、`auto_send`、`business_risk_acceptance`

真实 facts 通过时：

- `next_standard_chain_role`: `product-director`
- `required_owner_action`: `start_product_director_confirmed_brief`
- `allowed_actions`: 只允许 `real_qft_pai_discovery`、`confirmed_brief_drafting`、`phase1_boundary_freeze`
- `blocked_actions`: 仍必须包含 `language_selection`、`architecture_finalization`、`code_changes`、`commit`、`deploy`、`auto_send`、`business_risk_acceptance`

## Product-director Handoff

真实 facts 通过后，使用 renderer 生成 product-director handoff package：

```bash
python3 tools/eval/scripts/render_stage2_product_director_handoff.py --intake <real-stage-2-intake-facts.json>
```

renderer 必须输出：

- `artifact_type`: `stage-2-product-director-handoff`
- `handoff_owner_role`: `product-director`
- `required_product_director_steps`: `D-S1 -> D-S2 -> D-S3 -> D-S4 -> D-S5 -> D-S5.5 -> D-S6 -> D-G1`
- `discovery_boundary.allowed_actions`: 只允许真实采证、confirmed brief 草拟、Phase 1 边界冻结。
- `discovery_boundary.blocked_actions`: 继续阻断语言选型、架构定版、代码修改、提交、上线、自动外发和业务风险接受。

## Confirmed Brief Package

`product-director` 基于 handoff package 形成 confirmed brief 后，必须用 package gate 验证后才能交给 `product-manager`：

```bash
python3 tools/eval/scripts/validate_stage2_confirmed_brief_package.py --package <stage-2-confirmed-brief-package.json>
```

package 必须包含：

- `artifact_type`: `stage-2-product-director-confirmed-brief-package`
- `input_origin`: `stage-2-product-director-handoff`
- `handoff`: 上一步生成的 product-director handoff package。
- `brief`: canonical `brief` artifact，根问题、用户画像、目标、范围、非目标、风险和 Phase 规划必须与 handoff 对齐。
- `phase_prd`: canonical `phase-prd` artifact，Phase 1 目标、入口条件和出口条件必须与 handoff 对齐。
- `decision_boundary.blocked_actions`: 继续阻断 `language_selection`、`architecture_finalization`、`code_changes`、`commit`、`deploy`、`auto_send`、`business_risk_acceptance`。

通过后只表示 `confirmed_brief_ready_for_product_manager`，下一角色是 `product-manager`。它仍不授权语言选型、架构定版、代码修改、提交、上线、自动外发或业务风险接受。

## Product-manager Package

`product-manager` 基于 confirmed brief package 细化 PRD/UNIT 后，必须用 PM package gate 验证后才能交给 `design`：

```bash
python3 tools/eval/scripts/validate_stage2_product_manager_package.py --package <stage-2-product-manager-prd-package.json>
```

package 必须包含：

- `artifact_type`: `stage-2-product-manager-prd-package`
- `input_origin`: `stage-2-product-director-confirmed-brief-package`
- `confirmed_brief_package`: 上一步已通过的 confirmed brief package。
- `brief`: 保留 Director lock，并补齐 PM-owned acceptance criteria、design handoff 决策、非功能要求、review closure 和 delivery confirmation。
- `phase_prd`: 保留 Director lock，并补齐业务流程、用户路径、规则映射、UNIT 索引、优先级、结构化 design decision candidates、review closure 和 issue ledger。
- `units`: 至少一个闭环 `unit-definition`，每个 UNIT 必须有 `closure_definition`、Integration Context、AC 示例、Verification Plan、排除项、优先级和待 design 决策。
- `product_manager_ledger`: 覆盖 `M-S1 -> M-S9` 的 finalized co-creation ledger。
- `decision_boundary.blocked_actions`: 继续阻断 `language_selection`、`architecture_finalization`、`code_changes`、`commit`、`deploy`、`auto_send`、`business_risk_acceptance`。

通过后只表示 `product_manager_prd_ready_for_design`，下一角色是 `design`。它仍不授权语言选型、架构定版、代码修改、提交、上线、自动外发或业务风险接受；这些必须继续由 design、test-design、tech-lead 和 delivery-owner 后续门禁裁决。

## Design Package

`design` 基于 product-manager package 形成系统设计后，必须用 design package gate 验证后才能交给 `test-design`：

```bash
python3 tools/eval/scripts/validate_stage2_design_package.py --package <stage-2-design-package.json>
```

package 必须包含：

- `artifact_type`: `stage-2-design-package`
- `input_origin`: `stage-2-product-manager-prd-package`
- `product_manager_package`: 上一步已通过的 PM PRD/UNIT package。
- `design`: canonical `design` artifact，必须包含架构决策、候选方案取舍、运行时事实、接口输入/输出/错误码、模块边界、数据架构、质量属性、验证映射、UNIT 覆盖、影响面、风险响应、迁移、验证、回滚、review closure 和 final confirmation。
- `design_ledger`: 覆盖 design 语义阶段和 `finalize-design` 的 finalized co-creation ledger。
- `decision_boundary.blocked_actions`: 继续阻断实现语言最终定版、测试用例定义、任务拆解、代码修改、提交、上线、自动外发、业务风险接受和真实 qft-pai 代码修改。

通过后只表示 `design_ready_for_test_design`，下一角色是 `test-design`。它说明 HOW 层设计包已经可被测试设计消费，但仍不授权测试用例绕过设计缺口、Tech-lead 任务拆解、代码修改、提交、上线、自动外发或业务风险接受。

## Test-design Package

`test-design` 基于 design package 形成开发前测试义务后，必须用 test-design package gate 验证后才能交给 `tech-lead`：

```bash
python3 tools/eval/scripts/validate_stage2_test_design_package.py --package <stage-2-test-design-package.json>
```

package 必须包含：

- `artifact_type`: `stage-2-test-design-package`
- `input_origin`: `stage-2-design-package`
- `design_package`: 上一步已通过的 design package。
- `test_cases`: canonical `test-cases` artifact，必须包含 Test Basis、traceability matrix、AC coverage matrix、正向/反向/边界用例、QA handoff、special test triggers、typed gap report、review conclusion 和 issue ledger。
- `decision_boundary.blocked_actions`: 继续阻断 `task_decomposition`、`code_changes`、`commit`、`deploy`、`auto_send`、`qa_execution`、`release_recommendation`、`business_risk_acceptance` 和真实 qft-pai 代码修改。

通过后只表示 `test_design_ready_for_tech_lead`，下一角色是 `tech-lead`。它说明开发前测试义务已可被技术负责人消费，但仍不授权任务拆解绕过测试缺口、代码修改、提交、上线、自动外发、QA 执行或业务风险接受。

## Tech-lead Package

`tech-lead` 基于 test-design package 形成实施计划和冻结任务后，必须用 tech-lead package gate 验证后才能交给 `delivery-owner`：

```bash
python3 tools/eval/scripts/validate_stage2_tech_lead_package.py --package <stage-2-tech-lead-package.json>
```

package 必须包含：

- `artifact_type`: `stage-2-tech-lead-package`
- `input_origin`: `stage-2-test-design-package`
- `test_design_package`: 上一步已通过的 test-design package。
- `plan`: canonical `plan` artifact，必须包含 planning readiness、WBS、关键路径、依赖策略、并行批次、投入/风险信号、目标保真 review 和用户确认。
- `tasks`: canonical `tasks` artifact，必须包含可执行 Task 合同、来源追踪、设计引用、测试引用、依赖关系、批次、证明命令、真实依赖说明、证据目标和 mock 边界。
- `artifact_registry`: delivery-owner intake 可消费的 active registry，必须包含 brief、phase-prd、unit-definition、design、test-cases、plan 和 tasks 的 active finalized 条目。
- `decision_boundary.blocked_actions`: 继续阻断产品范围改写、架构决策改写、测试义务改写、代码修改、提交、上线、自动外发、QA 执行、发布建议、业务风险接受和真实 qft-pai 代码修改。

通过后只表示 `tech_lead_ready_for_delivery_owner`，下一角色是 `delivery-owner`。它说明冻结计划和任务已可被交付负责人接手，但仍不授权 developer 执行、QA 执行、提交、上线、自动外发或业务风险接受；这些必须由 delivery-owner 的 preflight、baseline audit、Task Packet、循环验收和 signoff gate 继续裁决。

材料自检由总入口覆盖：

```bash
python3 tools/eval/scripts/run_stage1_eval_checks.py
```

总入口会验证 `stage-2-intake-facts.example.json` 不能生成 handoff，并用一份带 human/source refs 的真实 candidate 验证 handoff 结构可生成；随后验证 confirmed brief package 能保留 product-director lock、阻断 PM-owned 字段和继续保留 code changes 禁区；再验证 product-manager package 能补齐业务流程、UNIT、AC、Verification Plan、PM ledger 和 review closure，并只能路由到 `design`；继续验证 design package 能补齐 canonical design、review digest、reference integrity、design ledger 和实现禁区，并只能路由到 `test-design`；继续验证 test-design package 能补齐 canonical test-cases、review digest、semantic integrity、typed gap 阻断和 tech-lead 边界，并只能路由到 `tech-lead`；最后验证 tech-lead package 能补齐 canonical plan/tasks、artifact registry、planning preflight、standard-chain semantic integrity、delivery-owner intake 和执行禁区，并只能路由到 `delivery-owner`。

## 边界

通过 intake gate 只表示 Stage 2 可以开始真实采证和 Phase 1 冻结。

它仍不等于：

- 已完成语言选型。
- 已完成 delivery-owner 调度、开发、验收或上线。
- 已允许真实提交。
- 已允许上线。
- 已允许自动外发。
- 已接受业务风险。

这些必须在后续 `standard-chain` 产物和 signoff gate 中继续裁决。真实 facts 通过后的第一个角色是 `product-director`，负责把真实事实收敛成 confirmed brief 和 Phase 1 边界；任何直接进入语言选型、架构定版或代码重写的动作都是越权。
