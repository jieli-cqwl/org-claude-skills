# Runtime Instruction Context Adherence 调研报告

> 调研模式：analysis  
> 呈现模式：decision + audit  
> 调研日期：2026-05-25  
> 状态：待用户确认

## 当前判断

当前结论：部分成立。

是否建议现在采取动作：建议收紧入口和常驻 rules，但不需要按“400 行硬限制”恐慌式拆分。

一句话判断：Claude Code 明确把 `CLAUDE.md`、imports、无路径 frontmatter 的 `.claude/rules/*.md` 作为上下文加载，官方也明确长文件会消耗上下文并降低 adherence；Codex 明确把全局和项目 `AGENTS.md` 拼入 combined prompt，并有 32 KiB 默认硬预算；但 Codex 官方证据没有显示 `~/.codex/rules/*.md` 会被原生自动加载，当前它们主要靠本仓入口 `AGENTS.md` 指令让模型按场景读取。

## 决策建议

1. 保持 `shared/assistant.md` 极简：它是安装后的 runtime 默认入口，越长越容易占用常驻注意力预算。
2. Claude Code 侧把全局 `.claude/rules/*.md` 控制为少数硬规则；能用 `paths` 限定的规则应路径限定，避免全局无条件加载。
3. Codex 侧不要把 `~/.codex/rules/*.md` 视为自动上下文；必须常驻的内容放进 `AGENTS.md` 的短摘要，长规则保留为文件并由入口指令按场景读取。
4. 不建议用“单文件 400 行”作为唯一门槛。更准确的门槛是：Claude 侧优先遵循官方“target under 200 lines”的可读性/adherence 建议；Codex 侧优先看 `project_doc_max_bytes` 的 32 KiB 默认预算和实际指令冲突/噪声。
5. 本仓当前安装形态未触发硬预算风险，但已经接近“常驻规则过多会稀释遵守效果”的治理区间，应继续把程序性细则从常驻入口下沉到 reference 或按场景读取。

## 决定性理由

1. Claude Code 侧 rules 明确计入上下文。官方机制说明 `.claude/rules` 会在每次会话或匹配文件打开时加载进 context；没有 `paths` frontmatter 的规则无条件加载。
2. Claude Code 没有“400 行硬截断”。官方说法是长 `CLAUDE.md` 会消耗更多 context 并降低 adherence，并建议 target under 200 lines；这支持“变长会降低遵守效果”的方向，但不支持“超过 400 行必然失效”的硬结论。
3. Codex `AGENTS.md` 明确进入模型可见指令。官方文档和源码都显示 global/project `AGENTS.md` 被读取、拼接，并作为 model-visible user instructions 注入。
4. Codex project docs 有 32 KiB 默认硬预算。源码 `DEFAULT_PROJECT_DOC_MAX_BYTES` 为 32 KiB；超出预算时会停止继续添加或截断，不是按行数判断。
5. 本仓当前安装后规模没有触发硬预算：Claude 入口 + rules 合计约 225 行、17,959 bytes；Codex 入口 + rules 合计约 225 行、17,936 bytes。

## 最大风险

最大风险是把 `rules` 当作“安装了就一定被 runtime 原生强制遵守”。Claude 侧成立：`.claude/rules` 有官方原生加载机制。Codex 侧对 `~/.codex/rules/*.md` 不成立：现有官方文档和源码证据只证明 `AGENTS.md` 会自动进入模型可见指令，没有证明 `~/.codex/rules/*.md` 会被 Codex 原生自动注入。

## 三条证据线

### 证据线一：官方机制

#### Claude Code

已确认机制：

- `CLAUDE.md` 在每次会话开始时加载到 context window。
- `@path` imports 会展开并加载到 context。
- `.claude/rules/*.md` 是 Claude Code 原生 rules 机制；无 `paths` frontmatter 的 rules 会无条件加载。
- 官方明确提示：更长的文件会消耗更多 context，并降低 adherence；建议把 `CLAUDE.md` target under 200 lines。
- 官方同时强调：这些内容是 context，不是 enforced configuration。换言之，它提高模型遵守概率，但不是不可违反的执行沙箱或策略引擎。

判断：Claude Code 上，“长入口/长规则降低遵守效果”有官方依据；“rules 是否计入同一上下文”答案为是，至少无路径限定的 `.claude/rules/*.md` 属于常驻 context。

#### Codex

已确认机制：

- Codex 官方文档说明会在工作前读取 `AGENTS.md`。
- Codex 会读取 global 与 project `AGENTS.md`，从 root 到 cwd 拼接 instruction chain。
- Codex 源码 `AgentsMdManager` 与 `user_instructions_with_fs` 证明这些内容会合成为 single model-visible instruction string。
- Codex 默认 `project_doc_max_bytes` 为 32 KiB，超出后会停止添加或截断。
- Codex 官方/源码证据没有显示 `~/.codex/rules/*.md` 被自动加载。

判断：Codex 上，`AGENTS.md` 是否计入同一模型上下文，答案为是；`~/.codex/rules/*.md` 是否由 Codex 原生自动计入，当前证据不足，应按否处理，除非后续找到官方机制或源码路径。

### 证据线二：仓库安装逻辑

本仓安装逻辑显示：

- Claude staging：`shared/assistant.md` 复制为 staging `CLAUDE.md`，`shared/rules` 复制到 staging `rules`，随后 placeholder 渲染为 `$HOME/.claude` 路径。
- Codex staging：`shared/assistant.md` 复制为 staging `AGENTS.md`，`shared/rules` 复制到 staging `rules`，随后 placeholder 渲染为 `$HOME/.codex` 路径。
- 安装 smoke 检查会检查 `~/.claude/CLAUDE.md`、`~/.claude/rules`、`~/.codex/AGENTS.md`、`~/.codex/rules` 是否存在。

关键差异：安装脚本能证明文件会被安装到对应 runtime home；不能单独证明 runtime 会以相同方式加载这些文件。Claude 侧加载由官方 rules 机制补强；Codex 侧只有 `AGENTS.md` 有官方/源码自动加载证据，`rules` 目录目前只是安装形态成立。

### 证据线三：本机安装形态

#### Claude runtime

| 文件 | 行数 | 字节数 |
|---|---:|---:|
| `~/.claude/CLAUDE.md` | 32 | 3,486 |
| `~/.claude/rules/代码规范.md` | 57 | 3,641 |
| `~/.claude/rules/文档管理.md` | 28 | 2,116 |
| `~/.claude/rules/执行纪律.md` | 42 | 3,974 |
| `~/.claude/rules/铁律.md` | 66 | 4,742 |
| 合计 | 225 | 17,959 |

判断：当前 Claude runtime 常驻入口 + rules 未超过 400 行，但无路径限定 rules 在 Claude Code 侧会计入上下文。真实风险不是当前已经超过硬阈值，而是未来继续堆叠会增加 context 占用和规则冲突概率。

#### Codex runtime

| 文件 | 行数 | 字节数 |
|---|---:|---:|
| `~/.codex/AGENTS.md` | 32 | 3,474 |
| `~/.codex/rules/代码规范.md` | 57 | 3,635 |
| `~/.codex/rules/文档管理.md` | 28 | 2,116 |
| `~/.codex/rules/执行纪律.md` | 42 | 3,973 |
| `~/.codex/rules/铁律.md` | 66 | 4,738 |
| 合计 | 225 | 17,936 |

判断：当前 Codex global `AGENTS.md` 自身只有 32 行，不接近 32 KiB 默认预算；即使把 rules 目录合计进人工估算，也约 17.9 KiB。但当前没有证据说明 Codex 会自动把 `~/.codex/rules/*.md` 合并进同一 prompt。

#### 项目入口

| 文件 | 形态 | 判断 |
|---|---|---|
| `/Users/lijieli/org-claude-skills/CLAUDE.md` | 只保留 `@AGENTS.md` import | 符合项目要求，Claude Code 会通过 import 读取项目 AGENTS 内容 |
| `/Users/lijieli/org-claude-skills/AGENTS.md` | 项目共享指令真源 | Codex 会作为项目 doc 读取；Claude 通过根 `CLAUDE.md` import 读取 |

判断：本仓 repo-local 入口治理是正确方向：只保留一个项目指令真源，避免 `CLAUDE.md` 与 `AGENTS.md` 双源漂移。

## 对“400 行”的精确结论

“超过 400 行导致遵守效果下降”不能作为平台事实直接下结论。更精确的结论是：

- Claude Code：官方支持“越长越占 context、越可能降低 adherence”，并建议 `CLAUDE.md` target under 200 lines；400 行可作为本仓内部治理红线，但不是官方硬阈值。
- Codex：官方机制以 bytes budget 为主，默认 `project_doc_max_bytes` 为 32 KiB；400 行不是 Codex 的硬阈值。
- 本仓规则中的“文件 <= 400 行”是代码规范/文档治理红线，不能直接投射为 Claude Code 或 Codex runtime prompt 的平台硬限制。

因此，正确治理动作不是“看到 401 行就拆”，而是：入口放稳定、高价值、少冲突的规则；长程序和低频细则放 reference；能确定性执行的规则交给脚本、schema、hook 或测试。

## 对“rules 是否计入同一上下文”的精确结论

| Runtime | 对象 | 是否自动计入模型上下文 | 证据状态 | 结论 |
|---|---|---:|---|---|
| Claude Code | `CLAUDE.md` | 是 | 官方文档 | 成立 |
| Claude Code | `@path` imports | 是 | 官方文档 | 成立 |
| Claude Code | `.claude/rules/*.md` 无 `paths` | 是 | 官方文档 | 成立 |
| Claude Code | `.claude/rules/*.md` 有 `paths` | 条件加载 | 官方文档 | 取决于匹配文件 |
| Codex | global/project `AGENTS.md` | 是 | 官方文档 + 源码 | 成立 |
| Codex | project AGENTS chain | 是 | 官方文档 + 源码 | 成立 |
| Codex | `~/.codex/rules/*.md` | 未证实 | 未找到官方/源码证据 | 不应视为原生自动加载 |

## 独立挑战记录

### 挑战 1：是否把“行数 400”误当平台限制？

反方问题：Claude/Codex 是否真的存在 400 行阈值？

核验结果：未找到官方或源码证据支持 400 行硬阈值。Claude 官方建议 target under 200 lines；Codex 使用 byte budget，默认 32 KiB。

结论：400 行只能作为本仓内部治理警戒线，不能写成平台事实。

### 挑战 2：是否把 Codex rules 目录误判为原生加载？

反方问题：安装到 `~/.codex/rules` 是否等于 Codex 自动加载？

核验结果：安装脚本证明文件存在；Codex 官方文档和源码证明 `AGENTS.md` 自动加载；未发现 `~/.codex/rules/*.md` 的自动加载路径。

结论：Codex rules 目录不能按 Claude `.claude/rules` 同等机制处理。

### 挑战 3：是否过度依赖本机状态？

反方问题：本机 225 行、约 18 KiB 是否能证明长期无风险？

核验结果：只能证明当前安装未触发硬预算；不能证明未来新增 rules 后 adherence 不下降。

结论：本机形态是当前快照证据，不是长期豁免。

### 挑战 4：是否忽略“context 不是 enforcement”？

反方问题：即使规则进入 context，是否等价于强制执行？

核验结果：Claude 官方将 `CLAUDE.md`/rules 定位为 context；Codex `AGENTS.md` 也是 model-visible instruction string。二者都不是确定性策略引擎。

结论：高风险、可枚举、可复验规则仍应落到代码、schema、script、hook 或测试。

## 失效边界

本报告结论在以下情况下需要重新验证：

1. Claude Code 改变 `rules` 加载机制，尤其是 `.claude/rules` 是否仍自动进入 context。
2. Codex 新增官方 rules 机制，开始自动加载 `~/.codex/rules/*.md`。
3. 本仓安装脚本改变 `shared/assistant.md`、`shared/rules` 的目标路径或渲染策略。
4. 本机 Codex `project_doc_max_bytes` 被显式调小，或项目层级新增多个大型 `AGENTS.md`。
5. runtime 入口和 rules 大幅增长，导致 Claude context 占用明显增加或 Codex byte budget 被触发。

## 检索路径与覆盖证明

已覆盖路径：

- 官方机制：Claude Code memory/rules/context 相关官方文档；OpenAI Codex AGENTS.md 官方文档。
- 源码机制：OpenAI Codex `agents_md.rs`、`agents_md_tests.rs`、`config/mod.rs`、`user_instructions.rs`、`hierarchical_agents_message.md`。
- 仓库安装逻辑：`/Users/lijieli/org-claude-skills/install.sh`、`AGENTS.md`、`CLAUDE.md`、`shared/assistant.md`。
- 本机安装形态：`~/.claude/CLAUDE.md`、`~/.claude/rules/*.md`、`~/.codex/AGENTS.md`、`~/.codex/rules/*.md`、`~/.codex/config.toml`。

未覆盖或未完全证明：

- 未做长 prompt adherence 的实证 A/B 测试；本报告判断来自官方机制、源码和本机结构审计。
- 未证明 Codex `~/.codex/rules/*.md` 自动加载；当前证据方向是“不应视为自动加载”。
- 未审计所有第三方 skill 或 community mirror 的指令长度；本次范围限定在 runtime 入口、rules、assistant 安装形态。

## 项目上下文

本仓项目规则要求：

- `AGENTS.md` 是共享项目指令真源。
- `CLAUDE.md` 只保留 `@AGENTS.md` import，除非确有 Claude-only 规则。
- 不要把项目记忆写进 `shared/assistant.md`。
- `shared/rules/*.md` 会安装到用户全局 runtime rules；只放跨仓库通用硬规则。
- 本仓私有规则写在根入口或 repo-local 文档，并用测试锁定承载位置。

本次结论与项目规则一致：继续压缩 global/default 入口，把跨仓库硬规则保留在 shared rules，把 repo-local 内容保留在项目 AGENTS，并避免多入口漂移。

## 证据索引

- E1：Claude Code memory 官方文档：`CLAUDE.md` 在会话开始加载进 context，imports 会进入 context，长文件会消耗 context 并降低 adherence。
- E2：Claude Code rules 官方文档：`.claude/rules` 在每次会话或匹配文件打开时加载；无 `paths` frontmatter 的 rules 无条件加载。
- E3：OpenAI Codex AGENTS.md 官方文档：Codex 会读取 global/project `AGENTS.md`，拼接 instruction chain；默认 `project_doc_max_bytes` 为 32 KiB。
- E4：OpenAI Codex 源码 `codex-rs/core/src/agents_md.rs`：`AGENTS.md` discovery、global instructions、project doc chain、读取预算和拼接逻辑。
- E5：OpenAI Codex 源码 `codex-rs/core/src/config/mod.rs`：`DEFAULT_PROJECT_DOC_MAX_BYTES` / `AGENTS_MD_MAX_BYTES` 为 32 KiB。
- E6：OpenAI Codex 源码 `codex-rs/core/src/context/user_instructions.rs`：`AGENTS.md` 内容进入 model-visible user instruction string。
- E7：本仓 `/Users/lijieli/org-claude-skills/install.sh`：Claude/Codex staging 安装路径和 placeholder 渲染逻辑。
- E8：本机 `wc -l` / `wc -c` 快照：Claude/Codex runtime 入口和 rules 的行数/字节数。
- E9：本机 runtime 文件读取：`~/.claude/CLAUDE.md`、`~/.claude/rules/*.md`、`~/.codex/AGENTS.md`、`~/.codex/rules/*.md` 的实际内容与安装模板一致。

## Sources

- [Claude Code memory](https://code.claude.com/docs/en/memory)
- [Claude Code context window](https://code.claude.com/docs/en/context-window)
- [OpenAI Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)
- [OpenAI Codex repository](https://github.com/openai/codex)
