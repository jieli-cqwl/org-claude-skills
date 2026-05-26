# AGENTS.md

## Commands
| 命令 | 用途 |
|---|---|
| `bash tests/run-all.sh --quick` | 快速回归 |
| `bash tests/run-all.sh` | 全量门禁 |
| `bash install.sh --target all --dry-run` | 预览安装写入 |
| `CODEX_SKILLS_DIR="$PWD/community/anthropic/skills" bash tests/run-all.sh --quick` | 本机缺 `skill-creator` 时的 quick 口径 |

## Instruction Sources
- `AGENTS.md` 是共享项目指令真源；`CLAUDE.md` 只保留 `@AGENTS.md` import，除非确有 Claude-only 规则。
- 不要把项目记忆写进 `shared/assistant.md`；它只维护安装后的 runtime 默认入口。
- `shared/rules/*.md` 会安装到用户全局 runtime rules；只放跨仓库通用硬规则。
- 本仓私有规则写在根入口或 repo-local 文档，并用测试锁定承载位置。

## Skill Sources
- `shared/skills/` 是 first-party 真源；`community/*/skills` 是锁 ref 的第三方镜像。
- 不要污染 `community/superpowers/skills`；保持 upstream 纯镜像，不放 overlay、adapter 或 runtime frontmatter。

## Testing
- 行为/约束变更先补可失败测试，再做最小实现，最后跑 fresh proving command。
- 测试断言边界：不得用 shell `assert_present` / `assert_absent` 锁定 Skill Markdown 自然语言正文。
- 低信号断言由 `tools/community/check_test_signal_assertions.py` 拦截；不得用 baseline 放行新增或存量 Skill Markdown 自然语言正文断言。
- 修改入口文档时，保持 `CLAUDE.md` 只 import `AGENTS.md`，避免双源漂移。

## Workflow
- 执行前定目标、对象、成功标准；改动前追影响面；交付前验证命令和 `git diff` 都要对上本次范围。
- `worklog.md` 只导航，standard-chain 状态真源是 canonical JSON；active docs 从 `contracts/active-doc-scope.yaml` 进入。
