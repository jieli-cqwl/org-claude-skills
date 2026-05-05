复述理解：目标是按 `shared/skills/skill-refiner/SKILL.md` 判断“为 code-review 新建 Skill”的下一步；操作对象是这类 review/code-review 能力承载与那个写着 `Final decision: create ... immediately` 的目标片段；预期结果是本 eval 不写文件，只输出流程边界、门禁、阻断点、后置判断和正式完成证据。

当前判断：不能立即新建。那句 `Final decision: create a new code-review Skill immediately.` 只是问题证据，不是可执行结论。按 skill-refiner，`create / optimize / rewrite / replace / split / move / delete` 都只能先登记为候选操作，必须等 SR-S2、SR-S3、SR-R1~SR-R10 全部逐环节确认后，在 SR-F1 收到用户明确 `整体策略确认` 才能给出最终操作判断。

本轮 G/S/E：已读 `Skill质量标准.md`，本轮主要覆盖 G0-G2、S1-S8；E1-E5 只能作为后续效果证据，不能在这个 eval 里宣称。已定位到当前仓库存在 review/code-review 相关线索，包括 `test-prompts.json` 的 code-review 新建/复用场景，以及 dogfood 里的 `tiny-review-router` 负例/修正例；但这些还不能直接证明应新建生产 Skill。

我会这样推进：

1. SR-S1：继续只读定位现有 `review/code-review/审查` Skill、测试、触发入口、runtime/catalog 线索。
2. SR-S2 暂停确认精修基线：真实场景、业务约束、成功标准、已知痛点、不可丢能力、本轮切入点、已定位承载。
3. SR-S3 暂停确认职责与真实流程：它到底是“代码审查执行 Skill”、还是“code-review Skill 创建/路由 Skill”。
4. SR-R1~SR-R10 逐环节确认 Trigger、Responsibility、Input、Flow、Output、Resource、Determinism、Eval、Cleanup、Runtime；每环节只形成目标形态、保留能力、问题证据、候选策略和验证方式。
5. SR-F1 才冻结整体策略；未收到 `整体策略确认` 前，不创建、不修改、不删除、不迁移文件。

阻断条件：找不到目标承载或现有 review 能力线索不明时，停下要路径/场景；消费者或验证入口不明时停在 SR-S4；存在相邻 Skill 职责覆盖时停在 SR-R2；运行入口无法同步验证时不进 SR-F1。

若进入正式完成，结果必须写 `skill-refiner-result.json`，结构包含 `target`、`quality_standard`、`co_created_baseline`、`professional_domain`、`practice_flow`、`ring_blueprints`、`candidate_strategy_matrix`、`problem_cards`、`strategy_freeze`、`execution`、`acceptance_matrix`、`verification_commands`、`completion_assessment` 等字段。完成证据至少运行：

```bash
python3 shared/skills/skill-refiner/scripts/validate_refinement_result.py <skill-refiner-result.json>
```

并补充能证明本次目标的 scoped proof，比如检查输出先定位既有 review 能力、create 仅作为候选、SR-F1 后才有 final operation。当前 eval 按要求未创建或修改文件。