我会把本次 eval 边界定为：只说明 Task `T1` 的 developer 执行方案，不读取 `shared/skills/developer/SKILL.md`，不联网，不实际改代码、不启动服务、不提交，也不真正生成 `developer-report.json`。

真实执行前必须先读取并解析：

- `work_dir=tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`
- `design.json`：确认设计边界、依赖、接口/数据约束、允许变更范围
- `tasks.json`：定位 `T1`，提取 AC、文件范围、实现范围、阻断条件
- `test-cases.json`：把测试用例映射到每条 AC，确定 RED/GREEN 证明命令
- 如链路要求，还要读取 active registry，确认任务状态、占用关系和可执行性

如果这些工件缺失、`T1` 不存在、AC 不明确、文件范围为空或超出允许范围，应阻断真实修改，只输出阻断原因和下一步补齐项。

执行拆解会按 AC 逐条做：

1. 解析 `T1` 的每个 AC，建立 `AC -> test_ref -> expected behavior -> target files` 映射。
2. RED：先写或定位能证明该 AC 尚未满足的测试，运行最小证明命令，记录失败输出。
3. GREEN：只在 `tasks.json` 允许的文件范围内做最小实现，重新运行对应测试直到通过。
4. REFACTOR：在测试保护下整理重复逻辑、命名和边界处理，不扩大行为范围。
5. 自测：至少覆盖单测/集成测试中与 `test-cases.json` 对应的命令；若涉及构建、类型或 lint，再补充对应证明命令。
6. 汇总影响范围：列出变更文件、覆盖 AC、通过命令、未覆盖风险和剩余阻断。

`developer-report.json` 关键字段应包含：

```json
{
  "task_id": "T1",
  "work_dir": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1",
  "status": "blocked_or_planned_or_completed",
  "ac_coverage": [],
  "changed_files": [],
  "red_results": [],
  "green_results": [],
  "self_test_commands": [],
  "self_test_results": [],
  "blockers": [],
  "risks": [],
  "next_steps": []
}
```

本 eval 的下一步不是执行代码，而是确认这些输入工件存在且 `T1` 可解析；满足后才进入真实 RED/GREEN 实现。