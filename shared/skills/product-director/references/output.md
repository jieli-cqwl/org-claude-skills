# Director 场景基线输出

## 产物清单

| 产物 | 职责 | 模板 / 标准 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 记录 Director 场景基线的根问题、目标、范围、约束事实、风险、Phase 结构和锁定字段 | `shared/skills/product-director/templates/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 记录每个 Phase 的目标、入口条件、出口条件和空的 UNIT 索引骨架 | `shared/skills/product-director/templates/phase-prd.template.json` |

## 写入规则

`brief.json` 必须覆盖以下基线字段：`root_problem`、`user_profile`、`business_goals`、`appetite`、`scope_boundaries`、`non_goals`、`feasibility_constraints`、`risks_and_unknowns`、`decision_rationale`、`delivery_plan`、`director_confirmation`。

`phase-prd.json` 必须覆盖以下 Phase 骨架字段：`phase_goal`、`entry_conditions`、`exit_conditions`、`unit_index`、`director_confirmation`。

写入 `brief.json` 和 `phase-prd.json` 时必须从上表 JSON 模板复制并替换示例值，禁止手写只含业务字段的简化 JSON。

`producer` 表示产品域产物生产者，不表示具体 skill 名。业务产品负责人写入时必须保留模板值 `product`；`product-director` 的权威体现在 `director_confirmation.locked_fields`、`director_confirmation.locked_field_digest` 和冻结前验证记录中。

`artifact_type` 必须与模板一致（`brief` 或 `phase-prd`），不得自行修改。

`chain_registry_digest` 必须与 `shared/runtime/standard-chain-catalog.json` 当前值一致。

## 约束值域

- `iteration_timebox_days` 必须是 1-14 的整数。
- `locked_field_digest` 格式为 `sha256:{64位hex}`。
- `unit_index` 保持为空数组，等待 `/product-manager` 填充。
- `director_confirmation.locked_fields` 只能包含 Director 场景基线锁定字段，不包含 UNIT、AC、交互体验方案、系统架构方案、测试策略或实现计划。

## 冻结前验证

冻结前验证每个 Director 产物：

- 对 `brief.json` 和每个 `phase-{N}/phase-prd.json` 分别构造 `{"artifacts":[产物内容]}` fixture，并运行 `python3 tools/community/validate_canonical_schema.py --fixture "$fixture_file"`；该命令同时校验 schema 与 catalog `producer` 权限。
- hooks 运行面通过 `product-director/scripts/completion_check.sh` 执行同等 gate。
