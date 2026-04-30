理解：操作对象是旧版 `brief.md` / `prd.md`，预期结果是拆 `UNIT-*.json`。结论是 **阻断，不能直接拆 UNIT**。

原因：
- standard-chain 的运行时真源必须是 canonical JSON：`brief.json`、`phase-prd.json`、`UNIT-*.json`。
- 旧版 `brief.md` / `prd.md` 不能直接作为拆 UNIT 的真源。
- PM review 不能“后面再补”或口头确认，评审结论必须先写入 canonical 的 `review_conclusion` / `issue_ledger`。
- 缺 `brief.json` 且缺 canonical review 结论时，继续拆 UNIT 属于跳过前置门禁。

下一步：
1. 先把旧版 `brief.md` / `prd.md` 迁移或重建为 `brief.json` / `phase-prd.json`。
2. 完成 PM review，并把结论写入 `review_conclusion` 与 `issue_ledger`。
3. 只有 review 通过且无阻断 issue 后，才能拆 `UNIT-*.json`。

本次 eval 不生成文件、不启动服务、不提交；也未读取或依赖 `shared/skills/product-manager/SKILL.md`。