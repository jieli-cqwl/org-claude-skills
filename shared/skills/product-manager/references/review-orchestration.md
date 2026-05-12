# 评审编排

## 评审写入字段

Manager 阶段评审闭环只写入 `brief.json.review_conclusion / issue_ledger` 以及相关 `phase-prd.json / UNIT-*.json` 字段。人类投影视图只能渲染这些字段，不能作为下游控制输入。

M-S8 / M-G1 只消费当前 JSON 状态；口头结论不能替代 `review_conclusion / issue_ledger`。

## 评审视角路由

- 召集 agent teams（使用 TeamCreate 创建），3 个 reviewer 分别从产品、架构、测试维度并行评审 `brief.json` + `phase-{N}/phase-prd.json` + `phase-{N}/units/UNIT-*.json`：
  - 产品审查 prompt：`references/prd-reviewer-prompt.md`（覆盖 R1~R6 + R13 + R14 + PR-C1 + Director lock：根问题清晰度 / UNIT 闭环性 / 示例驱动 AC / 遗漏检测 / 一致性 / 结构化待设计决策 / 成功信号完整性 / AI 可执行性 / 共创可信度 / Director 锁定内容漂移；用于确认 PRD 是否完整回答用户问题，并形成可继续设计的需求基线）
  - 架构审查 prompt：`references/architect-reviewer-prompt.md`（覆盖 R7~R9 + AR-C1：技术可行性 / 隐含依赖与影响范围 / 技术约束充分性 / Integration Context；用于确认需求在当前技术上下文中可落地，且关键依赖、业务影响范围和 design handoff 没有被漏掉）
  - 测试审查 prompt：`references/tester-reviewer-prompt.md`（覆盖 R10~R13 + TR-C1：影响范围与回归风险 / AC 可测试性 / 异常边界覆盖度 / 成功信号可验证性 / Verification Plan；用于确认 AC 能被真实验证，并提前暴露回归、异常边界和验证计划风险）
- 产品视角必须显式保留 `R13`、`PR-C1` 和 Director lock 一致性检查。
- 三个视角都必须检查 JSON 中的示例输入、预期结果、边界情况、失败模式、Verification Plan、Integration Context、结构化待设计决策和 AI 可执行性；不得从人类投影视图补充 JSON 中没有的结论。

## 评审收敛循环

- 评审编排为 `3 视角×max10轮`。
- 如有 FAIL：复核问题证据、影响范围与承接位置 → 系统性修复 `brief.json` / `phase-{N}/phase-prd.json` / `phase-{N}/units/UNIT-*.json` / `review_conclusion` / `issue_ledger` → 仅对 FAIL 视角重新提交评审 → 循环。
  - 若存在 FAIL，只重提 FAIL 视角，不重跑已 PASS 视角。
  - 循环上限 10 次；达到上限仍有 FAIL 时标记 `BLOCKED`。
  - 首轮全 PASS，仍要强制做一轮 `CONFIRMATION`；在 `review_conclusion / issue_ledger` 记录为 `R2 / CONFIRMATION`（防浅层通过）。
  - 连续 2 轮 FAIL 数不减少：`ASK_USER`。
  - 同一 issue 连续 3 轮未关闭：`BLOCKED`，停止自动修复。
- WARN / FAIL / 收敛轮次 / 阻断事实补充统一写入 `review_conclusion / issue_ledger`，不能口头带过。
- WARN 项在 `review_conclusion / issue_ledger` 中显式承接。
- 人类投影视图只渲染已闭合的评审状态，不作为下游控制输入。
