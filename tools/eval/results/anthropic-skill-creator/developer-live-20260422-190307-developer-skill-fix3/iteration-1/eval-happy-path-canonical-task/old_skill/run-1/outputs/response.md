我按 `developer` skill 的要求理解，这个 T1 在当前 workspace 里属于“只说明执行方式，不实际改代码”的 eval。基于我读到的工件：

- [phase-1/design.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-w_sgf6e9/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json)
- [phase-1/tasks.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-w_sgf6e9/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json)
- [phase-1/unit-1/test-cases.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-w_sgf6e9/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json)
- [phase-1/unit-1/tasks/T1/developer-report.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-w_sgf6e9/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json)

我会这样拆解和执行：

1. 先做前置校验
- 识别 T1 的唯一 AC：`AC-T1-1`
- 对照 `tasks.json` 和 `test-cases.json`，确认它覆盖的是“foundation contracts validate active artifacts”
- 发现一个关键阻断点：当前 `tasks.json` 里没有显式 `file_range/files/task_scope` 可用于代码改动范围收敛
- 按 skill 规则，真实实现阶段我会先停在这里，不进入代码修改，只向 delivery-owner 要补齐范围

2. RED 阶段
- 从 `test-cases.json` 反推测试意图，优先围绕 `TC-T1-1`
- 若有可执行测试骨架，我会先写一条最小失败测试，验证“foundation catalog and schema contracts validate active artifacts”
- RED 的判定标准是：测试必须先失败，而且失败原因要和 AC 对齐
- 这一步的证据会记录到 `tdd_evidence_index` 里，`phase: "RED"`，`result: "FAIL_EXPECTED"`

3. GREEN 阶段
- 只做满足 AC 的最小实现
- 只碰声明范围内的文件
- 目标是让 RED 那条测试变绿，且不引入额外行为
- GREEN 的证据同样写入 `tdd_evidence_index`，`phase: "GREEN"`，`result: "PASS"`

4. REFACTOR 阶段
- 如果没有可重构点，就明确记 `REFACTOR: no-op`
- 如果有结构清理，也只能在测试仍然全绿的前提下做
- 这一步不扩展 AC 范围

5. 自测阶段
按 skill 要求，我会补齐这几类验证，并把结果写进报告：
- 测试完备性审视：对照 `test-cases.json` 检查 AC 覆盖是否完整
- 全量回归：跑项目内完整测试套件
- 静态分析：lint、typecheck、build
- 冒烟：如果有真实运行入口，就跑一次真实路径验证
- E2E：如果有端到端场景，就按用例执行；没有就写明不适用原因

6. `developer-report.json` 输出方式
如果是真实交付，我会把报告写到：
- `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json`

报告里我会确保这些字段完整：
- `runtime_status`
- `active_plan_version_ref`
- `active_tasks_version_ref`
- `evidence_refs`
- `reviewable_anchor`
- `file_changes`
- `tdd_evidence_index`
- `task_scope`

结合当前这次 eval 的限制，`file_changes` 和 `task_scope` 在真实实现前会保持空数组，并把阻断原因写清楚；因为没有明确文件范围，我不会假装已经完成代码实现。

如果你要，我下一步可以直接按这个 T1 生成一份“可提交的 `developer-report.json` 骨架”，内容会严格对应当前工件。