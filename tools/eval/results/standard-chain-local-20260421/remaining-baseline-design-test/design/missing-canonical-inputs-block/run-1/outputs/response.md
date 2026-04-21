**结论**
- 阻断设计输出。
- 我理解你要我直接为“订单退款”做技术设计，但当前只有一句需求，没有 canonical 的 `brief.json`、`phase-prd.json` 和 `UNIT` 基线，所以不能进入 design 阶段，也不能凭这句话生成 `design.json`。

**依据**
- `design` skill 的定位本身就是 PRD 完成后才做架构设计，不能跳过前置收口。[`SKILL.md` L5](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/remaining-baseline-design-test/_workspaces/design/shared/skills/design/SKILL.md#L5)
- 前置条件明确要求 `docs/{feature}/brief.json`、`phase-{N}/phase-prd.json`、`phase-{N}/units/` 存在，缺失时必须终止并提示先执行 `/product-director → /product-manager`。[`SKILL.md` L82](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/remaining-baseline-design-test/_workspaces/design/shared/skills/design/SKILL.md#L82)
- 标准链路只把 `brief.json / phase-prd.json / units/UNIT-*.json / design.json` 当运行时权威工件，没有这些就没有可承接的设计真源。[`SKILL.md` L51](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/remaining-baseline-design-test/_workspaces/design/shared/skills/design/SKILL.md#L51)

**下一步**
- 先补 `/product-director` 产物，冻结根问题和范围。
- 再补 `/product-manager` 产物，生成 `brief.json`、`phase-prd.json`、`UNIT-*.json`。
- 等这些 canonical 工件齐全后，再回来走 design 流程。

本次只做了本地只读检查，未修改任何文件。