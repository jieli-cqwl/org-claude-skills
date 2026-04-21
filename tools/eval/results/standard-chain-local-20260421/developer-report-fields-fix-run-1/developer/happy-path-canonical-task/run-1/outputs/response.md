**复述理解**

你要我按当前工作区的 `shared/skills/developer/SKILL.md` 执行一次 developer skill eval：围绕 Task `T1`，在 `docs/customer/phase-1/unit-1` 下，以 `src/customer/remark.ts`、`tests/customer/remark.test.ts`、`docs/customer/phase-1/unit-1/tasks/T1/developer-report.json` 为唯一文件范围，说明如何按 AC 做 TDD 拆解、RED/GREEN、自测，并输出 canonical `developer-report.json` 的关键字段。

我已遵守约束：未联网、未修改文件。

**Skill 边界与阻断**

按 developer skill，实际执行必须以 canonical JSON 和 active `artifact-registry.json` 为事实源，且前置条件包括：

- Task 需求全文：AC、文件范围、`design_refs`、`test_refs`
- `{phase_dir}/design.json`
- `{phase_dir}/tasks.json`
- `{phase_dir}/artifact-registry.json` 或 active registry
- 如存在 `{unit_work_dir}/test-cases.json`，必须作为自测驱动源
- 输出只能写 canonical JSON 报告，模板来自 `contracts/canonical/templates/runtime/developer-report.template.json`

当前 eval prompt 能解析出：

- `task_id`: `T1`
- `unit_work_dir`: `docs/customer/phase-1/unit-1`
- AC:
  - `AC-1`: 新增客户备注字段校验
  - `AC-2`: 保存成功后写入 `developer-report.json`
- 文件范围:
  - `src/customer/remark.ts`
  - `tests/customer/remark.test.ts`
  - `docs/customer/phase-1/unit-1/tasks/T1/developer-report.json`

但实际执行被阻断：

- 当前工作区未找到 `docs/customer/phase-1/unit-1`
- 当前工作区未找到 `src`、`tests`
- eval prompt 未提供 `design_refs`、`test_refs`
- 未发现 `tasks.json`、active `artifact-registry.json`
- 未发现 `contracts/canonical/templates/runtime/developer-report.template.json`
- 用户明确要求“不要修改文件”，因此不能写测试、实现或生成最终 `developer-report.json`

所以本轮不能宣称完成 Task，也不能产出最终工件。按 skill 规则，实际执行结论是 `BLOCKED`，下一步应由 delivery-owner 提供完整 canonical 输入、正确工作区工件和写入许可。

**执行拆解口径**

若前置条件齐全，我会先完成 1a-1e：

1. 代码探索  
读取已存在的 `src/customer/remark.ts`、`tests/customer/remark.test.ts`，解析 `design.json` 中 `design_refs` 指向的 canonical 片段，读取 `test-cases.json` 中 `test_refs` 对应测试用例，并探索 `src/customer/`、`tests/customer/` 同级文件，识别校验和保存模式。

2. 模式识别与复用判断  
确认备注字段已有无语义一致校验函数、错误格式、边界规则、测试框架、断言风格。若已有可复用 validator 或 error helper，优先复用；若新建实现，必须说明不复用原因。

3. 步骤规划  
把 AC 拆成 TDD 步骤，每步绑定 AC、目标文件、参考模式和复用对象。

4. 风险标注  
`design.json` 不在文件范围内，因此发现接口微调也不能直接同步设计，只能上报 delivery-owner。若备注校验规则在 `design_refs/test_refs` 中缺失，也必须阻断，不能自行猜测最大长度、空值策略或字符规则。

5. 确认或提问  
若规则、测试引用和范围清晰，记录 mini-plan 后进入 TDD；若缺少规则或引用，停止并向 delivery-owner 提问。

**RED/GREEN 计划**

`AC-1 新增客户备注字段校验`

- RED：在 `tests/customer/remark.test.ts` 增加由 `test-cases.json` 推导的失败用例，例如空值、超长、非法字符、仅空白、边界长度等，具体用例必须来自 canonical `test_refs`。运行目标测试，期望失败，记录为 `FAIL_EXPECTED`。
- GREEN：在 `src/customer/remark.ts` 最小实现备注字段校验，复用项目已有错误处理和校验模式。再次运行目标测试，必须 `PASS`。
- REFACTOR：仅在测试保护下清理重复逻辑，不越出文件范围；重跑目标测试保持 `PASS`。
- 证据要求：测试命令、失败摘要、通过摘要、`test_ref`、AC 映射、证据锚点。

`AC-2 保存成功后写入 developer-report.json`

- RED：在实现完成前，报告文件不存在或缺少该 AC 的 TDD 证据索引、文件范围记录、自测记录，应视为报告验收失败。
- GREEN：在所有 RED/GREEN、自测、自审完成后，写入 `docs/customer/phase-1/unit-1/tasks/T1/developer-report.json`，并确保包含 AC-1、AC-2 的证据索引和可审查锚点。
- 证据要求：报告 schema 校验或结构检查通过；`tdd_evidence_index` 中每个 AC 有 RED `FAIL_EXPECTED`、GREEN `PASS`、`test_ref`、`evidence_refs`。

**自测层面**

完成 TDD 后必须执行 5 层自测：

1. 测试完备性审视：对照 `test-cases.json` 检查 AC、边界、错误路径、排除项。
2. 全量回归：运行完整测试套件，不只跑新增测试。
3. 静态分析：运行 lint、类型检查、构建。
4. 功能集成冒烟：若只是纯校验/库代码，标注“不适用”并说明理由；若涉及真实保存链路，启动真实服务并验证 happy path。
5. E2E：有前端或 E2E 框架时执行；无对应链路时标注“不适用”并说明理由。

**developer-report.json 关键字段**

按 skill 要求，canonical 报告必须显式包含：

- `task_scope`: task id、AC、允许修改文件范围
- `execution_decomposition`: 代码探索、复用判断、步骤规划、风险、确认记录
- `tdd_evidence_index`: 每个 AC 的 RED/GREEN 证据，含 `FAIL_EXPECTED`、`PASS`、`test_ref`
- `evidence_refs`: 测试、自测、静态分析、回归命令的一手证据引用
- `reviewable_anchor`: verify/review 可抽查的证据锚点
- `file_changes`: 每个变更文件、变更原因、是否在范围内
- `self_testing`: 5 层自测结果
- `self_review`: 7 维自审结论
- `interface_change_log`: 若有接口微调或重大变更，按规则记录；本任务中 `design.json` 未入范围，不能直接修改

**下一步**

请 delivery-owner 补齐 canonical Task 输入：正确的 `work_dir` 文件、`tasks.json`、active `artifact-registry.json`、`design_refs`、`test_refs`、developer-report 模板，并允许写入上述三个范围内文件。补齐后才能按 developer skill 进入真实 RED/GREEN 执行。