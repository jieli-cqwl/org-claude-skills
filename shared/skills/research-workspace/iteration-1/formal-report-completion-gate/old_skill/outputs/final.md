## Response

不能直接产出 `research-report.md`。按该 skill 的 HARD-GATE：**未确认调研对象、范围和关注维度前，禁止进入深度分析、禁止写正式报告、禁止声称完成研究**。

我理解你要的是：给团队复审留档的正式调研报告，且必须包含：

- `docs/{feature}/research-report.md`
- 独立挑战记录
- 检索路径与覆盖证明
- 可审计证据链

当前缺失最小必需信息，请确认：

1. **调研对象 / 待决策问题是什么？**  
   例如：某个技术方案选型、某篇文章论点审计、某个 community skill/plugin/package/repo 的实体定位。

2. **复审重点维度是哪 2-4 个？**  
   例如：正确性、适配当前项目、维护成本、风险边界、社区真实性、替代方案、证据覆盖。

3. **报告落盘目录的 `{feature}` 名称是什么？**  
   例如：`docs/skill-discovery/research-report.md`。

默认路由判断：这是 `audit` 呈现模式，因为你明确要求“团队复审留档”“独立挑战记录”“覆盖证明”。调研模式还不能确定，取决于对象类型：选型是 `selection`，论点深拆是 `analysis`，community 对象定位是 `discovery`。

## Self Check
- route: 范围确认；不得进入 Step 3+，不得生成正式报告
- mode: 待确认；可能是 `selection` / `analysis` / `discovery`
- presentation_profile: `audit`
- artifacts_required: `docs/{feature}/research-report.md`，独立挑战记录，检索路径与覆盖证明，候选排除表，证据源与时间标记