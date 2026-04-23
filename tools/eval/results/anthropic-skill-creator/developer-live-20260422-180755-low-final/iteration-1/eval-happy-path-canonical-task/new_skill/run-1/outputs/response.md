我按 `shared/skills/developer/SKILL.md` 复核后，结论是：**当前这次 eval 只能阻断，不能进入真实 TDD**。

阻断原因很明确：

- 你指定的 `work_dir=tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1` 下，实际只有 `test-cases.json`
- 该目录下缺少 skill 强制要求的 `design.json` 和 `tasks.json`
- 运行时报告模板 `developer-report.template.json` 也没有在当前 workspace 中找到
- 但 `phase-1/` 级别确实存在 canonical 的 `design.json`、`tasks.json`、`plan.json`、`artifact-registry.json`，说明这次输入路径和 skill 预期的单位工作区不一致

按 skill 规则，这种情况不能猜测补齐，必须先阻断并让上游补齐前置条件。

如果前置条件齐全，我会这样执行：

1. **拆解**
- 先读 `design.json`、`tasks.json`、`test-cases.json`
- 把 `T1` 拆成一条条 AC 对应的最小实现步骤
- 明确每步的目标文件、复用点、风险点、验证方式
- 形成 mini-plan，再开始 TDD

2. **RED**
- 从 `test-cases.json` 里取 `TC-T1-1`
- 先写能覆盖 `AC-T1-1` 的失败测试
- 先跑测试，确认它**真实失败**
- 失败证据会记录到 `tdd_evidence_index`

3. **GREEN**
- 只做满足 `T1` AC 的最小改动
- 重新跑同一组测试，确认全部通过
- 不做超范围实现，不碰任务外文件

4. **REFACTOR**
- 在测试保护下清理结构、重复代码、命名
- 重跑测试，确保绿灯不回退

5. **自测**
- 对照 `test-cases.json` 检查覆盖是否完整
- 跑全量回归
- 跑静态分析：`lint`、`typecheck`、`build`
- 如适用，再做真实冒烟和 E2E
- 每一项都要能落到报告里，不能只写“已验证”

6. **developer-report.json 输出**
- 写入任务级 canonical 报告
- 必须包含：
  - `evidence_refs`
  - `reviewable_anchor`
  - `file_changes`
  - `tdd_evidence_index`
  - `task_scope`
- 每个 AC 都要有 RED/GREEN 证据链
- 如果仍然是阻断状态，`runtime_status` 只能写 `BLOCKED`

当前这次 eval 的最终状态是：

- `RED/GREEN`: **未执行**
- `自测`: **未执行**
- `developer-report.json`: **无法生成符合 skill 要求的最终版**
- 原因：`unit-1/design.json`、`unit-1/tasks.json` 缺失，且报告模板不在当前 workspace 中

如果你要，我下一步可以继续做两种事之一：

1. 帮你把这次 eval 的**阻断报告**整理成一份规范的 `developer-report.json` 骨架
2. 先按 `phase-1/` 的 canonical 事实源，帮你确认这次正确的 `work_dir` 应该指向哪里