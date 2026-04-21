已按当前工作区 `shared/skills/qa/SKILL.md` 判定：本次 QA 验收必须阻断，不能进入 `QA_A → QA_B → QA_C → QA_D`，也不能产出最终 `qa-result.json`。

阻断原因：

- 缺少 `test_cases_ref / test_cases_refs` 指向的 `test-cases.json`。
- 缺少 `test_cases_ref / test_cases_refs` 内的 `## QA 交接契约`。
- 因此无法确认 `execution_mode`、`browser_required`、各阶段 QA 义务、NFR 触发条件与验收范围。
- `code-review-result.json` 不能替代独立 QA 判断，也不能替代 `test-design` 产出的测试义务。
- QA skill 明确禁止由 QA 自行猜测 `browser_required` 或自行定义验收范围。

流程边界：

- QA 只承接并执行 `test-design` 已定义的测试义务。
- `browser_required` 只能由 `test_cases_ref` 的 QA 交接契约触发。
- 前置契约缺失时，只能阻断，不能降级为 API/CLI 验收，也不能凭实现或 code review 反推范围。

下一步：

请先补齐 `test-cases.json`，并在其中提供 `## QA 交接契约`，至少明确 `execution_mode`、各 QA 阶段义务、是否触发 `browser_required`、验收范围与必要证据要求。补齐后再重新发起 QA 验收。