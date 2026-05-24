# AGENTS.md

## Commands
| 命令 | 用途 |
|------|------|
| `bash install.sh --target all --dry-run` | 预览 Claude/Codex runtime 安装变更 |
| `bash install.sh --target all --check full` | 安装后完整检查 |
| `bash tests/run-all.sh --quick` | 本地快速回归 |
| `bash tests/run-all.sh` | 全量测试门禁 |
| `bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills` | 探测 runtime 能力 |
| `bash tools/dev/probe-codex-hooks.sh` | 检查 Codex hooks trust 状态 |

## Architecture
- 本仓库是 Claude Code 与 Codex runtime 的分发源，维护 skills、rules、reference、hooks、agents 与 contracts。
- 根目录 `CLAUDE.md` / `AGENTS.md` 只约束开发本仓库；`shared/assistant.md` 是安装到用户 runtime 的入口模板，两者无承载关系。
- `shared/rules/*.md` 会被安装进全局 runtime rules，只能放可跨仓库分发的硬规则。
- `shared/skills/` 承载 first-party skills；`community/*/skills` 是第三方来源镜像，按 `community/SOURCES.yaml` 锁定。
- `contracts/` 与 `shared/runtime/` 定义 standard-chain、canonical registry、runtime surface 和安装边界。

## Code Style
- 优先保留既有目录、命名、shell/Python 风格；改动必须贴合当前消费者和验证入口。
- 确定性判断交给脚本、schema、fixture、hook 或测试，不用自然语言断言替代机器契约。
- 新增公共规则前先判断是否会被 runtime 分发；只属于本仓的规则放根入口或 repo-local 文档。
- 只改本次目标边界内的文件；发现边界外问题只记录和汇报。
- 文档变更要同步真实消费者、测试引用和报告引用，禁止留下双源事实。

## Environment
- 默认在 macOS/zsh 本地执行，脚本以 Bash 与 Python 为主；没有必要时不引入新工具链。
- 安装脚本会写入 `~/.claude`、`~/.codex` 和 `~/.agents`，执行安装相关测试前先确认目标和 dry-run 语义。
- `.claude/settings.local.json` 与本地缓存目录不是共享事实源，不作为项目入口文档。
- `docs/archive/` 是历史材料，默认接手不要读取，除非当前任务明确要求追溯历史。

## Testing
- 行为或约束变更先补能失败的测试，再做最小实现，最后运行能直接证明成功标准的 fresh command。
- 测试只锁机器契约：文件存在、路径、脚本名、参数、manifest、JSON/YAML 字段、schema、hook 注册、stdout/stderr、legacy 路径不复活。
- 测试断言边界：`shared/skills/**/*.md`、`references/*.md`、`projections/*.md` 的自然语言正文不得被 shell `assert_present` / `assert_absent` 锁定具体措辞。
- Skill 行为用 `shared/skills/*/evals/evals.json`、真实运行链路或专用验证脚本证明；命令形状只能断言脚本名、参数等 token。
- `tools/community/check_test_signal_assertions.py` 拦截新增低信号 Markdown 正文断言；`tests/fixtures/test-assertion-boundary/low-signal-prose-assertions.baseline` 只冻结历史遗留项。

## Gotchas
- 不要把 repo-local 测试治理文件放进 `shared/rules/`；该目录内容会进入用户全局 runtime rules。
- 不要把 `shared/assistant.md` 当当前仓库项目记忆；它是 runtime 入口模板。
- `community/superpowers/skills` 必须保持 upstream 纯镜像，不放本地 overlay、adapter 或运行时 frontmatter。
- `worklog.md` 只保存 active scope 导航字段；canonical JSON 才是 standard-chain 状态真源。
- 低信号 Markdown 断言不能通过扩大 baseline 绕过，必须改成行为 eval、schema/fixture 断言、脚本输出断言或删除。

## Workflow
- 执行前明确目标、操作对象、预期结果和可判定成功标准；存在多个合理解释时先对齐。
- 改动前列影响点，追到测试、文档、contracts、installer 和 runtime 消费路径。
- 涉及 active docs 时从 `contracts/active-doc-scope.yaml` 开始，再按 `worklog.md` 的 `state_ref` / `next_ref` 回源。
- 每个显著步骤都记录已完成、已验证和剩余事项；测试失败先按 Observe → Hypothesize → Test → Fix 定位根因。
- 交付前重新执行目标相关测试，检查 `git diff` 只包含本次范围，并按成功标准汇报证据。
