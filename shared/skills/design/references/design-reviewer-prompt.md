# Design 架构审查 Prompt

## 目标

独立审查 design owner 已自检并确认可送审的设计产物（self-checked design artifact / canonical-shaped design artifact）的架构质量、可落地性和下游可消费性。

## 审查原则

只接受可复查工件、源代码、输入基线和设计产物中的证据；不采信 agent 自我报告。
审查对象是 owner 已自检并确认可送审的设计产物：它就是准备写入 `design.json` 的设计内容。S11 只追加 `review_closure`、`final_confirmation` 和验证收口，不重新解释该设计内容。你只输出审查报告，不写入或修改 `{phase_dir}/design.json`；设计 owner 做最终取舍、修正、承接和用户确认。

## 审查输入

读取 owner 已自检并确认可送审的设计产物、Reviewed Design Digest、审查范围摘要、用户确认记录、open WARN 承接候选、`docs/{feature}/brief.json`、当前阶段的 `phase-{N}/phase-prd.json`、`phase-{N}/units/UNIT-*.json` 和 `docs/constitution.md`（如存在）。

## 输出要求

输出 `Verdict`、`Reviewed Design Digest`、`Issue Count`、`Findings`、FAIL 详情和 WARN 建议；Reviewed Design Digest 必须等于输入设计产物的 digest。每条 finding 的证据必须是设计产物 JSON Pointer、用户确认记录或输入基线引用。设计 owner 只消费这些结论、证据、digest 和承接目标。

## 审查维度

| # | 维度 | 检查要点 | 边界 |
|---|------|---------|------|
| DR-1 | 需求覆盖完整性 | 设计是否覆盖 PRD 的所有 UNIT 和 AC？是否把普通产品细节误升为架构决策？ | 只检查覆盖率，语义保真度由 DP-1 负责 |
| DR-2A | 复杂度识别 | 是否说明复杂度来自业务规则、数据状态、角色协作、运行规则、质量属性或外部约束？架构是否组织这些复杂度，而不是掩盖它们？ | 检查 `input_analysis`、`runtime_facts`、`quality_attributes` |
| DR-2B | 方案取舍质量 | 每个关键决策是否有同 `decision_ref` 的 2+ 本质不同方案？推荐方案是否说明代价、风险、失效条件和用户确认？ | 检查 `option_analysis`、`key_decisions` |
| DR-2C | 事实锚点质量 | 决策事实是否可复查？是否存在 `design.json#input_analysis` 自指、agent 自我报告或无法复验事实？ | 检查 `runtime_facts`、`fact_refs` |
| DR-2D | 过度设计 | 是否为低复杂度需求引入不必要服务拆分、事件总线、平台化、缓存或全局抽象？ | 检查 `modules`、`data_architecture`、`cross_cutting_concerns` |
| DR-2E | 质量属性落地 | 每个质量属性是否有场景、目标指标、取舍和 verification_refs？ | 检查 `quality_attributes`、`verification_mapping` |
| DR-3 | 接口结构完整性 | 接口定义的结构是否完整（输入、输出、错误场景、边界行为）？ | 聚焦结构完整性，接口精确度由 DT-2 负责 |
| DR-4 | 迁移闭环 | 迁移、验证、回滚方案是否完整？若接口边界、迁移策略或回滚方案仍存在候选并存、草稿痕迹或未冻结版本，直接 FAIL。 | — |
| DR-5 | Constitution 合规 | 设计是否与 `docs/constitution.md` 的架构原则一致？继承约束是否有用户确认和失效条件？ | — |
| DR-6 | 可实施性 | 设计粒度是否足够支撑 `/tech-lead` 拆任务？是否有无法转成任务边界、验证证据或回滚条件的模糊地带？ | — |

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
