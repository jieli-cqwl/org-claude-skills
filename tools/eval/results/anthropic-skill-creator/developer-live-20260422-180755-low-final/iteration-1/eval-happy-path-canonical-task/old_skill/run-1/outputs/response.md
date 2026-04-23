我会按 `sample-feature/phase-1/unit-1` 这个工作区来处理 `T1: freeze foundation contracts`，目标是把 `AC-T1-1` 对应的 foundation contracts 拆成可验证、可回填到 `developer-report.json` 的 TDD 证据链。

先说结论：前置条件是满足的。
- `design.json`、`tasks.json`、`test-cases.json` 都存在
- `T1` 的设计引用和测试引用都能解析到 canonical 条目
- `artifact-registry.json` 也存在，且 active revision 可用
- 这次 eval 明确说“不要求实际改代码”，所以我会只输出执行拆解和报告应如何组织，不做代码写入

**我会这样拆解 T1**
1. 代码探索
- 读取 `design.json` 的 `key_decisions`、`interface_boundary`、`verification_plan`
- 读取 `tasks.json` 里 `T1` 的 `design_refs`、`test_refs`
- 读取 `test-cases.json` 里的 `TC-T1-1`
- 结合 `artifact-registry.json` 确认当前 consumable 版本是 `plan-v2` / `tasks-v2`

2. 模式识别与复用判断
- 识别这个 task 的核心不是业务功能，而是“foundation contract 冻结”
- 复用对象应是 canonical registry / schema / template / catalog 这类基础设施约束
- 判断重点是：active artifact 路径、schema 约束、canonical tree 是否一致，而不是新增运行时行为

3. 步骤规划
- Step A: 对照 `AC-T1-1` 和 `TC-T1-1`，确认测试意图是“foundation catalog and schema contracts validate active artifacts”
- Step B: 设计 RED 用例，先让契约校验失败，证明测试不是空的
- Step C: GREEN 时只做最小修复，让 active artifacts、schema、catalog 一致通过
- Step D: REFACTOR 仅做不改变行为的整理；如果没有可整理项，标记 `REFACTOR: no-op`
- Step E: 自测时跑回归、静态分析、冒烟/端到端适用性检查
- Step F: 把每一步证据写回 `developer-report.json`

4. 风险标注
- 这次最主要的风险是“范围外文件误改”或“把上游 canonical 设计真源当成本次任务修改对象”
- 另一个风险是如果 `file_range/files/task_scope` 没有明确给出，就不能进入真实代码改动
- 但就当前 eval 来看，`T1` 是说明型任务，所以不会碰到实际改动边界

5. 确认结果
- 不需要向 delivery-owner 追问
- 可以进入说明性输出，不阻断

**如果这是实际执行，我会按 RED / GREEN / REFACTOR 这样跑**
- RED
  - 先针对 `TC-T1-1` 跑一个只读的 contract 校验
  - 预期在基线状态下能暴露出某个 foundation contract 不满足，或者至少确认测试能捕获契约偏差
  - 证据要记录为 `FAIL_EXPECTED`
- GREEN
  - 做最小修复，只让 foundation contract 满足 `design.json` 和 registry 约束
  - 重新跑同一条测试，必须变成 `PASS`
- REFACTOR
  - 如果没有可抽取的公共逻辑，就写 `no-op`
  - 若有整理，也必须保持测试全绿

**自测我会这样安排**
- 先审视 `test-cases.json` 是否覆盖 `T1`
- 再跑完整回归，确认没有旁路失败
- 再跑静态分析：lint / type / build
- 如果这个 eval 没有真实服务或 UI 场景，就在报告里标注 `smoke: not applicable`、`e2e: not applicable`，并说明原因
- 最后做自审，核对：
  - `AC-T1-1` 是否有 RED/GREEN 证据
  - 是否没有超范围修改
  - `developer-report.json` 是否包含 `evidence_refs`、`reviewable_anchor`、`file_changes`、`tdd_evidence_index`、`task_scope`

**`developer-report.json` 我会这样输出**
- `runtime_status`: 只有在前置条件缺失时才写 `BLOCKED`
- `task_scope`: 记录本次允许操作的对象
- `file_changes`: 这次 eval 不改代码的话就写空数组
- `tdd_evidence_index`: 按 AC 逐项列出 RED / GREEN / test_ref / evidence_ref
- `reviewable_anchor`: 指向能复核 TDD 证据的一手位置
- `self_test`: 记录回归、静态分析、冒烟、E2E 是否执行及结果

如果你愿意，我下一步可以直接把这个任务的 `developer-report.json` 完整骨架按 canonical 字段格式写出来，仍然保持“只说明、不改代码”。