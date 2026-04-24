我会直接阻断，不交给 `verify`。

结论：`developer-report.json` 不完整，状态应标记为 `BLOCKED / INCOMPLETE`。只有 `file_changes` 和 `summary` 不能证明开发已按 TDD 完成，也不具备可审查锚点。

缺失的必需门禁：

- `tdd_evidence_index`
- `reviewable_anchor`
- `self_testing`
- 每条 AC 对应的 RED 证据：`FAIL_EXPECTED`
- 每条 AC 对应的 GREEN 证据：`PASS`

处理方式：拒绝“先交付、后补证据”。必须回到 TDD 证据链，按每条 AC 补齐 RED → GREEN 证据、自测结果和可审查定位后，再重新整理报告交给 `verify`。

在补齐前，不能宣称完成，不能进入 verify，不能把这份摘要当作合格 developer 交付。