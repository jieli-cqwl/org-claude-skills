我理解：基于 `sample-feature` 的 canonical `brief/phase-prd/UNIT`，先做 `design` skill 的前半段：扫描事实、给出多方案和取舍，暂不写 `design.json`、不跑审查 agent、不做完整长链路交付。

**现状事实**
- PRD 已确认：目标是冻结 canonical runtime contracts/readiness gates；canonical JSON 是唯一控制源；状态转换必须 fail-closed。见 [brief.json](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-3/tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-with-skill/_workspaces/with_skill/design/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json:29)。
- UNIT 要求：catalog 与 canonical tree 存在，失败必须 readable fail-closed。见 [UNIT-1.json](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-3/tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-with-skill/_workspaces/with_skill/design/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/units/UNIT-1.json:23)。
- Phase validator 当前按固定 pipeline fail-closed 执行，并拒绝 legacy markdown runtime source。见 [validate_standard_chain_phase.py](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-3/tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-with-skill/_workspaces/with_skill/design/tools/community/validate_standard_chain_phase.py:12)。
- Readiness gate 当前检查必需 phase 文件、QA stage、signoff、registry、replay、freeze/quarantine rollback。见 [validate_standard_chain_readiness.py](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-3/tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-with-skill/_workspaces/with_skill/design/tools/community/validate_standard_chain_readiness.py:27)。
- 运行时采证：本 eval 无部署服务、DB、配置中心；本地 CLI 环境为 Python 3.14.2。阻塞项：workspace 只提供两个 validator 脚本，`validate_standard_chain_readiness.py --help` 因缺 `manage_artifact_registry` 失败；phase validator 因缺 `normalize_canonical_artifact.py` 无法跑完整 pipeline。

**方案对比**
1. 最小加固：只改两个 validator 脚本  
   好处：改动少，符合单阶段 appetite。  
   代价：catalog paths、required files、rollback 语义继续分散，后续 readiness 与 phase validator 易漂移。

2. 收敛为 shared contract module，再由两个 gate 调用  
   好处：把 canonical-only path、required artifacts、active registry、freeze/quarantine 规则集中成一个运行时契约源；两个 gate 行为一致，符合“canonical JSON only control source”。  
   代价：新增一个小模块和对应测试，需要调整现有 imports。

3. 完全 catalog/schema 驱动  
   好处：后续扩展 artifact type 更灵活。  
   代价：当前 sample-feature 只有一个 phase/UNIT，会引入过多间接层；且本 workspace 缺 `shared/runtime/standard-chain-catalog.json`，此方案前置不足。

**推荐收敛**
推荐方案 2，但范围要小：新增一个纯函数/常量模块承载标准链 contract，`validate_standard_chain_phase.py` 与 `validate_standard_chain_readiness.py` 只负责 CLI 编排。它比方案 1 更能防 drift，比方案 3 少引入运行时复杂度。

**接口边界**
- `validate_standard_chain_phase.py --phase-dir PHASE_DIR [--catalog CATALOG] [--enforce-canonical-only]`  
  输入：phase 目录、可选 catalog。输出：exit 0 或 readable exception。错误码语义：missing artifact、catalog drift、legacy runtime source、pipeline failure。
- `validate_standard_chain_readiness.py --phase-dir PHASE_DIR ...`  
  输入：完整 phase 目录。输出：readiness PASS/非 0。错误语义：product closure 未完成、QA stage 未 PASS、registry 与 artifact 不一致、replay 未过、signoff 未闭合。
- `validate_standard_chain_readiness.py --fixture FIXTURE [--expect-freeze-quarantine]`  
  输入：cutover rollback fixture。输出：校验 freeze + quarantine，不允许 `IN_PLACE_LEGACY`。

**门禁与下一步**
当前不能声称 `/design` 完成：skill 要求 S3-S10 逐步共创、最终确认、`design.json`、三视角审查和 phase validator 通过；本 eval 也缺完整 validator 依赖。

下一步只问一个确认问题：你是否确认采用“方案 2：小型 shared contract module + 两个 gate 复用”的方向，并把方案 1 作为低风险备选、方案 3 排除出本阶段？