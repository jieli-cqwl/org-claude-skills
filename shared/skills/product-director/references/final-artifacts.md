# 最终产物写入

## 写入条件

只有同时满足以下条件，才写最终 JSON 并完成移交：

- 问题澄清、目标/成功标准/投入边界、业务语义、范围/约束/决策理由、风险与未知项、Phase 规划均已闭合；仍会改变基线的事实未闭合时，停在对应环节。
- 已收到明确 `产品总监确认`。
- `docs/{feature}/product-director-ledger.json` 已写入 `finalization_basis`，且写入前 gate 通过：
  `python3 tools/community/validate_co_creation_ledger.py --artifact "docs/{feature}/product-director-ledger.json" --producer product-director --require-finalized`

业务语义检查点只用于范围、风险和 Phase 判断；不得把 `business_flows / user_paths / rule_mappings / semantic_draft / business_semantics_draft / semantics_gaps` 写入 Director 最终 JSON。

## 产物清单

| 产物 | 职责 | 模板 / 标准 |
|------|------|-------------|
| `docs/{feature}/product-director-ledger.json` | 记录已确认检查点、`supersedes` 和 `finalization_basis`；作为 Director 恢复与确认支撑 | `tools/community/validate_co_creation_ledger.py --producer product-director --require-finalized` |
| `docs/{feature}/brief.json` | 记录 Director 负责的根问题、目标、范围、约束事实、Phase 规划和确认门字段 | `shared/skills/product-director/templates/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 记录阶段目标、入口/出口条件和空的 UNIT 索引骨架 | `shared/skills/product-director/templates/phase-prd.template.json` |

## 信封字段

写入 `brief.json` 和 `phase-prd.json` 时必须从上表 JSON 模板复制并替换示例值，保留 artifact envelope，不写只含业务字段的简化 JSON。

`producer` 表示产品域产物生产者，不表示具体 skill 名。Director 写入时必须保留模板值 `product`；Director 权威体现在 `director_confirmation.locked_fields / locked_field_digest` 和移交语义中。

`artifact_type` 必须与模板一致：`brief.json` 使用 `brief`，`phase-prd.json` 使用 `phase-prd`。

`chain_registry_digest` 必须与 `shared/runtime/standard-chain-catalog.json` 当前值一致。

## 字段边界

`brief.json` 的 Director 业务字段只覆盖：`root_problem / user_profile / business_goals / appetite / scope_boundaries / non_goals / feasibility_constraints / risks_and_unknowns / decision_rationale / delivery_plan / director_confirmation`。

`brief.json` 不写产品经理同事、设计或下游字段：`acceptance_criteria / design_decisions / non_functional_requirements / business_flows / user_paths / rule_mappings / semantic_draft / business_semantics_draft / semantics_gaps / review_conclusion / issue_ledger / delivery_confirmation`。

`phase-prd.json` 的 Director 业务字段只覆盖：`phase_goal / entry_conditions / exit_conditions / unit_index / director_confirmation`。

`phase-prd.json.unit_index` 必须保持 `[]`，不得写 UNIT 编号、UNIT 排序或优先级。

`phase-prd.json` 不写产品经理同事、设计或下游字段：`business_flows / user_paths / rule_mappings / semantic_draft / business_semantics_draft / semantics_gaps / unit_priority_order / design_decision_candidates / review_conclusion / issue_ledger`。

`iteration_timebox_days` 必须是 1-14 的整数；单个 Phase 超过 14 天时先重切 Phase，不得冻结。

## 锁定字段

`director_confirmation.status` 必须是 `passed`，`confirmed_at` 必须是 ISO date-time。

`brief.json.director_confirmation.locked_fields` 必须精确快照以下字段，且值与顶层字段一致：`root_problem / user_profile / business_goals / appetite / scope_boundaries / non_goals / feasibility_constraints / risks_and_unknowns / decision_rationale / delivery_plan`。

`phase-prd.json.director_confirmation.locked_fields` 必须精确快照以下字段，且值与顶层字段一致：`phase_goal / entry_conditions / exit_conditions`。

`locked_field_digest` 必须是 `sha256:{64位hex}`，并等于 `locked_fields` 规范 JSON 的 SHA-256 摘要；不得单独手改 digest，修改任一锁定字段后必须回到对应步骤重新确认并由 canonical digest 计算生成。

## 验证

总监确认移交前必须验证每个 Director 产物：

- 对 `brief.json` 和每个 `phase-{N}/phase-prd.json` 分别构造 `{"artifacts":[产物内容]}` fixture，并运行：`python3 tools/community/validate_canonical_schema.py --fixture "$fixture_file"`。
- 对 `brief.json` 和每个 `phase-{N}/phase-prd.json` 分别运行：`python3 tools/community/validate_product_closure.py --artifact "$artifact_file"`。
- 对 `brief.json`、每个 `phase-{N}/phase-prd.json` 和 `product-director-ledger.json` 运行内容质量评估：
  `python3 shared/skills/product-director/scripts/evaluate_content_quality.py --brief "docs/{feature}/brief.json" --phase-prd "docs/{feature}/phase-{N}/phase-prd.json" --ledger "docs/{feature}/product-director-ledger.json" --min-score 12`。
- hook 运行面必须通过 Director gate：`printf '{"cwd":"%s","session_id":"manual","transcript_path":"/dev/null","tool_input":{"file_path":"docs/{feature}/brief.json"}}\n' "$PWD" | "$PWD/shared/skills/product-director/scripts/completion_check.sh"`。

任一 gate 失败时只修正 Director 边界内字段；schema、hook、runtime 或 contract 缺失属于环境阻塞，停止报告，不创建或修复 `product-director-ledger.json / brief.json / phase-prd.json` 之外的文件；需要改目标、范围、约束或 Phase 基线时，回到对应步骤重新确认。
