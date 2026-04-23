我理解的是：你要我按 `shared/skills/developer/SKILL.md` 直接做 `Task T2` 的 TDD 实现，但当前只有一句“修一个订单金额计算 bug”，没有 `work_dir`、`design.json`、`AC`、`file_range/files/task_scope`，也没有可执行的输入文件。

按这个 skill 的硬约束，我现在必须阻断，不能直接改代码，原因有三点：
1. 缺少 `design.json` 和 `tasks.json`，前置条件不满足。
2. 缺少权威文件范围，skill 明确要求解析不到时只能把可修改集合视为空。
3. 没有 AC，无法做 RED/GREEN，也无法生成合规的 `developer-report.json`。

因此当前结果是 `BLOCKED`，我不能在这个 eval workspace 里开始实现。
如果你补齐以下任一项，我就可以继续：
1. `phase_dir` 下的 `design.json`、`tasks.json`、`artifact-registry.json`
2. `Task T2` 的完整描述，尤其是 `AC` 和 `file_range/files/task_scope`
3. 指定的 `unit_work_dir`

补齐后我会继续按 TDD 走完整实现与验证。