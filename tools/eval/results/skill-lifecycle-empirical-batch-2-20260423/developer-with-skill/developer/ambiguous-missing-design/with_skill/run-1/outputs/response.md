**复述理解**
你要我按 [shared/skills/developer/SKILL.md](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-2/tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-with-skill/_workspaces/with_skill/developer/shared/skills/developer/SKILL.md) 处理 `Task T2` 的 eval。当前输入只有一句“修一个订单金额计算 bug”，没有 `work_dir`、`design.json`、AC、文件范围，所以这里只能做 developer skill 的前置门禁判断，不能进入实现。

**阻断结果**
- `runtime_status`: `BLOCKED`
- `current_boundary`: `前置条件检查未通过，未进入执行拆解 1a，未进入 RED/GREEN/REFACTOR`
- `task_scope`: `[]`
- `file_changes`: `[]`
- `tdd_evidence_index`: `[]`
- `evidence_refs`: `[]`
- `reviewable_anchor`: `[]`

门禁：
- 缺少 `work_dir`（至少要能定位 `phase_dir` / `unit_work_dir`），无法解析 `design.json`、`tasks.json`、artifact registry。
- 缺少 `{phase_dir}/design.json`，按 skill 前置条件必须终止并报告 `delivery-owner`。
- 缺少 Task T2 的 AC，不能做执行拆解，不能写 RED 测试，不能猜测实现。
- 缺少权威文件范围 `file_range` / `files` / `task_scope`，按 skill 当前允许修改集合只能是空集合，禁止任何代码改动。

发给 `delivery-owner` 的下一步问题：
1. 请提供本任务的 `work_dir`，或明确 `phase_dir` / `unit_work_dir` 路径。
2. 请提供 `{phase_dir}/design.json`。
3. 请补齐 Task T2 的完整定义，至少包含 AC；如有 `design_refs`、`test_refs` 也请一并提供。
4. 请提供权威文件范围：`file_range` / `files` / `task_scope`。

在这些输入补齐前，不进入 TDD，不修改代码，不生成完整产物。