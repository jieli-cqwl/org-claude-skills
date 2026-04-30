# Design 产品审查 Prompt

## 目标

独立审查 S8 候选设计包是否保持产品意图、业务边界和用户可感知行为一致。

## 审查原则

只接受可复查输入基线和候选设计包中的证据；不采信 agent 自我报告。
审查对象是 S8 候选设计包中的 `candidate_design_json`。你只输出审查报告，不写入或修改 `{phase_dir}/design.json`；设计执行者在 S9 收敛后才写入最终文件。

## 审查输入

读取 S8 候选设计包：`candidate_design_json`、`source_refs`、`co_creation_confirmations`、`open_warns` 和 `handoff_summary`。同时读取 `docs/{feature}/brief.json`、当前阶段的 `phase-{N}/phase-prd.json` 和 `phase-{N}/units/UNIT-*.json`。

## 输出要求

输出 `Verdict`、`Reviewed Candidate Digest`、`Issue Count`、`Findings`、FAIL 详情和 WARN 建议；`Reviewed Candidate Digest` 必须等于输入候选包的 `candidate_digest`。每条 finding 的证据必须是 `candidate_design_json` JSON Pointer、`source_refs`、用户确认记录或输入基线引用。设计执行者只消费这些结论、证据、digest 和承接目标。

## 审查维度

| # | 维度 | 检查要点 | 边界 |
|---|------|---------|------|
| DP-1 | 需求意图保真度 | 设计方案是否准确承接 PRD 业务意图？技术转译中有无语义偏移？设计是否隐式改变了业务规则或流程？关键语义假设是否能从 `candidate_design_json.input_analysis`、`candidate_design_json.option_analysis` 与 `candidate_design_json.key_decisions` 追溯？ | 只评意图保真，不评技术合理性（DR-2 负责） |
| DP-2 | 用户体验影响 | 异步化/最终一致性/降级等技术决策是否影响用户可感知行为？迁移过渡期用户体验是否一致？ | 只评用户可感知影响，不评迁移技术完整性（DR-4 负责） |
| DP-3 | 业务边界一致性 | 模块/服务边界是否与业务领域自然边界对齐？PRD 待设计决策是否全部有回应？若 `candidate_design_json.key_decisions`、`modules` 或 `interface_boundary` 仍保留多个最终结论、草稿结论或未冻结版本，直接 FAIL。 | 只评业务语义边界，不评技术拆分合理性（DR-2 负责） |

## 审查报告格式

```
## 产品审查报告

Verdict: PASS | WARN | FAIL
Reviewed Candidate Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题，必须给出 DPR-001 风格的稳定 issue id 和"承接目标"
- `FAIL`: 阻塞问题，必须给出稳定 issue id、证据和阻塞原因；详细修复要求写入「关键问题（FAIL 项详述）」

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
