# Director-Output Contract v1

## 产物清单

| 产物 | 职责 | 模板 / 合同 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 记录 Director 负责的根问题、目标、范围、约束事实、Phase 规划和确认门字段 | `contracts/canonical/templates/planning/director/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 记录阶段目标、入口/出口条件和空的 UNIT 索引骨架 | `contracts/canonical/templates/planning/director/phase-prd.template.json` |

## Director 字段

`brief.json` 必须暴露这些 WHY 层字段：

- `user_profile` / 用户画像：谁、场景、当前绕行方式。
- `business_goals` / 成功标准：基线、方向、观测窗口、数据来源。
- `appetite` / Appetite：投入量级和复杂度上限。
- `scope_boundaries` / 范围：本期做什么。
- `non_goals` / Non-goals：本期不交付什么。
- `feasibility_constraints` / 可行性约束：资源、系统、流程、合规或上线边界。
- `risks_and_unknowns` / 风险与未知项：会影响目标、范围或 Phase 拆法的不确定性。
- `decision_rationale` / 决策理由：关键范围取舍的原因。

`phase-prd.json` 必须暴露这些 Phase 骨架字段：

- `phase_goal`
- `entry_conditions`
- `exit_conditions`
- `unit_index`，保持为空索引，等待 `/product-manager` 填充
- `director_confirmation`

## 写入边界

- 只填写 Director 负责的根问题、用户画像、目标、Appetite、范围、Non-goals、业务规则、可行性约束、风险与未知项、决策理由、Phase 规划和确认门字段。
- 不写 UNIT 清单、UNIT AC、review 结果或 Manager 负责的执行映射字段。
- 锁定语义写入 canonical authority fields / evidence refs。
- 所有锁定字段以后只能通过 `/product-director` 重开 D-S2~D-G1 修改。
