---
name: parallel-subagent-development
description: Use after small-chain-execution-router returns decision=parallel to execute independent task groups in isolated worktrees.
---

> Source: local small-chain runtime addition

# Parallel Subagent Development

Execute a small-chain plan after `small-chain-execution-router` has produced `decision=parallel`.

## Hard Gate

Do not use this skill unless active workset contains:

- `tasks.md`
- `plan.md`
- `execution-route.json` with `decision=parallel`

If `execution-route.json` is missing, stale, blocked, or serial, stop and return to `small-chain-execution-router` or the serial path.

## Inputs

1. Active feature context
   - scope registry: `contracts/active-doc-scope.yaml`
   - handoff entry: `docs/{feature}/worklog.md`
   - latest `handoff_status`, `state_ref`, and `next_ref`
2. Active workset artifacts
   - `docs/{feature}/YYYY-MM-DD-{change}/tasks.md`
   - `docs/{feature}/YYYY-MM-DD-{change}/plan.md`
   - `docs/{feature}/YYYY-MM-DD-{change}/execution-route.json`

## Execution Contract

- Use only `parallel_groups` from `execution-route.json`.
- Respect `worktree_policy`; V1 supports `per_task_worktree` and `per_group_worktree`.
- Use bounded parallelism. Default maximum is 3 concurrent worker groups unless the route declares a lower value.
- Each worker owns only its assigned task ids and declared file set.
- No worker may write a shared file unless the route contains an explicit merge protocol.
- Each worker must run the proving commands declared for its task group.
- The controller merges one completed worktree at a time and records merge evidence.
- `tasks.md` remains the completion status source of truth.

## Output

Write `parallel-execution-report.json` in the active workset:

```json
{
  "decision": "parallel",
  "route_ref": "execution-route.json",
  "worktree_policy": "per_task_worktree",
  "groups": [
    {
      "group_id": "G1",
      "task_ids": ["T1"],
      "worktree": ".worktrees/example-T1",
      "status": "merged",
      "proving_commands": ["bash tests/example.sh"],
      "merge_evidence": "commit-or-merge-ref"
    }
  ],
  "failed_groups": []
}
```

## Workflow

1. Load `execution-route.json`.
   - Confirm `decision=parallel`.
   - Confirm `tasks_hash`, `plan_hash`, and `routing_input_hash` match the current workset artifacts.
2. Create isolated worktrees.
   - Use one worktree per route group for `per_group_worktree`.
   - Use one worktree per task for `per_task_worktree`.
3. Dispatch workers with bounded parallelism.
   - Give each worker only its task ids, plan section, file ownership, and proving commands.
   - Tell workers they are not alone in the codebase and must not revert edits made by others.
4. Collect worker results.
   - A group is complete only when its proving commands pass and its changed files match the route ownership.
5. Merge groups one at a time.
   - Stop on conflict.
   - Record merge evidence before moving to the next group.
6. Update `tasks.md`.
   - Mark a task `[x]` only after its group is merged and verified.
7. Write `parallel-execution-report.json`.
8. Continue to `verification-before-completion`.

## Failure Contract

Return blocked status if any of these occur:

- route hashes are stale
- a worker touches files outside its route ownership
- a merge conflict occurs
- a proving command fails
- `parallel-execution-report.json` cannot be written

## 流程导航

- 当前完成条件：所有 route groups 已合并，`tasks.md` 对应任务已标记完成，`parallel-execution-report.json` 已写入。
- 下一步：`verification-before-completion`
- 完整链路：`brainstorming → writing-plans → small-chain-execution-router → parallel-subagent-development → verification-before-completion → verify-change → finishing-a-development-branch → archive`

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；只对 `management_status in [managed, migrated]` 的 feature 建立默认接手上下文。
- `worklog.md` 最新记录的 `handoff_status / state_ref / next_ref` 决定接手入口。
- 并行执行状态不写入 `worklog.md` 正文；执行证据写入 active workset 的 `parallel-execution-report.json`。
