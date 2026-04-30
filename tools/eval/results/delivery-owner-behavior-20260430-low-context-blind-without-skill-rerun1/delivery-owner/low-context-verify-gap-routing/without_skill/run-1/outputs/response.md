理解：T2 开发报告声称 AC-2 完成，但最新 `verify-result=FAIL`，失败点是 AC-2 只有结论、缺少 scope evidence。因此当前不能推进到 QA、提交或交付确认。

**交付决策**
`BLOCKED`

**门禁结论**
- `developer_report`: 不可采信为完成证据，只能作为开发方声明。
- `verify_result`: 最新结果为 `FAIL`，优先级高于开发报告。
- `AC-2`: 阻断，缺少 scope evidence。
- `next_stage`: 不进入 QA / commit / release。

**流程边界**
- 交付负责人只做调度、门禁判断和证据验收。
- 不替开发方补写结论型证据。
- 不绕过 verifier 的 FAIL。
- 不用“开发说完成了”替代验收证据。

**下一步安排**
把 T2 退回开发侧补齐 AC-2 的 scope evidence，要求至少包含：
- AC-2 覆盖到的代码/配置/数据流/用户路径范围。
- 对应变更点与 AC-2 的映射。
- 能直接证明 AC-2 的 fresh proving command 及输出。
- 若 AC-2 实际未完全覆盖，开发侧先修复，再重新提交报告。

补齐后重新触发 T2 verify。只有最新 verify-result 变为 `PASS`，才能继续后续交付链路。