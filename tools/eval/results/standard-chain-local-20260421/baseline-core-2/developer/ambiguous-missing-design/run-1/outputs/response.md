已按当前工作区 `shared/skills/developer/SKILL.md` 执行本次 eval；未联网，未修改文件。

**执行结论：阻断**

我不能直接实现 Task T2，也不能进入 TDD 的 RED 阶段。原因是 developer skill 的前置条件不满足：

- 缺少 `work_dir` / `unit_work_dir`：无法定位任务工作区，也无法输出 `{unit_work_dir}/tasks/{task_id}/developer-report.json`
- 缺少 `{phase_dir}/design.json`：skill 明确规定缺失 `design.json` 时终止并报告 `delivery-owner`
- 缺少 AC 列表：无法为每条 AC 建立 RED/GREEN 证据
- 缺少文件范围：skill 明确禁止修改声明范围外文件；没有文件范围时不能猜测目标文件
- 只有一句 bug 描述：属于“任务描述不清晰”，按异常处理必须提问等待澄清

**流程边界**

developer skill 只负责在上游已经给出 Task 全量信息后，按 AC 和设计约束做最小 TDD 实现。它不负责补需求、补设计、猜文件范围，也不负责把一句描述扩写成可实现任务。

**向 delivery-owner 提问**

请 delivery-owner 补齐以下派发信息后再进入 developer 流程：

1. Task T2 的 `unit_work_dir` / `work_dir`
2. `{phase_dir}/design.json` 路径，并确认文件存在
3. Task T2 的完整 AC 列表
4. Task T2 的声明文件范围，包括允许修改的源码文件与测试文件
5. 如有，补充 `design_refs`、`test_refs`、`shared_files` 和 `artifact-registry.json` 位置

**下一步**

等待 delivery-owner 补齐上述信息。补齐前，本次任务保持 `BLOCKED`，不进入 TDD，不探索实现，不修改代码。