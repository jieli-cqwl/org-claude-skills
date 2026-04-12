# Delivery Owner 角色定义与差距说明

## 目的

澄清当前 `delivery-owner` skill 的真实语义、真实能力状态，以及它与“最佳实践级 Delivery Owner”之间的关键差距。本文先做基线收口，不直接给出改造方案。

## 当前角色定义

当前 `delivery-owner` skill，更准确的定义是：

`Delivery Owner 语义下的执行期交付负责人 + 质量门禁协调者 + 签收推进者`

含义：

- 它是 `plan.md` 的执行 owner，不是 `plan.md` 的制定 owner。
- 它负责组织开发、验证、QA、签收与提交这条交付链路。
- 它负责把计划推进完，并把交付证据链收齐。
- 它不负责重新定义需求、发明技术方案或亲自完成实现。

依据：

- 角色说明明确写的是：按 `/tech-lead` 已输出且经用户确认的 `plan.md` 组织开发执行、代码审查、功能验收并推进全链路交付。
- 同时明确写了：不负责需求定义、技术方案设计和代码实现。

## 当前能力状态

评估口径：

- `真实具备`：`skill + template + script + tests` 形成闭环支撑。
- `部分具备`：有流程骨架，但关键调度权、升级动作或验证闭环不完整。
- `形式具备`：文档写了，但缺少脚本和测试兜底。

| 能力 | 具备状态 | 成熟度判断 | 说明 |
|------|----------|------------|------|
| 启动前检查 | 真实具备 | 有明显缺口 | 已有基线检查、用户确认、前置验证点和 `preflight-evidence` 检查；但 `preflight-evidence` 目前仍偏 warning，不是严格 readiness gate。 |
| 任务调度 | 部分具备 | 有明显缺口 | 已有 developer/verifier/qa 派发、worktree 并行、修复流转；但更偏执行上游计划，缺少成熟的资源重排、优先级重算和动态升档调度。 |
| 过程推进 | 真实具备 | 中高，但未达最佳 | 已有 Phase 1-4、熔断、BLOCKED、插问处理、签收与提交链路；但执行期持续目标校准较弱。 |
| 质量门禁 | 真实具备 | 中高，但未达最佳 | 已有 `REVIEW_A/B`、`QA_A-D`、`fresh proving command`、`mock boundary`、issue ledger 和 completion check；但缺动态门禁升级和更强的 preflight 硬门。 |
| 交付收口 | 真实具备 | 有明显缺口 | 已有 `acceptance-summary`、`release_recommendation`、`residual_risk`、签收记录；但更偏“门禁通过 + 用户签收”，还不是“目标达成判定”。 |

## 当前角色不负责什么

以下边界在当前定义中是清楚的，应视为现状事实：

- 不负责需求定义
- 不负责技术方案设计
- 不亲自替代 developer / qa / review 完成交付
- 不单方面决定业务目标或风险接受

## 当前定义的强项

- 交付流程骨架完整
- 质量门禁较强，且有脚本与测试支撑
- 证据链追溯意识强
- 签收与发布建议已经形成 Phase 级闭环

## 当前定义的核心缺口

当前最大的缺口不是“不会推进”，而是“更擅长保证流程跑完，不擅长保证目标闭环”。

具体表现：

- 目标保真主要在 `tech-lead` 的计划评审里完成，执行期缺少明确的持续目标校准责任。
- 执行中风险升高时，`delivery-owner` 还没有成熟的动态 review / QA 升档能力。
- 完成定义主要证明“任务完成、门禁通过、用户签收”，不足以单独证明“阶段目标和交付价值真的达成”。

## 目标角色定义

如果按当前方向收敛，目标角色应定义为：

`最佳实践级 Delivery Owner（当前 Phase 的交付目标负责人）`

含义：

- 在 `brief / prd / design / plan` 已确认前提下，对“是否真正达成当前 Phase 目标”负责。
- 负责调度开发、测试等资源，推进排期、批次和里程碑。
- 在 `Scope Freeze` 内做范围内决策。
- 持续监控偏差，并在必要时触发 replan / rebaseline。
- 根据实际执行风险，决定是否升级 review / QA 强度。
- 在签收前回到 `brief` 成功标准、Phase 目标和交付价值，判断是否真正达成目标。

## 当前角色与目标角色的关键差距

| 维度 | 当前 skill（Delivery Owner 语义已形成） | 目标态（最佳实践级 Delivery Owner） |
|------|---------------------|----------------------|
| 责任中心 | 对计划执行结果负责 | 对阶段目标达成结果负责 |
| 启动动作 | 前置检查 + 用户确认开始 | readiness 校准 + 风险 owner 对齐 + 正式 kickoff |
| 调度能力 | 依 plan 派发与推进 | 可在 guardrail 内重排批次、优先级和验证强度 |
| 偏差治理 | 失败、BLOCKED、熔断时暂停 | 持续监控偏差并主动触发升级、再计划和再基线 |
| 质量门禁 | 主要执行 plan 预设分级 | 可依据执行信号动态升档 |
| 收口定义 | 门禁通过 + 签收通过 | 目标达成 + 风险边界清楚 + 签收通过 |

## 当前阶段结论

当前 `delivery-owner` 的基线已经足够清楚：

- 它不是“没人负责交付”，而是已经形成了较强的执行编排和质量门禁能力。
- 它的真实语义已经进入 `Delivery Owner` 范畴，但还不是最佳实践级完整闭环。
- 下一步重点是继续收敛仓库口径，避免同一角色在不同文档里被多种名字解释。

因此，后续讨论应从“继续优化执行编排器”切换到“把 `Delivery Owner` 语义冻结成仓库真源，并清理漂移表述”。

补充：

- 关于为什么当前 skill 更接近 `Delivery Owner` 而不是完整的 `Project Manager`，见 [delivery-owner-vs-project-manager.md](/Users/lijieli/org-claude-skills/docs/delivery-owner-role-20260411/delivery-owner-vs-project-manager.md)。
- 关于为什么下一步必须先定义能力模型，见 [capability-model-rationale.md](/Users/lijieli/org-claude-skills/docs/delivery-owner-role-20260411/capability-model-rationale.md)。
