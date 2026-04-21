我理解你要把当前 phase 的设计收口成可交给 `tech-lead` 的 canonical `design.json`。这次我按 `shared/skills/design/SKILL.md` 核对后，结论是 `FAIL / 阻断`，不能输出成品；本次也没有修改任何文件。

**为什么阻断**
- 这个 skill 的硬门槛要求先扫代码和运行时、再做 2+ 方案共创、迁移/验证/回滚闭环、审查 FAIL 清零、最后还要用户终确认，不能直接跳到交付。见 [SKILL.md](./shared/skills/design/SKILL.md#L16)、[SKILL.md](./shared/skills/design/SKILL.md#L34)、[SKILL.md](./shared/skills/design/SKILL.md#L153)、[SKILL.md](./shared/skills/design/SKILL.md#L165)。
- 前置条件要求 `docs/{feature}/brief.json`、`phase-{N}/phase-prd.json`、`phase-{N}/units/` 必须存在。当前工作区里我只看到 `shared/skills/design/*`，没有任何 `docs/{feature}/phase-*` canonical 输入，也没有 phase 级 `design.json`。见 [SKILL.md](./shared/skills/design/SKILL.md#L82)。
- 完成校验还要求 Phase 工作区里存在 canonical `design.json`，并且至少包含 `input_analysis / key_decisions / interface_boundary / quality_attributes`。门禁脚本也只认 `docs/{feature}/phase-{N}/design.json`。见 [SKILL.md](./shared/skills/design/SKILL.md#L175)、[SKILL.md](./shared/skills/design/SKILL.md#L191)、[completion_check.sh](./shared/skills/design/scripts/completion_check.sh#L75)。
- 目前没有可解析的审查结果，所以“未解决审查 FAIL 时不得完成”这条也无法被满足。见 [SKILL.md](./shared/skills/design/SKILL.md#L30)。

**流程边界**
- 我现在停在 Step 1/2 的前置检查和现状核对，尚未进入 Step 3-8 的共创，更没有到 Step 9 审查或 Step 10 最终确认。
- 按 skill 规则，不能因为你希望直出就跳过这些步骤。见 [SKILL.md](./shared/skills/design/SKILL.md#L34) 和 [SKILL.md](./shared/skills/design/SKILL.md#L45)。

**下一步**
1. 把实际的 phase 工作区补齐到当前目录，至少提供 `docs/{feature}/brief.json`、`phase-{N}/phase-prd.json`、`phase-{N}/units/`。
2. 如果根问题或范围还没冻结，先走 `/product-director → /product-manager`，冻结后再回来跑 `/design`。
3. 你把这些 canonical 输入给到位后，我再从 Step 1 重新开始，走完共创、审查 PASS 和最终确认，才会输出 `design.json`。