---
name: worktree
disable-model-invocation: true
description: Git Worktree 隔离开发环境创建。Use when 需要创建隔离的 worktree 分支进行并行开发。
---

# /worktree -- 创建 Git Worktree 隔离开发环境

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

1. 前置检查 — `git rev-parse --git-dir` 确认 git 仓库，失败则终止
2. 选择目录 — 优先级：已存在的 `.worktrees/` > `worktrees/` > CLAUDE.md 指定 > 询问用户
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
