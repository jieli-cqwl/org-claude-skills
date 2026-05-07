# 产品总监输出

## 产物清单

| 产物 | 职责 | 模板 / 标准 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 记录 Director 负责的根问题、目标、范围、约束事实、Phase 规划和确认门字段 | `shared/skills/product-director/templates/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 记录阶段目标、入口/出口条件和空的 UNIT 索引骨架 | `shared/skills/product-director/templates/phase-prd.template.json` |

## 产物信封字段

写入 `brief.json` 和 `phase-prd.json` 时必须从上表 JSON 模板复制并替换示例值，禁止手写只含业务字段的简化 JSON。每个产物必须保留完整 envelope：

- `artifact_type`
- `artifact_id`
- `schema_version`
- `producer`
- `produced_at`
- `chain_version`
- `chain_registry_digest`
- `authority_scope`
- `authoritative_fields`

`brief.json` 的 `artifact_type` 固定为 `brief`，`phase-prd.json` 的 `artifact_type` 固定为 `phase-prd`。`chain_registry_digest` 必须与 `shared/runtime/standard-chain-catalog.json` 当前值一致。

`producer` 表示产品域产物生产者，不表示具体 skill 名。Director 写入 `brief.json` 和 `phase-prd.json` 时必须保留模板值 `product`；`product-director` 的权威体现在 `director_confirmation.locked_fields / locked_field_digest` 和 handoff 语义中。

## 产品总监负责字段

`brief.json` 必须暴露这些 WHY 层字段：

- `user_profile` / 用户画像：谁、场景、现有处理方式。
- `business_goals` / 成功标准：基线、方向、观测窗口、数据来源。
- `appetite` / 投入边界：投入量级和复杂度上限。
- `scope_boundaries` / 范围：本期做什么。
- `non_goals` / 本期不做范围：本期不交付什么。
- `feasibility_constraints` / 可行性约束：资源、系统、流程、合规或上线边界。
- `risks_and_unknowns` / 风险与未知项：会影响目标、范围或 Phase 拆法的不确定性。
- `decision_rationale` / 决策理由：关键范围取舍的原因。
- `delivery_plan[]` / Phase 计划：每项必须包含 `phase_id`、`goal` 与 `iteration_timebox_days`；`iteration_timebox_days` 必须是 1-14 的整数，代表单个 Phase 的最大敏捷迭代周期。

`phase-prd.json` 必须暴露这些 Phase 骨架字段：

- `phase_goal`
- `entry_conditions`
- `exit_conditions`
- `unit_index`，保持为空索引，等待 `/product-manager` 填充
- `director_confirmation`

`director_confirmation` 必须包含：

- `status: "passed"`
- `confirmed_at`，ISO 8601 date-time
- `locked_fields`，逐项快照 Director 锁定字段
- `locked_field_digest`，对 `locked_fields` 计算出的 `sha256:{64位hex}` 摘要

## 写入边界

- 只填写 Director 负责的根问题、用户画像、目标、投入边界、范围、本期不做范围、业务规则、可行性约束、风险与未知项、决策理由、Phase 规划和确认门字段。
- 不写 UNIT 清单、UNIT AC、review 结果或 Manager 负责的执行映射字段。
- 锁定语义写入 `authoritative_fields` 与证据引用字段。
- 所有锁定字段以后只能通过 `/product-director` 重开 Director 共创链路修改。

## 验证

总监确认门 handoff 前验证每个 Director 产物：

- 对 `brief.json` 和每个 `phase-{N}/phase-prd.json` 分别构造 `{"artifacts":[产物内容]}` fixture，并运行 `python3 tools/community/validate_canonical_schema.py --fixture "$fixture_file"`；该命令同时校验 schema 与 catalog `producer` 权限。
- hooks 运行面通过 `product-director/scripts/completion_check.sh` 执行同等 gate。
