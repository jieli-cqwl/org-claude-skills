结论：不能先交给 `product-manager` 拆 UNIT。当前只有 legacy `brief.md`，没有产品总监确认，也没有 canonical `brief.json`，前置门禁不成立。

阻断条件：

- `/product-manager` 只能消费已通过 Director 确认门的 `brief.json` / `phase-prd.json`
- 缺少 `director_confirmation`
- 缺少 `locked_fields`
- 缺少 `locked_field_digest`
- 缺少 `phase-prd` 骨架
- 未通过 Director schema gate

下一步：

1. 先把 legacy `brief.md` 迁移/整理为合规 `brief.json`
2. 补齐产品总监确认：`director_confirmation`
3. 冻结关键字段：`locked_fields`
4. 生成冻结摘要：`locked_field_digest`
5. 补齐 `phase-prd.json` 骨架
6. 通过 Director schema gate 后，才允许交给 `/product-manager` 继续拆 UNIT

本 eval 只做门禁判定，不生成完整产物、不启动服务、不调用审查 agent。