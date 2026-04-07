# Small Chain

`small-chain` 是当前仓库的轻量默认链路，负责把需求澄清、计划、执行、验证和归档收口到一条无重叠流程中。

## 链路

1. `using-superpowers`（meta）
2. `brainstorming`（entry）
3. `writing-plans`（plan）
4. `using-git-worktrees`（env）
5. `subagent-driven-development`（execute）
6. `verification-before-completion`（verify-preflight）
7. `verify-change`（verify）
8. `finishing-a-development-branch`（integrate）
9. `archive`（finish）

其中 `verify-change` 是规格门禁，`finishing-a-development-branch` 负责分支集成与 worktree 收尾，`archive` 只在变更已经集成到目标分支后执行。

## 关键工件

- `docs/{feature}/YYYY-MM-DD-{change}/design.md`
- `docs/{feature}/YYYY-MM-DD-{change}/tasks.md`
- `docs/{feature}/YYYY-MM-DD-{change}/plan.md`

其中 `tasks.md` 是唯一进度真源，`plan.md` 只承载执行拆解和 task-id 映射。

## 关联文档

- 链路合同：`contracts/small-chain.yaml`
- 边界合同：`docs/small-chain/boundary-contract.md`
- 运行时边界：`contracts/superpowers-boundary.yaml`
