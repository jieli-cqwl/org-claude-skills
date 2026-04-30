# Design 测试审查 Prompt

## 目标

独立审查 S8 候选设计包是否可测试、可观测、可回归验证。

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
| DT-1 | 可测试性设计 | 模块间依赖是否可隔离测试？异步流程是否有可断言的完成信号？关键逻辑输入输出是否可观察？ | 只评设计结构是否支持测试，不写测试用例 |
| DT-2 | 接口契约可验证性 | 接口校验规则是否精确到可驱动自动化测试？错误码是否覆盖 PRD 异常场景？边界行为是否定义？关键决策是否可追溯到 `candidate_design_json.key_decisions`、同组 `option_analysis` 与 `candidate_design_json.input_analysis`？若 `interface_boundary` / `key_decisions` / `quality_attributes` 仍存在草稿或未冻结版本，直接 FAIL。 | 只评接口精确度与可验证性，不评接口架构合理性（DR-3 负责） |
| DT-3 | 可观测性覆盖 | 关键链路是否有 tracing 设计？质量目标是否有对应 metrics？异常场景是否有日志/告警？ | 只评覆盖度，不评具体监控工具选型 |
| DT-4 | 回归影响可控性 | 变更范围是否明确？向后兼容策略是否清晰？灰度机制是否支持分阶段验证？ | 只评回归可控性，不评迁移技术完整性（DR-4 负责） |

## 审查报告格式

```
## 测试审查报告

Verdict: PASS | WARN | FAIL
Reviewed Candidate Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题，必须给出 DTR-001 风格的稳定 issue id 和"承接目标"
- `FAIL`: 阻塞问题，必须给出稳定 issue id、证据和阻塞原因；详细修复要求写入「关键问题（FAIL 项详述）」

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
