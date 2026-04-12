# QA 阶段义务矩阵

## 目标
把 `test-design` 输出的 `QA 交接契约` 收束成 `qa` 的唯一执行模型，避免阶段职责漂移。

## 阶段归属

| 阶段 | 必须承接的测试义务 | 允许承接的条件义务 | 不做什么 |
|------|--------------------|--------------------|----------|
| QA_A | 冒烟、AC/功能、API/接口、MOD/约束验收 | 被明确分配到 QA_A 的 NFR | 不负责完整旅程和自由探索 |
| QA_B | 完整旅程、异常恢复、UX 检查点 | 被明确分配到 QA_B 的 NFR | 不负责替代 QA_A 的逐条 AC 验收 |
| QA_C | 回归、影响面验证 | 性能/契约等回归型 NFR | 不负责创造性探索 |
| QA_D | 风险章程、探索发现 | 被章程纳入的恢复/UX/NFR 追问 | 不负责基础门禁替代 |
| NFR | 不是独立阶段 | 由 `test-design` 触发后挂到 QA_A/B/C/D | 不允许脱离业务义务单独漂浮 |

## requiredness 解释

| 值 | 含义 | QA 行为 |
|----|------|---------|
| REQUIRED | 每次都必须执行 | 不得写 `N/A` |
| CONDITIONAL | 命中触发条件才执行 | 未命中时必须落盘 `not_executed_reason` |

## execution_mode 解释

| 值 | 含义 | QA_B 行为 |
|----|------|-----------|
| browser_required | 必须通过浏览器验证真实 Web/H5 入口与页面反馈 | 仅允许浏览器 E2E；必须写 `browser_tool` + `entry_url` + `browser_evidence` |
| non_browser_ok | 可用 API/CLI/服务级入口完成闭环验证 | 仍需保证真实入口与状态闭环，不得退化成单接口验证 |

## 执行原则
- `qa` 只能承接 `test_cases_ref` 已声明的义务，不能自行省略或新增强制义务。
- `qa` 可以补充风险探索，但补充项必须写进报告，不得伪装成原始交接契约。
- 任一被触发义务未执行时，必须在 `## 非执行项记录` 中写明 `stage_or_obligation + not_executed_reason`。
- 任一 `QA_B` 义务标记为 `browser_required` 时，不得用 API/CLI 结果替代浏览器证据。
- `browser_required` 所需证据拿不到时，必须标记 BLOCKED 并回传 `project-manager`，禁止静默降级成非浏览器验证。
- `not_executed_reason` 不是结束语；若原因触及环境、依赖、范围或交接契约缺失，必须升级给 `project-manager`。
