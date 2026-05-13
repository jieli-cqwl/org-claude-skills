## Response

理解一致：你要做 `discovery` 调研，目标是解析 community 中的 `agent-browser` 到底对应哪个实体，并提供可审计的排除证明。呈现模式按 `audit` 处理，因为你明确要求“排除证明”。

我会按以下范围执行，而不是直接下结论：

- 名称归一化：`agent-browser` / `agent browser` / `agentbrowser` / 可能 owner 前缀
- 对象类型覆盖：skill / MCP / plugin / package / repo / 目录项
- 证据要求：每个候选必须有来源、对象类型、owner/路径、安装或引用入口、排除理由
- 输出目标：命中对象 + 候选排除表 + 搜索覆盖证明 + 剩余盲区
- 完成门槛：落盘 `docs/{feature}/research-report.md`，并经你确认后才算完成

当前根据 skill 的硬门槛，不能在未完成检索覆盖、候选排除表和报告落盘前宣称 `agent-browser` 指向哪个对象。

## Self Check

- route: `/research`
- mode: `discovery`
- presentation_profile: `audit`
- artifacts_required: `docs/{feature}/research-report.md` 必须落盘；需包含名称归一化、对象类型覆盖、候选排除表、检索路径与覆盖证明、独立挑战记录，并等待用户确认后才能声明完成。