# 关键假设验证

## 每轮回应结构

- 回复前读取当前步骤 reference、Director baseline、当前 JSON 工件和已闭合 PM checkpoint。
- 第一段用一句话复述已冻结事实、当前 PM 步骤目标，以及本步骤已闭合结论。
- 第二段给一个 PM 推荐结论草案；草案包含推荐结论、推荐理由和会改变结论的未闭合业务假设。
- 只有业务事实会改变 UNIT 闭环、AC 可验收性、Verification Plan、design handoff、评审结论或交付确认时，才列出 2-3 个业务场景分支；每个分支包含触发条件和默认推荐。
- 最后一段只暴露一个会改变写入结果的假设：默认写入 X，依赖事实 Y；若 Y 不成立，只接收替换事实，不要求用户选择方法。
- 发出关键假设验证后暂停；业务事实回应前不写最终 `brief.json / phase-prd.json / units/UNIT-*.json` 结论。

## 业务事实回应处理

- 回应中的业务事实支撑关键假设时，将 PM 推荐结论作为当前步骤结论写入 checkpoint，再进入下一步。
- 回应包含当前步骤替换事实时，重写当前步骤草案并再次按每轮回应结构验证关键假设。
- 回应包含 Director 锁定字段、Phase 边界、范围或约束事实的替换事实时，回退 `/product-director`。
- 回应接受默认路径时，继续使用 PM 默认推荐；只有会改变最终 JSON 正确性的关键假设仍未闭合时，按每轮回应结构验证该假设。
- 回应包含多个事实时，只处理会影响当前步骤结论的事实；其余事实登记为后续步骤候选线索。
- 关键假设闭合后的结论只写入 `brief.json / phase-prd.json / units/UNIT-*.json` 支持的字段；人类投影视图只渲染这些 JSON 字段。

## 不同环节回应方式

| 回应方式 | 行为 |
| --- | --- |
| 静默扫描 | 校验 handoff、读取工件、扫描缺口；不输出 PRD、UNIT 或 AC 草案。 |
| 关键假设确认 | 从已冻结事实生成 PM 推荐结论草案，验证一个会改变结论的具体业务假设。 |
| 业务草案确认 | 基于已有草案重写不确定部分；用 `[?]` 标出未闭合的示例输入、预期结果、边界情况、失败模式、验证操作或可观察结果。 |
| 条件缺口确认 | 先扫描开放问题或完整性缺口；无缺口时继续；有缺口时只暴露会影响 design handoff 或执行性的事实缺口。 |
| 评审收敛 | 汇总 FAIL、WARN、承接目标和 gate 结果；FAIL 未关闭时回到修复步骤；无 FAIL 时进入交付确认。 |
| 收口确认 | 汇总 PASS/WARN、未关闭 FAIL、WARN 承接目标和阻断事实；无未关闭 FAIL 才进入交付确认。 |
| 交付确认 | 汇总已闭合产物路径、gate 命令和交付确认字段；只接受明确交付确认，不引入新业务事实。 |

## 关键假设模板

- 准入验证：`缺少 brief.json 或 phase-prd.json 时阻断；handoff 工件缺失时回到 /product-director 重签。`
- UNIT Integration Context：`我将把 X 作为本 UNIT 的 Integration Context，除非 Y 依赖不成立；若 Y 不成立，给出替换事实。`
- 示例驱动 AC：`我将把 X 作为验收示例，除非 Y 不是用户真实操作；若 Y 不成立，给出替换事实。`
- Verification Plan：`我将用 X 业务操作证明 AC，除非 Y 观察结果不可见；若 Y 不成立，给出替换事实。`
- 结构化待设计决策：`我将把 X 交给 /design 收口，除非 PM 已能基于 Y 业务事实收口；若 Y 不成立，给出替换事实。`
- AI 可执行性：`我将先修复 X FAIL 并把 Y WARN 写入 issue_ledger；若 Y 不需要承接，给出替换事实。`

## 回退触发

- 用户要求改变 Phase 边界、交付价值、Director 锁定规则或约束事实时，回退 `/product-director`。
- Integration Context 出现文件路径、接口方案或架构落点时，改写为业务约束或交给 `/design`。
- AC 只复述需求且缺少示例输入、预期结果、边界情况或失败模式时，回到当前 UNIT 的 AC 草案确认。
- Verification Plan 出现测试命令、测试框架或 Mock 策略时，改写为业务操作和预期观察。
- 待设计决策已包含技术答案时，改写为候选选项、约束、影响 UNIT 和 design handoff。
- `director_confirmation.locked_fields` 或 `locked_field_digest` 会被改动时，停止 PM 细化并回退 `/product-director`。
