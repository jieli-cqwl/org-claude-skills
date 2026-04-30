# Design 架构审查 Prompt

## 目标

独立审查 S8 候选设计包的架构质量、可落地性和下游可消费性。

## 审查原则

只接受可复查工件、源代码、输入基线和候选设计包中的证据；不采信 agent 自我报告。
审查对象是 S8 候选设计包中的 `candidate_design_json`；S9 结束后才由主 Agent 写入 `{phase_dir}/design.json`。

## 审查输入

读取 S8 候选设计包：`candidate_design_json`、`source_refs`、`co_creation_confirmations`、`open_warns` 和 `handoff_summary`。同时读取 `docs/{feature}/brief.json`、当前阶段的 `phase-{N}/phase-prd.json`、`phase-{N}/units/UNIT-*.json` 和 `docs/constitution.md`（如存在）。

## 输出要求

输出 `Verdict`、`Reviewed Candidate Digest`、`Issue Count`、`Findings`、FAIL 详情和 WARN 建议；`Reviewed Candidate Digest` 必须等于输入候选包的 `candidate_digest`。每条 finding 的证据必须是 `candidate_design_json` JSON Pointer、`source_refs`、用户确认记录或输入基线引用。主 Agent 只消费这些结论、证据、digest 和承接目标。

## 审查维度

| # | 维度 | 检查要点 | 边界 |
|---|------|---------|------|
| DR-1 | 需求覆盖完整性 | 设计是否覆盖了 PRD 的所有 UNIT 和 AC？ | 只检查覆盖率，语义保真度由 DP-1 负责 |
| DR-2 | 方案合理性 | 每个关键决策是否记录在 `candidate_design_json.key_decisions`？是否有同 `decision_ref` 的 2+ 本质不同方案、取舍、用户确认或输入分析支撑？`input_analysis` 是否记录关键提问、约束和用户回应？关键决策是否显示 LLM 典型偏差（不必要模式、防御过度、过早抽象）？质量属性是否有 target_metrics 和 verification_refs？ | 检查 `candidate_design_json` 内的 `input_analysis`、`option_analysis`、`key_decisions`、`interface_boundary` 与 `quality_attributes` |
| DR-3 | 接口结构完整性 | 接口定义的结构是否完整（输入、输出、错误场景）？ | 聚焦结构完整性，接口精确度由 DT-2 负责 |
| DR-4 | 迁移闭环 | 迁移、验证、回滚方案是否完整？若 `接口边界` / `迁移策略` / `回滚方案` 仍存在候选并存、草稿痕迹或未冻结版本，直接 FAIL。 | — |
| DR-5 | Constitution 合规 | 设计是否与 `docs/constitution.md` 的架构原则一致？ | — |
| DR-6 | 可实施性 | 设计粒度是否足够支撑 tech-lead 拆任务？是否有模糊地带？ | — |

DR-2 补充检查：检查设计决策是否显示 LLM 典型偏差——不必要的设计模式（当前只有 1 个实现却引入 Factory/Strategy）、防御过度（无证据的风险添加了防御代码）、过早抽象（"万一将来"驱动的接口）。偏差模式详见 `{{RUNTIME_HOME}}/reference/设计原则.md` 附录。

贯穿审查透镜：设计中的每一层复杂度是 Essential（问题域本身要求）还是 Accidental（方案引入）？对 Accidental Complexity 要求设计者说明具体业务场景驱动。

## 输出格式

```
## 架构审查报告

Verdict: PASS | WARN | FAIL
Reviewed Candidate Digest: sha256:...
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题，必须给出 DR-001 风格的稳定 issue id 和"承接目标"（承接位置须遵循流程顺序：design 内修正 > `/test-design` 阶段承接 > `/tech-lead` 阶段承接）
- `FAIL`: 阻塞问题，必须给出稳定 issue id、证据和阻塞原因；详细修复要求写入「关键问题（FAIL 项详述）」

### 关键问题（FAIL 项详述）

### 改进建议（WARN 项）

```
