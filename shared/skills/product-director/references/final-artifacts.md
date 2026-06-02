# 最终产物写入

## 写入条件

只有同时满足以下条件，才写最终产物：

- 问题澄清、目标/成功标准/投入边界、业务语义、范围/约束/决策理由、风险与未知项、Phase 规划均已闭合；仍会改变基线的事实未闭合时，停在对应环节。
- 已收到用户明确回复 `产品总监确认`。
- `docs/{feature}/product-director-ledger.json` 已写入 `finalization_basis`，并通过 finalized 校验：
  `python3 tools/community/validate_co_creation_ledger.py --artifact "docs/{feature}/product-director-ledger.json" --producer product-director --require-finalized`

## 产物清单

| 产物 | 职责 | 模板 / 验证 |
|------|------|-------------|
| `docs/{feature}/product-director-ledger.json` | 只记录 Director finalization 前的确认检查点、漂移恢复、输出引用和最终确认依据；不得承载 PM 产品模型、AC、设计决策、实现细节或下游需求 | `tools/community/validate_co_creation_ledger.py --producer product-director --require-finalized` |
| `docs/{feature}/brief.json` | 记录 canonical envelope、Director confirmation、根问题、用户画像、业务目标、投入边界、范围、约束、风险、决策理由和 Phase 计划 | `shared/skills/product-director/templates/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 记录 canonical envelope、Director confirmation、对应 Phase 的目标、入口条件和出口条件 | `shared/skills/product-director/templates/phase-prd.template.json` |

`brief.json` 和 `phase-prd.json` 必须带 canonical envelope 与 Director confirmation marker，作为 PM handoff 的唯一 JSON 真源；不要加入 PM-owned 下游字段。

## 验证

收到用户明确回复 `产品总监确认` 后，对每个 Phase 运行：

- 内容质量评估：
  `python3 shared/skills/product-director/scripts/evaluate_content_quality.py --brief "docs/{feature}/brief.json" --phase-prd "docs/{feature}/phase-{N}/phase-prd.json" --ledger "docs/{feature}/product-director-ledger.json" --min-score 12`
- Director result gate：
  `printf '{"cwd":"%s","session_id":"manual","transcript_path":"/dev/null","tool_input":{"file_path":"docs/{feature}/brief.json"}}\n' "$PWD" | "$PWD/shared/skills/product-director/scripts/completion_check.sh"`

任一验证失败时，只修正 Director 边界内产物；schema、hook、runtime 或 contract 缺失属于环境阻塞，停止报告。
