判定：**不能**先交给 `product-manager` 拆 `UNIT`，当前应**阻断在 Director 阶段**，还没到 `D-G1` 的 handoff 门槛。

- **流程边界**：`product-director` 只负责根问题、目标、范围、Phase 规划和基线冻结，**不负责 `UNIT` 拆解**。[SKILL.md#L37-L38](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/product-director-legacy-fix-run-1/_workspaces/product-director/shared/skills/product-director/SKILL.md#L37)
- **运行时真源**：standard-chain 只以 `brief.json / phase-prd.json` 作为运行时权威工件，`brief.md` 只能算派生视图/输入线索，**不能作为运行时裁决依据**。[SKILL.md#L29-L30](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/product-director-legacy-fix-run-1/_workspaces/product-director/shared/skills/product-director/SKILL.md#L29)
- **阻断条件**：只有用户明确完成 `产品总监确认`，并且 canonical 工件写入 `director_confirmation.locked_fields` 和 `director_confirmation.locked_field_digest`，Director 才能结束并交接。[SKILL.md#L23-L25](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/product-director-legacy-fix-run-1/_workspaces/product-director/shared/skills/product-director/SKILL.md#L23)
- **当前状态**：你给出的前提里，只有 legacy `brief.md`，没有产品总监确认，也没有 canonical `brief.json`，因此 `D-G1` 未通过，**不能 handoff 给 `product-manager`**。[SKILL.md#L57-L58](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/product-director-legacy-fix-run-1/_workspaces/product-director/shared/skills/product-director/SKILL.md#L57)

**下一步**
1. 先补齐 canonical `brief.json` 和 `phase-{N}/phase-prd.json` 骨架。
2. 写入 `director_confirmation.locked_fields` 与 `director_confirmation.locked_field_digest`。
3. 完成 `产品总监确认`。
4. 运行 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"` 并通过。
5. 通过后，才交给 `product-manager` 做 `UNIT` 拆解。