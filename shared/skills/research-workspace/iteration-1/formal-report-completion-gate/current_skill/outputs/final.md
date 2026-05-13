## Response

我理解你要的是正式 `research-report.md`，用于团队复审留档，并且必须包含“独立挑战记录”和“覆盖证明”。但当前缺少调研对象与评估维度，按 skill 的 HARD-GATE，不能进入深度分析，也不能编造报告。

请先确认 3 点：

1. 调研对象是什么？例如某个技术方案、package、MCP、plugin、仓库、架构路线。
2. 重点关注哪 2-4 个维度？例如可维护性、成熟度、性能、生态、接入成本、风险、替代方案。
3. 报告落盘 feature 目录名是什么？用于 `docs/{feature}/research-report.md`。

默认判断：这是正式 `research`，不是 `deep-research`，因为你要求的是 `research-report.md` 与审计记录，没有明确要求 Deep Research / 横纵分析 / PDF 报告。

## Self Check
- route: `research`，等待范围确认；不路由 `deep-research`
- mode: 待确认，倾向 `selection` 或 `discovery`，取决于调研对象
- presentation_profile: `audit`，因为要求团队复审留档、独立挑战记录、覆盖证明
- artifacts_required: `docs/{feature}/research-report.md`，确认范围后才能产出