# Design 测试审查 Prompt

## 目标

独立审查 design owner 已自检并确认可送审的设计产物（self-checked design artifact / canonical-shaped design artifact）是否可测试、可观测、可回归验证。

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
| DT-1 | 可测试性设计 | 模块间依赖是否可隔离测试？异步流程是否有可断言的完成信号？关键逻辑输入输出是否可观察？ | 只评设计结构是否支持测试，不写测试用例 |
| DT-2 | 接口契约可验证性 | 接口校验规则是否精确到可驱动自动化测试？错误码是否覆盖 PRD 异常场景？边界行为是否定义？关键决策是否可追溯到 `key_decisions`、同组 `option_analysis` 与 `input_analysis`？每个边界行为必须能转成断言，并通过 `verification_ref` 回到 `verification_mapping[].evidence_ref`；引用悬空或无法消费时 FAIL。若 `interface_boundary`、`key_decisions` 或 `quality_attributes` 仍存在草稿或未冻结版本，直接 FAIL。 | 只评接口精确度与可验证性，不评接口架构合理性（DR-3 负责） |
| DT-3 | 可观测性覆盖 | 关键链路是否有 tracing 设计？质量目标是否有对应 metrics？异常场景是否有日志、告警或排障证据路径？ | 只评覆盖度，不评具体监控工具选型 |
| DT-4 | 回归影响可控性 | 变更范围是否明确？向后兼容策略是否清晰？灰度机制是否支持分阶段验证？缺少可生成下游测试义务或回归边界的字段时，阻断交接。 | 只评回归可控性，不评迁移技术完整性（DR-4 负责） |

## 审查报告格式

```
## 测试审查报告

Verdict: PASS | WARN | FAIL
Reviewed Design Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题，必须给出 DTR-001 风格的稳定 issue id 和承接目标
- `FAIL`: 阻塞问题，必须给出稳定 issue id、证据和阻塞原因；详细修复要求写入「关键问题（FAIL 项详述）」

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
