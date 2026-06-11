结论：这次 `test-design` 只能停在分析层，不能冻结测试义务，更不能 handoff。原因有两个，都是阻断级。

1. 形式准入失败  
- `preflight_check.sh` 直接失败：当前输入路径不是规范的 `docs/{feature}/phase-N` 结构，而是 fixture 路径。  
- 这意味着 canonical 准入没过，按 skill 规则不能继续往下产出最终 `test-cases.json`。

2. 实质设计缺口：回滚不可测  
- AC 明确要求“历史记录可回滚”。  
- 但 `design.json` 只有高层声明，没有可用于测试的回滚数据结构、迁移步骤、回滚策略细节。  
- 现有内容只能证明“有 rollback_plan 这个字段”，不能证明“历史记录可回滚”这件事可实现、可验证、可回退。

**Typed Gap**
- `gap_type`: `DESIGN_GAP`
- `product_refs`: `unit-1/acceptance_criteria[0]`
- `design_refs`: `design.json#data_architecture`, `design.json#migration_plan`, `design.json#rollback_plan`, `design.json#verification_mapping`
- `missing`:
  - `observable outcome`: 回滚成功后历史记录应呈现什么状态
  - `assertion target`: 哪个历史记录结构、版本字段或快照字段可被断言
  - `evidence expectation`: 需要什么前后对照证据、日志、或版本链证明回滚已发生且可恢复
  - 还缺少明确的数据结构、迁移路径、回滚触发条件与恢复边界
- `owner`: `design`
- `required_artifact_ref`: `design.json` 中补齐历史记录数据结构、迁移方案、回滚方案与对应验证映射
- `decision_needed`: 明确历史记录如何建模、如何迁移、失败时回退到哪个稳定状态、回滚后如何判定成功
- `blocking`: `true`

**下一步**
- 先补 `design.json` 的回滚模型和迁移/恢复策略，再重新跑 canonical preflight。
- 这一步没补齐前，不应进入测试用例冻结，也不应交给 `/tech-lead`。

等待用户裁决。