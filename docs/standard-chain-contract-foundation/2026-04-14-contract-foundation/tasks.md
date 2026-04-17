# Tasks — Standard Chain Contract Foundation
Created: 2026-04-14
Related plan: ./plan.md

## 需求

把当前标准链路从 `process md` 控制面切换为 `canonical JSON + evidence refs + HTML` 三层模型。

这次不是补一个局部脚本，而是把标准链路运行时真源、引用解析、阶段流转、签收授权、HTML 投影、replay oracle 与 cutover gate 一起收束到统一 contract foundation 上。

## 目标

1. 在 `contracts/canonical/` 冻结 v1 的 registry bundle、schema、template 与默认输出布局，形成唯一 contract 真源。
2. 在 `tools/community/` 落地 runtime state、artifact registry、validator stack、`user-decision writer`、projection/replay CLI。
3. 让标准链路的新 `feature-phase` 默认运行在 canonical-only 模式，不允许 `md/json` mixed mode，不允许 HTML 回退偷读旧 `md`。
4. 用一条 golden pilot 样本证明 `REPLAN`、`BLOCKED -> 恢复`、`QUARANTINED -> 恢复`、`user-decision`、`PARTIAL` goal closure、projection provenance 与 replay oracle 全部闭环。

## 验收标准

- 标准链路 canonical JSON 成为唯一 LLM 输出真源，`shared/runtime/standard-chain-catalog.json` 能列出 v1 全量 artifact、schema、template 与默认物理路径。
- 旧 `process md` 不再承担标准链路运行时真源或 gate 输入；新 phase 的控制面只允许消费 canonical artifact、active registry 与 projection sidecar。
- validator stack 必须替代标题/关键词匹配，能够 fail-close 拦截缺关键字段、非法枚举、断链引用、stale evidence、mixed-version、非法阶段流转与 authority conflict。
- replay matrix 必须覆盖 `BLOCKED`、`REPLAN`、`CONDITIONAL_ALLOW`、`PARTIAL`、`N_A`、`QUARANTINED -> 恢复`、`mixed-version fail`、`authority-conflict fail`、`ref-break fail`。
- HTML 必须只从 canonical JSON + evidence refs 生成，并且每个 view 都带 `projection-manifest.json` 证明 provenance。
- 失败 cutover 单元只能走 `freeze + quarantine`，不能在同一 `feature-phase` 内回切旧 `md` 链路。

## 修改范围

- foundation contracts
  - `contracts/canonical/`
  - `shared/runtime/standard-chain-catalog.json`
  - `shared/runtime/projection-views.json`
- runtime tools
  - `tools/community/build_standard_chain_catalog.py`
  - `tools/community/canonical_ref_resolver.py`
  - `tools/community/manage_artifact_registry.py`
  - `tools/community/update_delivery_state.py`
  - `tools/community/normalize_canonical_artifact.py`
  - `tools/community/validate_canonical_schema.py`
  - `tools/community/validate_canonical_rules.py`
  - `tools/community/resolve_evidence_refs.py`
  - `tools/community/validate_projection_manifest.py`
  - `tools/community/validate_standard_chain_phase.py`
  - `tools/community/authority_proof.py`
  - `tools/community/write_user_decision.py`
  - `tools/community/materialize_canonical_html.py`
  - `tools/community/replay_canonical_phase.py`
- standard-chain skills and gates
  - `contracts/skill-chain.yaml`
  - `shared/skills/{product-director,product-manager,design,test-design,tech-lead,developer,review,verify,qa,delivery-owner}/`
  - 对应 `references/templates/*.md`
  - 对应 `scripts/completion_check.sh`
- tests and fixtures
  - `tests/fixtures/standard-chain-foundation/`
  - `tests/test-standard-chain-foundation-registry.sh`
  - `tests/test-standard-chain-runtime-state.sh`
  - `tests/test-standard-chain-validator-stack.sh`
  - `tests/test-standard-chain-user-decision.sh`
  - `tests/test-standard-chain-projection-replay.sh`
  - `tests/test-standard-chain-cutover.sh`
  - 受影响的既有 gate tests

## 非目标

- 不迁移已经在旧链路中执行中的历史 `feature-phase`。
- 不在 v1 内纳入 `mod.json`、`adr.json` 与 richer aggregate HTML views。
- 不允许长期双跑、双真源、手工解释兜底。
- 不把 evidence 正文统一成大一统 schema；v1 只统一 evidence 最小引用合同。

## Acceptance Checklist

- [x] T1 冻结 foundation registry bundle、shared core schema、artifact template 与 runtime catalog
  - AC: `contracts/canonical/registry-bundle.yaml` 将 `chain_version` 唯一映射到 `vocabulary / authority / stage / compatibility` 四类 registry，并由 `tools/community/build_standard_chain_catalog.py` 基于 `registry-bundle.yaml + 解析后的 bundle 映射 + 被引用 registry 内容` 计算唯一 `chain_registry_digest`。
  - AC: `contracts/canonical/vocabulary-registry.yaml`、`authority-registry.yaml`、`stage-registry.yaml`、`compatibility-matrix.yaml` 覆盖 design 冻结的全部枚举、authority 与 transition matrix，且不允许私有变体绕过。
  - AC: `contracts/canonical/schemas/` 覆盖 v1 必需的 `16` 个 canonical artifact，`contracts/canonical/templates/` 为每个 artifact 提供同名模板，其中 `developer-report.json` 与 `verify-result.json` 冻结到 task 级 `default_path`。
  - AC: `shared/runtime/standard-chain-catalog.json` 列出每个 artifact 的 `schema`、`template`、`scope`、`default_path`，其中 task-scope 工件默认落点为 `docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/...`，并与 registry digest 一致。
  - AC: `tests/test-standard-chain-foundation-registry.sh` 与更新后的 `tests/test-chain-completeness.sh` 能拦截缺 schema、缺 template、重复 digest、未知枚举、bundle 漂移与 task-scope 路径收缩错误。

- [x] T2 落地 runtime state、artifact registry、task lineage 与 blocked/quarantine 恢复路径
  - AC: `delivery-state.json` 与 `artifact-registry.json` 的 schema/template/CLI 均已落地，能区分 `baseline_*` 与 `active_*` 版本语义。
  - AC: `artifact-registry.json` 冻结 append-only `revisions[]` 历史模型；新 revision 只能追加，不能整表覆盖旧 revision。
  - AC: `tools/community/canonical_ref_resolver.py` 只能通过 `artifact-registry.json` 解析物理路径，且只允许消费 `active_for_consumption=true && lifecycle_state=FINALIZED` 的 active revision entry。
  - AC: `tools/community/manage_artifact_registry.py` 能验证 active entry 唯一性、`QUARANTINED -> FINALIZED` 显式恢复、`restore_basis_refs` 与历史 revision tuple 对比。
  - AC: `tools/community/update_delivery_state.py` 能写入 `tasks` runtime state、`BLOCKED` 进入字段、`BLOCKED -> 恢复` 解阻字段，以及 `REPLAN` 后的 `active_plan_version_ref + active_tasks_version_ref` 切换。
  - AC: `tests/test-standard-chain-runtime-state.sh` 覆盖 active discovery、task lineage、`BLOCKED -> 恢复`、quarantine/restore、`DRAFT/SUPERSEDED active fail` 与 replan version switch。

- [x] T3 落地 fail-closed validator stack 与 upstream closure 校验
  - AC: `normalize / schema / rule / evidence / projection` 五层 validator 都有独立 CLI，且 `tools/community/validate_standard_chain_phase.py` 只做顺序编排并透传任一 validator 的非零退出，不允许退化为文件存在检查或私有兜底规则。
  - AC: schema validator 会拦截缺字段、错类型、非法枚举、非法 ref grammar、未知 artifact type。
  - AC: rule validator 会拦截非法阶段流转、producer 越权、`baseline_*`/`active_*` 混用、task supersede 断链、upstream goal/constraint/obligation 丢失与 mixed-version 消费。
  - AC: evidence resolver 会校验 anchor 存在、`relation_type` 合法、stale evidence、`superseded_by_ref` 冲突与 signoff freshness 基线。
  - AC: `tests/test-standard-chain-validator-stack.sh` 覆盖负路径：missing anchor、unknown enum、mixed-version、stale evidence、illegal transition、authority mismatch、upstream closure break。

- [x] T4 落地 `user-decision writer`、authority proof 与 signoff baseline/active 一致性
  - AC: `tools/community/write_user_decision.py` 是 v1 唯一 `user-decision.json` 写入入口，输出 `decision_payload_digest`、`authority_proof_refs`、`decision_basis_refs` 与 `sign_off_status` / `business_risk_acceptance_status`。
  - AC: `tools/community/authority_proof.py` 能根据 authority registry 解析 `verified_actor_id`、`verified_channel`、`proof_type`，并强制 `decision_source -> proof_type`、`actor_id == verified_actor_id`、payload digest 绑定，以及 `verified_at <= produced_at <= verified_until` 的 freshness 窗口；缺 proof、错 actor、错 channel、过期 proof 一律 fail。
  - AC: `user-decision.json` 与 `signoff-package.json` 的 validator 会强制非 `SUPERSEDED` verdict 满足 `baseline_plan_version_ref == active_plan_version_ref`、`baseline_tasks_version_ref == active_tasks_version_ref`，并要求 active refs 与当前 runtime state 一致；旧 decision 在 `REPLAN` 后不能继续 active consumption，`SCRIPT` 不能作为 finalized decision source。
  - AC: `tests/test-standard-chain-user-decision.sh` 覆盖 `APPROVE / REJECT / ACCEPT_RISK / REQUEST_CHANGES`、supersede、authority-conflict、missing-proof、digest-mismatch、expired-proof、script-source fail 与 stale-baseline。

- [x] T5 落地 projection provenance、replay oracle 与 golden pilot
  - AC: `tools/community/materialize_canonical_html.py` 只读 canonical JSON + evidence refs，生成 HTML 与同名 `projection-manifest.json`，并由 projection validator 校验 provenance。
  - AC: `shared/runtime/projection-views.json` 定义最小 operational view 的 `section_sources` 映射，不允许隐式 section 来源，且 projection validator 与 materializer 共用该配置。
  - AC: `shared/runtime/replay-profiles.json` 定义 shared replay profile 与 artifact-specific oracle fields，至少显式覆盖 `BLOCKED -> 恢复`、`CONDITIONAL_ALLOW`、`PARTIAL`、`N_A`、`mixed-version`、`authority-conflict`、`ref-break`、`QUARANTINED -> 恢复`。
  - AC: `tests/fixtures/standard-chain-foundation/golden-pilot/` 提供单 `feature-phase-unit` 黄金样本，覆盖 `REPLAN`、`BLOCKED -> 恢复`、`QUARANTINED -> 恢复`、`user-decision`、`PARTIAL`，并产出 replay oracle record。
  - AC: `tests/test-standard-chain-projection-replay.sh` 覆盖 projection provenance、一致性 digest、replay matrix、authority-conflict/quarantine profile 与 replay oracle record。

- [x] T6 完成 standard-chain cutover、legacy consumer replacement 与 canonical-only readiness gate
  - AC: `contracts/skill-chain.yaml` 与 `shared/runtime/standard-chain-catalog.json` 对齐，标准链路角色输出切到 canonical JSON 文件名与默认路径，其中 task-scope 工件保持 task 级落点。
  - AC: `shared/skills/{product-director,product-manager,design,test-design,tech-lead,developer,review,verify,qa,delivery-owner}`、`shared/protocols/phase-selection-protocol.md`、`shared/agents/{code-reviewer,designer,developer,qa,tech-lead,test-designer,verifier}.md` 已把 standard-chain lane 切到 canonical JSON + active registry，不再把旧 `md` 章节/关键词当运行时真源。
  - AC: `shared/skills/*` 的说明模板不再重复维护 canonical schema 骨架，统一改为引用 `contracts/canonical/templates/*` 或生成示例，避免第二份合同真源。
  - AC: 受影响 hook/check scripts 改为调用 validator stack、ref resolver、readiness gate 与 projection/replay CLI，不再允许 HTML 或旧 `md` 兜底判定。
  - AC: `tests/test-standard-chain-cutover.sh` 与 `tests/test-standard-chain-readiness-gate.sh` 能拦截 mixed mode、旧 `md` fallback、缺 readiness gate、非法 rollback 与未 quarantine 的半成品。
  - AC: 更新后的 `tests/test-chain-completeness.sh`、`tests/test-runtime-integrity.sh`、`tests/test-skill-output-and-gate-contract.sh`、`tests/test-phase-context-resolution.sh`、`tests/test-delivery-owner-phase3-contract.sh`、`tests/test-constraint-closure-contract.sh`、`tests/test-review-convergence-gates.sh`、`tests/test-qa-browser-gate-contract.sh` 能在 canonical-only 新链路下通过。

## Definition of Done

All tasks checked, `tasks.md` 与 `plan.md` 一致性通过，且以下 fresh gate 全绿：

- `bash tests/test-standard-chain-foundation-registry.sh`
- `bash tests/test-standard-chain-runtime-state.sh`
- `bash tests/test-standard-chain-validator-stack.sh`
- `bash tests/test-standard-chain-user-decision.sh`
- `bash tests/test-standard-chain-projection-replay.sh`
- `bash tests/test-standard-chain-cutover.sh`
- `bash tests/test-standard-chain-readiness-gate.sh`
- `bash tests/test-chain-completeness.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-phase-context-resolution.sh`
- `bash tests/test-delivery-owner-phase3-contract.sh`
- `bash tests/test-constraint-closure-contract.sh`
- `bash tests/test-review-convergence-gates.sh`
- `bash tests/test-qa-browser-gate-contract.sh`

## Review Hardening Log

- [x] 2026-04-17: Agent Team 复审发现的 readiness / template field / product split / installed runtime / eval hollow path 已完成系统性修复，并落盘 `fix-7.md` 与 `fix-8.md`。
- [x] 2026-04-17: readiness gate 已覆盖完整 active delivery artifact set：`code-review-result.json`、task-level `developer-report.json` / `verify-result.json`、upstream `brief.json` / `phase-prd.json` / `design.json` / `test-cases.json`、`signoff-package.json` 与 `user-decision.json`。
- [x] 2026-04-17: 模板字段、schema、golden fixture、skill-chain key_fields 与 registry tests 已同步，`authoritative_fields` 不能为空，`tasks.design_refs` / `tasks.test_refs` 不允许空壳。
- [x] 2026-04-17: `product-director` / `product-manager` 拆分后的 Director-only handoff 与 Manager finalized closure 已分层校验；legacy alias、WARN/TBD 空壳、ghost unit index 均 fail-closed。
- [x] 2026-04-17: installed runtime root shadow、缺失 runtime helper、legacy fallback contract 缺失与 product split hollow eval 均有回归覆盖。
- [x] 2026-04-17: Fresh proving commands 覆盖 standard-chain 主链路、角色 gate、安装系统测试、product split eval、clean HOME fallback、contract validator 与任务计划一致性。
- [x] 2026-04-17: Agent Team 第二轮 P1/P2 已完成系统性修复并落盘 `fix-9.md`：readiness 精确任务覆盖、code-review/verify/signoff/user-decision 语义闭环、Director lock digest、UNIT 可执行字段、design/qa completion_check schema 收敛、legacy extra denylist 与 marker-free keyword stuffing 均有 RED/GREEN 回归。
- [x] 2026-04-17: Agent Team 第三轮 P1 已完成复核与修复并落盘 `fix-10.md`：Director lock 快照绑定、plan source/basis required、Phase 3 REVIEW_C 强门禁一致性、low-repeat keyword stuffing、brief legacy alias 与 readiness duplicate/goal/finding 误放行均已补 RED/GREEN 回归。
- [x] 2026-04-17: 最终复审追加问题已收口：active registry 增加 `director_lock_digest`，`user-decision.json.director_lock_digests` 提供 authority-bound 独立锚点，product split eval 增加 distributed keyword stuffing 负例，delivery-owner REVIEW_A/B/C/QA_A 非豁免文档/模板/测试一致，design/QA/test-design skill、reviewer prompt、methodology 与 canonical gate 重新对齐。
