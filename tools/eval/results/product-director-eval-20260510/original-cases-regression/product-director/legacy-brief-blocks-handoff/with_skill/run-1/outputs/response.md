使用 `product-director` skill 判定。对齐结果：本次只做门禁判断，不写文件、不启动服务、不调用审查 agent、不联网。

**结论：不能交给 `/product-manager` 拆 UNIT。**

原因很硬：`/product-manager` 只能消费已经通过 Director 确认门的 canonical 产物，不消费 legacy `brief.md` 这种未冻结材料。当前缺口是阻断级：

- 没有明确 `产品总监确认`
- 没有 `brief.json`
- 没有 `director_confirmation.status=passed`
- 没有 `director_confirmation.locked_fields`
- 没有 `director_confirmation.locked_field_digest`
- 没有 `phase-{N}/phase-prd.json` Phase 骨架
- 没有通过 Director schema gate

`product-director` 的边界也明确：Director 负责 WHY 层基线冻结和 Phase 骨架，不输出 UNIT；`/product-manager` 只有在拿到冻结后的 `brief.json / phase-prd.json` 后，才能继续细化 WHAT 层、拆 UNIT，且不得修改 `locked_fields / locked_field_digest`。

**下一步**

先回到 `/product-director` 补齐 Director 链路：

1. 将 legacy `brief.md` 仅作为候选线索，不作为权威输入。
2. 完成 D-S1 → D-G1，拿到明确 `产品总监确认`。
3. 按模板生成 `brief.json` 和每个 `phase-{N}/phase-prd.json`。
4. 写入 `director_confirmation.locked_fields` 与 `locked_field_digest`。
5. 保持 `phase-prd.json` 的 `unit_index: []`，只提供 Phase 目标、入口/出口条件骨架。
6. 通过 Director gate 后再 handoff 给 `/product-manager`。

应执行的门禁是：

```bash
python3 tools/community/validate_co_creation_ledger.py --artifact "docs/{feature}/product-director-ledger.json" --producer product-director --require-finalized
python3 tools/community/validate_canonical_schema.py --fixture "$fixture_file"
```

或者运行同等的 `product-director/scripts/completion_check.sh`。当前状态未过门，直接交 PM 是跳步。