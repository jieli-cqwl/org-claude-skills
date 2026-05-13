## Response

我理解你要做的是：从 GitHub repo 里筛出几个“适合采用”的候选，并给每个候选标注 `discard / watch / trial / adopt` 动作状态。

但按该 skill 的硬门槛，现在不能直接给 repo 结论。缺少调研范围和评估维度，进入深度分析会变成拍脑袋。

请确认这 3 点后我再推进：

1. 你要找哪一类 repo？
   例如：Claude/Codex skills、MCP server、agent framework、RAG、browser automation、prompt eval、代码审查工具等。

2. 采用场景是什么？
   例如：个人本地使用、团队生产集成、企业内网部署、插件市场收录、二次开发基座。

3. 最关键的评估维度选 2-4 个：
   默认我会按：维护活跃度、项目适配度、架构/代码质量、文档与安装成本、许可证风险、社区/生产使用证据。

默认路由：`selection + decision`。确认后会先收敛 TOP 3 repo，再给每个 repo 的 `discard / watch / trial / adopt` 动作、证据、反方挑战和失效条件。最终按 skill 要求需要落盘为 `docs/{feature}/research-report.md` 并经你确认后才算完成。

## Self Check
- route: 需要范围确认，不能直接深度调研或给 repo 结论
- mode: selection
- presentation_profile: decision
- artifacts_required: `docs/{feature}/research-report.md` 最终必需；当前阶段尚不能产出工件