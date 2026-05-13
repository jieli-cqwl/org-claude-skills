## Response

我理解你的目标是：做一次 `research` 的 `discovery` 调研，搞清楚 community 里提到的 `agent-browser` 实际指向哪个对象，并给出可审计的排除证明。

默认范围确认如下：

- 调研对象：`agent-browser`
- 关注维度：名称归一化、对象类型覆盖、候选命中、候选排除证明、剩余盲区
- 调研模式：`discovery`
- 呈现模式：`audit`
- 证据要求：必须覆盖 `agent browser` / `agent-browser` / `agentbrowser` / owner 变体，以及 repo / skill / MCP / plugin / package / 目录对象类型
- 产物门槛：正式完成前需要落盘 `docs/{feature}/research-report.md`，且用户确认；当前不能直接声称已完成调研

下一步应进入候选收敛：先做名称归一化和对象类型覆盖表，再给候选表、排除表和盲区说明。当前 isolated evaluation 禁止读取本地文件和联网，所以我不能编造 community 命中或排除证明。

## Self Check
- route: research
- mode: discovery
- presentation_profile: audit
- artifacts_required: `docs/{feature}/research-report.md`；但需完成证据收集、独立挑战并经用户确认后才可声明正式完成