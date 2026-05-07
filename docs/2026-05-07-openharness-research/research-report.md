# HKUDS/OpenHarness 调研报告

抓取日期：2026-05-07

调研模式：analysis + GitHub repo radar
呈现模式：decision
操作对象：https://github.com/HKUDS/OpenHarness

## 结论

OpenHarness 是一个 Python 实现的 agent harness / 本地 coding agent runtime，不是单纯 benchmark。它把 Claude Code / Codex 类工具的关键运行时能力拆成可检查的开源组件：agent loop、工具注册、权限、hooks、skills、plugins、MCP、subagent/swarm、任务、TUI、provider profile，以及建立在其上的 ohmo 个人代理。

对当前 `org-claude-skills` 项目，建议动作是 `deep-read + trial`，不是 `adopt`。它最值得研究的是运行时工程实现和安全边界，而不是直接迁移我们的 skill / rules / small-chain 体系。

决定性理由：

- 目标相近：当前项目维护 Claude Code 与 Codex 的 skills/rules/reference/hooks/agents，并以 small-chain/standard-chain 合同收束交付流程；OpenHarness 正好在实现这些能力对应的 runtime 层。
- 机制有参考价值：它有 Pydantic tool schema、permission checker、hook lifecycle、skill/plugin loader、subprocess teammates、background tasks、provider profiles、dry-run preview 等可拆读模块。
- 成熟度仍早：仓库 2026-04-01 创建，v0.1.x 快速迭代，最新 v0.1.8 发布于 2026-05-06；热度高但工程稳定性还需要时间验证。
- 安全边界仍在快速补洞：近期合并了 remote channel allowlist 和 `/bridge` local-only 等高影响安全修复，说明维护者响应快，也说明 remote/ohmo 场景尚属高风险区域。

当前动作状态：`deep-read` 用于学习，`trial` 用于隔离试跑，`watch` 用于持续跟踪；不建议进入 `adopt` 或把它加入本项目运行依赖。

## 它是干什么的

OpenHarness 解决的问题是：把“模型 + 工具 + 上下文 + 权限 + 记忆 + 多 agent 协作 + UI/通道”包装成一个可运行、可扩展、可观察的本地 agent runtime。

核心模块画像：

| 模块 | 证据 | 对应能力 |
| --- | --- | --- |
| `src/openharness/engine` | `QueryEngine` 持有消息、system prompt、tool registry、permission checker、hook executor，并调用 `run_query` 执行 tool-aware loop | agent loop 与会话状态 |
| `src/openharness/tools` | `BaseTool` 暴露 Pydantic `input_model` 和 `to_api_schema()` | 类型化工具协议 |
| `src/openharness/permissions` | `PermissionChecker` 支持敏感路径硬拒绝、工具 deny/allow、路径规则、命令 deny、plan/default/full-auto 模式 | 权限与安全边界 |
| `src/openharness/skills` | loader 同时加载 bundled/user/plugin skills | Markdown skill 运行时 |
| `src/openharness/plugins` | plugin schemas/loader/installer | Claude-style plugin 生态 |
| `src/openharness/swarm` | team lifecycle、mailbox、worktree、subprocess backend | 多 agent 协作 |
| `ohmo` + `src/openharness/channels` | Feishu/Slack/Telegram/Discord 等通道 | 个人代理与远程 gateway |
| `frontend/terminal` | React terminal UI | 交互式 TUI |

官方 README 对自身定位是 lightweight agent infrastructure，包含 tool-use、skills、memory、multi-agent coordination 和 ohmo；PyPI 包名为 `openharness-ai`，最新版本 0.1.8，发布时间 2026-05-06。

## 对你的帮助

高价值帮助：

- 运行时心智模型：帮助我们把当前项目里的 `skills / hooks / agents / contracts` 和实际 agent runtime 能力一一映射，识别哪些约束应该在 prompt 层，哪些应该下沉到工具/权限/运行时层。
- Skill 与 plugin 兼容性参考：它直接支持 `.md` skill、Claude-style plugin、hooks、agents，对我们维护 upstream skill mirror 和 Codex adapters 有参考价值。
- 安全治理参考：`PermissionChecker`、remote local-only 命令、allowlist secure default、dry-run preview 这些方向，和本项目的“禁止降级、权限、验证、完成证据”文化高度相关。
- 多 agent/任务机制参考：team lifecycle、mailbox、worktree、background tasks 可作为我们评估 subagent 编排边界的源码样本。

低价值或不宜直接采纳的部分：

- 它不是我们的合同系统：OpenHarness 没有等价于本项目 `contracts/small-chain.yaml`、`contracts/standard-chain.yaml`、active scope registry、artifact ownership 的交付治理真源。
- 它是 runtime，不是 skill governance 仓库：直接把它 vendor 进来会把本项目从“跨 Claude/Codex 的规则与 skill 真源”拉向“维护一个 agent CLI/runtime”，范围会膨胀。
- ohmo 远程通道场景风险更高：它可以让聊天渠道驱动本地 coding agent，安全边界、凭据、远程命令、工作区隔离必须非常谨慎。

## 当前项目适配度

本项目真实画像：

- README 明确：统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`，默认轻量链为 `small-chain`。
- `community/SOURCES.yaml` 已有外部来源锁定机制，要求 upstream ref、captured_at、scope 和 notes。
- `contracts/superpowers-boundary.yaml` 明确 upstream body policy、local overlay、source fidelity 和更新流程。
- 本项目的核心价值是“规则、Skill、合同、验证与安装暴露”，不是提供一个新的 agent CLI。

适配判断：

| 方向 | 判断 | 原因 |
| --- | --- | --- |
| 直接引入为依赖 | 不建议 | 会引入 runtime 边界、远程通道、安全与 provider 管理复杂度，且当前项目不需要替代 Claude/Codex runtime |
| 作为 community source vendor | 暂不建议 | 它不是单个 skill/plugin，而是完整 runtime；纳入 `community/SOURCES.yaml` 会扩大维护面 |
| 作为源码学习对象 | 建议 | 可读 `permissions/checker.py`、`tools/base.py`、`skills/loader.py`、`swarm/*`、`engine/query_engine.py` |
| 作为隔离试点 | 建议 | 在临时目录用 v0.1.8 跑 `oh --dry-run`、plugin/skill playground、provider profile，不接真实生产 workspace |
| 作为安全/治理灵感 | 建议 | dry-run readiness、remote local-only、allowlist 默认拒绝、sensitive path deny 可以转成我们自己的规则或验证项 |

## 质量评估

| 层级 | 判断 | 证据 |
| --- | --- | --- |
| 真实性 | 通过 | `HKUDS/OpenHarness` 是非 fork 公开仓库，GitHub API 显示 MIT license、Python 主语言、默认分支 main |
| 维护 | 强但早期 | GitHub API：创建于 2026-04-01，最近 push 为 2026-05-06，376 commits，v0.1.8 于 2026-05-06 发布 |
| 文档 | 中上 | README、中文 README、SHOWCASE、CONTRIBUTING、CHANGELOG、release notes 存在；但 README 营销密度较高，需要源码交叉验证 |
| License | 通过 | GitHub 与 PyPI 均显示 MIT |
| 安全 | 中等风险 | 有安全修复 PR 和测试覆盖，但 remote gateway/bridge/allowlist 刚经历高影响修复；GitHub security advisory API 当前返回空 |
| 采用 | 早期高热 | GitHub API：约 12k stars、2k forks、68 subscribers；PyPI 0.1.8 已发布，但真实生产采用证据不足 |
| 适配 | 学习强，采用弱 | 与当前项目方向相邻但层级不同：它实现 runtime，我们维护 skill/rule/contract 真源 |

## 红旗与反方挑战

最强支持证据：

- OpenHarness 的目录结构与源码确实覆盖 agent runtime 关键层，而不只是 README 叙事。
- CI 配置包含 Python 3.10/3.11 tests、ruff、frontend TypeScript check；最近 main CI run 成功。
- v0.1.8 release notes 明确列出 provider 扩展、ohmo Feishu group、remote-channel hardening、Windows/MCP 稳定性修复。

最强反方挑战：

- 创建时间只有一个多月，v0.1.x 仍在快速变动；star/fork 不能证明生产可靠。
- remote coding agent 的安全失败代价很高。近期安全修复说明维护响应不错，但也说明边界还在收敛。
- PyPI 0.1.8 文件显示未使用 Trusted Publishing；供应链成熟度不能按生产依赖标准放行。
- `docs.open-harness.dev` 指向的是另一个 TypeScript 项目 `MaxGfeller/open-harness`，社区语义存在近名混淆，调研时必须锁定 owner。

失效条件：

- 如果我们未来要做“自研 agent runtime / CLI / 远程个人代理”，OpenHarness 的采用价值会显著上升。
- 如果它后续发布 0.2/1.0，补齐安全公告流程、trusted publishing、稳定 API、真实下游案例，可以从 `trial` 升级为正式选型候选。
- 如果本项目目标继续保持“skill/rules/contracts 真源 + Claude/Codex 适配层”，它只应作为参考对象。

## 建议动作

1. `deep-read`：先读五条链路，不改本项目。
   - `src/openharness/engine/query_engine.py`：agent loop 如何装配。
   - `src/openharness/tools/base.py` 与 `src/openharness/tools/*`：tool schema 与 read-only/mutating 边界。
   - `src/openharness/permissions/checker.py`：权限模式、路径规则和敏感路径硬拒绝。
   - `src/openharness/skills/loader.py`、`src/openharness/plugins/*`：skills/plugins 如何发现与注册。
   - `src/openharness/swarm/*`：subagent、mailbox、worktree、team lifecycle。

2. `trial`：隔离试跑，不接真实工作区和真实 IM channel。
   - 临时目录 clone。
   - 只运行 `oh --dry-run`、`oh --dry-run -p "..." --output-format json`。
   - 验证是否能加载一个最小 `SKILL.md` 和一个只读 plugin。
   - 不运行 `ohmo gateway start`，不配置 Feishu/Slack/Telegram/Discord。

3. `watch`：两周后复查。
   - v0.1.9/v0.2 是否稳定 API。
   - 安全 advisory / Snyk / release notes 是否新增高危项。
   - issue/PR 响应是否保持。
   - PyPI 是否启用 Trusted Publishing。

## 检索路径与覆盖证明

名称归一化：

| 变体 | 类型 | 结果 |
| --- | --- | --- |
| `HKUDS/OpenHarness` | GitHub repo | 命中，本报告对象 |
| `openharness-ai` | PyPI package | 命中，HKUDS 仓库发布包 |
| `OpenHarness` | 泛名 | 存在混淆，需要 owner 锁定 |
| `MaxGfeller/open-harness` | GitHub repo | 排除，TypeScript SDK，文档域名 `docs.open-harness.dev` 指向它 |
| `openharness-sdk` | PyPI package | 排除，非本报告对象 |

覆盖来源：

- GitHub repo API：repo stats、license、语言、更新时间。
- GitHub releases/tags/actions/community profile：发布、CI、社区文件。
- GitHub raw files：README、pyproject、CONTRIBUTING、SHOWCASE、release notes、关键源码。
- PyPI：`openharness-ai` 当前版本、发布时间、license、requires-python、发布文件元数据。
- 第三方安全数据库：仅作为风险提示；关键安全事实优先回到 GitHub PR/commit 验证。

剩余盲区：

- 未执行第三方代码，未跑 OpenHarness 自身测试。
- 未验证 ohmo 真实渠道接入。
- 未审计完整依赖树与所有 transitive vulnerability。
- 未确认维护者长期路线图。

## 来源

- GitHub 仓库：https://github.com/HKUDS/OpenHarness
- README：https://github.com/HKUDS/OpenHarness/blob/main/README.md
- PyPI：https://pypi.org/project/openharness-ai/
- v0.1.8 release：https://github.com/HKUDS/OpenHarness/releases/tag/v0.1.8
- v0.1.8 notes：https://github.com/HKUDS/OpenHarness/blob/main/RELEASE_NOTES_v0.1.8.md
- CONTRIBUTING：https://github.com/HKUDS/OpenHarness/blob/main/CONTRIBUTING.md
- SHOWCASE：https://github.com/HKUDS/OpenHarness/blob/main/docs/SHOWCASE.md
- CI workflow：https://github.com/HKUDS/OpenHarness/blob/main/.github/workflows/ci.yml
- Security PR #147：https://github.com/HKUDS/OpenHarness/pull/147
- Security PR #208：https://github.com/HKUDS/OpenHarness/pull/208
- Bridge hardening commit：https://github.com/HKUDS/OpenHarness/commit/438e37309778e19060dfe7b172eb142e543c4cd6
- Allowlist hardening commit：https://github.com/HKUDS/OpenHarness/commit/fab40c6eabfb15f2bdf23cddd3cfe66a64ea203d
- 近名排除对象：https://github.com/MaxGfeller/open-harness
