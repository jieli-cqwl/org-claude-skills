# Self-check

Self-check 阶段读取本文；只做送审前过程对齐、交付成功标准验收、反馈和回流。不新增产物字段，字段以 templates/contracts 为准。

## 过程对齐

- Handoff gate：Director baseline 已通过；Director-owned 字段未漂移；PM 可关闭缺口、用户裁决缺口和 Director 回流缺口已分清。
- Evidence and AS-IS：每个会影响判断的入口、流程、状态、日志、文档或裁决都有证据、明确 N/A 或阻断记录；`source_type` 写真实来源，`supports` 指向具体判断，`required_evidence` 和 `blocks_fields` 写清缺什么、阻断什么。
- TO-BE product model：目标流程只改变达成 Phase 目标所需的业务行为；正常、边界、失败路径和可观察结果已闭合；未改变 Phase 出口、范围、非目标或可行性。
- Feature inventory and risk：功能清单来自已闭合流程；每项能力是 `IN_SCOPE`、`OUT_OF_SCOPE` 或 `NEEDS_DECISION`；模块能力、入口场景、业务对象、状态、权限、规则和风险能支撑 UNIT。
- Pre-UNIT gate：没有会改变 UNIT 边界的证据、流程、功能、入口、对象、状态、权限、规则或风险缺口。
- UNIT split：每个 UNIT 完成一个 `输入或触发 -> 核心行为 -> 可观察结果` 闭环；优先级、依赖、排除项、Integration Context、功能追溯、流程追溯和风险追溯一致。
- Cross-UNIT consistency：同一对象、状态和规则使用同一名称与口径；排除项、依赖和 Integration Context 不冲突。
- AC：每条 AC 都能用业务操作和可观察结果证明行为，且包含示例输入、预期结果、边界情况和失败模式。
- Verification Plan：每条计划说明要证明哪个业务结果，写清业务操作、预期观察、证据目标，并映射 AC、成功信号、风险或设计交接项。
- Design handoff：只交接 PM 已定义业务边界、且需要 `/design` 选择的决策；PM 能基于业务事实直接判断的问题已在 PM 产物内关闭。

## 交付成功标准

下游能直接回答这些问题时，PM 产物才可送审：

- 现在是什么。
- 目标是什么。
- 工作从哪里开始。
- 谁能做。
- 哪个对象如何变更状态。
- 什么在范围内或范围外。
- 风险还剩什么，由谁承接。
- 每个 UNIT 完成什么闭环。
- AC 如何被观察。
- Verification Plan 要证明什么业务结果。
- `/design` 必须决策什么。

## 反馈

任一检查失败，返回下列运行时阻断反馈；这些反馈字段不得直接写入 JSON，落盘时映射到既有 `pre_review_issue_ledger` 或 `issue_ledger` 字段，不新增模板外字段：

- `status`：`NEEDS_PM_FIX`、`NEEDS_USER_DECISION` 或 `NEEDS_DIRECTOR`，仅作为当前回复状态。
- `failed_check`：失败的过程对齐项或交付成功标准。
- `evidence`：对应 JSON 路径、证据编号或缺失字段。
- `impact`：影响哪个判断、产物、UNIT、AC、Verification Plan、风险或交接项。
- `return_to`：回到 The Process 的哪个节点。
- `fix`：PM 直接修正动作，或需要用户/Director 裁决的一个问题。

落盘映射：

- `NEEDS_PM_FIX` 写入 `pre_review_issue_ledger.status=OPEN` 或 `PARTIAL`；修正后改为 `RESOLVED`。
- `NEEDS_USER_DECISION` 或 `NEEDS_DIRECTOR` 写入 `pre_review_issue_ledger.status=BLOCKED`，`owner` 写用户或 Director。
- Review digest 之后仍需承接的问题，写入 `issue_ledger` 的合法状态：`ACCEPTED`、`ACCEPTED_RISK`、`DEFERRED`、`RESOLVED`、`WAIVED` 或 `CLOSED`。

## 回流

- Director baseline、Phase 出口、范围、非目标或可行性漂移，回 Handoff gate。
- 证据缺口阻断产品判断，回 Evidence and AS-IS。
- 目标路径、业务对象、状态、权限或规则不闭合，回 TO-BE product model。
- 能力、入口场景、业务语义或风险不能支撑 UNIT，回 Feature inventory and risk。
- UNIT 边界、优先级、依赖或 Integration Context 矛盾，回 UNIT split。
- 跨 UNIT 术语、状态、规则、排除项、依赖或 Integration Context 不一致，回对应 The Process 节点修正；仍需承接时写入既有 issue/review 字段。
- AC 不可观察或缺边界/失败覆盖，回 AC。
- Verification Plan 不能证明业务结果，回 Verification Plan。
- Design handoff 混入 PM 可直接判断的问题，回 Design handoff。
- 全部通过后进入 Review digest；未通过不送审。
