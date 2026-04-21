结论：**阻断（BLOCK）**，本次 **QA 不执行**。

**流程边界**
- 我只做前置条件校验，不进入 `QA_A / QA_B / QA_C / QA_D`。
- 不启动真实服务，不做浏览器 E2E，不产出放行结论。
- `code-review-result.json` 只能作为输入之一，不能替代独立 QA 基线。

**阻断条件**
- 缺少 `test_cases_ref / test_cases_refs`，也就是缺少可引用的 `test-cases.json`。
- 缺少 `## QA 交接契约`，因此没有 `execution_mode` 可读。
- 既然没有交接契约，就**不能自行推测** `browser_required`。
- 也不能自行扩展或猜测本次验收范围、旅程覆盖和回归边界。
- 另外，我在当前工作区可见内容里也没有看到项目侧的基线 JSON，可执行验收输入不足。

**下一步**
- 先补齐 `test-cases.json`，并确保其中包含带 `execution_mode` 的 `## QA 交接契约`。
- 然后再按 skill 顺序读取 `brief.json`、`phase-prd.json`、`UNIT-*.json`，再决定 `scope` 并执行对应 QA 阶段。
- 如果仍然只做局部验证，要明确哪些阶段未执行，并写出对应 `not_executed_reason`。

如果你把缺失的 QA 交接契约补上，我可以继续按 skill 重新进入验收流程。