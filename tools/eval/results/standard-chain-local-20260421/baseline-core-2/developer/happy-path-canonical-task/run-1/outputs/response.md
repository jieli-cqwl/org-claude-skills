我按 `shared/skills/developer/SKILL.md` 读取并执行 eval 判定。理解如下：操作对象是 Task `T1`，目标工作区是 `docs/customer/phase-1/unit-1`，目标文件范围限定为：

- `src/customer/remark.ts`
- `tests/customer/remark.test.ts`
- `docs/customer/phase-1/unit-1/tasks/T1/developer-report.json`

预期结果是按 developer skill 说明执行拆解、RED/GREEN、自测与报告字段，但本轮约束是“不联网、不修改文件”，所以不能真实写测试、改实现或生成 `developer-report.json`。

**阻断结论**

真实执行被阻断，不能进入 TDD，也不能产出最终工件。

原因：

- 当前工作区中 `docs/customer/phase-1/unit-1` 不存在；我已执行读取检查，结果为 `No such file or directory`。
- developer skill 的前置条件不只要求 `design.json` 和 `test-cases.json`，还要求 `{phase_dir}/tasks.json`、active `artifact-registry.json`，以及 Task 需求全文中的 `design_refs` / `test_refs` 可解析。
- 当前 eval prompt 给出了 AC 与文件范围，但没有提供 canonical `tasks.json`、active registry、`design_refs`、`test_refs`。按 skill 的 Runtime Authority，非 canonical 派发文本不能替代 canonical JSON 输入。
- `developer-report.template.json` 在当前工作区未找到；skill 要求输出 canonical JSON 报告，Markdown 模板只可做人类投影视图。

**流程边界**

按 developer skill，真实执行顺序必须是：

1. 执行拆解 1a-1e：代码探索、模式识别与复用判断、步骤规划、风险标注、确认或提问。
2. 对每条 AC 执行 TDD：先 RED，再 GREEN，再在测试保护下 REFACTOR。
3. 全流程自测：测试完备性、全量回归、静态分析、功能集成冒烟、E2E。
4. 自审：AC 完整性、TDD 完整性、自测证据、范围合规、代码规范、报告完整性、执行拆解遵循度。
5. 只在证据齐全时写入 `docs/customer/phase-1/unit-1/tasks/T1/developer-report.json`。

**前置补齐后的拆解计划**

AC-1：新增客户备注字段校验  
RED：在 `tests/customer/remark.test.ts` 增加失败用例，覆盖客户备注字段的合法值、空值、超长、非法字符或设计约束中定义的边界。证据要求是运行对应测试命令后，该新增测试先失败，失败原因指向当前缺少备注校验。  
GREEN：在 `src/customer/remark.ts` 最小实现备注字段校验，复用同目录或同项目已有校验/错误处理模式。证据要求是同一测试命令通过，且只修改声明范围内文件。  
REFACTOR：仅在测试保护下清理命名或局部结构，重跑对应测试保持通过。

AC-2：保存成功后写入 `developer-report.json`  
RED：在 `tests/customer/remark.test.ts` 或 Task 指定测试中增加保存成功后的报告写入断言，验证目标路径、关键字段、AC 证据与文件范围记录。证据要求是测试先失败，失败原因指向报告未写入或字段缺失。  
GREEN：按 canonical JSON 模板写入 `docs/customer/phase-1/unit-1/tasks/T1/developer-report.json`，记录 TDD、文件变更、自测、自审与接口变更信息。证据要求是测试通过，并且报告路径在声明文件范围内。  
REFACTOR：如报告构造逻辑有重复，只在现有测试保护下做最小清理。

**自测层面**

- 测试完备性：对照 `test-cases.json` 中 T1 的 `test_refs`，逐条确认 AC-1、AC-2 都有测试覆盖。
- 全量回归：运行完整测试套件，不能只跑新增测试。
- 静态分析：运行项目实际 lint、类型检查、构建命令。
- 功能集成冒烟：若 `remark.ts` 只是纯函数，记录“不适用”及理由；若涉及 API/DB/服务，则启动真实服务走 happy path。
- E2E：若存在前端到后端链路或 E2E 框架，按用例执行；否则记录“不适用”及理由。

**developer-report.json 关键字段**

报告需要落到 canonical JSON 对应字段，至少包含：

- Task 标识：`task_id = T1`、工作区、文件范围。
- 执行拆解：代码探索结论、复用候选、实现步骤、风险与发现、进入 TDD 的判断。
- TDD 记录：每条 AC 的测试描述、RED 证据、GREEN 证据、REFACTOR 记录。
- 自测结果：测试完备性、全量回归、静态分析、冒烟、E2E。
- 文件变更：每个文件的操作、涉及 AC、是否在范围内。
- 接口变更记录：无变更则明确记录无；发现设计接口问题则按 TWEAK/BREAK 规则处理。
- 自审结果：7 个维度的 PASS/FAIL 与备注。
- 整体状态：当前真实状态只能是 `BLOCKED`，原因是 canonical 前置与工作目录不可解析。

下一步是由 delivery-owner 补齐或确认 `docs/customer/phase-1/unit-1`、`tasks.json`、active `artifact-registry.json`、T1 的 `design_refs` / `test_refs`，以及 canonical `developer-report.template.json`。补齐后才能进入 RED 阶段。