# 评审编排

PM owner 自检通过且 Review digest 当前有效后读取本文。本文只组织评审循环，不补写 PRD 内容。

## 输入

Manager 阶段评审闭环只写入 `brief.json.review_conclusion / issue_ledger`、`phase-prd.json.review_conclusion / issue_ledger` 和被问题要求修正的 PM-owned JSON 字段。

Reviewer 只读取 digest 绑定的送审包：

- `brief.json`
- `phase-{N}/phase-prd.json`
- `phase-{N}/units/UNIT-*.json`
- `reviewed_bundle_digest`

聊天记录、临时草稿、legacy markdown 和 projection-only 文本只作背景。人类投影视图只渲染 canonical JSON 字段，不能作为下游控制输入。

## 执行

- 确认 `reviewed_artifact_refs` 和 `reviewed_bundle_digest` 来自当前送审包。
- 召集 agent teams，让三视角 reviewer 审同一份 `reviewed_bundle_digest`。
- 派发 reviewer prompt；禁止 reviewer 改写 PM JSON 或补造业务事实。
- 每个 reviewer verdict 必须回写 issue id、severity、finding、evidence path + value、carryover target 和同一个 `reviewed_bundle_digest`。
- PM owner 将评审状态写入 `review_conclusion.agent_team_review`：`reviewed_artifact_refs`、`reviewed_bundle_digest`、reviewer verdicts、finding refs、evidence refs、read-only marker 和 `convergence_evidence`。

## 判断

三视角 reviewer 必须判断：

- PRD 是否回答 Director baseline，且没有漂移。
- `/design` 是否能理解行为、约束、状态、风险和待决事项。
- `/test-design` 是否能验证 AC、失败路径、边界和风险。
- 下游是否无需补造业务事实就能行动。

## Review Team

- Product：`references/prd-reviewer-prompt.md`，用于确认 PRD 是否完整回答用户问题。
- Architecture：`references/architect-reviewer-prompt.md`，用于确认需求在当前技术上下文中可落地。
- Test：`references/tester-reviewer-prompt.md`，用于确认 AC 能被真实验证。

## Loop

- 执行 `3 视角×max10轮`。
- 任一视角 FAIL：修 PM-owned JSON，回到 Review digest 刷新 digest，只对 FAIL 视角重新提交评审。
- 首轮全 PASS：写 `convergence_evidence[].control_action=CONFIRMATION`，再跑一轮确认。
- WARN 写入 `issue_ledger`，带 owner、evidence、handoff target 和承接状态。
- 连续 2 轮 FAIL 数不减少：ASK_USER。
- 同一 issue 连续 3 轮未关闭：BLOCKED。
- 第 10 轮仍未关闭：BLOCKED。

停止条件：无 open FAIL；WARN 均有 owner、handoff target 和承接状态；`reviewed_bundle_digest` 与最终送审包一致。

## High-Risk Signals

同一评审循环内检查上线、失败重试、回滚、批量重放、外部依赖、幂等、重复提交、权限升级和不可逆状态变化。

高风险发现必须写回 AC、Verification Plan、`issue_ledger`、阻断项或下游 owner。
