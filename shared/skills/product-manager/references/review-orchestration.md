# 评审编排

PM owner 自检通过后读取本文。Digest 用来证明 reviewer 审的是同一份包；评审目标是产品质量。

## 输入

Manager 阶段评审闭环写入 `brief.json.review_conclusion / issue_ledger` 和最终 JSON 字段。Reviewer 输入限定为：

- `brief.json`
- `phase-{N}/phase-prd.json`
- `phase-{N}/units/UNIT-*.json`
- `reviewed_bundle_digest`

聊天记录、临时草稿、legacy markdown 和 projection-only 文本作为背景。

评审状态必须写入 `review_conclusion.agent_team_review`：记录 `reviewed_artifact_refs`、`reviewed_bundle_digest`、三视角 verdict、finding/evidence refs、read_only 和 `convergence_evidence`。

## 判断

三视角 reviewer 先回答这些问题：

- PRD 是否回答 Director baseline，且没有漂移。
- `/design` 是否能理解行为、约束、状态、风险和待决事项。
- `/test-design` 是否能验证 AC、失败路径、边界和风险。
- 下游是否无需补造业务事实就能行动。

## Review Team

召集 agent teams，三视角 reviewer 审同一份 digest：

- Product：`references/prd-reviewer-prompt.md`，用于确认 PRD 是否完整回答用户问题。
- Architecture：`references/architect-reviewer-prompt.md`，用于确认需求在当前技术上下文中可落地。
- Test：`references/tester-reviewer-prompt.md`，用于确认 AC 能被真实验证。

三视角 reviewer 审同一份 `reviewed_bundle_digest`；每个 reviewer verdict 必须回写 issue id、severity、evidence path、carryover target 和同一个 `reviewed_bundle_digest`。

PM owner 将评审状态写入 `review_conclusion.agent_team_review`：`reviewed_artifact_refs`、`reviewed_bundle_digest`、reviewer verdicts、finding refs、evidence refs、read-only marker 和 `convergence_evidence`。

## Loop

- 执行 `3 视角×max10轮`。
- 任一视角 FAIL：修 PM-owned JSON，重新提交 FAIL 视角评审。
- 首轮全 PASS：写 `convergence_evidence[].control_action=CONFIRMATION`，再跑一轮确认。
- WARN 写入 `issue_ledger`，带 owner 和 handoff target。
- 连续 2 轮 FAIL 数不减少：ASK_USER。
- 同一 issue 连续 3 轮未关闭：BLOCKED。
- 第 10 轮仍未关闭：BLOCKED。

下游控制输入以 canonical JSON 为准；人类投影视图只渲染这些字段。

## High-Risk Signals

同一评审循环内检查上线、失败重试、回滚、批量重放、外部依赖、幂等、重复提交、权限升级和不可逆状态变化。

高风险发现必须写回 AC、Verification Plan、`issue_ledger`、阻断项或下游 owner。
