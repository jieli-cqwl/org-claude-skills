# skill-optimizer Harness Delivery Implementation Plan

**Goal:** Build `skill-optimizer` as a Harness Engineering skill that audits, optimizes, verifies, and migrates existing Skills through machine-readable runtime contracts.

**Architecture:** Create `shared/skills/skill-optimizer/` with a concise `SKILL.md`, Codex adapter, contract references, examples, minimal runtime schemas, deterministic scripts, evals, templates, and install integration. Runtime truth starts with `skill-audit.json`; `optimization-plan.json` and `verification-result.json` become hard runtime artifacts only after their real consumers are implemented. Markdown/HTML reports are rendered views. `new-skills` is retired; creation defaults to official `skill-creator` and optimization defaults to `skill-optimizer`.

**Tech Stack:** Markdown Skill files, YAML Codex adapters, Bash contract tests, Python JSON validators, JSON fixtures, shell install checks.

---

## Plan 状态

- 设计基线：`design.md`
- Runtime 细节：`runtime-blueprint.md`
- Review 裁决：`review-resolution.md`
- Source map：`source-notes.md`
- 执行入口：按 small chain 计划推进；涉及写入、危险动作或 gate 放行时，以当前会话授权为准。
- 执行纪律：每个 Task 必须 RED -> GREEN -> REFACTOR；计划不引入阶段式交付报告。

## Scope Freeze

| Scope item | Design anchor | Files |
| --- | --- | --- |
| Skill 入口与 adapter | SO-TRIGGER-01 / SO-PERMISSION-01 | `shared/skills/skill-optimizer/SKILL.md`, `shared/skills/skill-optimizer/agents/openai.yaml` |
| 审计 references、examples、source coverage | SO-LOAD-01 / SO-REFERENCE-01 / SO-SUBAGENT-01 | `shared/skills/skill-optimizer/references/`, `shared/skills/skill-optimizer/examples/` |
| Runtime artifact MVP | SO-RUNTIME-01 | `shared/skills/skill-optimizer/schemas/skill-audit.schema.json`, `shared/skills/skill-optimizer/schemas/field-consumers.json`, `shared/skills/skill-optimizer/scripts/validate_*.py` |
| Runner、renderer、optimization-plan 消费 | SO-RUNTIME-01 / SO-VALIDATION-01 | `shared/skills/skill-optimizer/scripts/audit_skill.py`, `shared/skills/skill-optimizer/scripts/render_report.py`, `shared/skills/skill-optimizer/scripts/generate_optimization_plan.py`, `shared/skills/skill-optimizer/templates/` |
| Permission、manifest、hook adapter contract | SO-PERMISSION-01 / SO-SCRIPT-01 | `shared/skills/skill-optimizer/rules/`, `shared/skills/skill-optimizer/scripts/manifest.json`, `shared/skills/skill-optimizer/references/hook-adapter-contract.md` |
| Eval 与 benchmark | SO-VALIDATION-01 / SO-SUBAGENT-01 | `shared/skills/skill-optimizer/evals/`, `tests/fixtures/skill-optimizer/evals/` |
| 旧入口退役与安装 | SO-MIGRATION-01 | `install.sh`, install/runtime tests, `tests/test-skill-optimizer-migration.sh` |
| 端到端验证与覆盖 | SO-TRACKING-01 | `tests/test-skill-optimizer-end-to-end.sh`, `docs/skill-optimizer/2026-04-16-course-derived-methodology/implementation-coverage.md` |

### Task 1: Skill Entry And Adapter [T1]

Files:
- Create: `shared/skills/skill-optimizer/SKILL.md`
- Create: `shared/skills/skill-optimizer/agents/openai.yaml`
- Create: `tests/test-skill-optimizer-contract.sh`
- Modify: `tests/test-codex-skill-adapter.sh`

Change boundary:
- T1 creates the new entry and adapter only.
- T1 does not retire `shared/skills/new-skills/`; trigger conflict retirement is T7.

Verification command:
- `bash tests/test-skill-optimizer-contract.sh`
- `bash tests/test-codex-skill-adapter.sh`

Expected output:
- RED fails before entry files exist.
- GREEN and REFACTOR reruns pass after `SKILL.md` and adapter are present.

1. [T1] RED: Create `tests/test-skill-optimizer-contract.sh` assertions for `SKILL.md` frontmatter, installed-reference routing, audit workflow, permission mode, source boundary, and six-link audit chain.
2. [T1] RED: Extend `tests/test-codex-skill-adapter.sh` with `skill-optimizer` positive trigger checks and creation-trigger exclusion before creating `agents/openai.yaml`.
3. [T1] RED: Run `bash tests/test-skill-optimizer-contract.sh` and `bash tests/test-codex-skill-adapter.sh`; expected failures are missing `shared/skills/skill-optimizer/SKILL.md` and missing `skill-optimizer/agents/openai.yaml`.
4. [T1] GREEN: Create `shared/skills/skill-optimizer/SKILL.md` with trigger boundary, input contract, audit workflow, JSON output contract, permission mode, completion gate, and contract references under `shared/skills/skill-optimizer/references/`.
5. [T1] GREEN: Create `shared/skills/skill-optimizer/agents/openai.yaml` with optimize/audit/improve existing Skill triggers and no new Skill creation trigger.
6. [T1] GREEN: Run `bash tests/test-skill-optimizer-contract.sh` and `bash tests/test-codex-skill-adapter.sh`; expected output is PASS.
7. [T1] REFACTOR: Tighten wording to keep `SKILL.md` as router, remove runtime dependency on `docs/skill-optimizer/...`, and rerun both T1 verification commands; expected output remains PASS.

### Task 2: References, Examples, And Source Coverage [T2]

Files:
- Create: `shared/skills/skill-optimizer/references/audit-method.md`
- Create: `shared/skills/skill-optimizer/references/reference-contract.md`
- Create: `shared/skills/skill-optimizer/references/permission-script-contract.md`
- Create: `shared/skills/skill-optimizer/references/subagent-handoff-contract.md`
- Create: `shared/skills/skill-optimizer/references/d1-d7-mapping.md`
- Create: `shared/skills/skill-optimizer/references/source-map.md`
- Create: `shared/skills/skill-optimizer/examples/trigger-cases.md`
- Create: `shared/skills/skill-optimizer/examples/reference-contract-cases.md`
- Create: `shared/skills/skill-optimizer/examples/permission-cases.md`
- Create: `shared/skills/skill-optimizer/examples/subagent-eval-cases.md`
- Modify: `tests/test-skill-optimizer-contract.sh`

Change boundary:
- T2 adds installable knowledge resources and examples only.
- T2 does not create runtime schemas or scripts.

Verification command:
- `bash tests/test-skill-optimizer-contract.sh`

Expected output:
- RED fails on missing references, examples, source coverage, and keyword coverage.
- GREEN and REFACTOR reruns pass after resources are routed by contract.

1. [T2] RED: Extend contract tests to require each reference file, each example file, and `SKILL.md` routing by contract rather than bare filename.
2. [T2] RED: Add source coverage checks for C09/C10/C11/C12/C13/C14/C99, `$ARGUMENTS`, `!command`, Quick Reference, QUICKREF, INDEX, Push/Pull, skills marketplace, SLASH_COMMAND_TOOL_CHAR_BUDGET, 全量预加载, pipeline, 跨平台, 自包含, namespace, monorepo, and 复用.
3. [T2] RED: Run `bash tests/test-skill-optimizer-contract.sh`; expected failures are missing reference/example files and missing source coverage terms.
4. [T2] GREEN: Create `audit-method.md` with the six-link audit chain, finding fields, source marker handling, and D1-D7 relation.
5. [T2] GREEN: Create `reference-contract.md`, `permission-script-contract.md`, `subagent-handoff-contract.md`, `d1-d7-mapping.md`, and `source-map.md`.
6. [T2] GREEN: Create trigger, reference, permission, and SubAgent/fork examples with positive, negative, boundary, and handoff cases.
7. [T2] GREEN: Run `bash tests/test-skill-optimizer-contract.sh`; expected output is PASS.
8. [T2] REFACTOR: Remove duplicate prose, keep high-frequency routing in `SKILL.md`, keep low-frequency content in references/examples, and rerun `bash tests/test-skill-optimizer-contract.sh`; expected output remains PASS.

### Task 3: Runtime MVP Schemas And Validators [T3]

Files:
- Create: `shared/skills/skill-optimizer/schemas/skill-audit.schema.json`
- Create: `shared/skills/skill-optimizer/schemas/state-vocabulary.json`
- Create: `shared/skills/skill-optimizer/schemas/field-consumers.json`
- Create: `shared/skills/skill-optimizer/scripts/validate_schema.py`
- Create: `shared/skills/skill-optimizer/scripts/validate_semantics.py`
- Create: `shared/skills/skill-optimizer/scripts/validate_consumers.py`
- Create: `tests/test-skill-optimizer-runtime-artifacts.sh`
- Create: `tests/fixtures/skill-optimizer/runtime/`

Change boundary:
- T3 hardens only the `skill-audit.json` MVP runtime contract.
- T3 does not harden `optimization-plan.json` or `verification-result.json`; those become hard contracts when their consumers exist in T4 and T8.

Verification command:
- `bash tests/test-skill-optimizer-runtime-artifacts.sh`

Expected output:
- RED fails on missing schemas, validators, and fixtures.
- GREEN and REFACTOR reruns pass after schema, semantic, and consumer validators reject negative cases.

1. [T3] RED: Write runtime artifact tests for positive `skill-audit.json` and negative fixtures: missing evidence refs, E5 hard gate, unknown state, missing design anchor, and field with no consumer.
2. [T3] RED: Run `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected failures are missing `skill-audit.schema.json`, `field-consumers.json`, and validator scripts.
3. [T3] GREEN: Create `skill-audit.schema.json`, `state-vocabulary.json`, and `field-consumers.json` as machine-readable runtime truth.
4. [T3] GREEN: Implement `validate_schema.py` to validate artifact shape against JSON schema.
5. [T3] GREEN: Implement `validate_semantics.py` to check design anchors, source markers, E5 rules, evidence refs, legal states, and Markdown/HTML fact-source boundary.
6. [T3] GREEN: Implement `validate_consumers.py` to fail when runtime fields lack entries in `field-consumers.json`.
7. [T3] GREEN: Run `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected output is PASS.
8. [T3] REFACTOR: Split shared Python helpers only when duplicated logic appears across validators, then rerun `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected output remains PASS.

### Task 4: Audit Runner, Renderer, And Optimization Plan Consumption [T4]

Files:
- Create: `shared/skills/skill-optimizer/schemas/optimization-plan.schema.json`
- Create: `shared/skills/skill-optimizer/scripts/audit_skill.py`
- Create: `shared/skills/skill-optimizer/scripts/render_report.py`
- Create: `shared/skills/skill-optimizer/scripts/generate_optimization_plan.py`
- Create: `shared/skills/skill-optimizer/scripts/validate_plan_consumption.py`
- Create: `shared/skills/skill-optimizer/scripts/validate_rendered_views.py`
- Create: `shared/skills/skill-optimizer/templates/audit-report.md.tmpl`
- Create: `shared/skills/skill-optimizer/templates/audit-report.html.tmpl`
- Modify: `tests/test-skill-optimizer-runtime-artifacts.sh`
- Modify: `shared/skills/skill-optimizer/schemas/field-consumers.json`
- Create: `tests/fixtures/skill-optimizer/target-skills/minimal-good/`
- Create: `tests/fixtures/skill-optimizer/target-skills/reference-broken/`

Change boundary:
- T4 reads target Skill fixtures, emits audit and optimization-plan artifacts, and renders views.
- T4 does not emit final `verification-result.json`.

Verification command:
- `bash tests/test-skill-optimizer-runtime-artifacts.sh`

Expected output:
- RED fails on missing runner, renderer, optimization plan schema, plan consumer, and rendered view validator.
- GREEN and REFACTOR reruns pass after artifacts and derived views are validated.

1. [T4] RED: Extend runtime tests to run `audit_skill.py` against `minimal-good` and `reference-broken` fixtures.
2. [T4] RED: Add assertions that `reference-broken` produces a `FAIL` finding with `file_ref`, `evidence_refs`, source marker, and `SO-REFERENCE-01`.
3. [T4] RED: Add renderer assertions for `source_artifact_hash`, `renderer_version`, `generated_at`, stale detection, and JSON-only fact source.
4. [T4] RED: Add optimization-plan assertions for accepted findings, file boundaries, verification contracts, and `validate_plan_consumption.py`.
5. [T4] RED: Run `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected failures are missing runner, renderer, optimization-plan schema, and plan consumer.
6. [T4] GREEN: Implement `audit_skill.py` to parse `SKILL.md` frontmatter, resource routing, reference contracts, permission hints, examples, and D1-D7 mapping.
7. [T4] GREEN: Implement `generate_optimization_plan.py` and `validate_plan_consumption.py` so `optimization-plan.json` fields have real consumers.
8. [T4] GREEN: Implement `render_report.py`, templates, and `validate_rendered_views.py` to generate Markdown/HTML from JSON artifacts only.
9. [T4] GREEN: Run `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected output is PASS.
10. [T4] REFACTOR: Consolidate shared artifact loading, hashing, and error formatting; rerun `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected output remains PASS.

### Task 5: Permission, Manifest, And Hook Adapter Contract [T5]

Files:
- Create: `shared/skills/skill-optimizer/rules/permission-profiles.md`
- Create: `shared/skills/skill-optimizer/scripts/manifest.json`
- Create: `shared/skills/skill-optimizer/scripts/validate_manifest.py`
- Create: `shared/skills/skill-optimizer/references/hook-adapter-contract.md`
- Modify: `tests/test-skill-optimizer-contract.sh`
- Modify: `tests/test-skill-optimizer-runtime-artifacts.sh`
- Modify: `shared/skills/skill-optimizer/SKILL.md`
- Modify: `shared/skills/skill-optimizer/schemas/field-consumers.json`

Change boundary:
- T5 defines permission and script execution contracts.
- T5 does not add global hook registry entries and does not create executable hook files.

Verification command:
- `bash tests/test-skill-optimizer-contract.sh`
- `bash tests/test-skill-optimizer-runtime-artifacts.sh`

Expected output:
- RED fails on missing permission rules, manifest, manifest validator, hook adapter lifecycle fields, and skill-local rules consumer.
- GREEN and REFACTOR reruns pass after all permission and manifest gates are enforceable.

1. [T5] RED: Extend contract tests to require read-only audit mode, no direct commit/delete/deploy path, exact write scope for edit/refactor/fix, and user authorization text for dangerous actions.
2. [T5] RED: Extend contract tests to require `rules/permission-profiles.md` to declare consumers, skill-local delta, and no weakening of global rules.
3. [T5] RED: Extend runtime tests to validate `scripts/manifest.json`, `validate_manifest.py`, and hook adapter lifecycle fields.
4. [T5] RED: Run `bash tests/test-skill-optimizer-contract.sh` and `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected failures are missing rules, manifest, validator, lifecycle fields, and rule consumers.
5. [T5] GREEN: Create permission profile rules for read/review/audit/explain, edit/refactor/fix, script run, and commit/deploy/delete.
6. [T5] GREEN: Create script manifest with path, allowed args, denied args, external commands, timeout, output limit, exit code meanings, shell parameter strategy, failure message, and verification command.
7. [T5] GREEN: Implement `validate_manifest.py` to fail on missing timeout, unbounded output, absent denied args, missing exit code meanings, or shell command without parameter strategy.
8. [T5] GREEN: Create `references/hook-adapter-contract.md` with `phase`, `trigger`, `input_artifact`, `allowed_action`, `output_artifact`, `failure_state`, `owner`, and `rollback`; assert no global registry entry is added.
9. [T5] GREEN: Run `bash tests/test-skill-optimizer-contract.sh` and `bash tests/test-skill-optimizer-runtime-artifacts.sh`; expected output is PASS.
10. [T5] REFACTOR: Reduce duplicate permission prose between `SKILL.md`, rules, and references; rerun both T5 verification commands; expected output remains PASS.

### Task 6: Eval Dataset And Benchmark [T6]

Files:
- Create: `shared/skills/skill-optimizer/evals/evals.json`
- Create: `shared/skills/skill-optimizer/evals/README.md`
- Create: `shared/skills/skill-optimizer/scripts/run_evals.py`
- Create: `shared/skills/skill-optimizer/scripts/validate_eval_results.py`
- Create: `tests/test-skill-optimizer-evals.sh`
- Create: `tests/fixtures/skill-optimizer/evals/`

Change boundary:
- T6 adds eval dataset and runner after script manifest gates exist.
- T6 eval cases use `run_command_id` from manifest or pure fixture checks; raw shell command strings are rejected.

Verification command:
- `bash tests/test-skill-optimizer-evals.sh`

Expected output:
- RED fails on missing eval files, required categories, manifest integration, and raw shell rejection.
- GREEN and REFACTOR reruns pass after eval results are validated.

1. [T6] RED: Create `tests/test-skill-optimizer-evals.sh` checks for trigger, non-trigger, neighbor conflict, missing argument, wrong argument, permission denied, format injection, migration compatibility, fork isolation, SubAgent `skills:` full preload, pipeline handoff, `$ARGUMENTS`, and `!command`.
2. [T6] RED: Add checks that eval cases use `run_command_id` tied to manifest or fixture-level assertions, and reject raw shell command text.
3. [T6] RED: Add checks that 5/10/30 output is recorded as usability evidence only.
4. [T6] RED: Run `bash tests/test-skill-optimizer-evals.sh`; expected failures are missing eval dataset, runner, and result validator.
5. [T6] GREEN: Create `evals/evals.json` with stable `case_id`, `category`, `input`, `expected_decision`, `target_skill_ref`, `neighbor_skill_refs`, `run_command_id`, and `pass_fail_condition`.
6. [T6] GREEN: Implement `run_evals.py` to load the dataset, execute manifest-approved checks, and write eval result input for final verification aggregation.
7. [T6] GREEN: Implement `validate_eval_results.py` to fail on trigger mismatch, missing failure path coverage, invalid command id, or quality claim based only on 5/10/30.
8. [T6] GREEN: Run `bash tests/test-skill-optimizer-evals.sh`; expected output is PASS.
9. [T6] REFACTOR: Normalize fixture naming and result summaries; rerun `bash tests/test-skill-optimizer-evals.sh`; expected output remains PASS.

### Task 7: Retirement And Install Integration [T7]

Files:
- Delete: `shared/skills/new-skills/`
- Modify: `install.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `tests/test-install-smoke.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-skill-context-budget.sh`
- Create: `tests/test-skill-optimizer-migration.sh`

Change boundary:
- T7 retires the old entry, install completeness, quick check, and install/runtime tests.
- T7 does not change official `skill-creator` source files.

Verification command:
- `bash tests/test-skill-optimizer-migration.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-install-smoke.sh`
- `bash tests/test-install-systematic.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-skill-context-budget.sh`

Expected output:
- RED fails while `shared/skills/new-skills/` or installed runtime `new-skills` still exists.
- GREEN and REFACTOR reruns pass after retirement and installation checks are verified.

1. [T7] RED: Create migration test requiring `shared/skills/new-skills/` to be absent.
2. [T7] RED: Add adapter checks that `skill-creator` owns new Skill creation, `skill-optimizer` owns existing Skill optimization, and `new-skills` is not installed.
3. [T7] RED: Add install smoke and runtime integrity checks for installed `skill-optimizer`, absent `new-skills`, and quick check completeness.
4. [T7] RED: Add context budget hard assertions that `skill-optimizer` is in the audit list and its directory exists; keep over-budget result as WARN.
5. [T7] RED: Run all T7 verification commands; expected failures are old source directory, installed runtime directory, missing quick check assertions, and missing runtime assertions.
6. [T7] GREEN: Delete `shared/skills/new-skills/`.
7. [T7] GREEN: Update `install.sh` runtime completeness, quick check, and retired skill cleanup for `skill-optimizer` present and `new-skills` absent.
8. [T7] GREEN: Update install smoke, runtime integrity, Codex adapter, and context budget tests.
9. [T7] GREEN: Run all T7 verification commands; expected output is PASS.
10. [T7] REFACTOR: Remove duplicate retirement wording while keeping verification evidence; rerun all T7 verification commands; expected output remains PASS.

### Task 8: End-To-End Evidence And Coverage [T8]

Files:
- Create: `shared/skills/skill-optimizer/schemas/verification-result.schema.json`
- Create: `shared/skills/skill-optimizer/scripts/build_verification_result.py`
- Create: `tests/test-skill-optimizer-end-to-end.sh`
- Create: `tests/fixtures/skill-optimizer/e2e/`
- Create: `docs/skill-optimizer/2026-04-16-course-derived-methodology/implementation-coverage.md`
- Modify: `docs/skill-optimizer/2026-04-16-course-derived-methodology/tasks.md`
- Modify: `docs/skill-optimizer/2026-04-16-course-derived-methodology/plan.md`
- Modify: `shared/skills/skill-optimizer/schemas/field-consumers.json`

Change boundary:
- T8 aggregates evidence and closes the full small-chain verification loop.
- T8 does not introduce new feature scope beyond coverage, verification-result, and final gates.

Verification command:
- `bash tests/test-skill-optimizer-end-to-end.sh`
- Full gate set listed in this plan

Expected output:
- RED fails on missing e2e fixture, verification-result schema, aggregator, and coverage report.
- GREEN and REFACTOR reruns pass after full evidence chain is present.

1. [T8] RED: Create end-to-end test that runs audit, optimization plan generation, schema validation, semantic validation, consumer validation, rendered view validation, eval runner, verification-result aggregation, and coverage validation on a fixed Skill fixture.
2. [T8] RED: Add assertions that `verification-result.json` contains `schema_validation`, `semantic_validation`, `fresh_commands`, `eval_results`, `coverage`, and `decision`.
3. [T8] RED: Add coverage assertions for source marker, review-resolution IDs F1/F2/W1/W2/W3/M1, SO-* anchor, implemented files, fresh proving command, and result.
4. [T8] RED: Run `bash tests/test-skill-optimizer-end-to-end.sh`; expected failures are missing e2e test target, `verification-result.schema.json`, `build_verification_result.py`, and coverage report.
5. [T8] GREEN: Create `verification-result.schema.json` and extend `field-consumers.json` for verification fields.
6. [T8] GREEN: Implement `build_verification_result.py` to aggregate schema, semantic, consumer, rendered view, eval, fresh command, coverage, and decision evidence.
7. [T8] GREEN: Create `implementation-coverage.md` from actual implementation evidence after T1-T7.
8. [T8] GREEN: Run `bash tests/test-skill-optimizer-end-to-end.sh`; expected output is PASS.
9. [T8] REFACTOR: Tighten report rendering and coverage text without changing artifact semantics; rerun `bash tests/test-skill-optimizer-end-to-end.sh`; expected output remains PASS.
10. [T8] FINAL: Run the full verification gate set below; expected output is PASS for every command.
11. [T8] FINAL: After all Task checkboxes are marked, invoke verify-change with `design.md`, `tasks.md`, `plan.md`, implementation diff, and fresh command evidence as inputs.

## Full Verification

1. [T1] Run `bash tests/test-skill-optimizer-contract.sh`.
2. [T3] Run `bash tests/test-skill-optimizer-runtime-artifacts.sh`.
3. [T6] Run `bash tests/test-skill-optimizer-evals.sh`.
4. [T7] Run `bash tests/test-skill-optimizer-migration.sh`.
5. [T8] Run `bash tests/test-skill-optimizer-end-to-end.sh`.
6. [T7] Run `bash tests/test-install-smoke.sh`.
7. [T7] Run `bash tests/test-install-systematic.sh`.
8. [T7] Run `bash tests/test-codex-skill-adapter.sh`.
9. [T7] Run `bash tests/test-runtime-integrity.sh`.
10. [T7] Run `bash tests/test-skill-context-budget.sh`.
11. [T8] Run `python3 tools/community/check_task_plan_consistency.py docs/skill-optimizer/2026-04-16-course-derived-methodology/tasks.md docs/skill-optimizer/2026-04-16-course-derived-methodology/plan.md`.
12. [T8] Run `python3 -c 'import pathlib,re,sys; pat=re.compile("\\u57fa\\u672c\\u4e0a|\\u5e94\\u8be5|\\u53ef\\u80fd|\\u5927\\u6982|\\u5dee\\u4e0d\\u591a|"+"TO"+"DO|TB"+"D"); paths=[pathlib.Path("shared/skills/skill-optimizer"), pathlib.Path("docs/skill-optimizer/2026-04-16-course-derived-methodology")]; hits=[]; [hits.append(str(p)) for root in paths if root.exists() for p in root.rglob("*") if p.is_file() and pat.search(p.read_text(encoding="utf-8", errors="ignore"))]; print("\\n".join(hits)); sys.exit(1 if hits else 0)'`.
13. [T8] Run `git diff --check`.
