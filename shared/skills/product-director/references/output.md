# 产品总监输出

## 产物清单

| 产物 | 职责 | 模板 / 标准 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 记录 Director 负责的根问题、目标、范围、约束事实、Phase 规划和确认门字段 | `shared/skills/product-director/templates/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 记录阶段目标、入口/出口条件和空的 UNIT 索引骨架 | `shared/skills/product-director/templates/phase-prd.template.json` |

## 写入规则

`brief.json` 必须覆盖以下 WHY 层字段（完整结构见模板）：`root_problem`、`user_profile` / 用户画像、`business_goals`、`appetite` / 投入边界、`scope_boundaries`、`non_goals` / 本期不做范围、`feasibility_constraints` / 可行性约束、`risks_and_unknowns` / 风险与未知项、`decision_rationale` / 决策理由、`delivery_plan`、`director_confirmation`。

写入 `brief.json` 和 `phase-prd.json` 时必须从上表 JSON 模板复制并替换示例值，禁止手写只含业务字段的简化 JSON。

`producer` 表示产品域产物生产者，不表示具体 skill 名。Director 写入时必须保留模板值 `product`；`product-director` 的权威体现在 `director_confirmation.locked_fields / locked_field_digest` 和 handoff 语义中。

`chain_registry_digest` 必须与 `shared/runtime/standard-chain-catalog.json` 当前值一致。

## 约束值域

- `iteration_timebox_days` 必须是 1-14 的整数。
- `locked_field_digest` 格式为 `sha256:{64位hex}`。
- `unit_index` 保持为空索引，等待 `/product-manager` 填充。

## 验证

总监确认门 handoff 前验证每个 Director 产物：

- 对 `brief.json` 和每个 `phase-{N}/phase-prd.json` 分别构造 `{"artifacts":[产物内容]}` fixture，并运行 `python3 tools/community/validate_canonical_schema.py --fixture "$fixture_file"`；该命令同时校验 schema 与 catalog `producer` 权限。
- hooks 运行面通过 `product-director/scripts/completion_check.sh` 执行同等 gate。
