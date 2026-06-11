结论：当前这次 `test-design` 不能下发成完整测试义务，先阻断。

- 准入失败：`preflight_check` 没过。它要求的输入形态是 `docs/{feature}/phase-N`，但当前给到的是 `tests/fixtures/.../sample-feature`，且它还判定缺少 canonical 输入路径上的 `brief.json`、`phase-prd.json`、`design.json`、`units/`。
- 事实层面，现有 `design.json` 只有高层的 `migration_plan` / `rollback_plan`，没有把“历史记录可回滚”落到可测试的数据结构、版本迁移路径、回滚粒度、失败恢复点。也就是说，能看到“要回滚”，但看不到“怎么回滚、回滚什么、依据什么结构回滚”。

按 skill 规则，这是一个阻断型缺口，不能直接 handoff 给 `/tech-lead`。

**typed gap**
- `gap_type`: `DESIGN_GAP`
- `missing`: `history data structure`, `migration strategy`, `rollback strategy`, `observable outcome`, `assertion target`, `evidence expectation`
- `owner`: `product-manager`
- `required_artifact_ref`: `phase-1/design.json#migration_plan` / `phase-1/design.json#rollback_plan` 的等价上游补充，外加可追踪的历史记录数据结构定义
- `decision_needed`: 明确历史记录的存储结构、版本演进规则、回滚触发条件、回滚后可观测结果，以及失败时是否应 fail-closed
- `blocking`: `true`

下一步只能二选一：
1. 先补齐上游设计工件，再重新跑 `test-design`。
2. 如果你要我继续，我可以基于现有 JSON 先给出“缺口清单 + 应补字段列表”，但不会假装完成测试设计。