# Director-Output Contract v1

## 产物清单

| 产物 | 职责 | 模板 / 合同 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 记录 Director 负责的根问题、目标、范围、约束事实、Phase 规划和确认门字段 | `contracts/canonical/templates/planning/director/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 记录阶段目标、入口/出口条件和空的 UNIT 索引骨架 | `contracts/canonical/templates/planning/director/phase-prd.template.json` |

## 写入边界

- 只填写 Director 负责的根问题、目标、范围、业务规则、约束事实、Phase 规划和确认门字段。
- 不写 UNIT 清单、UNIT AC、review 结果或 Manager 负责的执行映射字段。
- 锁定语义写入 canonical authority fields / evidence refs。
- 所有锁定字段以后只能通过 `/product-director` 重开 D-S2~D-G1 修改。
