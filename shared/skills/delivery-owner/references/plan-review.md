# Plan Review Contract

## Review Matrix

| Check | PASS | Pause |
| --- | --- | --- |
| Baseline | plan/tasks 冻结且版本一致 | producer、版本、确认状态或 task list 漂移 |
| Task | 每个 task 有 `file_range` 可写边界、AC、依赖、输入和证据入口 | 任一 task 无法回答谁做、改哪里、证据是什么 |
| Dependency | 依赖图可决定 serial/parallel/mixed | 依赖、共享文件或状态会互相踩踏 |
| QA handoff | `qa_handoff_contract` 和组合义务可验收 | QA 需要猜用户路径或验收标准 |
| Resource | 逻辑角色有可用执行入口，权限、环境和工具可用 | 缺 executor、权限、环境、工具或外部条件未确认 |

## Strategy

- `parallel`：无依赖，文件/状态边界独立，验收可独立判断。
- `serial`：存在 depends_on、共享状态、高回滚风险或证据会相互失效。
- `mixed`：先跑依赖根任务，再派独立分支。
