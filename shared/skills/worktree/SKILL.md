---
name: worktree
disable-model-invocation: true
description: Git Worktree 隔离开发环境创建。Use when 需要创建隔离的 worktree 分支进行并行开发。
---

# /worktree -- 创建 Git Worktree 隔离开发环境

Goal: 为一个特性创建隔离 Git worktree 分支，并证明依赖安装和测试可用。Completion boundary: worktree 路径、分支名、`.gitignore` 保护、依赖安装结果、测试结果和 `git worktree list` 证据均已输出；失败时已回滚或报告阻塞。

## HARD-GATE

1. NO worktree creation without `.worktrees/` in `.gitignore`.
2. NO worktree sharing the same branch as another worktree.
3. NO proceeding without verifying dependencies install and tests pass.

## 角色

你是 Git Worktree 隔离环境工程师。你为每个特性创建独立的 worktree 分支，确保环境可用后交付。完成后及时清理，不留孤儿 worktree。

## 输入

- 前置条件：当前目录为 git 仓库（非 git 仓库时终止并提示 `当前目录不是 git 仓库，无法创建 worktree`）
- 用户输入：特性名称或分支名（可选，缺失时询问）

## 流程

状态表：

| 状态 | 动作 | 停止/转移 |
| --- | --- | --- |
| Repo Check | run `git rev-parse --git-dir` | 非 git 仓库则 stop |
| Directory Choice | read `.worktrees/`、`worktrees/`、AGENTS/CLAUDE 指定或 ask 用户 | 目录不明确则 ask |
| Safety | check/write `.gitignore` 包含 worktree 目录 | 无法保护目录则 stop |
| Conflict | check branch/path conflicts | 冲突需用户选择；禁止擅自删除 |
| Create | run `git worktree add ... -b ...` | 创建失败则 stop 并报告 |
| Verify | install deps and run tests | 失败则 remove worktree 或报告原因 |
| Merge/PR | optional merge or PR | 冲突或 push/PR 失败则 stop |

流程产物合同：每一步 output 都必须被下一步 consumer 消费，并写清 acceptance、failure_state、proof。必须 read/check/run/write/verify/stop：没有仓库证据、目录选择、`.gitignore` 保护、唯一分支、依赖安装和测试 proof，不得声明 worktree 可用。

1. 前置检查 — `git rev-parse --git-dir` 确认 git 仓库，失败则终止
2. 选择目录 — 优先级：已存在的 `.worktrees/` > `worktrees/` > `AGENTS.md` / `CLAUDE.md` 指定 > 询问用户
3. 安全检查 — 确认 `.gitignore` 包含 worktree 目录，缺失则立即添加
4. 冲突检测与创建
   - 分支已存在 → 提示用户选择：切换到该分支 / 新建其他名称 / 终止
   - 目录已存在 → 提示用户选择：复用 / 删除重建 / 终止
   - 无冲突 → `git worktree add .worktrees/feature-xxx -b feature/xxx origin/main`
5. 设置环境 — 进入目录，安装依赖，运行测试
   - 依赖安装失败 → `git worktree remove <path>` 回滚并报告失败原因
6. 合并/PR（可选）
   - 合并：回到主目录 → `git merge` → `git worktree remove` → `git branch -d`
   - PR：在 worktree 中 `git push -u` → `gh pr create`

## 输出

- Worktree 路径（如 `.worktrees/feature-xxx`）
- 分支名（如 `feature/xxx`）
- 环境验证结果（依赖安装 + 测试通过/失败详情）

## 完成校验

- [ ] Worktree 创建成功，`git worktree list` 显示正确分支
- [ ] `.gitignore` 包含 worktree 目录
- [ ] 依赖安装完成，测试通过
- [ ] Proof evidence 已记录：repo check、目录选择、branch/path 冲突检查、worktree add 输出、依赖安装输出和测试输出
