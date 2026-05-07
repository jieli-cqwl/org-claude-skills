# HKUDS/OpenHarness 调研报告

抓取日期：2026-05-07

调研模式：analysis + GitHub repo radar
呈现模式：decision
操作对象：https://github.com/HKUDS/OpenHarness

## 一页决策版

本次要做的不是“OpenHarness 好不好”，而是三选一：

| 选项 | 结论 | 为什么 |
| --- | --- | --- |
| A. 不管它 | 不选 | 会错过 agent runtime 的真实工程参考，尤其是权限、plugin、subagent/worktree |
| B. 只做源码精读 + 隔离试验 | 选这个 | 能吸收设计经验，不改变当前项目边界，风险最低 |
| C. 正式采用 / 加入依赖 / vendor 到 `community/SOURCES.yaml` | 不选 | 它是完整 runtime，不是 skill；会把本项目范围从“skill/rules/contracts 治理”拉到“agent CLI/runtime 维护” |

最终建议：`deep-read + controlled trial + watch`。不 `adopt`，不加入当前项目依赖，不写入 `community/SOURCES.yaml`。

如果必须拍一个投入量：先花 1 天做定向精读，最多再花 0.5 天做 `--dry-run` 隔离试验；到这里就停，除非我们明确要自研 agent runtime。

## 最终结论

OpenHarness 是一个 Python 实现的 agent harness / 本地 coding agent runtime，不是单纯 benchmark。它把 Claude Code / Codex 类工具的关键运行时能力拆成可检查的开源组件：agent loop、工具注册、权限、hooks、skills、plugins、MCP、subagent/swarm、任务、TUI、provider profile，以及建立在其上的 ohmo 个人代理。

对当前 `org-claude-skills` 项目，建议动作是 `deep-read + trial`，不是 `adopt`。它最值得研究的是运行时工程实现和安全边界，而不是直接迁移我们的 skill / rules / small-chain 体系。

决定性理由：

- 目标相近：当前项目维护 Claude Code 与 Codex 的 skills/rules/reference/hooks/agents，并以 small-chain/standard-chain 合同收束交付流程；OpenHarness 正好在实现这些能力对应的 runtime 层。
- 机制有参考价值：它有 Pydantic tool schema、permission checker、hook lifecycle、skill/plugin loader、subprocess teammates、background tasks、provider profiles、dry-run preview 等可拆读模块。
- 成熟度仍早：仓库 2026-04-01 创建，v0.1.x 快速迭代，最新 v0.1.8 发布于 2026-05-06；热度高但工程稳定性还需要时间验证。
- 安全边界仍在快速补洞：近期合并了 remote channel allowlist 和 `/bridge` local-only 等高影响安全修复，说明维护者响应快，也说明 remote/ohmo 场景尚属高风险区域。

当前动作状态：`deep-read` 用于学习，`trial` 用于隔离试跑，`watch` 用于持续跟踪；不建议进入 `adopt` 或把它加入本项目运行依赖。

## 深入源码后的关键发现

这次我没有只看 README，而是 clone 到临时目录 `/tmp/openharness-deep-dive-UVw4Pq/OpenHarness` 做了源码静态深读。未执行它的安装脚本、agent runtime、ohmo gateway 或第三方模型调用。

| 研究面 | 源码事实 | 对我们有什么用 | 决策影响 |
| --- | --- | --- | --- |
| Agent loop | `QueryEngine` 把 api client、tool registry、permission checker、hook executor、cwd、model、system prompt 装配进 `QueryContext`；`run_query` 负责模型流、tool use、tool result、auto compact、hook stop | 证明它是 runtime 层，不是 skill 仓库；可学习工具循环和 carryover metadata | 支持“学习，不采用” |
| Tool schema | `BaseTool` 用 Pydantic `input_model.model_json_schema()` 生成工具 schema，`is_read_only()` 决定权限语义 | 我们可以借鉴“工具能力声明 + 读写语义”的检查口径 | 可吸收设计 |
| 权限模型 | `PermissionChecker` 有 built-in sensitive path deny、allowed/denied tools、path_rules、denied_commands、default/plan/full_auto | 对我们的 hooks/rules 很有参考价值，尤其是“full_auto 也不能越过 credential path” | 必读 |
| Bash/文件工具 | bash 有 600s 上限、非交互 scaffold 预检、输出截断；文件工具只在 docker sandbox active 时做 sandbox path check，普通模式主要靠 permission checker | 说明 runtime 安全不是天然全面，需要组合权限、sandbox、hook | 不适合直接信任采用 |
| Plugin loader | project-local plugins 默认禁用，只有 `allow_project_plugins=True` 才加载；但 enabled plugin tools 通过 `exec_module` 导入 Python 代码 | 这正好说明 plugin 是强执行面，不能像普通 markdown skill 一样纳管 | 不建议 vendor/adopt |
| Skill loader | 支持 bundled/user/extra/plugin skills，读取 `<root>/<skill>/SKILL.md`，用 `yaml.safe_load` 解析 frontmatter | 对我们 adapter/manual-only/frontmatter 兼容有参考价值 | 可吸收 |
| MCP | settings 与 plugin MCP 合并；stdio MCP 会执行配置里的 command；project plugin MCP 只有显式 opt-in 才加载 | 说明 MCP 是强外部执行面；我们的 source lock 和显式信任边界仍必要 | 谨慎参考 |
| Remote/ohmo | 远程 channel 默认 `allow_from=[]` deny-all；敏感 slash command 如 `/bridge`、`/login`、`/config`、`/plugin`、`/permissions` 标记 local-only + remote admin opt-in | 维护者已意识到远程安全边界，但也说明这里失败代价高 | 暂不碰 ohmo |
| Subagent/worktree | `WorktreeManager` 校验 slug、防绝对路径和 `..`，用 git worktree 隔离；subprocess backend 用 direct argv 避免 shell quoting 问题 | 对 small-chain 并行 worktree 和 subagent 调度有参考价值 | 必读 |
| Autopilot | 默认 policy 里 execution `permission_mode=full_auto`、`use_worktree=True`，verification policy 有 shell metachar 拒绝和显式 shell opt-in | 设计很有启发，但自动执行 repo task 风险大 | 不采用，只读 |

## 可吸收内容

只建议吸收这些设计思想，不搬代码：

- 权限规则分层：内建硬拒绝、用户配置拒绝、路径规则、命令规则、模式控制分开处理。
- “read-only tool” 显式声明：工具自己暴露 `is_read_only()`，权限层不靠工具名猜测。
- Project plugin 默认禁用：本地项目里的可执行扩展必须显式 opt-in。
- Remote admin 命令默认 local-only：远程 IM channel 不应默认能改配置、权限、provider、MCP、plugin。
- Worktree slug 白名单：worktree 名称先做长度、字符、绝对路径、`.`/`..` 校验。
- Verification command 默认 argv，含 shell metachar 的命令必须显式 `shell: true`。

## 不该吸收内容

- 不把 OpenHarness 当 runtime 依赖。
- 不把 ohmo 接入真实 Feishu/Slack/Telegram/Discord。
- 不复制它的 provider profile 体系。
- 不迁移我们的 small-chain / standard-chain 到 OpenHarness。
- 不把 OpenHarness 作为 `community/SOURCES.yaml` source；它不是 skill source，而是 runtime source。

## 决策失效条件

只有出现以下任一条件，才重新评估是否从 `trial` 升级：

- 我们明确要开发自己的 agent CLI/runtime，而不是只维护 Claude/Codex skills 与 rules。
- OpenHarness 发布稳定 API 或 1.0，并清楚声明 plugin/MCP/remote security model。
- PyPI 供应链成熟度提升，例如启用可信发布或提供更明确 provenance。
- 出现真实下游生产采用案例，而不只是 star/fork 热度。
- 我们需要一个可替代 Claude/Codex 本地 runtime 的开源执行器。

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

## 项目上下文与适配度

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
| 维护 | 强但早期 | GitHub API：创建于 2026-04-01，最近 push 为 2026-05-06；v0.1.8 于 2026-05-06 发布；main 最近 5 次 CI 均成功 |
| 文档 | 中上 | README、中文 README、SHOWCASE、CONTRIBUTING、CHANGELOG、release notes 存在；但 README 营销密度较高，需要源码交叉验证 |
| License | 基本通过 | GitHub API 显示 MIT；`pyproject.toml` 声明 MIT；PyPI JSON 的 `info.license` 当前为 null，因此采用前仍需以仓库 LICENSE/包元数据复核 |
| 安全 | 中等风险 | 有安全修复 PR 和测试覆盖，但 remote gateway/bridge/allowlist 刚经历高影响修复；GitHub security advisory API 当前返回空 |
| 采用 | 早期高热 | GitHub API：12066 stars、2017 forks、68 subscribers；PyPI 0.1.8 已发布，但真实生产采用证据不足 |
| 适配 | 学习强，采用弱 | 与当前项目方向相邻但层级不同：它实现 runtime，我们维护 skill/rule/contract 真源 |

## 红旗与反方挑战

最强支持证据：

- OpenHarness 的目录结构与源码确实覆盖 agent runtime 关键层，而不只是 README 叙事。
- CI 配置包含 Python 3.10/3.11 tests、ruff、frontend TypeScript check；本次 clone 静态统计有 111 个测试文件、约 932 个 test 函数；最近 main CI run 成功。
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

## 独立挑战记录

Challenger 视角：你可能会说“我们现在也有 hooks、skills、agents，OpenHarness 也有这些，为什么不直接采用它来统一 runtime？”这个反方有道理，因为 OpenHarness 的实现已经覆盖工具调用、plugin、MCP、权限、subagent 和 UI，短期看似能减少我们维护适配层的成本。

处理结论：反方不改变最终建议。原因是当前项目的权威资产是 `shared/`、`contracts/`、`community/SOURCES.yaml`、`superpowers-boundary.yaml` 和安装/验证链路；OpenHarness 的强项是执行器/runtime。采用它不会替代我们的合同、source fidelity、manual-only、active scope 和完成验证要求，反而会新增远程通道、provider、插件 Python 执行、MCP stdio、autopilot full_auto 等高风险面。

残余风险：如果 OpenHarness 后续成为事实标准 runtime，而我们完全不跟进，可能错失生态适配机会。因此建议 `watch`，但不是 `adopt`。

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
