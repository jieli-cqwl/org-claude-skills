# Standard-chain Content Readiness Product Director First Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `QFT-QMI-PC-001` 的最小评估证据工作区，用当前 `product-director` 完成可复核的静态内容/Harness 审计和 case-bounded 角色裁决；只有继承 runtime 输入已显式冻结且不存在阻断级工作流冲突时，才运行双 lane 诊断回放、Oracle/分叉/下游消费复核。在隔离或 runtime 证据不足时明确阻断，不签发虚假 `CONTENT_PASS`。

**Architecture:** 在 `tools/eval` 新增一个只负责 case、runtime 继承面、隔离、attempt、review、role verdict 和跨文件引用的评估层契约；单 Skill 能力对齐和正式报告原样复用 `skill-quality-audit`，Director canonical 产物原样复用现有 completion gate。先用 disposable subagent probe 枚举 `fork_turns="none"` 仍继承的文件型指令，并把它们作为 Harness surface 冻结；目标 Skill 与强制 process Skill 冲突属于静态内容/Harness 发现，不得靠 executor prompt 绕过。只有静态门通过后才采用人工协调的诊断双 lane，不新增自动回放框架。`run.json` 是运行状态真源；canonical 产物保持原 Schema，`evaluation_only` 只放在 manifest。当前运行器只能证明 `DECLARED_ONLY`，因此回放只产生诊断证据。

**Tech Stack:** Markdown 实施契约、JSON/JSON Schema 评估产物、Python 3 跨文件验证器、仓内 `SimpleSchemaValidator`、Bash contract tests、现有 `skill-quality-audit` validators、现有 Product Director ledger/content/completion gates、Codex subagents 的人工多轮回放。

## Global Constraints

- 批准设计是唯一需求基线：`docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--design.md`，commit `293f624455eb9570f9426b457fadfbb946351049`，blob `adf392c35d01fd1d7fa9013de2e8682aecbcced9`。
- 批准事件唯一真源：`docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--approval-record.md`，commit `d7efad0923136d5cf7c9390a2d38a22cb6a71ff2`，blob `36d9bd0e3673bdd971105bc0f08679a208313277`。正式 alignment 引用第 8 行批准文本、第 18 行能力 ID；case confirmation 文件只保存引用，不复制批准原文。
- 第一片只评估 `SC-CAP-PD-001`。`product-manager` 到 `delivery-owner` 不得被顺带评估或签发结论。
- 不修改任何目标 Skill、Skill 引用、canonical schema、runtime hook、`contracts/active-doc-scope.yaml`、QFT 源码或 QFT 历史提交。
- 不生成真实开发、修复或提交；不执行外部系统操作。
- 不把现有 `tests/fixtures/product-director-manager-move-in-chain/golden-rubric.json` 当 Oracle。它覆盖面更大且包含历史答案，只能作为现有产物形状/validator 的发现入口。
- 不修改 `shared/skills/skill-quality-audit` 的 schema、validator、fixtures 或 tests。新增契约不得复制它的评分、证据等级或 report verdict。
- 现有 `standard_chain_local_eval` 的 `workspace-write`、临时目录和来源自报只能算 `DECLARED_ONLY`。在新的机制证据出现前，任何 replay 都是 diagnostic；不得签 `CONTENT_PASS` 或 `CASE_REPLAY_PASS`。
- `fork_turns="none"` 只清除父对话，不清除 system/developer 注入。当前 runtime 明确暴露 `using-superpowers` 和 `brainstorming`；不得假装 Product Director executor 只看 staging。probe 发现的强制文件读必须进入冻结 Harness surface，未冻结的 `$HOME`/repo 外读取仍是污染。
- `chain-verdict.json`、根 `summary.md` 和 `shadow-phase/` 在本片不得创建。没有执行的阶段不写 `NOT_RUN` 占位。
- 行为/约束变更必须先有失败测试；测试不得用 `grep`/`rg` 锁 Skill/Rule/Reference/Agent Markdown 自然语言正文。
- 每个结论区分 `fact`、`inference`、`assumption` 和 `unknown`；历史代码只支持或反驳实现主张，不拥有业务真相。

---

## Current Evidence And Stop Rules

### Facts

- `QFT-QMI-PC-001`、六个能力 ID、八个 Oracle atom 已由用户批准。
- `qft-tenants@a387e1403d9bcf4a2b3816749054c88fd3b01f31` 的候选 PRD SHA-256 是 `bb451b968112296dc03d78659d85792a1e1d0300881c805653244244b151aacf`。
- `qft-app` 的 ancestry-path 分母是两个提交：`4963626adb7d514d26dfcab22b027ba1eb29e9dc`、`fda108fbc4978cd41e60ddc4cc197cb93e973065`。
- `qft-all` 的 ancestry-path 分母是九个提交：`f3240c69799cc794f3048d7d00d71bd06e42b821`、`b681eb8d80b051ce79f506c4f849545735a6e09c`、`da4a4ca22f87edb162c9834c77f7d20eac64e79f`、`abc9703ad0a4853bfd122b9b1a6f9e441d7b41c9`、`22e2c684a476bdc0818ad7243e21a4e0ff0932c1`、`dc279ab981bb2895f4662b8d534699e4ee859bb2`、`de66075c6f5a8cec730db613dd97b9ad24d231d4`、`1a0355018be04c635290d6a0090dc000a7d984c5`、`e34b45255f14c680edbd1630357d96a10a8b2982`。
- 当前 `standard_chain_local_eval/workspace.py` 使用 `codex exec ... --sandbox workspace-write -C "$WORKSPACE"`，没有读取 allowlist 或可信完整访问日志；历史 executor log 已出现读取工作区外 `$HOME/.codex/rules/*` 的事实。
- `codex sandbox -P :read-only -C /tmp -- /bin/test -r /Users/lijieli/org-claude-skills/docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--approval-record.md` 当前返回 0，证明旧 read-only profile 允许读取工作区外批准记录。

### Inferences

- 当前隔离等级只能是 `DECLARED_ONLY`；这一结论会阻断 authentic replay pass，但不阻止静态审计和诊断回放。
- 本片最有价值的交付不是一个好看的分数，而是验证“冻结输入 -> 两个执行结果 -> 分叉/Oracle/消费 -> 正式内容报告 -> 角色裁决”是否能被第二名审查者重建。

### Unknowns

- 当前 `product-director` 是否存在 P0/P1 内容或 Harness 缺陷，必须由本片证据判断。
- 两个诊断 lane 是否产生无依据关键分叉，不能从现有局部 eval 推断。
- 已批准 Oracle 给出了可观察行为方向、失败信号和 PC/后端范围，但没有独立批准数值目标、观察窗口、观测数据源或资源/时间投入上限。静态审计必须先区分哪些字段可直接映射已批准 atom、哪些是当前内容或 Harness 额外要求；只有后者确实阻断 Director baseline 时，Business Proxy 才返回 `unknown` 并请求业务方裁决。不得用历史排期或实现结果伪造业务成功标准。
- 隔离修复应采用新 Codex permission profile、外部容器还是跨 runtime sandbox，属于本片之后的独立设计，不在此计划猜答案。

### Role Verdict And Run-state Rules

批准设计同时规定了角色裁决、全局状态和隔离上限。为避免偷偷发明新 precedence，本计划分别处理：

Role verdict 按以下顺序匹配：

1. 当前内容或 Harness 有已证 P0/P1：`CONTENT_FAIL`。`DECLARED_ONLY` 下的单次模型表现不能独立证明内容 P0/P1；必须同时有当前内容或 Harness 的直接证据。
2. 业务 Oracle 不足或冲突：`BLOCKED_ORACLE`。
3. 必需输入、surface、提交或验证证据不可复核：`BLOCKED_EVIDENCE`。
4. 上述均未命中但决定性 attempt 仍是 `DECLARED_ONLY`：`BLOCKED_ISOLATION`。

Run global state 独立按批准设计处理：

1. 同一 lane 初始 attempt 加两次重跑均污染：`INCONCLUSIVE_CONTAMINATED`；不得生成 role verdict。
2. 否则，只要本轮隔离能力仍是 `DECLARED_ONLY`，global state 必须是 `BLOCKED_ISOLATION`，即使 role verdict 已记录 `CONTENT_FAIL`、`BLOCKED_ORACLE` 或 `BLOCKED_EVIDENCE`。同时用 `primary_role_outcome` 和 `next_authorized_action` 保留真实首要问题，不把它伪装成 global readiness state。
3. 只有未来另证 `ENFORCED` 或 `OBSERVED` 后，才允许按设计使用 `REPAIR_REQUIRED`、`BLOCKED_ORACLE`、`BLOCKED_EVIDENCE` 或 `CASE_REPLAY_PASS`。
4. 本片永远不允许 `CASE_REPLAY_PASS`；六角色未完成，不能越权。

---

## Acceptance Scope

本计划完成必须同时证明：

- 评估层 JSON schema 和跨文件 validator 能 fail closed 地拒绝 stale approval、漏分类 source、lane 输入 hash 不一致、污染 attempt 参与裁决、`DECLARED_ONLY + CONTENT_PASS`、Oracle Bridge 后 pass、canonical artifact 被塞 `evaluation_only`、未完成六角色却写 chain pass。
- case admission 冻结了批准记录、八个 Oracle atom、QFT 仓库/提交/文件 digest 和完整 ancestry-path/path 分类分母。
- `product-director` content package、runtime surface、consumer 和验证入口已冻结并形成 `surface.json`；`SC-CAP-PD-001` alignment 通过现有 validator。
- runtime inheritance probe 冻结所有已声明的强制文件输入和不可哈希的注入边界；若存在未枚举输入或阻断级 process-Skill/Product-Director 冲突，静态分支合法终止且不得启动 replay。
- 若静态门允许 replay，两个 lane 从相同 staging digest 和 inherited-runtime digest 开始；每轮 Business Proxy 只回答被问到的已批准事实，未知就返回 `unknown`；每个 lane 都记录实际读取声明和 attempt 状态。
- 若静态门允许 replay，每个 lane 要么合法产出不含评估元字段的 canonical Director 产物并经过 ledger/content/completion gates，要么按当前 Skill 正确停止并留下可复核的缺口证据；不得为满足目录结构伪造产物。
- replay 实际发生时，divergence、Oracle 和下游消费记录可追到原 transcript、产物字段、Oracle atom 和当前代码/契约证据。
- 正式 `skill-quality-audit` report 通过现有 alignment/report validators；case-bounded role verdict 按上方 precedence 签发。
- `run.json`、所有 manifest hash 和 verdict 引用由新的跨文件 validator 重新验证通过。
- 目标范围测试通过；仓库全局 quick gate 的既有第三方 mirror 失败与本片结果明确分离。

## Non-goals

- 不修 Product Director Skill；发现先交付，修复另开设计。
- 不扩展到 Product Manager 或其后角色。
- 不实现新的自动 multi-turn runner、judge 或 Viewer。
- 不做 with-skill/without-skill、多模型、多温度、多样本统计。
- 不把诊断 lane 当行为评测。
- 不把历史结果提交泄露给 executor。
- 不为 Delivery Owner 建 shadow runtime；见文末 Deferred Slice。

---

## File Structure

### Evaluation Infrastructure

```text
tools/eval/contracts/standard-chain-content-readiness.schema.json
tools/eval/scripts/validate_standard_chain_content_readiness.py
tests/fixtures/standard-chain-content-readiness/product-director-blocked-isolation/
  run.json
  case/
    confirmation-ref.json
    input-manifest.json
    oracle-manifest.json
    source-classification.json
  roles/product-director/
    surface.json
    decision-atoms.json
    content-audit-alignment.json
    content-audit-report.json
    content-audit-summary.md
    executor-a/lane.json
    executor-a/attempts/attempt-1/attempt.json
    executor-a/attempts/attempt-1/transcript.json
    executor-a/attempts/attempt-1/artifact-manifest.json
    executor-a/attempts/attempt-1/artifacts/product-director-ledger.json
    executor-a/attempts/attempt-1/artifacts/brief.json
    executor-a/attempts/attempt-1/artifacts/phase-1/phase-prd.json
    executor-b/lane.json
    executor-b/attempts/attempt-1/attempt.json
    executor-b/attempts/attempt-1/transcript.json
    executor-b/attempts/attempt-1/artifact-manifest.json
    executor-b/attempts/attempt-1/artifacts/product-director-ledger.json
    executor-b/attempts/attempt-1/artifacts/brief.json
    executor-b/attempts/attempt-1/artifacts/phase-1/phase-prd.json
    divergence-review.json
    oracle-review.json
    downstream-consumption.json
    role-verdict.json
tests/test-standard-chain-content-readiness-contract.sh
tests/gate-plan.json
```

The fixture is synthetic and exists only to test contract semantics. It must not be cited as evidence for `QFT-QMI-PC-001`.

### Real First-slice Evidence

```text
tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/
  run.json
  case/
    confirmation-ref.json
    input-manifest.json
    oracle-manifest.json
    source-classification.json
  roles/product-director/
    surface.json
    decision-atoms.json
    content-audit-alignment.json
    executor-a/
      lane.json
      attempts/attempt-1/attempt.json
      attempts/attempt-1/transcript.json
      attempts/attempt-1/artifact-manifest.json
      attempts/attempt-1/artifacts/product-director-ledger.json
      attempts/attempt-1/artifacts/brief.json
      attempts/attempt-1/artifacts/phase-1/phase-prd.json
    executor-b/
      lane.json
      attempts/attempt-1/attempt.json
      attempts/attempt-1/transcript.json
      attempts/attempt-1/artifact-manifest.json
      attempts/attempt-1/artifacts/product-director-ledger.json
      attempts/attempt-1/artifacts/brief.json
      attempts/attempt-1/artifacts/phase-1/phase-prd.json
    divergence-review.json
    oracle-review.json
    downstream-consumption.json
    content-audit-report.json
    content-audit-summary.md
    role-verdict.json
```

Attempts 2 and 3 use sibling immutable directories under `attempts/` only when a prior attempt is `VOID_CONTAMINATED`, or once after a recorded recovery from `INFRA_FAILURE`; both causes share the hard limit of three total attempts. `lane.json` lists every attempt ref and exactly one `decisive_attempt_ref`, unless all three are contaminated or infrastructure remains unrecoverable. Never overwrite an attempt directory.

The three canonical files under each real attempt directory are conditional: create them only after that attempt legitimately reaches Director finalization. A correctly stopped attempt contains `attempt.json`, `transcript.json`, and an empty-output `artifact-manifest.json`, not fake canonical files.

Temporary executor staging uses `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-executor-a-1/` and `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-executor-b-1/`; retries use the same names ending in `-2` or `-3`. Delete staging after its manifest digest is recorded. It is not a source of truth.

---

## Task 1: Add The Evaluation-layer Contract And Fail-closed Validator

**Files:**
- Create: `tools/eval/contracts/standard-chain-content-readiness.schema.json`
- Create: `tools/eval/scripts/validate_standard_chain_content_readiness.py`
- Create: `tests/fixtures/standard-chain-content-readiness/product-director-blocked-isolation/**`
- Create: `tests/test-standard-chain-content-readiness-contract.sh`
- Modify: `tests/gate-plan.json`

- [ ] **Step 1: Write the failing contract test first**

Create `tests/test-standard-chain-content-readiness-contract.sh`. The test must build or copy the valid synthetic `BLOCKED_ISOLATION` fixture, run the absent validator, then mutate JSON with Python—not with prose matching.

The test creates a temporary synthetic inherited-runtime root and rewrites all fixture refs/digests to it. No checked-in fixture or quick-gate command may require `/Users/lijieli/.agents`, `/Users/lijieli/.codex`, or any QFT checkout.

The negative matrix is mandatory:

| Mutation | Required rejection |
| --- | --- |
| approval commit/blob/line no longer matches current file | `stale approval reference` |
| one ancestry-path commit or changed path is absent/unclassified/duplicated | `source classification denominator mismatch` |
| executor A/B `starting_input_sha256` differs | `lane starting input mismatch` |
| the same Business Proxy fact key has a different class/value in either lane, or the visible message is not its canonical rendering | `business proxy answer drift` |
| Oracle proxy fact rows change without refreshing `authorized_business_proxy_fact_key_digest` and the derived `starting_input_sha256` | `stale business proxy baseline digest` |
| inherited runtime refs/bytes or Harness descriptor change without refreshing `inherited_runtime_digest` and `starting_input_sha256` | `stale inherited runtime digest` |
| runtime inheritance has unresolved file inputs but still claims a complete digest, omits its typed unavailable evidence, or leaks inherited refs/derived digests into the admission input manifest | `unresolved runtime input cannot claim complete digest` |
| an actual read is outside both the staged manifest and frozen inherited-runtime refs | `unauthorized executor read` |
| decisive attempt status is `VOID_CONTAMINATED` | `contaminated attempt cannot be decisive` |
| attempt count for one lane exceeds 3 | `attempt limit exceeded` |
| attempt directory is overwritten, missing from ordered refs or has a reused number | `attempt history must be immutable and contiguous` |
| `INFRA_FAILURE` is marked decisive or has outputs | `infrastructure failure cannot be decisive` |
| role `CONTENT_PASS` with `DECLARED_ONLY` | `CONTENT_PASS requires ENFORCED or OBSERVED` |
| a verdict omits a baseline digest without `BLOCKED_EVIDENCE` plus the matching typed unavailable entry, or supplies a partial digest | `missing baseline digest is not legally blocked` |
| role pass depends on `oracle_bridge_used=true` | `authentic role pass cannot depend on oracle bridge` |
| canonical ledger/brief/phase JSON contains `evaluation_only` | `canonical artifact contains evaluation metadata` |
| report/alignment validator fails | surface the invoked validator failure |
| `chain-verdict.json` exists before six role verdicts | `chain verdict requires all primary roles` |
| only `run.json.global_state` is changed to `CASE_REPLAY_PASS` | `CASE_REPLAY_PASS requires six CONTENT_PASS roles, chain verdict, ENFORCED/OBSERVED and no bridge` |
| any role or chain verdict claims `READY_FOR_BEHAVIOR_EVAL` | `unsupported verdict` |

Run:

```bash
bash tests/test-standard-chain-content-readiness-contract.sh
```

Expected: FAIL because `validate_standard_chain_content_readiness.py` does not exist.

- [ ] **Step 2: Implement the evaluation-only JSON schema**

Use `$id: "https://qft.local/schemas/standard-chain-content-readiness.schema.json"`, `schema_version: 1`, `additionalProperties: false`, and `$defs` for these artifact types only:

```text
run
confirmation_ref
input_manifest
oracle_manifest
source_classification
role_surface
decision_atom_register
replay_attempt
replay_lane
transcript
artifact_manifest
divergence_review
oracle_review
downstream_consumption
role_verdict
chain_verdict
```

Required enums:

```json
{
  "primary_roles": ["product-director", "product-manager", "design", "test-design", "tech-lead", "delivery-owner"],
  "lifecycle_statuses": ["OPEN", "CLOSED"],
  "current_stages": ["CASE_ADMISSION", "STATIC_AUDIT", "DIAGNOSTIC_REPLAY", "ROLE_VERDICT"],
  "closure_validation_stages": ["admitted", "static-audit", "diagnostic-replay", "role-verdict", "terminal-run"],
  "isolation_levels": ["ENFORCED", "OBSERVED", "DECLARED_ONLY"],
  "attempt_statuses": ["COMPLETED", "STOPPED", "VOID_CONTAMINATED", "INFRA_FAILURE"],
  "role_verdicts": ["CONTENT_PASS", "CONTENT_FAIL", "BLOCKED_ORACLE", "BLOCKED_EVIDENCE", "BLOCKED_ISOLATION"],
  "global_states": ["REPAIR_REQUIRED", "BLOCKED_ORACLE", "BLOCKED_EVIDENCE", "BLOCKED_ISOLATION", "INCONCLUSIVE_CONTAMINATED", "CASE_REPLAY_PASS"],
  "source_classes": ["relevant", "supporting", "unrelated"],
  "fact_classes": ["fact", "inference", "assumption", "unknown"],
  "divergence_classes": ["ALLOWED_VARIATION", "ALLOWED_TRADE_OFF", "CORRECT_UNCERTAINTY_HANDLING", "MODEL_BEHAVIOR_SIGNAL", "CONTENT_AMBIGUITY", "SHARED_REASONING_DEFECT", "HIGH_RISK_DIVERGENCE"]
}
```

All file references use one exact shape; the validator must never guess a base directory from existence:

```json
{
  "scope": "repo",
  "path": "relative/path.json",
  "sha256": "64-lowercase-hex",
  "source_id": "org-claude-skills",
  "commit": "40-lowercase-hex",
  "blob": "40-lowercase-hex",
  "line": 8
}
```

- `scope` is exactly `repo`, `run`, or `external_repo`.
- `repo` resolves from the current `org-claude-skills` root; `run` resolves from `RUN_ROOT`; `external_repo` requires `source_id` and a matching repeated CLI `--source-root source_id=/absolute/path`.
- `path` is always relative and must not contain `..`; absolute paths are rejected.
- `sha256` always hashes the referenced bytes. `commit`, `blob`, and `line` are omitted unless the claim is commit/line-bound; when present they are re-opened and checked.
- `run.case_refs` has exactly `confirmation`, `input`, `oracle`, and `source_classification`. `run.role_refs` is a map keyed by primary role; each present role lists only scoped refs already produced at the current stage. Future or missing artifact refs are forbidden. Every artifact write that changes bytes must refresh the owning ref before stage validation.

Freeze the required fields below. Fields not listed are forbidden unless marked optional:

| `$def` | Required fields |
| --- | --- |
| `run` | `artifact_type`, `schema_version`, `run_id`, `case_id`, `evaluation_only=true`, `lifecycle_status`, `current_stage`, `active_role`, `primary_roles`, `evaluated_roles`, `case_refs`, `role_refs`; `isolation_assessment` is required from `static-audit` onward; optional only when closed: `global_state`, `primary_role_outcome`, `next_authorized_action`, `closure_validation_stage` |
| `confirmation_ref` | `artifact_type`, `case_id`, `design_ref`, `approval_ref`, `approval_line`, `capability_line`, `approved_capability_ids`, `approved_oracle_atom_ids`, `approved_scope_lines`, `stale_if` |
| `input_manifest` | admission requires `artifact_type`, `case_id`, `starting_clue`, `executor_visible`, `reviewer_only`, `forbidden_to_executor`, `baseline_code_view`, `oracle_version`; from `static-audit` onward also require `product_director_content_digest`, `inherited_runtime_digest`, `inherited_runtime_refs`, `authorized_business_proxy_fact_key_digest`, and `starting_input_sha256` |
| `oracle_manifest` | `artifact_type`, `case_id`, `oracle_version`, `authority_ref`, `atoms`, `business_proxy_facts`; optional `supplement_ref`; each atom requires `atom_id`, `business_invariant`, `observable_assertion`, `scope`, `exclusions`, `approval_ref`, `design_line`, `historical_support_refs`, `business_proxy_fact_keys`; each proxy fact requires `fact_key`, `fact_class`, `answer_text`, and `authority_refs` |
| `source_classification` | `artifact_type`, `case_id`, `path_diff_policy=first_parent`, `sources`; each source requires `source_id`, `baseline_commit`, `result_commit`, `ancestry_commits`, `source_atoms`; each source atom requires `commit`, `parent_commit`, `change_status`, `path`, optional `previous_path`, `classification`, `reason`, `oracle_atom_ids` |
| `role_surface` | `artifact_type`, `case_id`, `role`, `repo_revision`, `files`, `dependency_edges`, `scope_surfaces`, `runtime_inheritance`; each file requires one scoped ref, `surface_class`, `in_scope_reason`, `consumer_refs`; `runtime_inheritance` always requires `probe_prompt`, `probe_response`, `declared_mandatory_refs`, `harness_descriptor`, `unresolved_file_inputs`, `unobservable_nonfile_injections`, `system_injection_observable=false`, and `evidence_level=DECLARED_ONLY`; when `unresolved_file_inputs=[]`, require complete `inherited_runtime_digest`; otherwise forbid that digest and require typed `inherited_runtime_unavailable` with `reason_code` and scoped `evidence_refs` |
| `decision_atom_register` | `artifact_type`, `case_id`, `role`, `target_capability_id`, `atoms`; each atom requires every required property listed in Task 3 Step 3; `finding_ref` is the only optional atom property |
| `replay_lane` | `artifact_type`, `case_id`, `role`, `lane_id`, `ordered_attempt_refs`, `terminal_condition`; `terminal_condition` is exactly `DECISIVE`, `ALL_CONTAMINATED`, or `UNRECOVERABLE_INFRA_FAILURE`; `decisive_attempt_ref` is required only for `DECISIVE` |
| `replay_attempt` | `artifact_type`, `case_id`, `role`, `lane_id`, `attempt_number`, `starting_input_sha256`, `oracle_version`, `isolation_level`, `attempt_status`, `environment`, `actual_read_declaration`, `commands`, `business_fact_keys_received`, `output_refs`, `continue_stop_return`, `contamination_findings`; optional `blocking_fact_refs`; `environment` requires absolute staging/output roots, `pwd`, realpaths, resolved runtime root, tool versions, sorted staged relative-path/SHA-256 entries, and their canonical digest; every actual-read entry requires path, SHA-256, and authorization result |
| `transcript` | `artifact_type`, `case_id`, `role`, `lane_id`, `attempt_number`, `turns`; each turn requires `turn_number`, `actor`, `message`, `visible_fact_keys`, `state_before`, `state_after`; a `business-proxy` turn additionally requires sorted `answers` containing only `fact_key`, `fact_class`, and `answer_text`, plus reviewer-only `answer_authority_refs`; its visible `message` must be the canonical JSON rendering of exactly `answers`, never the authority refs |
| `artifact_manifest` | `artifact_type`, `case_id`, `role`, `lane_id`, `attempt_number`, `evaluation_only=true`, `canonical_output_refs`; empty array is required for a stopped attempt |
| `divergence_review` | `artifact_type`, `case_id`, `role`, `lane_refs`, `comparisons`, `blocking_findings`; each comparison requires `subject`, `classification`, `lane_evidence_refs`, `impact`, `owner` |
| `oracle_review` | `artifact_type`, `case_id`, `role`, `lane_refs`, `field_checks`, `historical_implementation_boundary`; each field check requires `artifact_field_ref`, `oracle_atom_ids`, `fact_class`, `result`, `evidence_refs` |
| `downstream_consumption` | `artifact_type`, `case_id`, `producer_role`, `consumer_role`, `candidate_results`; each candidate requires `lane_id`, `input_status`, `consumer_action`, `checks`, `evidence_refs`; `input_status` is `CANONICAL_HANDOFF` or `BLOCKED_UPSTREAM` |
| `role_verdict` | always requires `artifact_type`, `case_id`, `role`, `verdict_scope`, `skill_revision`, optional `audit_report_ref`, `decisive_attempt_refs`, `isolation_level`, `oracle_bridge_used`, `open_p0_p1`, `verdict`, `reason_codes`, `evidence_refs`, `claim_boundaries`, `next_decision`; normally also requires `content_digest` and `inherited_runtime_digest`; only `BLOCKED_EVIDENCE` may replace an unavailable digest with a matching typed `unavailable_baselines` entry containing `baseline_type`, `reason_code`, and `evidence_refs` |
| `chain_verdict` | `artifact_type`, `case_id`, `role_verdict_refs`, `isolation_level`, `oracle_bridge_used`, `verdict`, `evidence_refs`; schema only permits `CASE_REPLAY_PASS` and validator requires all six `CONTENT_PASS` roles |

Stage conditions are exact:

| Stage | Required additions |
| --- | --- |
| `admitted` | run + four case files |
| `static-audit` | admitted + surface + decision atoms + validated alignment + isolation assessment |
| `diagnostic-replay` | static + two replay lanes with decisive attempts + divergence/oracle/downstream records; terminal branches use `terminal-run` instead |
| `role-verdict` | diagnostic replay or static-terminal evidence + legal role verdict; formal audit is mandatory for `CONTENT_PASS`, `CONTENT_FAIL`, or `BLOCKED_ISOLATION`, optional for `BLOCKED_ORACLE`/`BLOCKED_EVIDENCE` only when the missing evidence prevents formal audit |
| `terminal-run` | closed run with `INCONCLUSIVE_CONTAMINATED`, or unrecoverable evidence/oracle/static blocker evidence; it must not fabricate missing replay/review/report files |

Do not define `skill-audit-alignment`, `skill-audit-report`, brief, phase PRD or ledger fields here. The evaluation schema stores only their refs and SHA-256 digests.

### Validator implementation contract

`validate_standard_chain_content_readiness.py` CLI:

```text
usage: validate_standard_chain_content_readiness.py RUN_ROOT
       [--require-role product-director]
       [--require-stage admitted|static-audit|diagnostic-replay|role-verdict|terminal-run]
       [--source-root source_id=/absolute/path]...

       validate_standard_chain_content_readiness.py
       --emit-source-denominator
       --source-id SOURCE_ID
       --source-root source_id=/absolute/path
       --baseline 40_HEX --result 40_HEX
```

Implementation requirements:

- Load each JSON artifact through `tools/community/simple_json_schema.py` and the matching `$defs` entry.
- Resolve every ref only by its explicit `scope`. Reject absolute/parent-escaping artifact paths, missing `external_repo` mappings and duplicate `--source-root` IDs.
- Recompute every declared SHA-256 from bytes. Never trust stored `status: PASS`.
- Re-open approval path at the approved commit and verify commit, blob, line and expected capability ID. `confirmation-ref.json` must not contain `approval_text` or `expected_snippet`.
- For each source in the manifest, recompute its ancestry-path commit denominator and the first-parent changed-path atoms. Expose the same pure enumerator through `--emit-source-denominator`; generator and validator must share the function. The validator contains no QFT commit IDs or `/Users/lijieli/project` path; real expected commits live in the real manifest, while synthetic tests inject temporary repositories.
- Before accepting replay evidence, require equal `starting_input_sha256`, equal canonical digests of the two staged relative-path/SHA-256 lists, and equal `inherited_runtime_digest`. The only authorized read set is that lane's staged-file list union its exact `inherited_runtime_refs`; reject any other actual read or hash mismatch.
- For every Business Proxy turn, resolve each answer and its authority refs against the current Oracle version, require byte-equal `fact_class` and `answer_text`, require the visible message to equal the canonical rendering of the sorted public answer fields, and reject any cross-lane drift for the same fact key.
- Recompute `authorized_business_proxy_fact_key_digest` from the fact-keyed projection of current `oracle_manifest.business_proxy_facts`; recompute `inherited_runtime_digest` from the sorted mandatory refs plus canonical Harness descriptor; then recompute `starting_input_sha256` from the exact clue/content/inherited-runtime/oracle-version/fact-digest tuple. These derived fields begin at `static-audit`; reject a stale digest at that and every later stage. A transcript cannot legitimize a changed Oracle or Harness baseline.
- When `surface.json.runtime_inheritance.unresolved_file_inputs=[]`, require `declared_mandatory_refs` to equal `input-manifest.json.inherited_runtime_refs`; `diagnostic-replay` requires this branch. Unobservable non-file system injection remains recorded and caps isolation at `DECLARED_ONLY` rather than being silently treated as frozen bytes.
- In a terminal Branch B surface with unresolved file inputs, typed `inherited_runtime_unavailable` replaces—not supplements—the complete inherited digest. Reject both a missing alternative and any partial/fake digest, and require the admission-form input manifest to omit `inherited_runtime_refs`, all three derived component digests, and `starting_input_sha256`. Only a fully frozen surface may populate those fields.
- Enforce the role-verdict digest alternative: only `BLOCKED_EVIDENCE` can omit a complete content or inherited-runtime digest, each omission requires its matching typed unavailable entry and scoped evidence, and no field may carry a partial digest disguised as the complete baseline.
- Invoke, do not reimplement:

```text
shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py
shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py
```

- When a lane declares canonical artifacts, copy them to `docs/qft-qmi-pc-001-executor-a` or `docs/qft-qmi-pc-001-executor-b` under a temporary workspace and invoke existing Product Director ledger validator, content evaluator and completion hook. A correctly stopped lane must instead carry an explicit blocking fact and an empty canonical output list. Delete the temp tree afterward.
- Reject `evaluation_only`, `case_id`, `lane_id`, `oracle_ref` and `attempt_id` in canonical ledger/brief/phase artifacts; those belong in `artifact-manifest.json`.
- Enforce Role Verdict And Run-state Rules plus isolation/bridge/contamination/infra-failure rules from this plan.
- `--require-stage` supports two monotonic tracks without `NOT_RUN` placeholders: normal `admitted -> static-audit -> diagnostic-replay -> role-verdict`, and direct static failure `admitted -> static-audit -> role-verdict`. `terminal-run` is a separate fail-closed exit: it requires the complete proven prefix plus its explicit terminal evidence, but never fabricates evidence from a stage that was not reached.
- Print one JSON object with `status`, `checked_stage`, `failures`, and invoked validator evidence. Exit 0 only when `failures=[]`.

Implement and test the validator in four small internal layers, in this order:

- [ ] **Step 3a: Add schema loading, scoped ref resolution and digest checks**

Add failing mutations for absolute path, `..`, wrong scope, missing source-root mapping, stale file SHA-256, changed proxy fact rows with stale fact-key digest, changed inherited runtime bytes/descriptor with stale inherited digest, and either derived digest changing with a stale starting-input digest; implement only loader/ref/digest code; rerun the test until this group passes.

- [ ] **Step 3b: Add portable Git source denominator checks**

In the Bash test, initialize two temporary Git repositories with a baseline, a normal commit, a two-parent merge and a result commit. Rewrite the copied synthetic run manifest with their real hashes and invoke `--source-root synthetic-app=... --source-root synthetic-backend=...`. Assert missing commits, wrong first parent, missing rename source path and duplicate `(source_id,commit,parent,status,path)` atoms fail.

- [ ] **Step 3c: Add lane, attempt and terminal state-machine checks**

Test immutable attempt order, maximum three attempts, decisive-ref legality, `VOID_CONTAMINATED`, `INFRA_FAILURE`, stopped-empty-output, Business Proxy answer drift, baseline-digest unavailable alternatives, isolation/bridge gates, `INCONCLUSIVE_CONTAMINATED`, and terminal branches. Add a direct mutation that changes only `run.json.global_state` to `CASE_REPLAY_PASS`; it must fail even when no `chain-verdict.json` exists.

- [ ] **Step 3d: Add existing-validator adapters**

Invoke the SQA alignment/report validators and the Product Director ledger/content/completion gates only when the stage and attempt status require them. Tests must prove a stopped attempt does not invoke canonical gates and a spoofed stored PASS cannot bypass a failing child validator.

- [ ] **Step 4: Build the valid synthetic fixture**

Use existing valid SQA and Product Director fixtures as structural sources, but give the new fixture a synthetic case ID `SYNTHETIC-PD-BLOCKED-ISOLATION-001`. Its terminal facts must be:

```json
{
  "isolation_level": "DECLARED_ONLY",
  "role_verdict": "BLOCKED_ISOLATION",
  "global_state": "BLOCKED_ISOLATION",
  "oracle_bridge_used": false,
  "evaluation_only": true
}
```

The fixture must use fake business data and must not copy the eight real Oracle meanings. Canonical artifacts remain schema-valid and carry no evaluation metadata.
The checked-in JSON is a fixture template. The Bash test copies it, creates temporary Git histories, rewrites the copied source refs/hashes, and validates the copy with injected `synthetic-app` and `synthetic-backend` roots. No checked-in quick test may require `/Users/lijieli/project`.

- [ ] **Step 5: Register one quick gate**

Add a `tests/gate-plan.json` step:

```json
{
  "id": "standard-chain-content-readiness-contract",
  "command": ["bash", "tests/test-standard-chain-content-readiness-contract.sh"],
  "area": "standard-chain",
  "tier": "quick",
  "tags": ["contract", "content-readiness", "evaluation"],
  "parallel_safe": true,
  "timeout_sec": 120
}
```

Do not modify `tests/run-all.sh`; the gate plan is the existing owner.

- [ ] **Step 6: Verify Task 1**

Run:

```bash
bash tests/test-standard-chain-content-readiness-contract.sh
```

Expected: exit 0. The test's positive validator invocation contains `"status": "PASS"`, `"checked_stage": "role-verdict"`, and an empty `failures` array; all negative mutations are rejected.

- [ ] **Step 7: Commit Task 1**

```bash
git add tools/eval/contracts/standard-chain-content-readiness.schema.json \
  tools/eval/scripts/validate_standard_chain_content_readiness.py \
  tests/fixtures/standard-chain-content-readiness \
  tests/test-standard-chain-content-readiness-contract.sh \
  tests/gate-plan.json
git commit -m "test: add standard chain content readiness contract"
```

---

## Task 2: Admit And Freeze `QFT-QMI-PC-001`

**Files:**
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/confirmation-ref.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/input-manifest.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/oracle-manifest.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/source-classification.json`

- [ ] **Step 1: Prove all repositories and approved refs are readable and clean**

Run:

```bash
git status --short
git rev-parse HEAD
git -C /Users/lijieli/project/qft-tenants status --short
git -C /Users/lijieli/project/qft-tenants rev-parse a387e1403d9bcf4a2b3816749054c88fd3b01f31^{commit}
git -C /Users/lijieli/project/qft-tenants/qft-app status --short
git -C /Users/lijieli/project/qft-tenants/qft-app rev-parse 380e2458502a5b46751afa366f8f8535c4590eed^{commit}
git -C /Users/lijieli/project/qft-tenants/qft-app rev-parse fda108fbc4978cd41e60ddc4cc197cb93e973065^{commit}
git -C /Users/lijieli/project/qft-tenants/qft-all status --short
git -C /Users/lijieli/project/qft-tenants/qft-all rev-parse 377ec4801a79f73649c22496c837e32d677bf5fd^{commit}
git -C /Users/lijieli/project/qft-tenants/qft-all rev-parse e34b45255f14c680edbd1630357d96a10a8b2982^{commit}
```

Expected: all status outputs empty; each `rev-parse` echoes the requested commit. If any worktree is dirty, record the changed paths and stop admission instead of cleaning them.

- [ ] **Step 2: Freeze confirmation and Oracle authority**

`confirmation-ref.json` must contain:

- design path/commit/blob;
- approval path/commit/blob;
- approval line 8 and capability line 18 as numeric refs, without copying their text;
- approved capability IDs and Oracle IDs;
- case ID and approved scope line refs 42-49;
- a stale rule that material design/capability/Oracle change invalidates the run.

`oracle-manifest.json` must contain exactly `QFT-INV-001` through `QFT-INV-008`. For each atom record:

```text
atom_id
business_invariant
observable_assertion
scope
exclusions
approval_ref
design_line
historical_support_refs
business_proxy_fact_keys
```

Copy only the approved meaning from design lines 222-229. Historical code/test refs are `supporting`, never `authority`.

Use these stable Business Proxy fact keys; do not invent synonyms that would make lane comparison ambiguous:

| Fact key | Source |
| --- | --- |
| `problem.occupied_room_blocks_future_registration` | `QFT-INV-001` + case identity |
| `goal.register_non_overlapping_future_tenant` | `QFT-INV-001` |
| `success.preserve_current_tenant` | `QFT-INV-002` |
| `success.prevent_current_resource_side_effects` | `QFT-INV-003` |
| `success.find_same_registered_tenant` | `QFT-INV-004` |
| `success.review_selected_target_tenant` | `QFT-INV-005` |
| `success.concurrent_conflict_single_winner` | `QFT-INV-006` |
| `scope.centralized_whole_joint_modes` | `QFT-INV-007` |
| `regression.preserve_empty_room_registration` | `QFT-INV-008` |
| `scope.pc_and_backend_final_validation` | design lines 222, 226, 247-250 |
| `non_goal.full_move_in_program` | design line 247 |
| `non_goal.mobile_client_coverage` | design line 248 |
| `non_goal.copy_historical_implementation` | design line 250 |
| `unknown.business_value_metric` | no approved source; answer `unknown` |
| `unknown.observation_window` | no approved source; answer `unknown` |
| `unknown.success_data_source` | no approved source; answer `unknown` |
| `unknown.investment_appetite_or_timebox` | no approved source; answer `unknown` |

Persist every key exactly once in `oracle-manifest.json.business_proxy_facts`. Approved entries use `fact_class=fact`, one frozen `answer_text`, and scoped authority refs; unavailable entries use `fact_class=unknown`, exact `answer_text=unknown`, and refs proving the approved baseline contains no replacement fact. Oracle version 2 replaces only explicitly approved unknown rows and retains stable keys.

- [ ] **Step 3: Freeze the starting input and visibility split**

The executor starting clue is exactly:

```text
当前 PC 端在房间已有租客时无法再登记下一任租客，业务希望支持登记后续租客，并在后续办理入住时能够选中正确租客。请按 product-director 共创流程从这个需求线索开始，不进入产品或技术 HOW。
```

`input-manifest.json` must separate:

- `executor_visible`: at admission, the clue plus named categories that may later be exposed; Task 3 replaces the content/Harness categories with exact scoped refs and digests before any executor starts, and transcripts add only the Business Proxy answers actually given per turn;
- `reviewer_only`: Oracle manifest, candidate PRD excerpts, result commits/diffs/tests, and the other lane output;
- `forbidden_to_executor`: Oracle files, result snapshots, other lane files, review files, current PRD, sibling repos, MCP/browser/connectors and network; `$HOME` and repo-outside-staging are forbidden except the exact frozen refs in `inherited_runtime_refs`;
- `baseline_code_view`: pre-change refs and selected blob hashes. Product Director starts with no code files because its capability is WHY/boundary, not HOW; a code view may be opened only by the reviewer after replay.

At admission, store the clue and visibility split but do not invent the content, inherited-runtime, fact-key, or starting-input digests before the runtime surface exists. Task 3 adds all four derived fields atomically and refreshes the `run.json.case_refs.input` digest before `static-audit` validation.

- [ ] **Step 4: Classify the full commit and path denominator**

Generate the denominator with:

```bash
python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  --emit-source-denominator \
  --source-id qft-app \
  --source-root qft-app=/Users/lijieli/project/qft-tenants/qft-app \
  --baseline 380e2458502a5b46751afa366f8f8535c4590eed \
  --result fda108fbc4978cd41e60ddc4cc197cb93e973065

python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  --emit-source-denominator \
  --source-id qft-all \
  --source-root qft-all=/Users/lijieli/project/qft-tenants/qft-all \
  --baseline 377ec4801a79f73649c22496c837e32d677bf5fd \
  --result e34b45255f14c680edbd1630357d96a10a8b2982
```

The emitter returns ordered ancestry commits and source atoms keyed by `(source_id, commit, parent_commit, change_status, path, previous_path?)`. For every commit—including the two-parent merge `dc279ab981bb2895f4662b8d534699e4ee859bb2`—the path denominator is the diff from `commit^1` to `commit` with rename detection. Classify every emitted atom exactly once as `relevant`, `supporting`, or `unrelated`, with a one-sentence causal reason and affected Oracle IDs. A merge, metadata commit or broad unrelated change is not silently dropped. The validator calls the same enumerator and rejects denominator drift.

- [ ] **Step 5: Record the fresh PRD digest without promoting it to Oracle**

Run:

```bash
shasum -a 256 '/Users/lijieli/project/qft-tenants/docs/feature--将搬入--0629/登记租客闭环/登记租客闭环--PRD.md'
```

Expected digest:

```text
bb451b968112296dc03d78659d85792a1e1d0300881c805653244244b151aacf
```

If it differs, set admission to `BLOCKED_EVIDENCE`; do not silently update the approved baseline.

- [ ] **Step 6: Write `run.json` and validate admission**

Required run facts at this stage:

```json
{
  "artifact_type": "standard-chain-content-readiness-run",
  "schema_version": 1,
  "run_id": "standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001",
  "case_id": "QFT-QMI-PC-001",
  "evaluation_only": true,
  "lifecycle_status": "OPEN",
  "current_stage": "CASE_ADMISSION",
  "active_role": "product-director",
  "evaluated_roles": [],
  "primary_roles": ["product-director", "product-manager", "design", "test-design", "tech-lead", "delivery-owner"],
  "role_refs": {}
}
```

Also add `case_refs` with exactly four keys and scoped refs computed from the created bytes: `confirmation -> case/confirmation-ref.json`, `input -> case/input-manifest.json`, `oracle -> case/oracle-manifest.json`, and `source_classification -> case/source-classification.json`. Do not add `isolation_assessment` or a global state yet; neither has been established at admission.

Run:

```bash
python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001 \
  --require-role product-director \
  --require-stage admitted \
  --source-root agent-skills=/Users/lijieli/.agents \
  --source-root codex-home=/Users/lijieli/.codex \
  --source-root qft-tenants=/Users/lijieli/project/qft-tenants \
  --source-root qft-app=/Users/lijieli/project/qft-tenants/qft-app \
  --source-root qft-all=/Users/lijieli/project/qft-tenants/qft-all
```

Expected: exit 0 and JSON `status=PASS`, `checked_stage=admitted`.

- [ ] **Step 7: Commit Task 2**

```bash
git add tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case
git commit -m "eval: admit qft move in content readiness case"
```

---

## Task 3: Freeze Product Director Surface, Run Static Audit, And Classify Isolation

**Files:**
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/surface.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/decision-atoms.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-alignment.json`
- Modify: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/input-manifest.json`
- Modify: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json`

- [ ] **Step 0: Probe the inherited subagent runtime before claiming an allowlist**

Spawn one disposable subagent with `fork_turns="none"`; it is a Harness probe, not a Product Director executor and produces no role evidence. Give it exactly:

```text
不要执行产品任务，也不要假装只有父任务 prompt。检查你当前实际继承的 system/developer Skill 规则：如果随后被派发 Product Director 共创诊断，首次业务响应前必须读取哪些文件型 Skill/规则？逐项报告绝对路径、触发依据、是否可跳过，以及为得出结论实际读取的文件。另报告：父对话是否继承、当前 cwd、system/developer prompt 原文字节是否可见。不要读取任何 QFT、Oracle、历史结果或另一 agent 输出。
```

The coordinator writes the exact probe prompt/response and read declaration into `surface.json.runtime_inheritance`. Freeze every declared mandatory file as a scoped ref and digest. Current known minimum is:

```text
/Users/lijieli/.agents/skills/using-superpowers/SKILL.md
/Users/lijieli/.agents/skills/brainstorming/SKILL.md
```

Do not assume the minimum is exhaustive; persist any additional mandatory file discovered by the probe. Use this canonical Harness descriptor:

Use scoped refs rooted at `repo=/Users/lijieli/org-claude-skills`, `agent-skills=/Users/lijieli/.agents`, or `codex-home=/Users/lijieli/.codex`. A declared mandatory file outside those three roots is unfreezable in this slice and takes Branch B; never widen to all of `$HOME`.

```json
{
  "executor_kind": "collaboration-subagent",
  "fork_turns": "none",
  "parent_conversation_inherited": false,
  "system_developer_context_inherited": true,
  "shared_cwd": true,
  "file_read_observation": "SELF_REPORTED_ONLY",
  "system_prompt_bytes_observable": false
}
```

Set `unobservable_nonfile_injections` to `system/developer prompt bytes` and `injected skill catalog bytes`; these keep isolation at `DECLARED_ONLY` but do not become executor contamination by themselves. Replay requires `unresolved_file_inputs=[]`. If the probe reads forbidden case evidence, omits a known mandatory file, or reveals another mandatory file that cannot be frozen, list it in `unresolved_file_inputs`, omit `inherited_runtime_digest`, add typed `inherited_runtime_unavailable`, and take Branch B `BLOCKED_EVIDENCE`. That typed alternative describes missing evidence; it is never a partial baseline digest. If a frozen inherited process Skill conflicts with Product Director ownership, confirmation, artifact, or stop rules at P0/P1 severity, take Branch C `CONTENT_FAIL`. Never tell the executor to ignore a higher-priority Skill to make replay possible.

- [ ] **Step 1: Freeze the complete Product Director content package**

Build `surface.json` from tracked files, not `find` output, so `__pycache__` and local noise cannot enter the baseline:

```bash
git ls-files shared/skills/product-director \
  shared/skills/product-manager/SKILL.md \
  shared/skills/product-manager/scripts/preflight_check.sh \
  shared/skills/product-manager/scripts/preflight_check.py \
  shared/skills/product-manager/contracts/brief.schema.json \
  shared/skills/product-manager/contracts/phase-prd.schema.json \
  shared/skills/lib/contracts/shared-core.schema.json \
  shared/hooks/lib/common.sh \
  shared/runtime/standard-chain-catalog.json \
  tools/community/validate_co_creation_ledger.py \
  tools/community/validate_product_closure.py \
  tools/community/normalize_canonical_artifact.py \
  tools/community/review_digest_common.py \
  tools/community/validate_canonical_schema.py \
  tools/community/validate_standard_chain_readiness.py \
  contracts/canonical/registry-bundle.yaml \
  contracts/skill-runtime-surface.json \
  contracts/standard-chain-invocation-policy.yaml \
  contracts/co-creation-ledgers.yaml \
  contracts/product-artifacts.yaml \
  contracts/standard-chain.yaml \
  contracts/standard-chain-field-consumption.yaml \
  tests/gate-plan.json \
  tests/run-all.sh
```

For every file record path, blob SHA when Git-backed, byte SHA-256, surface class, why it is in scope and consumer/validator refs. Start from `shared/skills/product-director/scripts/manifest.json`, `completion_check.sh` sources/imports, `standard-chain-catalog.json` artifact schemas and the Product Manager downstream intake path; record the dependency edge that pulled each file into the closure. Add probe-discovered files as `inherited_runtime_instruction`, not target Skill content. If a referenced local file is missing from the inventory, the validator rejects the surface as incomplete. Cover the 16 SQA surfaces explicitly; absent directories are recorded `absent`, not omitted. `surface.json` is a frozen inventory, not a verdict.

Build all derived fields in memory or a sibling temp file; replace `input-manifest.json` only after every required source is readable and all four values are complete. Never persist a partial digest set. Then add:

1. `product_director_content_digest`: canonical digest of sorted relative-path/SHA-256 entries for the exact Task 4 staging allowlist, excluding generated `input/` files and inherited runtime files;
2. `inherited_runtime_digest`: canonical digest of the sorted scoped refs/digests from the probe plus the exact Harness descriptor above;
3. `authorized_business_proxy_fact_key_digest`: canonical digest of an object keyed by every stable fact key; each value contains `fact_class`, exact `answer_text`, and authority refs;
4. `starting_input_sha256`: canonical digest of exactly `starting_clue`, `product_director_content_digest`, `inherited_runtime_digest`, `oracle_version`, and `authorized_business_proxy_fact_key_digest`.

Canonical JSON everywhere in this plan means UTF-8, recursively sorted object keys, compact separators `(',', ':')`, and one terminal newline before SHA-256. Refresh `run.json.case_refs.input` after writing the manifest.

- [ ] **Step 2: Create and validate the formal capability alignment**

Use the current `skill-audit-alignment` contract unchanged:

```text
target_skill: shared/skills/product-director
target capability: SC-CAP-PD-001 only
claim source: user_supplied
stage: confirmed
co_creation_status: confirmed_with_user
user_confirmation.level: G0
user_confirmation.status: confirmed
confirmation_evidence: approval record line 8
capability definition evidence: design line 36 + approval record line 18
```

The effectiveness standard must use the approved design lines 43-92 for scenario, success, failure, risk and evidence; do not ask the user to approve the same standard twice.

Run:

```bash
python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-alignment.json
```

Expected: `[PASS] skill audit alignment valid`.

- [ ] **Step 3: Extract decision atoms and perform the static gate**

For each behavior-changing Product Director instruction, write one `decision-atoms.json` row with:

```text
atom_id
sentence_class
source_ref (scoped ref including the current line)
trigger
fact_source
decision_owner
action_mode (`required`, `allowed`, or `forbidden`)
action
artifact_or_state_change
completion_evidence
failure_conflict_unknown_route
downstream_consumer
validator_or_harness
static_assessment
optional finding_ref
```

Keep `action_mode` separate from `action`; do not collapse modality and executable action into one ambiguous prose field.

Review at minimum: root problem, success standard, appetite/investment boundary, scope/non-goals, feasibility, risk/unknown, Phase boundary, one-question-per-turn co-creation, user confirmation, upstream fact replacement, Director/PM ownership boundary, canonical artifacts, ledger, content quality, completion hook, runtime trigger, downstream field consumption, and every inherited process Skill's trigger/order/output/confirmation contract against Product Director. In particular, decide whether mandatory `brainstorming` and Product Director can compose without changing the role under test; do not wave the collision away as “agent behavior.”

Any P0/P1 candidate must include required claims, current path:line evidence, direct refutation check, severity calibration and owner. Do not produce the formal audit report yet; replay evidence is still absent.

- [ ] **Step 4: Classify current isolation with fresh evidence**

Use the actual Step 0 collaboration-subagent probe, not the legacy local-eval sandbox, as the fresh mechanism evidence. The probe's ability to read mandatory files outside staging proves no read allowlist is enforced; the tool exposes no trusted complete read log, so a self-reported allowlist remains hygiene rather than observation.

Record in `run.json.isolation_assessment`:

```json
{
  "level": "DECLARED_ONLY",
  "mechanism": "fork-none collaboration subagent plus staged inputs, frozen inherited-runtime refs, prompt allowlist and self-reported reads",
  "supports_authentic_pass": false,
  "read_allowlist_enforced": false,
  "complete_access_log_available": false
}
```

Also add `evidence_refs` with scoped refs to `surface.json.runtime_inheritance`, the current `standard_chain_local_eval/workspace.py` Codex routing line, and the current historical executor-log external-read line identified in Current Evidence. Reopen current files to bind line refs; never store routing prose instead of refs. Set `current_stage=STATIC_AUDIT`, and populate `run.json.role_refs.product-director` with scoped refs to `surface.json`, `decision-atoms.json`, and `content-audit-alignment.json`. Do not set `CONTENT_PASS`.

- [ ] **Step 5: Validate the static stage**

Run:

```bash
python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001 \
  --require-role product-director \
  --require-stage static-audit \
  --source-root agent-skills=/Users/lijieli/.agents \
  --source-root codex-home=/Users/lijieli/.codex \
  --source-root qft-tenants=/Users/lijieli/project/qft-tenants \
  --source-root qft-app=/Users/lijieli/project/qft-tenants/qft-app \
  --source-root qft-all=/Users/lijieli/project/qft-tenants/qft-all
```

Expected on a complete surface: exit 0, `status=PASS`, isolation level `DECLARED_ONLY` and `supports_authentic_pass=false`. If the command instead proves a core surface or required source is unavailable, preserve the validator output as terminal evidence and take Branch B; do not claim that `static-audit` passed.

- [ ] **Step 5b: Apply the approved static stop rule**

If a complete static scope proves a P0/P1—including an inherited process-Skill conflict—that makes the content/Harness unable to produce a safe executable Director input, set candidate `CONTENT_FAIL` and take Branch C. If a core or mandatory inherited surface is unreadable/unfreezable, set candidate `BLOCKED_EVIDENCE` and take Branch B. Skip Task 4 in either case. This first slice does not create an Oracle Bridge or suppress higher-priority instructions to patch the target runtime; Task 5 closes the selected branch with direct evidence. Continue to Task 4 only when the static gate leaves diagnostic replay meaningful.

- [ ] **Step 6: Commit Task 3**

Run this commit only after `static-audit` validation passes, including the complete-static Branch C case. An incomplete Branch B does not pretend Task 3 closed; Task 5's Branch B commit captures its present terminal evidence.

```bash
git add tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/input-manifest.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/surface.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/decision-atoms.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-alignment.json
git commit -m "eval: freeze product director content baseline"
```

---

## Task 4: Run Two Independent Diagnostic Product Director Lanes

Execute this task only when Task 3 explicitly records no blocking P0/P1 runtime collision and no unfreezable mandatory inherited input. Otherwise go directly to Task 5.

**Files:**
- Create only after an additional user approval: `docs/superpowers/specs/2026-07-14--qft-qmi-pc-001-oracle-supplement.md`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-a/**`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-b/**`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/divergence-review.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/oracle-review.json`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/downstream-consumption.json`
- Modify: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json`

- [ ] **Step 0: Pass the Business Proxy readiness gate before spawning executors**

Compare the approved fact keys against Product Director's required locked fields and `success-investment-boundary.md`. The base Oracle intentionally answers product behavior and scope, but has no separately approved numeric metric, observation window, observation data source, or resource/time appetite. Do not assume all four are missing: first map categorical baseline, target direction, failure signals, and change-scope limit to the approved atoms, then isolate only the fields that still lack authority and are mandatory under the current content/Harness.

Present only the remaining blocking facts as a concise recommended package to the business owner, one material decision at a time. Do not re-ask facts already entailed by approved atoms, and do not treat silence as approval. If the owner supplies and explicitly approves new facts, create the immutable record:

```text
docs/superpowers/specs/2026-07-14--qft-qmi-pc-001-oracle-supplement.md
```

It must record exact user text, timestamp, base design/approval commit and blob, added fact keys, scope/exclusions and approval event. Update `oracle-manifest.json` to `oracle_version=2` with a scoped ref and digest to that record. Recompute `authorized_business_proxy_fact_key_digest`, then recompute `starting_input_sha256` with the exact five-key canonical formula from Task 3, changing only the fact-key digest and `oracle_version` to 2. `product_director_content_digest` and `inherited_runtime_digest` remain byte-identical; any content or Harness change makes the run stale instead of becoming part of this approval update.

Both lanes must start from that same digest. If the user cannot or does not approve the missing facts, do not spawn either executor: record role candidate `BLOCKED_ORACLE`, close via Task 5's terminal branch, and return the unresolved business questions to the user.

Before spawning either executor, validate and commit the new authority boundary independently from replay evidence:

```bash
python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001 \
  --require-role product-director \
  --require-stage static-audit \
  --source-root agent-skills=/Users/lijieli/.agents \
  --source-root codex-home=/Users/lijieli/.codex \
  --source-root qft-tenants=/Users/lijieli/project/qft-tenants \
  --source-root qft-app=/Users/lijieli/project/qft-tenants/qft-app \
  --source-root qft-all=/Users/lijieli/project/qft-tenants/qft-all

git add docs/superpowers/specs/2026-07-14--qft-qmi-pc-001-oracle-supplement.md \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/input-manifest.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case/oracle-manifest.json
git commit -m "eval: approve qft move in business baseline"
```

Expected: validator exit 0; the commit contains only the approved supplement, the two manifests it re-baselines, and `run.json` with refreshed case-ref digests. If no supplement is approved, do not run this commit block.

If any new user fact arrives after an attempt starts, never patch an active transcript or overwrite attempt directories. Mark the current run stale for the affected fact keys, close it without a pass, and require a follow-up plan with a new run ID and Oracle version. This slice only starts attempts after the readiness gate, so in-place rebaseline is forbidden.

- [ ] **Step 1: Build two byte-identical allowlist staging workspaces**

Create `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-executor-a-1/` and `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-executor-b-1/`, each containing only:

```text
shared/skills/product-director/**
shared/skills/product-manager/contracts/brief.schema.json
shared/skills/product-manager/contracts/phase-prd.schema.json
shared/skills/lib/contracts/shared-core.schema.json
shared/hooks/lib/common.sh
shared/runtime/standard-chain-catalog.json
tools/community/validate_co_creation_ledger.py
tools/community/validate_canonical_schema.py
tools/community/validate_standard_chain_readiness.py
contracts/canonical/registry-bundle.yaml
contracts/skill-runtime-surface.json
contracts/standard-chain-invocation-policy.yaml
contracts/co-creation-ledgers.yaml
contracts/product-artifacts.yaml
contracts/standard-chain.yaml
contracts/standard-chain-field-consumption.yaml
input/start.txt
input/runtime-surface-digest.json
input/inherited-runtime-manifest.json
```

Generate `input/inherited-runtime-manifest.json` from the frozen refs and Harness descriptor in Task 3; both lanes receive byte-identical copies. Record absolute `STAGING_ROOT`, `OUTPUT_ROOT`, `pwd`, both realpaths, `python3 --version`, `jq --version`, `bash --version` and `codex --version` in the attempt environment. Run the `common.sh` runtime-root probe and require its resolved runtime root to equal `STAGING_ROOT`; falling back to an unlisted `$HOME/.codex` file is contamination, not recovery. Do not copy `AGENTS.md`, approval record, design, Oracle, QFT PRD, result commits, result root or another lane. Produce a sorted relative-path/SHA-256 list for each workspace, store the list and its canonical digest in that lane's `attempt.json.environment`, and prove the two canonical digests equal before starting. The list excludes absolute staging/output roots, so lane-specific paths cannot create a false mismatch; `inherited_runtime_digest` separately proves the frozen external Harness refs equal.

- [ ] **Step 2: Start two new executors with no inherited conversation**

Use two new subagents with `fork_turns="none"`. Give both the same prompt except lane ID and output directory:

```text
你是 Product Director 内容就绪诊断回放执行者。授权输入由绝对路径 STAGING_ROOT 及 prompt 末尾的 INHERITED_RUNTIME_ALLOWLIST 共同组成，唯一授权输出根目录是 OUTPUT_ROOT。所有 shell/tool 调用显式使用 STAGING_ROOT 作为 workdir；先履行 system/developer 强制流程，并逐项声明因此读取的 allowlist 文件；随后记录 pwd、realpath 和两个输入 digest，再读取并严格遵守 STAGING_ROOT/shared/skills/product-director/SKILL.md 及其明确路由的内容。除 INHERITED_RUNTIME_ALLOWLIST 的精确 path+SHA-256 外，不得从当前 repo cwd、$HOME 或任何 staging 外路径读取文件；不得读取 Oracle、历史结果实现、另一 lane、审查结果、未列出的用户配置/memory、MCP/browser/connector 或网络。不得为了评测跳过、弱化或覆盖继承的高优先级流程；若它与 Product Director 冲突，停止并报告。当前隔离仅为 DECLARED_ONLY，所以你的输出只是诊断证据。

从 input/start.txt 的需求线索开始，按当前 Skill 逐轮共创；每轮只提出当前 Skill 允许的一个问题。事实不足时询问或停止，不得补业务真相，不进入产品/技术 HOW。协调者只会从已批准事实表回答被问到的事实，未批准事实返回 unknown。

只有当前 Skill 的前置事实和确认门禁满足时，才把 ledger、brief、phase-1/phase-prd 写入授权输出目录；否则必须停止并明确列出阻断事实，不得为了评测完整性伪造产物。同时输出实际读取文件、执行命令、事实/推断/假设/未知、每轮状态变化、继续/停止/退回结论。canonical JSON 不得加入 evaluation_only、case_id、lane_id、oracle_ref 或 attempt_id。

INHERITED_RUNTIME_ALLOWLIST 由协调者替换为 Task 3 已冻结的有序 path+SHA-256 列表；两个 lane 的列表必须字节一致。
```

For attempt 1, substitute exact roots before dispatch:

| Lane | `STAGING_ROOT` | `OUTPUT_ROOT` |
| --- | --- | --- |
| executor-a | `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-executor-a-1` | `/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-a/attempts/attempt-1/artifacts` |
| executor-b | `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-executor-b-1` | `/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-b/attempts/attempt-1/artifacts` |

Retries change both terminal path components to `attempt-2` or `attempt-3`. Any tool call that uses the repository cwd instead of the exact staging root voids the attempt.

Do not tell executors the expected role verdict or static findings.

- [ ] **Step 3: Act as a strict Business Proxy**

For every executor question:

1. map it to one or more `business_proxy_fact_keys` in the reviewer-only Oracle manifest;
2. answer only those keys;
3. cite the approved Oracle atom in the coordinator-side transcript metadata, not in the executor-visible answer;
4. return `unknown` when no approved key answers the question;
5. interrupt the real user only if the missing fact is business authority and would materially change the Director baseline.

For each response, select only the asked fact rows, sort by `fact_key`, project exactly `fact_key`, `fact_class`, and `answer_text`, and send the canonical JSON object `{"answers":[...]}` with the plan-wide terminal newline. Store the same array in the transcript turn; store authority refs only in `answer_authority_refs`. Do not volunteer future-step facts, implementation details or the other lane's question order. The same fact key must therefore receive byte-identical `fact_class` and `answer_text` in both lanes; free-form paraphrase is forbidden in this diagnostic protocol.

Confirmation authority is constrained by approved design line 485, which permits approved Oracle to proxy historical decisions:

- For a section checkpoint, confirm only the candidate fields whose complete semantics trace to approved fact keys; reject or return `unknown` for any bundled unapproved claim.
- Send the exact final token `产品总监确认` only after every Director-locked field, scope/non-goal, success standard, investment boundary and Phase choice traces to the current Oracle version and no new value trade-off exists.
- Record `confirmation_authority_ref`, confirmed field refs and Oracle/supplement refs in reviewer-side transcript metadata. The token is an evaluation proxy event, not a new production approval.
- If any locked field remains unknown, do not send the token and do not allow final artifacts; the attempt ends `STOPPED` with blocking fact refs.

- [ ] **Step 4: Persist and police each attempt**

Write every attempt under `executor-a/attempts/attempt-N/` or `executor-b/attempts/attempt-N/`; never overwrite an earlier directory. Update the lane's `lane.json` with ordered refs and its decisive ref only after the attempt closes. `attempt.json` must record:

```text
lane_id
attempt_number
starting_input_sha256
isolation_level=DECLARED_ONLY
attempt_status
actual_read_declaration
commands
business_fact_keys_received
output_refs and hashes
continue_stop_return
contamination_findings
```

If an executor reports or reveals an unauthorized read, set attempt status `VOID_CONTAMINATED`, discard it from all reviews and retry with a new Agent and a new temp directory. Maximum: attempt 1 plus attempts 2 and 3. Three contaminated attempts in one lane close the run as `INCONCLUSIVE_CONTAMINATED`.

`INFRA_FAILURE` is also non-decisive. One retry is allowed only after the coordinator records a concrete infrastructure recovery while preserving the same replay-baseline digest; it counts toward the same maximum of three total attempts. If recovery is impossible or three total attempts are exhausted without a decisive result, close with role candidate `BLOCKED_EVIDENCE`, global `BLOCKED_ISOLATION`, and terminal evidence; do not run reviews that require outputs.

If all three attempts in either lane are contaminated, set `lane.json.terminal_condition=ALL_CONTAMINATED`, omit `decisive_attempt_ref`, close `run.json` with `global_state=INCONCLUSIVE_CONTAMINATED`, and skip Steps 5-8 and Task 5's role-verdict path. Validate with `--require-stage terminal-run` and commit only the immutable contamination evidence and closed run.

The contamination terminal command is:

```bash
python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001 \
  --require-role product-director \
  --require-stage terminal-run \
  --source-root agent-skills=/Users/lijieli/.agents \
  --source-root codex-home=/Users/lijieli/.codex \
  --source-root qft-tenants=/Users/lijieli/project/qft-tenants \
  --source-root qft-app=/Users/lijieli/project/qft-tenants/qft-app \
  --source-root qft-all=/Users/lijieli/project/qft-tenants/qft-all

git add tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-a \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-b
git commit -m "eval: record inconclusive product director replay"
```

Expected: validator exit 0, no `role-verdict.json`, no review files, and no decisive ref for the contaminated lane. Stop the plan after this commit.

- [ ] **Step 5: Run canonical Product Director gates for each valid diagnostic attempt**

For each lane that legitimately produced canonical artifacts, read `ATTEMPT_NAME` from `lane.json.decisive_attempt_ref`, then initialize:

```bash
RESULT_ROOT="/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001"
LANE_NAME="executor-a"
ATTEMPT_NAME="$(jq -r '.decisive_attempt_ref.path | split("/")[-2]' "$RESULT_ROOT/roles/product-director/$LANE_NAME/lane.json")"
ATTEMPT_NUMBER="${ATTEMPT_NAME#attempt-}"
LANE_DIR="$RESULT_ROOT/roles/product-director/$LANE_NAME/attempts/$ATTEMPT_NAME/artifacts"
STAGING_ROOT="/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-$LANE_NAME-$ATTEMPT_NUMBER"
TMP_WORKSPACE="$(mktemp -d "${TMPDIR:-/tmp}/qft-qmi-pc-001-$LANE_NAME.XXXXXX")"
```

Run once with `LANE_NAME=executor-a` and once with `LANE_NAME=executor-b`:

```bash
python3 "$STAGING_ROOT/tools/community/validate_co_creation_ledger.py" \
  --artifact "$LANE_DIR/product-director-ledger.json" \
  --producer product-director \
  --require-finalized

python3 "$STAGING_ROOT/shared/skills/product-director/scripts/evaluate_content_quality.py" \
  --brief "$LANE_DIR/brief.json" \
  --phase-prd "$LANE_DIR/phase-1/phase-prd.json" \
  --ledger "$LANE_DIR/product-director-ledger.json" \
  --min-score 12
```

Copy the three artifacts into `$TMP_WORKSPACE/docs/qft-qmi-pc-001-$LANE_NAME/`, and invoke the frozen completion hook:

```bash
printf '{"cwd":"%s","session_id":"qft-qmi-pc-001-%s","transcript_path":"/dev/null","tool_input":{"file_path":"docs/qft-qmi-pc-001-%s/brief.json"}}\n' "$TMP_WORKSPACE" "$LANE_NAME" "$LANE_NAME" \
  | "$STAGING_ROOT/shared/skills/product-director/scripts/completion_check.sh"
```

Expected for a structurally/content-valid lane: ledger validator exit 0, content evaluator `verdict=PASS`, completion hook `decision=allow`. A correctly stopped lane must have no canonical artifact refs and a blocking fact trace; do not run these gates against missing files. Any other failure is evidence; do not edit the Skill or silently repair executor output.

- [ ] **Step 6: Run divergence and Oracle review after both lanes close**

Use a fresh reviewer subagent. It receives both complete attempts, approved Oracle, source classification, current content package and historical support evidence. It must write:

- `divergence-review.json`: every material difference mapped to one approved divergence class, with output refs and effect on root problem, target, success, appetite, scope, non-goals, Phase boundary or handoff;
- `oracle-review.json`: every Director-owned output field checked against relevant Oracle atoms, plus fact/inference/assumption/unknown classification and explicit rejection of file/class-name similarity scoring.

The reviewer may cite result commits only after both executor outputs exist. A common wrong answer is still a defect; agreement is not correctness evidence.

- [ ] **Step 7: Run downstream consumption without Oracle**

Create `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-pm-consumer/` with this exact allowlist and its sorted digest manifest:

```text
shared/skills/product-manager/SKILL.md
shared/skills/product-manager/scripts/preflight_check.sh
shared/skills/product-manager/scripts/preflight_check.py
shared/skills/product-manager/contracts/brief.schema.json
shared/skills/product-manager/contracts/phase-prd.schema.json
shared/skills/lib/contracts/shared-core.schema.json
tools/community/validate_product_closure.py
tools/community/normalize_canonical_artifact.py
tools/community/review_digest_common.py
input/candidate-a/
input/candidate-b/
```

For a completed candidate, copy only its `brief.json` and `phase-1/phase-prd.json`, then run the deterministic Handoff gate from the consumer staging root:

```bash
bash shared/skills/product-manager/scripts/preflight_check.sh \
  --brief "input/candidate-a/brief.json" \
  --phase-prd "input/candidate-a/phase-1/phase-prd.json"
```

Repeat with `candidate-b`. Expected for a consumable canonical handoff: JSON `status=PASS`. For a stopped lane, copy only its `attempt.json` as `input/candidate-a/upstream-stop.json` or candidate B equivalent; do not run preflight against fake missing artifacts.

Use one fresh Product Manager consumer subagent with `fork_turns="none"`, absolute consumer `STAGING_ROOT`, and this exact task:

```text
只执行当前 Product Manager 的 Director Handoff gate 和语义消费检查，不进入 PM 需求细化、不创建任何 PM 产物。只读取 STAGING_ROOT 和两个 candidate 输入，不读取 Oracle、transcript、review、另一仓库或网络。对 CANONICAL_HANDOFF，结合已执行 preflight 输出判断能否保留 Director-locked WHY 并开始 PM 职责；对 upstream-stop.json，必须返回 BLOCKED_UPSTREAM，不得发明 brief/phase 或开始 PM。输出 candidate A/B 各自的 single source、confirmed/candidate/unknown、authority/current state、start-or-route-back、invented-fact 检查及 path:field 证据。
```

This is a consumption check of Product Director output, not a Product Manager readiness verdict.

For each candidate record whether it can:

```text
locate a single source of truth
distinguish confirmed/candidate/unknown
preserve Director-locked WHY
identify authority/current state
start PM responsibility or route back
avoid inventing missing facts
```

If oral explanation would be required, record `HANDOFF_GAP`. Write one `downstream-consumption.json` with separate candidate results and path:field evidence. Delete consumer staging after re-opening the persisted result and digest.

- [ ] **Step 8: Validate the diagnostic replay stage**

Set `run.json.current_stage=DIAGNOSTIC_REPLAY`, keep `lifecycle_status=OPEN`, and refresh `role_refs.product-director` with both lane refs plus `divergence-review.json`, `oracle-review.json`, and `downstream-consumption.json`. Then run:

```bash
python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001 \
  --require-role product-director \
  --require-stage diagnostic-replay \
  --source-root agent-skills=/Users/lijieli/.agents \
  --source-root codex-home=/Users/lijieli/.codex \
  --source-root qft-tenants=/Users/lijieli/project/qft-tenants \
  --source-root qft-app=/Users/lijieli/project/qft-tenants/qft-app \
  --source-root qft-all=/Users/lijieli/project/qft-tenants/qft-all
```

Expected: exit 0 only if two decisive, non-contaminated diagnostic attempts exist with identical starting inputs and complete review/consumption evidence. A decisive attempt may be `COMPLETED` with gated artifacts or `STOPPED` with a proven blocking fact; it may not be contaminated or an infrastructure failure. Output must still state that `DECLARED_ONLY` cannot support authentic pass.

- [ ] **Step 9: Delete temp staging and commit Task 4**

Delete `/tmp/standard-chain-content-readiness-QFT-QMI-PC-001-*` only after all output hashes are re-opened from the result root.

```bash
git add tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-a \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/executor-b \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/divergence-review.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/oracle-review.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/downstream-consumption.json
git commit -m "eval: record product director diagnostic replay"
```

---

## Task 5: Complete Formal Audit And Issue The First-slice Verdict

**Files:**
- Create when formal audit evidence is available: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-report.json`
- Create when formal audit evidence is available: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-summary.md`
- Create: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/role-verdict.json`
- Modify: `tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json`

- [ ] **Step 0: Select one legal closure branch**

Use exactly one branch:

| Branch | Condition | Formal report | Role verdict | Validation stage |
| --- | --- | --- | --- | --- |
| A | three contaminated attempts in either lane | none | none | already closed in Task 4 as `terminal-run` / `INCONCLUSIVE_CONTAMINATED`; do not execute Task 5 |
| B | Business Proxy readiness fails, core evidence is unavailable, or contamination/infra failure prevents two decisive lanes or the reviews they require | none | `BLOCKED_ORACLE` or `BLOCKED_EVIDENCE` | `terminal-run` |
| C | static current content/Harness evidence directly proves blocking P0/P1 | required, based on complete static scope and claim review; replay is not fabricated | `CONTENT_FAIL` | `role-verdict` |
| D | two decisive diagnostic lanes and all reviews exist, including when either decisive lane legitimately stopped without canonical output | required from full evidence | `CONTENT_FAIL`, `BLOCKED_ORACLE`, `BLOCKED_EVIDENCE`, or `BLOCKED_ISOLATION` | `role-verdict` |

No branch may create empty report placeholders. Branch A has no role verdict by approved contamination rule. Branch D wins over B whenever both decisive lane refs and all three review artifacts exist; `STOPPED` is a legal decisive result and is not by itself a reason to downgrade to Branch B.

- [ ] **Step 1: Complete the formal SQA report only for Branch C or D**

Use `skill-quality-audit` in formal mode against `shared/skills/product-director`. The report must:

- reference the confirmed alignment and exactly `SC-CAP-PD-001`;
- cover all 16 surfaces and 10 dimensions;
- for Branch C, use complete static decision/surface/current-Harness evidence and explicitly state replay stopped by the static gate;
- for Branch D, merge static decision atoms, both decisive diagnostic attempts, divergence review, Oracle review, downstream consumption and runtime/harness evidence;
- use current path:line checks for every supported content-behavior field;
- calibrate and refutation-check every P0/P1;
- keep the evidence boundary explicit: one case, diagnostic replay, `DECLARED_ONLY`, no team-ready/production-ready claim;
- use SQA verdicts only: `fit|conditional|unfit|blocked`.

Run:

```bash
python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-alignment.json

python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-report.json
```

Expected for Branch C/D: both validators exit 0. A schema-valid report is necessary evidence, not automatic role pass. Branch B validates alignment only and must not invent a report merely to run the report validator.

- [ ] **Step 2: Issue `role-verdict.json` using precedence, not optimism**

Required fields:

```text
artifact_type=standard-chain-content-readiness-role-verdict
case_id=QFT-QMI-PC-001
role=product-director
verdict_scope=case_bounded_content_readiness
skill_revision
content_digest
inherited_runtime_digest
unavailable_baselines (required only when `BLOCKED_EVIDENCE` replaces one or both unavailable digests)
optional audit_report_ref (the scoped ref already carries its SHA-256)
decisive_attempt_refs (empty only for a legal terminal branch with no decisive attempt and explicit terminal evidence)
isolation_level
oracle_bridge_used
open_p0_p1
verdict
reason_codes
evidence_refs
claim_boundaries
next_decision
```

Apply Role Verdict And Run-state Rules exactly. With current known isolation, the no-P0/P1 happy path is `BLOCKED_ISOLATION`, not `CONTENT_PASS`. If direct current evidence proves P0/P1, role verdict is `CONTENT_FAIL`; do not let isolation hide the content defect, but do not rewrite the global state as `REPAIR_REQUIRED`.

Digest absence is not a wildcard. `content_digest` may be omitted only with `verdict=BLOCKED_EVIDENCE` and `unavailable_baselines.baseline_type=PRODUCT_DIRECTOR_CONTENT`; `inherited_runtime_digest` may be omitted only with the same verdict and `baseline_type=INHERITED_RUNTIME`. Each entry needs a reason code and scoped evidence proving why the complete baseline could not be read/frozen. Partial digests are forbidden. `BLOCKED_ORACLE`, `CONTENT_FAIL`, and `BLOCKED_ISOLATION` always require both complete digests.

- [ ] **Step 3: Close the first slice without pretending the full run completed**

Update `run.json`, including `role_refs.product-director` scoped refs for every present Product Director artifact and the issued verdict:

```text
current_stage=ROLE_VERDICT
lifecycle_status=CLOSED
evaluated_roles=[product-director]
global_state=BLOCKED_ISOLATION
primary_role_outcome equals the issued role verdict
next_authorized_action is exactly one of repair design, isolation harness design, or Oracle/evidence resolution
closure_validation_stage=role-verdict
```

For Branch B use `current_stage=CASE_ADMISSION`, `STATIC_AUDIT`, or `DIAGNOSTIC_REPLAY` according to the last proven stage, while `lifecycle_status=CLOSED`, `global_state=BLOCKED_ISOLATION`, `primary_role_outcome` equals the issued blocked role verdict, `closure_validation_stage=terminal-run`, and `evaluated_roles=[product-director]`. A core surface failure may legally stop at `CASE_ADMISSION`; never promote it to a static pass. Do not append the remaining five roles; do not create `chain-verdict.json`, root `summary.md` or `shadow-phase/`.

- [ ] **Step 4: Run final target-scope verification for the selected branch**

```bash
FINAL_STAGE="$(jq -r '.closure_validation_stage' tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json)"
bash tests/test-standard-chain-content-readiness-contract.sh

python3 tools/eval/scripts/validate_standard_chain_content_readiness.py \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001 \
  --require-role product-director \
  --require-stage "$FINAL_STAGE" \
  --source-root agent-skills=/Users/lijieli/.agents \
  --source-root codex-home=/Users/lijieli/.codex \
  --source-root qft-tenants=/Users/lijieli/project/qft-tenants \
  --source-root qft-app=/Users/lijieli/project/qft-tenants/qft-app \
  --source-root qft-all=/Users/lijieli/project/qft-tenants/qft-all

bash tests/test-product-director-real-demand-smoke.sh
bash tests/run-focused.sh skill-quality-audit
bash tests/run-focused.sh standard-chain
```

Expected: all five commands exit 0. The cross-file validator output must show the selected checked stage and no unsupported readiness claim. Branch C has no replay requirement; Branch B may omit the report and decisive outputs only for its explicit blocking reason; Branch D must show invoked SQA validators PASS and two decisive diagnostic lanes.

- [ ] **Step 5: Run the repository quick gate and separate the known outside-scope blocker**

```bash
bash tests/run-all.sh --quick
```

Current baseline expectation: the command may exit non-zero at the pre-existing third-party mirror issue:

```text
community/vercel/skills/agent-browser/SKILL.md: auto skill source must not declare hidden=true
```

Do not modify `community/vercel` to make this plan green. If that exact baseline blocker is the only failure and all target-scope commands passed, record global quick gate as `BLOCKED_BY_PRE_EXISTING_OUTSIDE_SCOPE`, not PASS. Any new failure, any changed failure text, or any target-scope failure blocks completion.

- [ ] **Step 6: Review scope and diff**

```bash
git status --short
git diff --check d7efad0923136d5cf7c9390a2d38a22cb6a71ff2
git diff --stat d7efad0923136d5cf7c9390a2d38a22cb6a71ff2
git diff --name-only d7efad0923136d5cf7c9390a2d38a22cb6a71ff2
```

Expected changed paths only under:

```text
docs/superpowers/plans/
docs/superpowers/specs/2026-07-14--qft-qmi-pc-001-oracle-supplement.md
tools/eval/contracts/
tools/eval/scripts/validate_standard_chain_content_readiness.py
tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/
tests/fixtures/standard-chain-content-readiness/
tests/test-standard-chain-content-readiness-contract.sh
tests/gate-plan.json
```

No target Skill, QFT repository, active standard-chain state, shared runtime rule or community mirror may change.

- [ ] **Step 7: Commit the final evidence slice for the selected branch**

For Branch B:

```bash
git add tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/case \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director
git commit -m "eval: close blocked product director content readiness slice"
```

Branch B's case and role directories are intentional: they capture every present case rebaseline, static, lane, attempt, failure, and verdict artifact. Before committing, the cross-file validator must reject any present terminal evidence missing from `run.json.case_refs`, `run.json.role_refs.product-director`, or the role verdict's `evidence_refs`; staging directories is not permission to keep unreferenced junk.

For Branch C or D:

```bash
git add tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/run.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-report.json \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/content-audit-summary.md \
  tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/roles/product-director/role-verdict.json
git commit -m "eval: close product director content readiness slice"
```

- [ ] **Step 8: Prove the committed range and clean worktree**

```bash
git diff --check d7efad0923136d5cf7c9390a2d38a22cb6a71ff2..HEAD
git diff --name-only d7efad0923136d5cf7c9390a2d38a22cb6a71ff2..HEAD
git status --short
```

Expected: the committed paths still match Step 6's allowlist and `git status --short` is empty. A commit does not cure an out-of-scope diff.

---

## Deferred Slice: Delivery Owner Shadow Contract

Delivery Owner `FULL_SHADOW_CONTRACT` is outside Slice 1. This plan must not modify active-doc-scope, delivery runtime Skills/hooks/manifests, standard-chain catalog/contracts or target repositories.

A later standalone design is required because current managed runtime has five proven gaps:

1. completion hooks bind role evidence to `docs/.../phase-N`, not `tools/eval/results/.../shadow-phase`;
2. consistency-audit Skill discovery/completion is bound to `docs/{feature}`;
3. runtime catalog and standard-chain contracts default canonical paths to active docs;
4. developer semantics require real TDD/file changes/current-repo commits, not read-only historical replay;
5. registry tooling can check/restore fixtures but lacks a general controlled append CLI for shadow owner writes.

Future work may reuse explicit `--phase-dir` validators and existing canonical schemas, but must not reuse fixture results as owner evidence. If an unmodified runtime cannot produce fresh owner-authored developer/verify/review/QA/final-consistency evidence, it must record:

```text
delivery_owner_coverage=INTAKE_ONLY
reason_code=HARNESS_MISMATCH
CASE_REPLAY_PASS blocked
```

No hook bypass and no fixture masquerading as `FULL_SHADOW_CONTRACT` is allowed.

---

## Execution Handoff

Recommended execution mode: `subagent-driven-development`.

- Use one fresh implementer per infrastructure task, then independent spec/code review before task commit.
- Use `fork_turns="none"` only for the two diagnostic executors and downstream consumer; they must not inherit this planning conversation or Oracle.
- The coordinator retains Business Proxy and verdict responsibility and must not delegate business truth to an executor.
- Stop after the Product Director role verdict. The next plan depends on evidence: content repair design, isolation harness design, or Oracle/evidence resolution.
