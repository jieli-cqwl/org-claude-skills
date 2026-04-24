我理解：你想用旧版 `brief.md` 和 `prd.md` 先拆 `UNIT`，把 review 后补。按 `shared/skills/product-manager/SKILL.md` 判定：**不能直接拆 UNIT，当前应阻断。**

阻断原因：
- standard-chain 的运行时真源是 `brief.json`、`phase-{N}/phase-prd.json`、`phase-{N}/units/UNIT-*.json`，旧版 Markdown 不能作为准入真源。
- M-S0 必须先校验 `brief.json` 的 Director 确认、锁定字段、digest，以及 `phase-prd.json` 的 Phase 边界一致性。
- review 不能口头通过或事后补。M-S7/M-S8 的结论必须写入 canonical `review_conclusion / issue_ledger`，未关闭 FAIL 会阻断进入交付。
- 阻断状态下禁止输出 PRD、UNIT 或 AC 草案。

固定 handoff 问题：  
请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-{N}/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。

下一步：先回到 `/product-director` 生成或重签 canonical `brief.json` / `phase-prd.json`；通过准入后，再按 M-S1 到 M-S9 共创 UNIT、AC、Verification Plan、评审和交付确认。