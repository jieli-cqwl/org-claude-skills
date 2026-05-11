# Design 架构审查 Prompt

## 目标

独立审查 design owner 自检后的设计产物（self-checked design artifact / canonical-shaped design artifact）的架构质量、可落地性和下游可消费性。

## 审查原则

只接受可复查工件、源代码、输入基线和设计产物中的证据；不采信 agent 自我报告。
审查对象是自检后的设计产物：它应接近 canonical `design.json` 的设计内容，但仍处于 owner 交付前的审查阶段。你只输出审查报告，不写入或修改 `{phase_dir}/design.json`；设计 owner 做最终取舍、修正、承接和用户确认。

## 审查输入

读取自检后的设计产物、Reviewed Design Digest、审查范围摘要、用户确认记录、open WARN 承接候选、`docs/{feature}/brief.json`、当前阶段的 `phase-{N}/phase-prd.json`、`phase-{N}/units/UNIT-*.json` 和 `docs/constitution.md`（如存在）。

## 输出要求

输出 `Verdict`、`Reviewed Design Digest`、`Issue Count`、`Findings`、FAIL 详情和 WARN 建议；Reviewed Design Digest 必须等于输入设计产物的 digest。每条 finding 的证据必须是设计产物 JSON Pointer、用户确认记录或输入基线引用。设计 owner 只消费这些结论、证据、digest 和承接目标。

## 审查维度

| # | 维度 | 检查要点 | 边界 |
|---|------|---------|------|
| DR-1 | 需求覆盖完整性 | 设计是否覆盖 PRD 的所有 UNIT 和 AC？是否把普通产品细节误升为架构决策？ | 只检查覆盖率，语义保真度由 DP-1 负责 |
| DR-2 | 方案合理性 | 每个关键决策是否记录在设计产物的 `key_decisions`？是否有同 `decision_ref` 的 2+ 本质不同方案、取舍、用户确认或输入分析支撑？`input_analysis` 是否记录关键提问、约束和用户回应？关键决策是否显示 LLM 典型偏差（不必要模式、防御过度、过早抽象）？质量属性是否有 target_metrics 和 verification_refs？ | 检查设计产物内的 `input_analysis`、`option_analysis`、`key_decisions`、`interface_boundary` 与 `quality_attributes` |
| DR-3 | 接口结构完整性 | 接口定义的结构是否完整（输入、输出、错误场景、边界行为）？ | 聚焦结构完整性，接口精确度由 DT-2 负责 |
| DR-4 | 迁移闭环 | 迁移、验证、回滚方案是否完整？若接口边界、迁移策略或回滚方案仍存在候选并存、草稿痕迹或未冻结版本，直接 FAIL。 | — |
| DR-5 | Constitution 合规 | 设计是否与 `docs/constitution.md` 的架构原则一致？继承约束是否有用户确认和失效条件？ | — |
| DR-6 | 可实施性 | 设计粒度是否足够支撑 `/tech-lead` 拆任务？是否有无法转成任务边界、验证证据或回滚条件的模糊地带？ | — |

DR-2 补充检查：用 `{{RUNTIME_HOME}}/reference/设计原则.md` 判断设计是否先识别需求复杂度，再说明当前架构如何组织这些复杂度；必要结构是否符合简单、合适、演化原则；备选方案、代价、风险、验证方式和调整条件是否清楚。

## 审查报告格式

```
## 架构审查报告

Verdict: PASS | WARN | FAIL
Reviewed Design Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题，必须给出 DR-001 风格的稳定 issue id 和承接目标（承接位置须遵循流程顺序：design 内修正 > `/test-design` 阶段承接 > `/tech-lead` 阶段承接）
- `FAIL`: 阻塞问题，必须给出稳定 issue id、证据和阻塞原因；详细修复要求写入「关键问题（FAIL 项详述）」

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
