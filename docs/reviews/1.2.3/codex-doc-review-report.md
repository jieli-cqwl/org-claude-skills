# Codex Doc Review Report

- 审查文件 (file): `shared/skills/research/SKILL.md` + `shared/skills/research/references/analysis-frameworks.md` + `shared/skills/research/references/deep-analysis-template.md` + `shared/skills/research/references/templates/research-shared-header-template.md` + `shared/skills/research/references/templates/research-tech-selection-template.md` + `shared/skills/research/references/templates/research-analysis-template.md`
- 审查阶段 (stage): `research-cross-review`
- 审查时间 (timestamp): `2026-03-28`
- 状态码: `REVIEW_ISSUE`

---

## Findings

| severity | location | description | recommendation |
|----------|----------|-------------|----------------|
| CRITICAL | `shared/skills/research/SKILL.md:17-19,80-82`; `shared/skills/research/references/deep-analysis-template.md:15-40` | “每个关键判断都要写最强支持/最强反方/失效边界/待验证项”把分析门槛抬得很高，但文档没有定义“关键判断”“最强”或充分证据阈值。执行者只能机械填槽，评审者也只能检查字段存在，难判断分析质量是否真的提升。 | 只对最终推荐和 1-3 个核心分歧点强制此结构，并补充可判定阈值与示例。 |
| WARNING | `shared/skills/research/SKILL.md:55-61`; `shared/skills/research/references/templates/research-shared-header-template.md:3-28`; `shared/skills/research/references/templates/research-tech-selection-template.md:16-30`; `shared/skills/research/references/templates/research-analysis-template.md:9-35` | 模板叠层明显：首屏判断、挑战表、优缺点表、采纳速览、逐项深析、矩阵、行动项同时要求，容易把 `/research` 从“研究流程”推成“报告模板填空”，形成静态规范堆砌。 | 压缩首屏到结论/最大风险/下一步三项，其余按 mode 按需展开。 |
| CRITICAL | `shared/skills/research/references/analysis-frameworks.md:53-79`; `shared/skills/research/SKILL.md:45-47,54-56`; `shared/skills/research/references/templates/research-project-analysis-template.md:1-40`; `shared/skills/research/references/templates/research-domain-template.md:1-31` | 新框架把 project analysis 与 domain research 折叠为 `analysis`，但仓库里旧模板仍保留且主 skill 不再引用，形成“新二分框架 + 旧两类模板”并存。表面上更简单，实际执行路径更含糊。 | 明确 `analysis` 子型映射并同步清理/归档旧模板，否则审稿与产出会持续漂移。 |
| CRITICAL | `shared/skills/research/SKILL.md:51-57`; `shared/skills/research/references/templates/research-analysis-template.md:1-35`; `shared/skills/research/references/templates/research-shared-header-template.md:24-28` | 当前契约没有“原始 query / 改写后 query / 改写理由 / 等价性确认”字段。若后续引入 query rewrite，报告只保留处理后的对象与结论，用户原始评审意图会在 rewrite 与 research 之间断链，责任难以回溯。 | 若引入 rewrite，强制记录 original query、rewritten query、rewrite rationale、user-confirmed equivalence；否则禁止 silent rewrite。 |
| WARNING | `shared/skills/research/references/analysis-frameworks.md:13-16`; `shared/skills/research/references/deep-analysis-template.md:15-18`; `shared/skills/research/references/templates/research-tech-selection-template.md:32-33` | 文档新增证据等级与时间标记，但没有要求“关键判断 -> 证据编号”的细粒度绑定。结果是报告外观更严谨，证据回查却仍然偏人工、偏主观。 | 在表格和结论段强制引用 evidence IDs，并让证据索引回链到具体段落/表格。 |
| WARNING | `shared/skills/research/references/templates/research-shared-header-template.md:3-10,24-28` | “一页判断”把当前结论、采纳动作和翻转条件都放到首屏，适合决策压缩，不适合高不确定性探索。对证据仍薄的 early-stage research，会诱导模型过早收敛。 | 将强结论限制在证据达到阈值的场景；默认输出“待验证/条件判断”。 |

## DECEPTION

| severity | location | description | evidence |
|----------|----------|-------------|----------|
| WARNING | `shared/skills/research/SKILL.md:17-19,78-82`; `shared/skills/research/references/deep-analysis-template.md:15-40`; `shared/skills/research/references/templates/research-shared-header-template.md:3-28` | 存在“rigor theater”风险：新增了证据等级、最强反方、稳健性、翻转条件等严谨外观字段，但没有相应的引用粒度、判定阈值和 provenance 机制，容易看起来更强，实际上更难执行、更难验收。 | 关键要求已扩张为多字段硬约束，但 diff 中未引入对应的 traceability / provenance 机制。 |

> 本轮未发现明确恶意误导；DECEPTION 主要表现为“严谨感外观强于可验证性”的结构性风险。

## Dimensions

| dimension | verdict | evidence |
|-----------|---------|----------|
| 执行可行性 | FAIL | `shared/skills/research/SKILL.md:17-19,51-57,80-82` 将高强度论证要求扩展到“每个关键判断”，但缺少可判定阈值。 |
| 可验证性 | FAIL | `shared/skills/research/references/analysis-frameworks.md:13-16`; `shared/skills/research/references/deep-analysis-template.md:15-18`; `shared/skills/research/references/templates/research-tech-selection-template.md:32-33` 只有证据分级与索引，没有判断到证据的强绑定。 |
| Prompt 负载控制 | WARN | `shared/skills/research/references/templates/research-shared-header-template.md:3-28`; `shared/skills/research/references/templates/research-tech-selection-template.md:1-30`; `shared/skills/research/references/templates/research-analysis-template.md:1-35` 模板层次增多，易先写格式后补研究。 |
| 模式清晰度 | WARN | `shared/skills/research/references/analysis-frameworks.md:18-79` 与仍保留的 `shared/skills/research/references/templates/research-project-analysis-template.md:1-40`、`shared/skills/research/references/templates/research-domain-template.md:1-31` 存在并存语义。 |
| 责任链完整性 | FAIL | `shared/skills/research/SKILL.md:51-57`; `shared/skills/research/references/templates/research-analysis-template.md:1-4` 未定义 query rewrite provenance。 |
| 反权威与诚实性 | PASS | `shared/skills/research/SKILL.md:17-19,29-30`; `shared/skills/research/references/analysis-frameworks.md:13-16` 明确禁止权威替代论证、要求时间标记与局限性。 |

## Summary

- total_findings: 6
- deception_count: 1
- status: REVIEW_ISSUE

---

## 处理建议

1. 先缩 scope：把“最强支持/反方/失效边界/待验证”只强制到最终推荐和 1-3 个核心争议点。
2. 给“关键判断”“最强证据”“稳健性高/中/低”补可判定标准和示例。
3. 统一 mode：若保留 `analysis` 二分，需归档或重写 `research-project-analysis-template.md` 与 `research-domain-template.md`，避免双轨漂移。
4. 若要试 query rewrite，先加 provenance 契约，再做 rewrite；不要先上线 rewrite 再补审计字段。
5. 把 evidence ID 回链到结论和表格，否则当前增强更像“合规外观升级”，不是“审计能力升级”。

## 保留意见

1. `shared/skills/research/SKILL.md:19,29-30` 的“反权威直通结论”约束是正确增量，值得保留。
2. `shared/skills/research/references/analysis-frameworks.md:5-16` 的证据分级 + 时间标记值得保留，但要补证据回链。
3. `shared/skills/research/references/templates/research-shared-header-template.md:3-10` 的一页判断对决策者有价值，但应作为证据收敛后的摘要，不应反向驱动研究过程。
