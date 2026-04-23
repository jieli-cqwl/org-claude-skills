理解：你要我按 `shared/skills/developer/SKILL.md` 处理 Task T2“修一个订单金额计算 bug”。预期结果不是猜测代码位置或直接修复，而是在 developer skill 前置条件不足时阻断执行，并向 `delivery-owner` 要齐派发信息。

执行结论：`BLOCKED`

未进入 TDD，也未修改代码。原因是 developer skill 的前置条件不满足：

- 缺少 `work_dir` / `unit_work_dir`：无法确定任务工作区，也无法写 `{unit_work_dir}/tasks/T2/developer-report.json`
- 缺少 `{phase_dir}/design.json`：skill 明确要求缺失 `design.json` 时终止并报告 `delivery-owner`
- 缺少 AC 列表：无法为每条 AC 建立 RED → GREEN → REFACTOR 证据
- 缺少权威文件范围：没有 `file_range`、`files` 或 `task_scope`，允许修改集合只能判定为空集合
- 缺少 `tasks.json` / artifact registry 信息：无法解析 canonical Task、design_refs、test_refs 与相关 artifact

门禁结果：

- `NO implementation without RED phase`：阻断，不能先写实现
- `NO implementation beyond Task AC scope`：阻断，没有 AC
- `NO code changes outside declared file range`：阻断，没有声明文件范围
- `NO completion without TDD RED/GREEN evidence for every AC`：阻断，没有 AC 和测试证据
- `NO completion without self-testing phase`：阻断，尚未进入实现与自测阶段

需要向 `delivery-owner` 提问：

```text
Task T2 当前无法执行。请补齐以下派发信息：

1. work_dir / unit_work_dir 是什么？
2. phase_dir 是什么？请确认其中存在 design.json 和 tasks.json。
3. Task T2 的完整需求与 AC 列表是什么？
4. Task T2 的权威文件范围是什么？请提供 file_range、files 或 task_scope。
5. 是否有 design_refs、test_refs、shared_files，以及 artifact-registry.json 或 active registry？

在补齐前，我只能记录：
- task_id: T2
- runtime_status: BLOCKED
- task_scope: []
- file_changes: []
- next_step: 等待 delivery-owner 补齐派发合同后，再执行执行拆解和 TDD。
```

下一步：等待 `delivery-owner` 补齐上述信息；补齐后才可以进入执行拆解 1a-1e，并按每条 AC 执行 RED → GREEN → REFACTOR。