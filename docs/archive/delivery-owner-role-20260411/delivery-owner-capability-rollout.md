# Delivery Owner 能力落地矩阵

## 目的

把 `delivery-owner` 能力矩阵和能力审计，翻译成可执行的落地清单：

- 哪项能力要补
- 要补到哪些真源
- 需要什么验证
- 达到什么标准才算补到位

## 总体策略

本轮 rollout 不再重复讨论角色方向。  
方向已经冻结：

- `delivery-owner` 作为当前标准流程中的执行期交付 owner，方向成立
- 当前不成立的是“已经具备最佳实践级能力”

因此，rollout 的目标不是“再解释角色”，而是：

`把最弱的 3 项能力和最关键的 4 个高风险缺口，从流程骨架做成可执行控制面。`

## 优先级

### `P0`

- `Execution Orchestration`
- `Progress & State Awareness`
- `Dynamic Quality Escalation`
- `Goal Closure`
- `Sign-off Orchestration`
- `QA` 边界与签收前风险包

### `P1`

- `Evidence Governance` 审计级升级
- replay 场景可执行化
- 术语与入口进一步收敛

## 能力落地矩阵

| 能力 / 缺口 | 当前状态 | 落地目标 | 主要改动面 | 验证方式 | 完成标准 | 优先级 |
|-------------|----------|----------|------------|----------|----------|--------|
| `Execution Orchestration` | 部分具备 | 从“按 plan 派发”升级为“可验证的调度控制面” | `shared/skills/delivery-owner/SKILL.md`、`references/templates/dev-report-template.md`、`scripts/completion_check.sh`、`tests/test-skill-output-and-gate-contract.sh` | 增加编排字段和失败用例 | 能区分串行/并行/批次重排/merge 决策依据，且缺失关键调度证据会失败 | `P0` |
| `Progress & State Awareness` | 部分具备 | 从事后汇总升级为运行态感知 | `dev-report-template.md`、`acceptance-summary-template.md`、`completion_check.sh`、replay/contract tests | 新增 runtime snapshot 类字段和 blocker 追踪检查 | 关键判断都能追到当前状态依据，而不是只靠轮次表 | `P0` |
| `Dynamic Quality Escalation` | 基线具备，动态部分偏弱 | 把 drift -> gate escalation 做成强门禁 | `phase3-grade-matrix.sh`、`phase3-dispatch.md`、`completion_check.sh`、Phase 3 合同测试 | 增加“命中触发器但未升档即失败”的用例 | 动态升档不再只是允许发生，而是漏掉会失败 | `P0` |
| `Goal Closure` | 真实具备但偏表格校验 | 把目标闭环做成真源绑定校验 | `acceptance-summary-template.md`、`completion_check.sh`、可能新增 `goal-evidence-model.md` 补充约束 | 校验目标来源、证据锚点、结果与发布建议一致性 | `goal closure` 必须能回指 `brief/prd`，且证据锚点真实存在 | `P0` |
| `Sign-off Orchestration` | 部分具备 | 从文档态签收升级为完整风险包签收 | `acceptance-summary-template.md`、`qa-report-template.md`、`completion_check.sh` | 增加签收前风险暴露和条件放行承接校验 | 用户看到的是完整风险包，而不是压平摘要 | `P0` |
| `QA` 边界矛盾 | 存在结构性冲突 | 去掉 QA 对尚未生成工件的前置依赖，恢复独立质量判断 | `shared/skills/qa/SKILL.md`、`qa-report-template.md`、`qa/scripts/completion_check.sh`、`delivery-owner/scripts/completion_check.sh` | 边界合同测试 + 交叉字段校验 | QA 不依赖 delivery-owner 先收口，delivery-owner 也保留更保守收口空间 | `P0` |
| `Evidence Governance` | 真实具备但偏格式治理 | 升级为审计级证据治理 | `delivery-owner/scripts/completion_check.sh`、`qa/scripts/completion_check.sh`、相关 templates | 新增锚点存在性、引用真实性、跨工件一致性校验 | 引用不仅“格式像”，还必须真实存在且可支撑结论 | `P1` |
| replay 场景 | 已定义，未可执行 | 变成 rollout gate 的自动化检查 | `docs/.../replay-scenarios.md`、新测试脚本或现有 contract tests | 跑通 4 个必跑场景 | 全部 replay 通过前，不宣称“可投入团队使用” | `P1` |

## 关键改动设计

### 1. 为 `Execution Orchestration` 增加运行态字段

建议新增或强化的字段：

- `dispatch_mode`
- `current_batch`
- `batch_unlock_condition`
- `merge_readiness`
- `scheduler_decision_basis`
- `next_action`

落点：

- `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- `shared/skills/delivery-owner/scripts/completion_check.sh`

目标：

- 不再只看“最后结果是什么”
- 还要能看见“为什么当前这样调度”

### 2. 为 `Progress & State Awareness` 增加 runtime snapshot

建议新增或强化的字段：

- `last_observed_at`
- `runtime_snapshot`
- `active_blocker`
- `blocker_owner`
- `takeover_note`
- `decision_basis`

目标：

- 任何暂停、升档、replan、签收判断，都能追到最近一次观察依据

### 3. 把动态升档从“记录动作”变成“强约束动作”

当前问题：

- `deviation_trigger` / `control_action` 会被记录
- 但命中触发器后，是否真的追加了 review/QA，还不会失败

必须补的验证：

- 若 `control_action=ESCALATE`，则 Phase 3 必须出现升级后的 gate 证据
- 若命中 `INTERFACE_BREAK / SHARED_FILES_EXPANSION / NON_CONVERGENCE` 等高风险触发器，仍沿基线分级通过，应直接失败
- 若 `control_action=REPLAN`，则必须存在计划修订或刷新后的 plan 证据

### 4. 把 `Goal Closure` 绑定到真实目标来源

当前问题：

- 现在更像“表格存在 + 枚举合法”

必须补的验证：

- `goal` 必须回指 `brief / prd / delivery value`
- `evidence` 必须指向真实锚点
- `remaining_gap` 不得与 `acceptance_release_recommendation=放行` 冲突
- `delivery-owner` 应保留比 QA 更保守的收口空间

### 5. 修正 QA 与签收边界

当前问题：

- `qa-report` 不能前置依赖尚未生成的 `acceptance-summary`
- `delivery-owner` 也不能被压成只能复制 QA 结论

修正方向：

- QA 只对自身验收范围、风险、未执行义务、`release_recommendation` 负责
- `delivery-owner` 负责承接 QA 风险包、目标闭环和最终签收输入包

## 建议验证包

### contract tests

- 新增 `dynamic escalation mismatch` 场景
- 新增 `replan without revised plan` 场景
- 新增 `goal closure source mismatch` 场景
- 新增 `qa boundary contradiction` 场景
- 新增 `sign-off risk package incomplete` 场景

### replay tests

- readiness failure
- execution drift and replan
- quality escalation after risk increase
- goal closure mismatch despite green gates

## rollout gate

只有同时满足以下条件，才可宣称“delivery-owner 已达到团队可用标准”：

1. `P0` 缺口全部补齐
2. 新增 contract tests 全绿
3. replay 场景全绿
4. `quality-rubric.md` 达到 `Full rollout` 阈值
5. 不再存在与当前结论冲突的旧真源

## 一句话结论

下一轮真正要做的，不是继续解释 `delivery-owner` 是谁，而是把最薄弱的能力补到：

`漏掉会失败，缺证据会失败，边界冲突会失败。`

