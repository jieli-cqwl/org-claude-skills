# Design 产品审查 Prompt

## 目标

独立审查 design owner 已自检并确认可送审的设计产物（self-checked design artifact / canonical-shaped design artifact）是否保持产品意图、业务边界和用户可感知行为一致。

## 审查原则

只接受可复查输入基线和设计产物中的证据；不采信 agent 自我报告。
审查对象是 owner 已自检并确认可送审的设计产物：它就是准备写入 `design.json` 的设计内容。S11 只追加 `review_closure`、`final_confirmation` 和验证收口，不重新解释该设计内容。你只输出审查报告，不写入或修改 `{phase_dir}/design.json`；设计 owner 做最终取舍、修正、承接和用户确认。

## 审查输入

读取 owner 已自检并确认可送审的设计产物、Reviewed Design Digest、审查范围摘要、用户确认记录、open WARN 承接候选、`docs/{feature}/brief.json`、当前阶段的 `phase-{N}/phase-prd.json` 和 `phase-{N}/units/UNIT-*.json`。

## 输出要求

输出 `Verdict`、`Reviewed Design Digest`、`Issue Count`、`Findings`、FAIL 详情和 WARN 建议；Reviewed Design Digest 必须等于输入设计产物的 digest。每条 finding 的证据必须是设计产物 JSON Pointer、用户确认记录或输入基线引用。设计 owner 只消费这些结论、证据、digest 和承接目标。

## 审查维度

| # | 维度 | 检查要点 | 边界 |
|---|------|---------|------|
| DP-1 | 需求意图保真度 | 设计方案是否准确承接 PRD 业务意图？技术转译中有无语义偏移？设计是否隐式改变业务规则或流程？关键语义假设是否能从 `input_analysis`、`option_analysis` 与 `key_decisions` 追溯？业务语义证据必须能回指输入基线、用户确认、`input_analysis`、`option_analysis` 或 `key_decisions`；不能用 agent 自我报告替代。 | 只评意图保真，不评技术合理性（DR-2 负责） |
| DP-2 | 用户体验影响 | 异步化、最终一致性、降级、迁移过渡是否改变用户可感知行为？这些变化是否有产品确认或清晰承接？ | 只评用户可感知影响，不评迁移技术完整性（DR-4 负责） |
| DP-3 | 业务边界一致性 | 模块/服务边界是否与业务领域自然边界对齐？PRD 待设计决策是否全部有回应？若 `key_decisions`、`modules` 或 `interface_boundary` 仍保留多个最终结论、草稿结论或未冻结版本，直接 FAIL。如 `/test-design` 或 `/tech-lead` 无法消费该边界，至少 WARN；涉及业务语义漂移时 FAIL。 | 只评业务语义边界，不评技术拆分合理性（DR-2 负责） |
| DP-4 | 口径一致性 | 跨字段出现的同一度量、阈值或术语是否口径一致？例如 SLO 阈值与 `rollback_plan` 触发阈值是否对齐、P99/P95 描述是否在 `quality_attributes` 和 `verification_mapping` 里统一、审计事件定义是否在 `cross_cutting_concerns` 和 `verification_mapping` 里一致。不一致直接 WARN 以上并给出跨字段证据。 | 只评已出现字段的口径对齐，不评度量值本身是否合理（DR-2/DR-4 负责） |

## 审查报告格式

```
## 产品审查报告

Verdict: PASS | WARN | FAIL
Reviewed Design Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题，必须给出 DPR-001 风格的稳定 issue id 和承接目标
- `FAIL`: 阻塞问题，必须给出稳定 issue id、证据和阻塞原因；详细修复要求写入「关键问题（FAIL 项详述）」

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
