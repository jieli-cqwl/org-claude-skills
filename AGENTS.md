# AGENTS.md

## Commands
| 命令 | 用途 |
|---|---|
| `bash tests/run-all.sh --quick` | 快速回归 |
| `bash tests/run-all.sh` | 全量门禁 |
| `bash install.sh --target all --dry-run` | 预览 runtime 安装 |
| `CODEX_SKILLS_DIR="$PWD/community/anthropic/skills" bash tests/run-all.sh --quick` | 本机 skill-creator 缺失时的 quick 口径 |

## Architecture
- 根 `CLAUDE.md` / `AGENTS.md` 只约束开发本仓；`shared/assistant.md` 是分发到用户 runtime 的入口模板。
- `shared/rules/*.md` 会进入全局 runtime rules；repo-local 规则留在根入口或本仓文档。
- `shared/skills/` 是 first-party 真源；`community/*/skills` 是锁 ref 的第三方镜像。

## Code Style
- 沿用现有 Bash/Python/Markdown 风格；确定性规则交给脚本、schema、fixture、hook 或测试。
- 文档、规则、测试任一变化影响同一约束时，同步真实消费者和报告引用。

## Environment
- 安装脚本可能写 `~/.claude`、`~/.codex`、`~/.agents`；涉及安装先用 dry-run 或 fixture。
- `docs/archive/` 默认不是接手真源；active docs 从 `contracts/active-doc-scope.yaml` 进入。

## Testing
- 行为/约束变更先补可失败测试，再做最小实现，最后跑 fresh proving command。
- 测试断言边界：不得用 shell `assert_present` / `assert_absent` 锁定 Skill Markdown 自然语言正文。
- 低信号断言由 `tools/community/check_test_signal_assertions.py` 和 `tests/fixtures/test-assertion-boundary/low-signal-prose-assertions.baseline` 管住。

## Gotchas
- 不要把本仓测试治理放进 `shared/rules/`；那里会被安装到全局 runtime。
- 不要污染 `community/superpowers/skills`；保持 upstream 纯镜像。
- `worklog.md` 只导航，standard-chain 状态真源是 canonical JSON。

## Workflow
- 执行前定目标、对象、成功标准；改动前追影响面；交付前验证命令和 `git diff` 都要对上本次范围。
