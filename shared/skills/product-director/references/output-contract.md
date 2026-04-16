# Director-Output Contract v1

## 产物清单

| 产物 | 职责 | 模板 / 合同 |
|------|------|-------------|
| `docs/{feature}/brief.md` | 记录 Director 负责的业务基线章节，并写入 `## 产品总监确认` | `references/templates/brief-template.md` + `contracts/product-artifacts.yaml#brief_lock` |
| `docs/{feature}/phase-{N}/prd.md` | 记录阶段目标、入口/出口条件和空的 UNIT 索引骨架 | `references/templates/phase-prd-template.md` + `contracts/product-artifacts.yaml#prd_lock` |
| `docs/{feature}/brief.lock.json` | D-G1 通过时生成，记录 Director 锁定字段的 canonical 快照 | `contracts/product-artifacts.yaml#brief_lock` |
| `docs/{feature}/phase-{N}/prd.lock.json` | D-G1 通过时生成，记录阶段骨架字段的 canonical 快照 | `contracts/product-artifacts.yaml#prd_lock` |

## 写入边界

- 只填写 Director 负责的根问题、目标、范围、业务规则、约束事实、Phase 规划和确认门字段。
- 不写 UNIT 清单、UNIT AC、review 结果或 Manager 负责的执行映射字段。
- `brief.lock.json` 与 `phase-{N}/prd.lock.json` 只在 D-G1 用户确认通过后生成。
- 所有锁定字段以后只能通过 `/product-director` 重开 D-S2~D-G1 修改。
