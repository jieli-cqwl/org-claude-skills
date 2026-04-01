# Small Chain

`small-chain` 是当前仓库的轻量默认链路，负责把需求澄清、计划、执行、验证和归档收口到一条无重叠流程中。

## 链路

1. `brainstorming`
2. `writing-plans`
3. `using-git-worktrees`
4. `subagent-driven-development`
5. `verify-change`
6. `archive`

## 关键工件

- `docs/{feature}/YYYY-MM-DD-{change}/design.md`
- `docs/{feature}/YYYY-MM-DD-{change}/tasks.md`
- `docs/{feature}/YYYY-MM-DD-{change}/plan.md`

其中 `tasks.md` 是唯一进度真源，`plan.md` 只承载执行拆解和 task-id 映射。

## 关联文档

- 链路合同：`contracts/small-chain.yaml`
- 边界合同：`docs/small-chain/boundary-contract.md`
- 运行时边界：`contracts/superpowers-boundary.yaml`
