# gstack Systematic Rebenchmark - 2026-05-26

## 结论

结论：`garrytan/gstack` 值得学习，但不建议直接安装或接入本仓 runtime。它的核心价值不是单个 Skill，而是覆盖需求澄清、计划评审、实现验证、浏览器运行、gbrain 同步、遥测、更新和主机集成的 agent operating system 形态。对本仓最优策略是：`Adapt` 前半段产品挑战和中段 review 机制，`Adapt` back-half 中 root-cause / QA / ship / retro 的方法论，`Isolate` 浏览器 daemon、Chrome extension、pair-agent、GBrain、telemetry、upgrade/setup runtime，`Reject` 静默安装、自动提交或不受控 host mutation。

本仓当前不是 gstack 的简化版，而是 contract-first agent delivery system：强项在 canonical JSON、schema、completion check、role boundary、runtime-surface policy 和真实证据门禁。gstack 更强在人类可感知的 workflow UX、front-half product taste、design/DX review、browser/runtime integration 和 agent-OS 野心。两者互补，不该互相替代。

## 执行口径

- 只读审计：没有安装 gstack，没有接入 runtime，没有运行 upstream setup/browser/runtime/telemetry/sync/upgrade/routing/commit scripts。
- Repo 内唯一新增目标：`docs/reports/gstack-systematic-rebenchmark-2026-05-26.md`。
- `/tmp` 证据保留：inventory、GitHub/skills.sh 证据、upstream clone 和 9 份 agent outputs。
- Upstream clone commit：`22f8c7f4e1eda65680d4b87a2548429f44020277`。
- Current repo HEAD at evidence capture：`a4e55432ab4410ce8d5f51b8d9e6d70918add512`。
- 重要限制：runtime/tooling inventory 满足计划分组 gate，但 inventory auditor 认为它不足以覆盖完整 runtime implementation，尤其遗漏 `browse/src/**`、`scripts/**`、`setup`、`supabase/**`、`make-pdf/src/**`、`browser-skills/**` 等实现面。因此本文只对系统形态和采用策略下结论，不声称验证了 runtime 行为正确性。

## 证据来源

- `/tmp/gstack-systematic-benchmark-2026-05-26/`：只读 upstream clone。
- `/tmp/gstack-skills-find.txt`：skills.sh search CLI 输出。
- `/tmp/gstack-skills-page.html`：skills.sh 页面证据。
- `/tmp/gstack-github-repo.json`：GitHub repo metadata。
- `/tmp/gstack-skill-inventory.json` 与 `/tmp/gstack-skill-inventory.md`：57 个 upstream `SKILL.md` inventory。
- `/tmp/gstack-runtime-inventory.json` 与 `/tmp/gstack-runtime-inventory.md`：140 个 runtime/tooling grouped inventory。
- `/tmp/gstack-ontology-input.md`：ontology agent 输入。
- `/tmp/gstack-agent-outputs/*.md`：9 个审计角色输出。

## 1. 全量 Skill Inventory 覆盖证明

Skill inventory 覆盖 57 个 upstream `SKILL.md`，附录 A 逐项列出所有路径。关键统计：front-half signal 56/57，middle signal 50/57，back-half signal 52/57，question signal 51/57，browser signal 50/57，write-tool signal 35/57，network/sync signal 53/57。

审计判断：覆盖 raw `SKILL.md` 文件本身为 PASS；但布尔字段受 generated preamble 影响，不能直接当成每个 skill 的实际行为证明。特别是 `uses_browser`、`modifies_repo`、`auto_commits`、`network_or_sync_behavior` 更适合作为 adoption risk scan 的候选信号，而不是已执行事实。

## 2. Runtime / Tooling Inventory 覆盖证明

Runtime/tooling inventory 覆盖 140 个计划指定分组文件。分组统计：`bin` 62, `docs` 33, `extension` 12, `hosts` 11, `lib` 6, `model-overlays` 6, `ARCHITECTURE.md` 1, `BROWSER.md` 1, `DESIGN.md` 1, `ETHOS.md` 1, `README.md` 1, `SKILL.md` 1, `USING_GBRAIN_WITH_GSTACK.md` 1, `agents` 1, `conductor.json` 1, `package.json` 1。

Mention flags：telemetry 34/140，sync/remote 105/140，browser runtime 42/140，host integration 98/140，update/install 101/140，repo mutation 31/140，security 84/140。

审计判断：计划最低 group coverage 为 PASS；完整 runtime implementation coverage 为 FAIL/limited。最终采用决策必须按 high-surface runtime 看待 gstack，不能只读 Skill Markdown 后得出安全集成结论。

## 3. 从 gstack 自身归纳出的能力 Ontology

从 inventory 归纳，gstack 至少有五层能力：

| Layer | 能力族 | 代表资产 | 采用含义 |
|---|---|---|---|
| Front half | 需求澄清、需求现实、CEO/founder challenge、设计咨询、问题调谐 | `office-hours`、`plan-ceo-review`、`design-consultation`、`design-shotgun`、`plan-tune` | 适合 Adapt 到本仓产品/设计前置阶段。 |
| Middle system | plan review、engineering/design/DX review、security/health review、autoplan | `plan-eng-review`、`plan-design-review`、`plan-devex-review`、`autoplan`、`cso`、`health` | 适合 Reference/Adapt，但本仓应保留 schema-backed gates。 |
| Back half | investigate、QA、review、ship、deploy、canary、retro、learn、docs | `investigate`、`qa`、`review`、`ship`、`land-and-deploy`、`canary`、`retro`、`learn` | 适合 Adapt 方法论和检查项，不直接引入自动提交/部署。 |
| Runtime layer | browser daemon、Chrome extension、pair-agent、GBrain、host adapters、model overlays、telemetry/update | `browse`、`open-gstack-browser`、`pair-agent`、`setup-gbrain`、`sync-gbrain`、`bin/*`、`extension/*`、`hosts/*` | 必须 Isolate/Reference only。 |
| Governance/safety | careful/freeze/guard、setup/upgrade、scoped runtime controls | `careful`、`freeze`、`guard`、`gstack-upgrade`、runtime docs | 可 Adapt 概念，但必须受本仓 runtime-surface contract 约束。 |

## 4. 社区推荐价值假设验证

GitHub metadata 显示强 adoption signal：stars `103302`、forks `15397`、subscribers `625`、open issues `503`、license `MIT`、language `TypeScript`、created `2026-03-11T21:22:45Z`、pushed `2026-05-27T02:11:32Z`。

Skills search evidence 显示 `garrytan/gstack@gstack` 约 `12.7K installs`，并有 first-party skills 如 `office-hours`、`plan-ceo-review`、`plan-eng-review`、`review`、`plan-design-review`、`qa` 获得较小但真实的直接安装量；还有 `gstack-workflow-assistant`、`gstack-openclaw-skills` 等 derivative/community-adjacent signal。

价值假设：用户推荐 gstack 很可能因为它降低 blank prompt anxiety、把 agent 工作组织成 named specialist team、让 browser/screenshot/runtime 证据更可感、把 founder/operator taste 包进 workflow，并让 solo builder 感觉拥有一支虚拟工程团队。反证风险：star velocity、Garry Tan/YC halo、novelty hype 和 README narrative 可能放大了未验证的长期价值。

## 5. Front Half: 需求澄清与 CEO 视角

`office-hours` 不只是 brainstorming，而是把模糊想法转成 demand claim、premise challenge、alternatives 和 design-doc input。六个 forcing questions 的价值在于把“有人感兴趣”拆成 demand reality、status quo、desperate specificity、willingness to pay、distribution/timing 等可反驳问题。

本仓已有 `product-director`、`product-manager`、`design`、`test-design` 和 standard-chain artifact flow，但更偏 contract 和交付闭环。相较之下，gstack 的 front-half 更擅长“在进入方案前质疑需求是否值得做”。建议 Adapt：把 demand gauntlet、CEO/founder adversarial review、alternatives generation、question tuning 融入本仓 product/director 阶段；不要引入 gstack runtime。

## 6. Middle System: 计划评审与实施前质量门

gstack 的 middle system 强在人类可读的 plan critique：`plan-eng-review`、`plan-design-review`、`plan-devex-review`、`autoplan` 把工程、设计、DX、外部声音和 task synthesis 串成计划前质量门。它的价值是让 agent 在执行前先被不同专家视角挑战。

本仓强项是 `contracts/standard-chain.yaml`、canonical JSON、developer/review/qa/verify/consistency-audit 的 machine-checkable contracts。建议 Adapt gstack 的 review prompts 和 scorecard 思路，但落地时必须转成本仓 schema/template/completion check 可消费字段；不要让 narrative review 替代 canonical artifact。

## 7. Back Half: 实现、验证、发布与学习闭环

gstack back half 覆盖 `/investigate`、`/qa`、`/qa-only`、`/review`、`/ship`、`/land-and-deploy`、`/canary`、`/retro`、`/learn`。强项是 root-cause-first debugging、browser-first QA、ship checklist、canary 和 post-ship learning。

本仓 back half 更强在 delivery-owner role separation、Task AC TDD、`developer-report.json`、`code-review-result.json`、`qa-result.json`、stable `QAR-XXX` issue identity、browser_required evidence 和 bounded loop。建议 Adapt root-cause packet、exploratory QA health scoring、ship/canary/retro checklist；不要直接导入 auto fix/commit/deploy 行为。

## 8. Runtime Layer: 主机集成、浏览器、gbrain、遥测与路由

gstack runtime layer 是最大差异：persistent browser daemon、Chrome extension、Side Panel PTY、pair-agent tunnel、browser-skills runtime、GBrain setup/sync、host adapters、telemetry、update/upgrade、routing/model overlays。它让 gstack 看起来像 agent OS，而不是 skill bundle。

价值：browser QA、authenticated session、screenshots、console/network inspection、remote pairing、memory/search 和 host integration 会显著提升 agent grounding。风险：本地 daemon、browser token、cookie/storage access、PTY injection、remote tunnel、host config mutation、telemetry、setup/update 脚本都扩大信任边界。建议 Isolate：只读学习架构与安全边界；若未来实验，必须 source-lock、sandbox、explicit opt-in、disable telemetry/sync/update by default、建立 runtime-surface contract 和卸载/回滚验证。

## 9. 当前仓库独立能力地图

本仓是 contract-first agent delivery system：

- Source governance：`shared/skills/` first-party truth，`community/*/skills` locked mirror，`AGENTS.md` 为共享指令真源。
- Runtime surface：`contracts/skill-runtime-surface.json` 对 skill mode、owner、auto/manual、auto_class 和 reason 做机器可读治理。
- Standard chain：`product-director` → `product-manager` → `design` → `test-design` → `tech-lead` → `developer` → `verify` / `review` / `qa` / `fix` / `consistency-audit` / `delivery-owner`。
- QA：真实运行、QA_A-D、browser_required evidence、`QAR-XXX`、`qa-result.json`。
- Review：十维覆盖、file_path:line evidence、confidence、excluded issues、Critical/High verification、`code-review-result.json`。
- Testing/install governance：`tests/run-all.sh --quick`、`tests/run-all.sh`、`install.sh --target all --dry-run`，并有低信号 Markdown 断言拦截。

弱项：front-half demand challenge、CEO/founder adversarial review、design/DX runtime-rich review、single integrated browser daemon、named root-cause investigation artifact、post-ship learning loops 相对不突出。

## 10. 双方成熟度矩阵

| 维度 | gstack | 当前仓库 | 判断 |
|---|---|---|---|
| Front-half product judgment | 强：office-hours、CEO review、demand gauntlet | 中强：product/director/PM artifacts，但 demand gauntlet 不突出 | gstack 可 Adapt。 |
| Plan review | 强：eng/design/DX/autoplan narrative critique | 强：schema-backed standard-chain gates | 双方互补。 |
| Implementation control | 广：ship/fix/QA/review 一体化 | 强：bounded Task + TDD + reports + role separation | 当前仓更安全。 |
| QA/browser | 强 runtime ambition，browser daemon/extension | 强 QA contract 和 browser evidence requirement | gstack runtime 强；本仓 gate 强。 |
| Runtime/agent OS | 很强但高风险 | 保守、契约化、manual exposure | 只可隔离试验。 |
| Governance | 有 safety skills，但 surface 很大 | 强 runtime-surface contract、mirror boundary、tests | 当前仓更适合团队交付。 |
| Community/adoption | 很强 | 本仓内部治理型 | gstack 值得学习，但不能被 popularity 替代审计。 |

## 11. Adopt / Adapt / Isolate / Reject 决策表

| 对象 | 决策 | 理由 | 落地方式 |
|---|---|---|---|
| Six forcing questions / demand reality gauntlet | Adapt | 提高前置需求质量，低 runtime 风险 | 转成 product-director/product-manager 可验证问题集。 |
| CEO/founder adversarial plan review | Adapt | 能补强 scope/premise challenge | 作为 design/tech-lead 前置 reviewer prompt，不替代 canonical JSON。 |
| Plan eng/design/DX review scorecards | Adapt / Reference only | 机制有价值，但 narrative 不能直接成为 gate | 映射到 schema 字段、review checklist 和测试。 |
| Root-cause-first investigate | Adapt | 当前 defect loop 可更显式记录 RCA | 增加 defect-investigation packet 或 fixer 输出要求。 |
| Browser QA exploration and health scoring | Adapt | 本仓已有 browser_required evidence，缺 richer exploration UX | 融入 QA_B/QA_D 方法论，保留 `qa-result.json` gate。 |
| Ship/canary/retro/learn checklist | Adapt | 补强 post-ship feedback loop | 作为 delivery-owner 后段检查项。 |
| Browser daemon / Chrome extension / Side Panel PTY | Isolate | 高权限 runtime，cookie/token/PTY/prompt-injection 边界大 | 只在独立 sandbox/source-lock 实验，不接入默认 runtime。 |
| GBrain setup/sync | Isolate / Reference only | 可能写 host config、索引 repo、引入远端/本地 state | 只参考 per-worktree pin 和 sync boundary。 |
| Telemetry/update/upgrade/setup scripts | Reject for direct adoption | 用户明确禁止安装；团队默认不应静默变更 host/runtime | 不接入；只记录风险。 |
| Community popularity signal | Reference only | 可解释为什么值得看，不能证明质量 | 作为优先级信号，不作为采用证据。 |

## 12. 当前仓库查漏补缺

1. 在 product-director / product-manager 前置阶段增加 demand reality gauntlet：实际用户、status quo、付费/切换成本、具体 persona、timing、distribution。
2. 为设计与 DX 增加 plan-stage scorecard，但输出必须进入 canonical artifact 或 review result，不能只留聊天文本。
3. 为 fixer/QA issue loop 增加 root-cause-first investigation packet：hypothesis、observed evidence、falsification、fix proof、regression proof。
4. 增强 QA_B/QA_D 的 browser exploration 方法论：console/network/screenshot/trace/repro/health score，同时保留 `browser_required` 严格证据规则。
5. 建立 post-ship learning/retro 的稳定 artifact，供 delivery-owner 和 future planning 消费。
6. 若要探索 browser runtime，先做 isolated spike：禁 telemetry/sync/update，限定 localhost/token scope，禁止 PTY 注入默认开启，所有 host writes 显式 opt-in。

## 13. 分阶段路线图

| 阶段 | 动作 | 验收证据 |
|---|---|---|
| Phase 0 | 不接入 runtime，只把本报告作为 reference | 无 repo runtime diff；只保留报告和 `/tmp` 证据。 |
| Phase 1 | Adapt front-half demand gauntlet 到 product/director 流程 | schema/template/test 同步；fixtures 能证明问题被消费。 |
| Phase 2 | Adapt plan review scorecards 到 design/tech-lead/review artifacts | completion check 能验证 scorecard 字段；低信号自然语言断言不新增。 |
| Phase 3 | Adapt root-cause investigation 和 QA exploration 方法论 | `QAR-XXX` / fixer / qa-result 中有 RCA 与 browser evidence refs。 |
| Phase 4 | 设计 isolated browser-runtime spike，不接默认安装 | runtime-surface contract、sandbox、rollback、security review、manual opt-in 全部 PASS。 |
| Phase 5 | 评估是否需要长期 runtime provider | 真实项目 dogfood 证据、风险记录、卸载验证和用户裁决。 |

## 14. 明确不建议做的事

- 不建议把 gstack 加入 `community/SOURCES.yaml` 或默认安装路径。
- 不建议修改 `contracts/skill-runtime-surface.json` 来直接暴露 gstack runtime。
- 不建议运行 upstream setup、browser daemon、telemetry、sync、upgrade、routing injection、commit scripts。
- 不建议把 gstack 的 narrative review 直接当作本仓 readiness gate。
- 不建议把 GitHub stars、skills installs、YC/Garry Tan halo 当作质量证明。
- 不建议在没有 source-lock、sandbox、卸载/回滚、security review 前接入 browser extension、PTY injection、remote tunnel 或 GBrain sync。

## 15. Red-Team 复核结果

Red-team 认为本 benchmark 最容易错在：

1. 从 generated skill preamble 过度推断实际能力，即 inventory over-infer 风险。
2. 把 runtime/tooling inventory 的 140 文件当成完整 runtime implementation coverage。
3. 低估当前仓 contract/schema/gate governance，因为它不如 browser runtime 显眼。
4. 高估 front-half 和 QA/browser 文档声明，因为本次没有运行 daemon。
5. 混淆 setup-time mutation 与 normal skill invocation mutation。
6. 同时也可能低估 setup/install side effects，因为没有建模完整 side-effect graph。
7. 用 community popularity 替代长期 reliability/security/value evidence。
8. 把双方能力放在同一计数轴上，而不是区分 runtime ambition 与 governance maturity。

本文已把这些风险写入执行口径、runtime coverage limitation、决策表和剩余不确定性。

## 16. 剩余不确定性

- 未运行 gstack runtime，因此无法验证 browser daemon、extension、GBrain、telemetry、setup/upgrade 的实际行为、性能和安全边界。
- Runtime inventory 没有覆盖完整 implementation source groups；需要下一轮 isolated audit 才能做 code-level security conclusion。
- skills.sh installs 和 GitHub stars 是 adoption signal，不是 retention、成功交付或安全质量证明。
- 当前仓脏工作树中已有大量 pre-existing changes，本报告没有审查这些变更。
- 本报告没有提出或实施任何本仓 skill/contract/test 改动；路线图需要后续单独任务和失败测试先行。

## 附录 A: gstack Skill Coverage Table

| # | Path | Name | Front | Middle | Back | Questions | Browser | Write | State | Repo | Auto Commit | Network/Sync | Artifact |
|---:|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `SKILL.md` | `gstack` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 2 | `autoplan/SKILL.md` | `autoplan` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 3 | `benchmark/SKILL.md` | `benchmark` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 4 | `benchmark-models/SKILL.md` | `benchmark-models` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 5 | `browse/SKILL.md` | `browse` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 6 | `browser-skills/hackernews-frontpage/SKILL.md` | `hackernews-frontpage` | yes | no | no | no | yes | no | no | no | no | no | no |
| 7 | `canary/SKILL.md` | `canary` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 8 | `careful/SKILL.md` | `careful` | yes | no | no | no | no | no | yes | no | no | yes | yes |
| 9 | `codex/SKILL.md` | `codex` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 10 | `context-restore/SKILL.md` | `context-restore` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 11 | `context-save/SKILL.md` | `context-save` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 12 | `cso/SKILL.md` | `cso` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 13 | `design-consultation/SKILL.md` | `design-consultation` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 14 | `design-html/SKILL.md` | `design-html` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 15 | `design-review/SKILL.md` | `design-review` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 16 | `design-shotgun/SKILL.md` | `design-shotgun` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 17 | `devex-review/SKILL.md` | `devex-review` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 18 | `document-generate/SKILL.md` | `document-generate` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 19 | `document-release/SKILL.md` | `document-release` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 20 | `freeze/SKILL.md` | `freeze` | yes | no | no | yes | no | no | yes | no | no | no | yes |
| 21 | `gstack-upgrade/SKILL.md` | `gstack-upgrade` | yes | no | yes | yes | no | yes | yes | yes | no | yes | no |
| 22 | `guard/SKILL.md` | `guard` | yes | no | no | yes | no | no | yes | no | no | yes | yes |
| 23 | `health/SKILL.md` | `health` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 24 | `investigate/SKILL.md` | `investigate` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 25 | `ios-clean/SKILL.md` | `ios-clean` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 26 | `ios-design-review/SKILL.md` | `ios-design-review` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 27 | `ios-fix/SKILL.md` | `ios-fix` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 28 | `ios-qa/SKILL.md` | `ios-qa` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 29 | `ios-sync/SKILL.md` | `ios-sync` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 30 | `land-and-deploy/SKILL.md` | `land-and-deploy` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 31 | `landing-report/SKILL.md` | `landing-report` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 32 | `learn/SKILL.md` | `learn` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 33 | `make-pdf/SKILL.md` | `make-pdf` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 34 | `office-hours/SKILL.md` | `office-hours` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 35 | `open-gstack-browser/SKILL.md` | `open-gstack-browser` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 36 | `openclaw/skills/gstack-openclaw-ceo-review/SKILL.md` | `gstack-openclaw-ceo-review` | yes | yes | yes | yes | no | no | no | no | no | yes | yes |
| 37 | `openclaw/skills/gstack-openclaw-investigate/SKILL.md` | `gstack-openclaw-investigate` | yes | yes | yes | no | yes | no | no | no | no | no | yes |
| 38 | `openclaw/skills/gstack-openclaw-office-hours/SKILL.md` | `gstack-openclaw-office-hours` | yes | yes | yes | no | no | no | no | no | no | yes | yes |
| 39 | `openclaw/skills/gstack-openclaw-retro/SKILL.md` | `gstack-openclaw-retro` | no | no | yes | no | yes | no | no | no | no | yes | yes |
| 40 | `pair-agent/SKILL.md` | `pair-agent` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 41 | `plan-ceo-review/SKILL.md` | `plan-ceo-review` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 42 | `plan-design-review/SKILL.md` | `plan-design-review` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 43 | `plan-devex-review/SKILL.md` | `plan-devex-review` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 44 | `plan-eng-review/SKILL.md` | `plan-eng-review` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 45 | `plan-tune/SKILL.md` | `plan-tune` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 46 | `qa/SKILL.md` | `qa` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 47 | `qa-only/SKILL.md` | `qa-only` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 48 | `retro/SKILL.md` | `retro` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 49 | `review/SKILL.md` | `review` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 50 | `scrape/SKILL.md` | `scrape` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 51 | `setup-browser-cookies/SKILL.md` | `setup-browser-cookies` | yes | yes | yes | yes | yes | no | yes | yes | yes | yes | yes |
| 52 | `setup-deploy/SKILL.md` | `setup-deploy` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 53 | `setup-gbrain/SKILL.md` | `setup-gbrain` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 54 | `ship/SKILL.md` | `ship` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 55 | `skillify/SKILL.md` | `skillify` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 56 | `sync-gbrain/SKILL.md` | `sync-gbrain` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| 57 | `unfreeze/SKILL.md` | `unfreeze` | yes | no | no | no | no | no | yes | no | no | no | yes |

## 附录 B: Runtime / Tooling Coverage Table

| # | Path | Group | Telemetry | Sync/Remote | Browser | Host | Update/Install | Repo Mutation | Security |
|---:|---|---|---|---|---|---|---|---|---|
| 1 | `ARCHITECTURE.md` | `ARCHITECTURE.md` | yes | yes | yes | yes | yes | yes | yes |
| 2 | `BROWSER.md` | `BROWSER.md` | yes | yes | yes | yes | yes | yes | yes |
| 3 | `DESIGN.md` | `DESIGN.md` | no | no | yes | yes | no | no | no |
| 4 | `ETHOS.md` | `ETHOS.md` | no | no | no | yes | no | no | yes |
| 5 | `README.md` | `README.md` | yes | yes | yes | yes | yes | yes | yes |
| 6 | `SKILL.md` | `SKILL.md` | yes | yes | yes | yes | yes | yes | yes |
| 7 | `USING_GBRAIN_WITH_GSTACK.md` | `USING_GBRAIN_WITH_GSTACK.md` | yes | yes | yes | yes | yes | yes | yes |
| 8 | `agents/openai.yaml` | `agents` | no | no | yes | no | no | no | yes |
| 9 | `bin/chrome-cdp` | `bin` | no | yes | yes | no | no | no | no |
| 10 | `bin/dev-setup` | `bin` | no | no | no | yes | yes | no | no |
| 11 | `bin/dev-teardown` | `bin` | no | no | no | yes | yes | no | no |
| 12 | `bin/gstack-analytics` | `bin` | yes | no | no | no | yes | no | no |
| 13 | `bin/gstack-artifacts-init` | `bin` | no | yes | no | yes | yes | yes | yes |
| 14 | `bin/gstack-artifacts-url` | `bin` | no | yes | no | yes | no | no | no |
| 15 | `bin/gstack-brain-consumer` | `bin` | no | yes | no | yes | yes | no | yes |
| 16 | `bin/gstack-brain-context-load.ts` | `bin` | no | yes | no | yes | yes | no | no |
| 17 | `bin/gstack-brain-enqueue` | `bin` | no | yes | no | no | no | no | yes |
| 18 | `bin/gstack-brain-reader` | `bin` | no | yes | no | yes | yes | no | yes |
| 19 | `bin/gstack-brain-restore` | `bin` | no | yes | no | no | yes | no | yes |
| 20 | `bin/gstack-brain-sync` | `bin` | no | yes | no | yes | yes | yes | yes |
| 21 | `bin/gstack-brain-uninstall` | `bin` | no | yes | no | yes | yes | yes | yes |
| 22 | `bin/gstack-builder-profile` | `bin` | no | no | no | no | yes | no | no |
| 23 | `bin/gstack-codex-probe` | `bin` | yes | no | no | yes | yes | no | yes |
| 24 | `bin/gstack-community-dashboard` | `bin` | yes | yes | no | no | yes | no | no |
| 25 | `bin/gstack-config` | `bin` | yes | yes | no | yes | yes | yes | yes |
| 26 | `bin/gstack-developer-profile` | `bin` | no | yes | no | no | yes | no | no |
| 27 | `bin/gstack-diff-scope` | `bin` | no | yes | no | no | no | no | yes |
| 28 | `bin/gstack-extension` | `bin` | no | no | yes | yes | yes | no | no |
| 29 | `bin/gstack-gbrain-detect` | `bin` | no | yes | no | yes | yes | no | no |
| 30 | `bin/gstack-gbrain-install` | `bin` | no | yes | no | yes | yes | no | no |
| 31 | `bin/gstack-gbrain-lib.sh` | `bin` | no | yes | no | no | yes | no | yes |
| 32 | `bin/gstack-gbrain-mcp-verify` | `bin` | no | yes | no | yes | yes | no | yes |
| 33 | `bin/gstack-gbrain-repo-policy` | `bin` | no | yes | no | yes | yes | no | yes |
| 34 | `bin/gstack-gbrain-source-wireup` | `bin` | no | yes | no | no | yes | no | yes |
| 35 | `bin/gstack-gbrain-supabase-provision` | `bin` | no | yes | no | yes | yes | no | yes |
| 36 | `bin/gstack-gbrain-supabase-verify` | `bin` | no | yes | no | yes | no | no | no |
| 37 | `bin/gstack-gbrain-sync.ts` | `bin` | no | yes | no | yes | yes | yes | yes |
| 38 | `bin/gstack-global-discover.ts` | `bin` | no | yes | no | yes | yes | no | no |
| 39 | `bin/gstack-ios-qa-daemon` | `bin` | no | yes | no | yes | yes | no | yes |
| 40 | `bin/gstack-ios-qa-mint` | `bin` | no | yes | no | no | yes | no | yes |
| 41 | `bin/gstack-jsonl-merge` | `bin` | no | yes | no | no | no | no | yes |
| 42 | `bin/gstack-learnings-log` | `bin` | no | yes | no | no | no | no | yes |
| 43 | `bin/gstack-learnings-search` | `bin` | no | yes | no | no | no | no | yes |
| 44 | `bin/gstack-memory-ingest.ts` | `bin` | yes | yes | no | yes | yes | yes | yes |
| 45 | `bin/gstack-model-benchmark` | `bin` | no | yes | no | yes | no | no | yes |
| 46 | `bin/gstack-next-version` | `bin` | no | yes | no | yes | no | no | no |
| 47 | `bin/gstack-open-url` | `bin` | no | no | no | no | no | no | no |
| 48 | `bin/gstack-patch-names` | `bin` | no | no | no | no | yes | no | no |
| 49 | `bin/gstack-paths` | `bin` | yes | no | no | yes | yes | no | yes |
| 50 | `bin/gstack-platform-detect` | `bin` | no | no | no | yes | yes | no | no |
| 51 | `bin/gstack-pr-title-rewrite.sh` | `bin` | no | no | no | no | no | no | no |
| 52 | `bin/gstack-question-log` | `bin` | no | yes | no | yes | no | no | yes |
| 53 | `bin/gstack-question-preference` | `bin` | no | yes | no | no | no | no | yes |
| 54 | `bin/gstack-relink` | `bin` | no | yes | yes | yes | yes | no | no |
| 55 | `bin/gstack-repo-mode` | `bin` | no | yes | no | no | no | no | no |
| 56 | `bin/gstack-review-log` | `bin` | no | yes | no | no | no | no | no |
| 57 | `bin/gstack-review-read` | `bin` | no | no | no | no | no | no | no |
| 58 | `bin/gstack-security-dashboard` | `bin` | yes | no | no | no | yes | no | yes |
| 59 | `bin/gstack-session-update` | `bin` | yes | no | no | yes | yes | no | no |
| 60 | `bin/gstack-settings-hook` | `bin` | no | yes | no | yes | yes | no | no |
| 61 | `bin/gstack-slug` | `bin` | no | yes | no | no | no | no | yes |
| 62 | `bin/gstack-specialist-stats` | `bin` | no | no | no | no | no | no | yes |
| 63 | `bin/gstack-taste-update` | `bin` | no | yes | no | no | yes | no | yes |
| 64 | `bin/gstack-team-init` | `bin` | no | yes | no | yes | yes | yes | yes |
| 65 | `bin/gstack-telemetry-log` | `bin` | yes | yes | no | yes | yes | no | yes |
| 66 | `bin/gstack-telemetry-sync` | `bin` | yes | yes | no | yes | yes | no | no |
| 67 | `bin/gstack-timeline-log` | `bin` | no | yes | no | no | no | no | no |
| 68 | `bin/gstack-timeline-read` | `bin` | no | yes | no | no | no | no | no |
| 69 | `bin/gstack-uninstall` | `bin` | yes | yes | yes | yes | yes | no | no |
| 70 | `bin/gstack-update-check` | `bin` | yes | yes | no | yes | yes | no | no |
| 71 | `conductor.json` | `conductor.json` | no | no | no | no | yes | no | no |
| 72 | `docs/ADDING_A_HOST.md` | `docs` | no | no | no | yes | yes | yes | yes |
| 73 | `docs/ON_THE_LOC_CONTROVERSY.md` | `docs` | yes | yes | yes | yes | yes | no | yes |
| 74 | `docs/OPENCLAW.md` | `docs` | yes | yes | no | yes | yes | yes | yes |
| 75 | `docs/REMOTE_BROWSER_ACCESS.md` | `docs` | no | yes | yes | yes | yes | no | yes |
| 76 | `docs/designs/BROWSER_SKILLS_V1.md` | `docs` | yes | yes | yes | yes | yes | yes | yes |
| 77 | `docs/designs/BUN_NATIVE_INFERENCE.md` | `docs` | no | yes | yes | no | no | no | yes |
| 78 | `docs/designs/CHROME_VS_CHROMIUM_EXPLORATION.md` | `docs` | no | yes | yes | no | no | no | yes |
| 79 | `docs/designs/CONDUCTOR_CHROME_SIDEBAR_INTEGRATION.md` | `docs` | no | no | yes | yes | yes | no | no |
| 80 | `docs/designs/CONDUCTOR_SESSION_API.md` | `docs` | no | yes | yes | yes | yes | no | yes |
| 81 | `docs/designs/DESIGN_SHOTGUN.md` | `docs` | no | yes | yes | yes | yes | no | yes |
| 82 | `docs/designs/DESIGN_TOOLS_V1.md` | `docs` | no | yes | yes | yes | yes | yes | yes |
| 83 | `docs/designs/FIX_1671_PROFILE_MIGRATION.md` | `docs` | no | yes | no | yes | yes | no | yes |
| 84 | `docs/designs/GCOMPACTION.md` | `docs` | yes | yes | yes | yes | yes | yes | yes |
| 85 | `docs/designs/GSTACK_BROWSER_V0.md` | `docs` | yes | yes | yes | yes | yes | no | yes |
| 86 | `docs/designs/ML_PROMPT_INJECTION_KILLER.md` | `docs` | yes | yes | yes | yes | yes | yes | yes |
| 87 | `docs/designs/PACING_UPDATES_V0.md` | `docs` | yes | no | yes | yes | yes | no | no |
| 88 | `docs/designs/PLAN_TUNING_V0.md` | `docs` | yes | yes | yes | yes | yes | no | yes |
| 89 | `docs/designs/PLAN_TUNING_V1.md` | `docs` | yes | yes | yes | yes | yes | yes | yes |
| 90 | `docs/designs/SELF_LEARNING_V0.md` | `docs` | yes | yes | no | yes | yes | yes | yes |
| 91 | `docs/designs/SESSION_INTELLIGENCE.md` | `docs` | yes | yes | no | yes | no | no | yes |
| 92 | `docs/designs/SIDEBAR_MESSAGE_FLOW.md` | `docs` | no | yes | yes | yes | yes | no | yes |
| 93 | `docs/designs/SLATE_HOST.md` | `docs` | yes | yes | no | yes | yes | yes | yes |
| 94 | `docs/designs/SLOP_SCAN_FOR_REVIEW_SHIP.md` | `docs` | no | yes | yes | yes | yes | yes | yes |
| 95 | `docs/designs/SYNC_GBRAIN_BATCH_INGEST.md` | `docs` | no | yes | no | yes | yes | yes | yes |
| 96 | `docs/designs/v2_PLAN.md` | `docs` | yes | yes | yes | yes | yes | yes | yes |
| 97 | `docs/domain-skills.md` | `docs` | yes | yes | yes | yes | yes | no | yes |
| 98 | `docs/explanation-diataxis-in-gstack.md` | `docs` | no | yes | no | no | yes | no | no |
| 99 | `docs/gbrain-sync-errors.md` | `docs` | no | yes | no | no | yes | no | yes |
| 100 | `docs/gbrain-sync.md` | `docs` | yes | yes | yes | yes | yes | yes | yes |
| 101 | `docs/howto-document-a-shipped-feature.md` | `docs` | no | yes | no | yes | yes | no | no |
| 102 | `docs/howto-ios-testing-with-gstack.md` | `docs` | no | yes | yes | yes | yes | no | yes |
| 103 | `docs/skills.md` | `docs` | yes | yes | yes | yes | yes | yes | yes |
| 104 | `docs/tutorial-document-generate.md` | `docs` | no | yes | no | yes | yes | yes | no |
| 105 | `extension/background.js` | `extension` | no | yes | yes | yes | yes | no | yes |
| 106 | `extension/content.css` | `extension` | no | no | no | yes | no | no | no |
| 107 | `extension/content.js` | `extension` | no | yes | yes | yes | no | no | no |
| 108 | `extension/inspector.css` | `extension` | no | no | no | no | no | no | no |
| 109 | `extension/inspector.js` | `extension` | no | yes | yes | no | yes | no | no |
| 110 | `extension/manifest.json` | `extension` | no | no | no | yes | no | no | yes |
| 111 | `extension/popup.html` | `extension` | no | no | no | yes | no | no | no |
| 112 | `extension/popup.js` | `extension` | no | yes | yes | no | yes | no | no |
| 113 | `extension/sidepanel-terminal.js` | `extension` | no | yes | yes | yes | yes | yes | yes |
| 114 | `extension/sidepanel.css` | `extension` | no | no | yes | yes | yes | no | yes |
| 115 | `extension/sidepanel.html` | `extension` | no | no | yes | yes | yes | no | yes |
| 116 | `extension/sidepanel.js` | `extension` | no | yes | yes | yes | yes | no | yes |
| 117 | `hosts/claude.ts` | `hosts` | no | yes | no | yes | yes | no | no |
| 118 | `hosts/codex.ts` | `hosts` | no | yes | no | yes | yes | no | yes |
| 119 | `hosts/cursor.ts` | `hosts` | no | yes | no | yes | yes | no | yes |
| 120 | `hosts/factory.ts` | `hosts` | no | yes | no | yes | yes | no | yes |
| 121 | `hosts/gbrain.ts` | `hosts` | no | yes | no | yes | yes | yes | yes |
| 122 | `hosts/hermes.ts` | `hosts` | no | yes | no | yes | yes | yes | yes |
| 123 | `hosts/index.ts` | `hosts` | no | yes | no | yes | no | no | no |
| 124 | `hosts/kiro.ts` | `hosts` | no | yes | no | yes | yes | no | yes |
| 125 | `hosts/openclaw.ts` | `hosts` | no | yes | no | yes | yes | yes | yes |
| 126 | `hosts/opencode.ts` | `hosts` | no | yes | no | yes | yes | no | yes |
| 127 | `hosts/slate.ts` | `hosts` | no | yes | no | yes | yes | no | yes |
| 128 | `lib/conductor-env-shim.ts` | `lib` | no | yes | no | yes | no | no | no |
| 129 | `lib/gbrain-exec.ts` | `lib` | no | yes | no | yes | no | no | no |
| 130 | `lib/gbrain-local-status.ts` | `lib` | no | yes | no | yes | yes | no | no |
| 131 | `lib/gbrain-sources.ts` | `lib` | no | yes | no | no | yes | no | no |
| 132 | `lib/gstack-memory-helpers.ts` | `lib` | no | yes | no | yes | yes | no | yes |
| 133 | `lib/worktree.ts` | `lib` | no | yes | no | yes | yes | no | no |
| 134 | `model-overlays/claude.md` | `model-overlays` | no | no | no | no | no | no | no |
| 135 | `model-overlays/gemini.md` | `model-overlays` | no | no | no | no | no | no | no |
| 136 | `model-overlays/gpt-5.4.md` | `model-overlays` | no | no | no | no | yes | no | no |
| 137 | `model-overlays/gpt.md` | `model-overlays` | no | no | no | no | no | no | no |
| 138 | `model-overlays/o-series.md` | `model-overlays` | no | no | no | no | no | no | no |
| 139 | `model-overlays/opus-4-7.md` | `model-overlays` | no | no | no | yes | yes | no | yes |
| 140 | `package.json` | `package.json` | yes | no | yes | yes | yes | no | no |

## 附录 C: Agent Team Verbatim Output Index

- `/tmp/gstack-agent-outputs/01-inventory-auditor.md`
- `/tmp/gstack-agent-outputs/02-ontology.md`
- `/tmp/gstack-agent-outputs/03-community-value.md`
- `/tmp/gstack-agent-outputs/04-front-half.md`
- `/tmp/gstack-agent-outputs/05-middle-system.md`
- `/tmp/gstack-agent-outputs/06-back-half.md`
- `/tmp/gstack-agent-outputs/07-runtime-governance.md`
- `/tmp/gstack-agent-outputs/08-current-repo.md`
- `/tmp/gstack-agent-outputs/09-red-team.md`

## 附录 D: 关键证据索引

| Evidence | Path / Value |
|---|---|
| Upstream clone | `/tmp/gstack-systematic-benchmark-2026-05-26/` |
| Upstream commit | `22f8c7f4e1eda65680d4b87a2548429f44020277` |
| Current repo HEAD | `a4e55432ab4410ce8d5f51b8d9e6d70918add512` |
| Skill search output | `/tmp/gstack-skills-find.txt` |
| Skills page HTML | `/tmp/gstack-skills-page.html` |
| GitHub metadata | `/tmp/gstack-github-repo.json` |
| Skill inventory JSON | `/tmp/gstack-skill-inventory.json` |
| Skill inventory Markdown | `/tmp/gstack-skill-inventory.md` |
| Runtime inventory JSON | `/tmp/gstack-runtime-inventory.json` |
| Runtime inventory Markdown | `/tmp/gstack-runtime-inventory.md` |
| Ontology input | `/tmp/gstack-ontology-input.md` |
| Agent outputs directory | `/tmp/gstack-agent-outputs/` |
| Inventory auditor output | `/tmp/gstack-agent-outputs/01-inventory-auditor.md` |
| Ontology output | `/tmp/gstack-agent-outputs/02-ontology.md` |
| Community value output | `/tmp/gstack-agent-outputs/03-community-value.md` |
| Front-half output | `/tmp/gstack-agent-outputs/04-front-half.md` |
| Middle-system output | `/tmp/gstack-agent-outputs/05-middle-system.md` |
| Back-half output | `/tmp/gstack-agent-outputs/06-back-half.md` |
| Runtime/governance output | `/tmp/gstack-agent-outputs/07-runtime-governance.md` |
| Current-repo output | `/tmp/gstack-agent-outputs/08-current-repo.md` |
| Red-team output | `/tmp/gstack-agent-outputs/09-red-team.md` |
