# Tasks — skill-optimizer Harness Delivery
Created: 2026-04-16
Related plan: ./plan.md

## 需求

基于 `design.md`、`runtime-blueprint.md`、`review-resolution.md` 和 `source-notes.md`，交付一套可安装、可触发、可审计、可验证的 `skill-optimizer`。它用于优化已有 Skill 或草稿 Skill，最终输出 JSON runtime artifact、派生 Markdown/HTML 报告、验证结果和迁移证据。

## 修改范围

- 新建 `shared/skills/skill-optimizer/`
- 删除 `shared/skills/new-skills/` 旧入口
- 扩展 `install.sh` 的 runtime completeness 与 quick check
- 增加 skill-optimizer 专用 contract、runtime、eval、migration、end-to-end tests
- 扩展 install、Codex adapter、runtime integrity 和 skill context budget 测试
- 保持 `review-report.md` 为外部输入材料，不把它当实施真源

## Review Team 裁决

- 采纳 small-chain reviewer：`plan.md` 不承载待确认状态，实施按 RED -> GREEN -> REFACTOR 逐 Task 推进。
- 采纳 TDD reviewer：每个 Task 先写可失败测试，再实现，再复跑同一 fresh proving command。
- 采纳 permission reviewer：任何可执行命令先进入 manifest、参数策略、超时、输出上限和退出码语义，再进入 eval runner。
- 采纳 runtime reviewer：consumer-first gate 使用机器可读 field consumer matrix；renderer、eval、verification-result 均有专门 validator 或 aggregator。
- 采纳 migration reviewer：安装器 quick check、runtime completeness、旧入口退役和 rollback 验证进入 T7。
- 采纳 completeness reviewer：每条 AC 补齐 source marker、review 裁决、SO anchor、验证方式、fresh command 和 Pass/Fail condition。
- 采纳 overengineering challenger：首轮先证明最小 `skill-audit.json` 闭环；完整 JSON 三件套、eval、hook adapter 合同和迁移闭环仍进入最终交付。

## Source Coverage Map

| Source | 关键方法论 | 承接任务 | 验证命令 |
| --- | --- | --- | --- |
| C09 | `description`、frontmatter、Tools/SubAgent/Hooks/Skills 边界 | T1, T2, T5 | `bash tests/test-skill-optimizer-contract.sh` |
| C10 | manual-only、`$ARGUMENTS`、`!command`、allowed-tools、hooks、失败路径 | T2, T5, T6 | `bash tests/test-skill-optimizer-contract.sh`; `bash tests/test-skill-optimizer-evals.sh` |
| C11 | Quick Reference、QUICKREF、INDEX、契约式引用、渐进加载、SLASH_COMMAND_TOOL_CHAR_BUDGET | T2, T3, T4 | `bash tests/test-skill-optimizer-contract.sh`; `bash tests/test-skill-optimizer-runtime-artifacts.sh` |
| C12 | fork、SubAgent `skills:` 全量预加载、pipeline、handoff、冲突裁决 | T2, T6, T8 | `bash tests/test-skill-optimizer-evals.sh`; `bash tests/test-skill-optimizer-end-to-end.sh` |
| C13 | script/template 边界、skill-local `rules/`、成熟度证据 | T2, T5, T8 | `bash tests/test-skill-optimizer-contract.sh`; `bash tests/test-skill-optimizer-runtime-artifacts.sh` |
| C14 | Push/Pull、skills marketplace、跨平台、自包含、namespace、monorepo、分发 | T2, T7, T8 | `bash tests/test-skill-optimizer-migration.sh`; `bash tests/test-install-smoke.sh` |
| C99 | 5/10/30、复用、Test Case、可复测 dataset、收益证据 | T2, T6, T8 | `bash tests/test-skill-optimizer-evals.sh`; `bash tests/test-skill-optimizer-end-to-end.sh` |

## Acceptance Checklist

- [x] T1 建立 `skill-optimizer` Skill 入口与 Codex adapter
  - AC1: `shared/skills/skill-optimizer/SKILL.md` 明确触发边界、只读审计默认权限、官方 `skill-creator` 职责分工，并只契约式引用随 Skill 安装的 `references/*`。Source marker: C09/C11/C14/O/S。Review decision refs: F1/W1/W2/M1。Design anchor: SO-TRIGGER-01 / SO-PERMISSION-01 / SO-TRACKING-01。Verification method: frontmatter 与正文 contract test。Fresh proving command: `bash tests/test-skill-optimizer-contract.sh`。Pass/Fail condition: PASS 仅当入口不引用 `docs/skill-optimizer/...`，且触发、权限、来源边界均被断言覆盖。
  - AC2: `shared/skills/skill-optimizer/agents/openai.yaml` 只暴露优化、审计、改造 Skill 质量类请求，不抢 `skill-creator` 新建 Skill 入口；`new-skills` 退役冲突留到 T7 验收。Source marker: C09/C14/O。Review decision refs: F1/W3。Design anchor: SO-TRIGGER-01 / SO-MIGRATION-01。Verification method: Codex adapter install smoke。Fresh proving command: `bash tests/test-codex-skill-adapter.sh`。Pass/Fail condition: PASS 仅当 `skill-optimizer` adapter 存在且 creation trigger 仍归 `skill-creator`。

- [x] T2 建立审计方法 references、examples、D1-D7 与 source coverage
  - AC1: `references/` 覆盖触发、加载、契约式引用、权限、脚本、SubAgent/fork、迁移、D1-D7、source map coverage、Quick Reference、Push/Pull、跨平台、自包含、namespace、monorepo、skills marketplace。Source marker: C09/C10/C11/C12/C13/C14/C99/L/O/S。Review decision refs: W1/W2/M1。Design anchor: SO-LOAD-01 / SO-REFERENCE-01 / SO-SUBAGENT-01 / SO-TRACKING-01。Verification method: reference presence、keyword coverage、contract routing test。Fresh proving command: `bash tests/test-skill-optimizer-contract.sh`。Pass/Fail condition: PASS 仅当每个 reference 有触发条件、读取对象、内容预期、消费方式、证据要求和同步义务。
  - AC2: `examples/` 至少包含触发、非触发、相邻 Skill 冲突、契约式引用好坏例、权限边界、`$ARGUMENTS`、`!command`、QUICKREF/INDEX、fork 隔离、pipeline handoff、格式诱导和复用判断样例。Source marker: C10/C11/C12/C99。Review decision refs: W1/M1。Design anchor: SO-REFERENCE-01 / SO-SUBAGENT-01 / SO-VALIDATION-01。Verification method: example coverage assertions。Fresh proving command: `bash tests/test-skill-optimizer-contract.sh`。Pass/Fail condition: PASS 仅当正例、反例和边界例均可被后续 eval 或报告消费。

- [x] T3 建立最小 JSON runtime schema 与 consumer-first validator
  - AC1: `schemas/skill-audit.schema.json`、`schemas/state-vocabulary.json`、`schemas/field-consumers.json` 和 `validate_schema.py` / `validate_semantics.py` / `validate_consumers.py` 覆盖最小 `skill-audit.json` 闭环。Source marker: C11/C13/S。Review decision refs: F1/F2/W2/M1。Design anchor: SO-RUNTIME-01 / SO-VALIDATION-01。Verification method: positive/negative JSON fixtures。Fresh proving command: `bash tests/test-skill-optimizer-runtime-artifacts.sh`。Pass/Fail condition: PASS 仅当无证据 FAIL、E5 硬化、未知 state、无消费者字段和 Markdown/HTML 反向污染均被拦截。
  - AC2: `field-consumers.json` 是 validator 的机器事实源，不解析 Markdown 表格作为 runtime truth。Source marker: S/L。Review decision refs: F2/M1。Design anchor: SO-RUNTIME-01。Verification method: consumer matrix negative fixture。Fresh proving command: `bash tests/test-skill-optimizer-runtime-artifacts.sh`。Pass/Fail condition: PASS 仅当删除任一必需 consumer 会导致测试失败。

- [x] T4 建立审计 runner、optimization-plan 消费路径与 renderer
  - AC1: `audit_skill.py` 读取目标 Skill，产出 `skill-audit.json`，并从 JSON 渲染 `audit-report.md` / `audit-report.html`；renderer 输出 `source_artifact_hash`、`renderer_version`、`generated_at` 和 stale 判定。Source marker: C11/C13/C99/S。Review decision refs: F1/F2/M1。Design anchor: SO-RUNTIME-01 / SO-VALIDATION-01。Verification method: fixture runner、renderer provenance、stale check。Fresh proving command: `bash tests/test-skill-optimizer-runtime-artifacts.sh`。Pass/Fail condition: PASS 仅当报告只由 JSON 生成，且 source hash 变化后 stale 校验失败。
  - AC2: `optimization-plan.schema.json`、`generate_optimization_plan.py` 和 `validate_plan_consumption.py` 证明 accepted findings、file boundaries 与 verification contracts 有真实消费者。Source marker: C99/S。Review decision refs: F1/F2/M1。Design anchor: SO-RUNTIME-01 / SO-TRACKING-01。Verification method: plan-consumption fixture。Fresh proving command: `bash tests/test-skill-optimizer-runtime-artifacts.sh`。Pass/Fail condition: PASS 仅当缺少 accepted finding、file boundary 或 verification contract 会阻断。

- [x] T5 建立权限、skill-local rules、script manifest 与 hook adapter 合同
  - AC1: review/audit/explain 默认只读；edit/refactor/fix 需要精确写范围；commit/delete/deploy 需要本轮显式授权；`rules/permission-profiles.md` 只描述 skill-local delta，且不得放宽全局 rules。Source marker: C10/C13/L/S。Review decision refs: F2/W2/M1。Design anchor: SO-PERMISSION-01。Verification method: contract test 和权限反例 fixture。Fresh proving command: `bash tests/test-skill-optimizer-contract.sh`。Pass/Fail condition: PASS 仅当只读模式无写工具、写动作缺 scope 被拒绝、危险动作缺授权被拒绝。
  - AC2: `scripts/manifest.json` 记录脚本路径、允许参数、禁止参数、外部命令、超时、输出上限、退出码语义、shell 参数策略和验证命令；`validate_manifest.py` 对任一缺失字段失败。Source marker: C10/C13/L/S。Review decision refs: F1/F2/M1。Design anchor: SO-SCRIPT-01。Verification method: manifest positive/negative fixtures。Fresh proving command: `bash tests/test-skill-optimizer-runtime-artifacts.sh`。Pass/Fail condition: PASS 仅当缺 timeout、output limit、denied args、exit code meanings 或 shell parameter strategy 均失败。
  - AC3: `references/hook-adapter-contract.md` 只定义 adapter lifecycle，不接入全局 hook registry；字段包含 `phase`、`trigger`、`input_artifact`、`allowed_action`、`output_artifact`、`failure_state`、`owner` 和 `rollback`。Source marker: C10/L/S。Review decision refs: F1/F2/W2。Design anchor: SO-SCRIPT-01 / SO-RUNTIME-01。Verification method: contract test 和 runtime artifact lifecycle check。Fresh proving command: `bash tests/test-skill-optimizer-runtime-artifacts.sh`。Pass/Fail condition: PASS 仅当 lifecycle 字段完整且仓库全局 registry 不出现 `skill-optimizer` hook 接入。

- [x] T6 建立 eval seed dataset 与 benchmark 协议
  - AC1: `evals/` 覆盖触发、非触发、相邻冲突、缺参、错参、权限不足、格式诱导、迁移兼容、fork 隔离、SubAgent `skills:` 全量预加载、pipeline 接力、冲突裁决、`$ARGUMENTS`、`!command` 和 `audit_skill.py` fixture 行为。Source marker: C10/C12/C99/S。Review decision refs: W1/W2/M1。Design anchor: SO-SUBAGENT-01 / SO-VALIDATION-01。Verification method: dataset category、fixture assertions、audit fixture output。Fresh proving command: `bash tests/test-skill-optimizer-evals.sh`。Pass/Fail condition: PASS 仅当缺任一必需类别、缺 audit fixture case 或 audit finding 输出错误会失败。
  - AC2: `run_evals.py` 只执行 manifest 允许的 `run_command_id` 或纯 fixture 检查；eval 结果进入 `verification-result` draft input，5/10/30 只作为 usability evidence；seed eval 不作为 live model benchmark。Source marker: C10/C99/S。Review decision refs: F1/W2/M1。Design anchor: SO-SCRIPT-01 / SO-VALIDATION-01。Verification method: eval runner、manifest integration、`validate_eval_results.py`。Fresh proving command: `bash tests/test-skill-optimizer-evals.sh`。Pass/Fail condition: PASS 仅当 raw shell command 被拒绝，且 5/10/30 未被计作质量收益。

- [x] T7 完成 `new-skills` 退役与安装集成
  - AC1: `shared/skills/new-skills/` 删除；默认创建入口回到官方 `skill-creator`，默认优化入口转到 `skill-optimizer`；安装产物不再包含旧入口。Source marker: C14/C99/O/S。Review decision refs: W3/M1。Design anchor: SO-MIGRATION-01 / SO-TRIGGER-01。Verification method: retirement contract and adapter conflict tests。Fresh proving command: `bash tests/test-skill-optimizer-migration.sh && bash tests/test-codex-skill-adapter.sh`。Pass/Fail condition: PASS 仅当 shared 源目录不存在、creation 归 `skill-creator`、optimization 归 `skill-optimizer`。
  - AC2: `install.sh` quick check、runtime completeness、install smoke、runtime integrity、context budget 和 systematic install gate 识别 `skill-optimizer`，并拒绝安装 `new-skills`；context budget 对“未纳入审计清单或目录缺失”硬失败，超预算仍保持 WARN。Source marker: C14/C99/L/S。Review decision refs: F1/W3/M1。Design anchor: SO-MIGRATION-01 / SO-LOAD-01。Verification method: install and runtime smoke tests。Fresh proving command: `bash tests/test-install-smoke.sh && bash tests/test-install-systematic.sh && bash tests/test-runtime-integrity.sh && bash tests/test-skill-context-budget.sh`。Pass/Fail condition: PASS 仅当安装器缺 `skill-optimizer` 会失败，且 Claude/Codex runtime 均不出现 `new-skills`。

- [x] T8 完成端到端样例、verification-result 聚合、覆盖报告与最终验证
  - AC1: 固定 Skill fixture 跑通审计、`skill-audit.json`、`optimization-plan.json`、schema validation、semantic validation、consumer validation、renderer validation、eval、`verification-result.json` 聚合和 final decision。Source marker: C09-C14/C99/L/O/S。Review decision refs: F1/F2/W1/W2/W3/M1。Design anchor: SO-RUNTIME-01 / SO-VALIDATION-01 / SO-TRACKING-01。Verification method: end-to-end fixture and `build_verification_result.py`。Fresh proving command: `bash tests/test-skill-optimizer-end-to-end.sh`。Pass/Fail condition: PASS 仅当 `verification-result.json` 同时包含 schema、semantic、consumer、rendered view、eval、fresh commands、coverage 和 decision。
  - AC2: `implementation-coverage.md` 包含 source marker、review-resolution 裁决、SO-* 锚点、实现文件、验证命令和结果；所有 Task 勾选后进入 verify-change。Source marker: C99/S。Review decision refs: F2/W1/W2/W3/M1。Design anchor: SO-TRACKING-01。Verification method: coverage assertions and final gate set。Fresh proving command: `bash tests/test-skill-optimizer-end-to-end.sh`。Pass/Fail condition: PASS 仅当 coverage 任一链路缺失会失败，且 final gate set 全部通过。

## Definition of Done

All tasks checked = ready for verify-change.

MVP gate is an internal checkpoint, not the completion boundary:

- `bash tests/test-skill-optimizer-contract.sh`
- `bash tests/test-skill-optimizer-runtime-artifacts.sh`

Final gate set:

- `bash tests/test-skill-optimizer-contract.sh`
- `bash tests/test-skill-optimizer-runtime-artifacts.sh`
- `bash tests/test-skill-optimizer-evals.sh`
- `bash tests/test-skill-optimizer-migration.sh`
- `bash tests/test-skill-optimizer-end-to-end.sh`
- `bash tests/test-install-smoke.sh`
- `bash tests/test-install-systematic.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-skill-context-budget.sh`
- `python3 tools/community/check_task_plan_consistency.py docs/skill-optimizer/2026-04-16-course-derived-methodology/tasks.md docs/skill-optimizer/2026-04-16-course-derived-methodology/plan.md`
- `python3 -c 'import pathlib,re,sys; pat=re.compile("\\u57fa\\u672c\\u4e0a|\\u5e94\\u8be5|\\u53ef\\u80fd|\\u5927\\u6982|\\u5dee\\u4e0d\\u591a|"+"TO"+"DO|TB"+"D"); paths=[pathlib.Path("shared/skills/skill-optimizer"), pathlib.Path("docs/skill-optimizer/2026-04-16-course-derived-methodology")]; hits=[]; [hits.append(str(p)) for root in paths if root.exists() for p in root.rglob("*") if p.is_file() and pat.search(p.read_text(encoding="utf-8", errors="ignore"))]; print("\\n".join(hits)); sys.exit(1 if hits else 0)'`
- `git diff --check`
