# Small Chain Boundary Contract

本文件定义 small-chain 在本仓库中的活跃运行边界。

## 目标

- 默认链路收口到 `small-chain`
- 执行统一收口到 `subagent-driven-development`
- 移除 OpenSpec CLI 作为运行前提
- 保留 OpenSpec 概念来源，不保留运行时 skill/command 依赖

## 活跃链路

small-chain 的唯一活跃链路定义见 `contracts/small-chain.yaml`。

## 活跃工件

- `docs/{feature}/YYYY-MM-DD-{change}/design.md`
- `docs/{feature}/YYYY-MM-DD-{change}/tasks.md`
- `docs/{feature}/YYYY-MM-DD-{change}/plan.md`
- `docs/archive/{feature}/YYYY-MM-DD-{change}/`

## 约束

1. `tasks.md` 是唯一完成状态真源。
2. `plan.md` 不持有 checkbox 状态。
3. `verification-before-completion` 提供 fresh verification evidence，不能被口头判断替代。
4. `verify-change` 通过后才能进入 `finishing-a-development-branch` 或 `archive`。
5. `archive` 只允许在变更已经集成到目标分支后执行。
6. 任何活跃文档和运行时检查都不得把 OpenSpec CLI 作为默认前提。

## 关联文件

- `contracts/small-chain.yaml`
- `contracts/superpowers-boundary.yaml`
