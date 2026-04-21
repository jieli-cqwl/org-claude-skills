**理解复述**

本次 eval 的操作对象是 `shared/skills/developer/SKILL.md` 下的 developer 流程，Task 为 `T1`，`unit_work_dir=docs/customer/phase-1/unit-1`。目标 AC 是：

- `AC-1`：新增客户备注字段校验
- `AC-2`：保存成功后写入 `developer-report.json`

声明文件范围是：

- `src/customer/remark.ts`
- `tests/customer/remark.test.ts`
- `docs/customer/phase-1/unit-1/tasks/T1/developer-report.json`

预期结果不是直接改代码，而是按 developer skill 判断前置条件、说明 TDD 拆解、自测与报告输出边界。本轮已遵守：未联网、未修改文件。

**当前阻断**

我已读取 `shared/skills/developer/SKILL.md` 及其执行拆解、自测、自审方法论。按 skill，真实执行前必须先读取并解析：

- Task 需求全文：AC、文件范围、`design_refs`、`test_refs`
- `{phase_dir}/design.json`
- `{phase_dir}/tasks.json`
- `{phase_dir}/artifact-registry.json` 或 active registry
- `{unit_work_dir}/test-cases.json`，存在时必须作为自测驱动源

当前工作区检查结果：`docs/` 目录不存在，也未找到 `design.json`、`tasks.json`、`test-cases.json`、`artifact-registry.json`。因此不能进入真实 RED/GREEN，不能写 `src/customer/remark.ts`、不能写测试、不能生成最终 `developer-report.json`。

整体结论：部分完成 / 阻塞。阻塞原因是 canonical 输入工件缺失，且本轮约束为只读、不改文件。

**流程边界**

developer skill 只负责按已确认的 Task AC 和设计约束做最小实现，不负责定义需求、设计决策或测试设计。不能仅凭“客户备注字段校验”自行发明长度、空值、字符集、错误码等规则；这些必须来自 `design.json`、`tasks.json`、`test-cases.json` 或 active registry。

另一个边界：`design.json` 不在声明文件范围内。若实现中发现接口字段、校验规则或响应结构需要同步设计，只能报告 delivery-owner；不能直接修改 `design.json`。

**前置满足后的执行拆解**

1. `1a 代码探索`  
   读取已存在的 `src/customer/remark.ts`、`tests/customer/remark.test.ts`，读取 Task 的 `design_refs` / `test_refs`，解析 canonical 设计片段和测试用例；再查看 `src/customer/`、`tests/customer/` 同级文件，搜索已有备注、校验、保存逻辑。

2. `1b 模式识别与复用判断`  
   识别导出方式、校验函数命名、错误对象格式、测试框架、断言风格、fixture 方式；搜索可复用的字段校验工具。若不复用已有实现，必须记录原因。

3. `1c TDD 步骤规划`  
   - `AC-1 RED`：在 `tests/customer/remark.test.ts` 增加客户备注字段校验失败用例，规则来自 `test-cases.json` 或 AC 对应 test_ref；先运行目标测试，确认失败结果为预期失败。
   - `AC-1 GREEN`：在 `src/customer/remark.ts` 最小实现备注校验，让新增失败用例转为通过。
   - `AC-1 REFACTOR`：在测试保护下清理重复逻辑，重跑目标测试。
   - `AC-2 RED`：先确认 AC-2 的 canonical 语义。若它是交付报告要求，则以报告缺失或缺少 canonical 字段作为 RED 证据；若它是运行时代码行为，则必须从 design/test_refs 写保存成功后的可失败测试。
   - `AC-2 GREEN`：写入 `docs/customer/phase-1/unit-1/tasks/T1/developer-report.json`，并让报告检查或对应测试通过。

4. `1d 风险标注`  
   重点记录三类风险：校验规则来源缺失、AC-2 语义不清、需要修改范围外文件。出现任一项都报告 delivery-owner。

5. `1e 确认或提问`  
   当前因 canonical 工件缺失，不能进入 TDD；下一步是要求 delivery-owner 补齐工件或提供 active registry。

**自测层面**

TDD 通过后必须执行 5 层自测并写入报告：

- 测试完备性：逐条对照 `test-cases.json` 或 AC，确认 AC-1/AC-2 都有覆盖
- 全量回归：运行完整测试套件，不能只跑新增测试
- 静态分析：运行 lint、类型检查、构建
- 功能集成冒烟：涉及真实服务或保存链路时执行；纯函数则记录不适用理由
- E2E：有前端或端到端框架时执行；无框架则记录不适用理由

**developer-report.json 关键字段**

最终报告必须是 canonical JSON，至少显式包含：

- `artifact_type: "developer-report"`
- `task_id: "T1"`
- `task_scope`
- `evidence_refs`
- `reviewable_anchor`
- `file_changes`
- `tdd_evidence_index`
- 自测结果
- 自审结果
- 接口变更记录，若无变更也要记录无变更结论

`tdd_evidence_index` 必须按 AC 记录 RED/GREEN：RED 的结果是 `FAIL_EXPECTED`，GREEN 的结果是 `PASS`，并包含 `test_ref` 与可追溯证据引用。

**下一步**

请 delivery-owner 提供或恢复 `docs/customer/phase-1/unit-1` 下的 canonical 工件，尤其是 `design.json`、`tasks.json`、`test-cases.json`，以及 `artifact-registry.json` 或 active registry；同时解除只读限制后，才能按 developer skill 从 `1a 代码探索` 开始真实执行 TDD。