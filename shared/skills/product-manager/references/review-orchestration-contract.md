# Review-Orchestration Contract v1

## product-manager-review.md 产物契约

product-manager-review.md 是 Manager 阶段的评审闭环证据文件；在 standard-chain lane 中它是 legacy/人工审计 sidecar，记录三方 Verdict、当前未关闭 issue、收敛轮次、用户裁决和未决阻断。

standard-chain lane 的评审闭环结论写入 canonical `brief.json.review_conclusion / issue_ledger` 以及相关 `phase-prd.json / UNIT-*.json` 字段；`product-manager-review.md` 仅是 legacy markdown lane 的人工投影视图或迁移 sidecar。

M-S8 / M-G1 只消费已落盘的当前状态；口头结论不能替代 canonical 字段或 legacy lane 的 `product-manager-review.md`。

## 编排规则

- 召集 Agent Team（TeamCreate 协作团队），3 个 reviewer 分别从产品、架构、测试维度并行评审 `brief.json` + `phase-{N}/phase-prd.json` + `phase-{N}/units/UNIT-*.json`（legacy lane 可投影为 `brief.md` + `phase-{N}/prd.md` + `phase-{N}/units/`）：
  - 产品审查 prompt：`references/prd-reviewer-prompt.md`（覆盖 R1~R6 + R13 + PR-C1 + Director lock：根问题清晰度 / UNIT 闭环性 / AC 可验证性 / 遗漏检测 / 一致性 / 待设计决策 / 成功信号完整性 / 共创可信度 / Director 锁定内容漂移；用于确认 PRD 是否完整回答用户问题，并形成可继续设计的需求基线）
  - 架构审查 prompt：`references/architect-reviewer-prompt.md`（覆盖 R7~R9：技术可行性 / 隐含依赖与影响范围 / 技术约束充分性；用于确认需求在当前技术上下文中可落地，且关键依赖与影响范围没有被漏掉）
  - 测试审查 prompt：`references/tester-reviewer-prompt.md`（覆盖 R10~R13：影响范围与回归风险 / AC 可测试性 / 异常边界覆盖度 / 成功信号可验证性；用于确认 AC 能被真实验证，并提前暴露回归与异常边界风险）
- 产品视角必须显式保留 `R13`、`PR-C1` 和 Director lock 一致性检查。
- 评审编排为 `3 视角×max10轮`。
- 如有 FAIL：复核问题证据、影响范围与承接位置 → 系统性修复 `brief.json` / `phase-{N}/phase-prd.json` / `phase-{N}/units/UNIT-*.json` / canonical review fields（legacy lane 同步到 `product-manager-review.md`）→ 仅对 FAIL 视角重新提交评审 → 循环。
  - 若存在 FAIL，只重提 FAIL 视角，不重跑已 PASS 视角。
  - 循环上限 10 次；达到上限仍有 FAIL 时标记 `BLOCKED`。
  - 首轮全 PASS，仍要强制做一轮 `CONFIRMATION`；在 `product-manager-review.md` 记录为 `R2 / CONFIRMATION`（防浅层通过）。
  - 连续 2 轮 FAIL 数不减少：`ASK_USER`。
  - 同一 issue 连续 3 轮未关闭：`BLOCKED`，停止自动修复。
- WARN / FAIL / 收敛轮次 / 用户裁决统一沉淀到 canonical `review_conclusion / issue_ledger`；legacy lane 可同步到 `product-manager-review.md`，不能口头带过。
- WARN 项在 canonical `review_conclusion / issue_ledger` 中显式承接；legacy lane 同步到 `product-manager-review.md` 时也必须显式承接。
- legacy lane 的过程证据统一沉淀到 `product-manager-review.md`；standard-chain lane 不以 `product-manager-review.md` 作为下游控制输入。

## product-manager-review.md 收口规则

写入 `product-manager-review.md` 时使用以下收口规则，不要依赖 gate 去猜：

- `审查汇总` 的 `Issue Count` 只统计当前仍未关闭的稳定 issue（`PR-* / AR-* / TR-*`）；某视角 `Verdict=PASS` 时必须为 `0`。
- 已关闭但仍想保留修订痕迹的内容，改写为 `HIS-*` 历史记录；不要在 PASS 视角继续保留 `PR/AR/TR` 的已关闭行。
- `审查问题台账` 不能留空；即使首轮全 PASS，也至少保留 1 条 `HIS-*` 历史记录来承接修订或确认轮痕迹。
- `审查问题台账` 的 `Review Round` 只写 issue 首次出现轮次（如 `R1`），不要写 `R1-R3` 这类范围。
- `收敛轮次摘要` 的 `未关闭 Issue IDs` 只列该轮仍未关闭的稳定 issue；若 `FAIL数=0`，这里必须写 `无`。
- `FAIL数` 只统计该轮仍未关闭的 FAIL 项，不把 WARN 混进去；若首轮全 PASS，仍要补一轮 `R2 / CONFIRMATION`。
- `用户裁决记录` 只在 `ASK_USER` 或 `BLOCKED` 时填写；未触发时保留表头为空，不要写“无”或占位行。

## 高风险上线补充审查

对高风险上线类需求，再补 1 轮发布场景审查，至少覆盖：

- 首次上线
- 重复上线 / 重入触发
- 高频重复触发 / 批量重放（例如连续 10 次提交、重复回调、脚本重放）
- 失败重试
- 回滚 / 撤销
- 外部依赖不可用
- 幂等与重复提交

如果这些场景中的任一项会改写目标、范围、规则或 Phase 边界，不在当前 skill 内拍板，直接回退 `/product-director`。
