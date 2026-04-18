# Fix 1 Report

## Input

- Source report: `docs/skill-auditor/2026-04-16-course-derived-methodology/code-review-report.md`
- Work dir: `docs/skill-auditor/2026-04-16-course-derived-methodology`
- Round: 1
- Historical fix reports: none

## Environment Snapshot

- Branch: `main`
- Recent commits:
  - `026bb47 docs: tighten assistant config navigation`
  - `0d92452 docs: incorporate internal skill optimizer review`
  - `c31c59e docs: align skill optimizer design with source notes`
  - `136eee5 docs: expand skill optimizer source notes`
  - `aeff7b9 docs: add skill optimizer course source notes`
- Related dirty scope: `shared/skills/skill-auditor/`, `tests/test-skill-auditor-*.sh`, `tests/fixtures/skill-auditor/`, `docs/skill-auditor/2026-04-16-course-derived-methodology/`
- Unrelated existing dirty scope left untouched: `docs/角色拆分 copy.md`, `docs/学以致用 Copy.md`

## Issue Diagnosis

| Issue | failure_class | Symptom | Confirmed root cause | Static trace |
| --- | --- | --- | --- | --- |
| REVIEW_A_01 | FIXABLE | `build_verification_result.py` emitted `verified` for invalid audit input | `build()` loaded upstream JSON and emitted PASS without validating artifact type, status, evidence, rendered views, or command provenance | `build()` calls now pass through `validate_audit_artifact`, `validate_plan_artifact`, `validate_eval_artifact`, and `validate_fresh_commands` at `shared/skills/skill-auditor/scripts/build_verification_result.py:183` |
| REVIEW_A_02 | FIXABLE | Repo-relative `run_evals.py` invocation failed inside manifest command execution | `run_manifest_command()` built a relative `script_path`, then changed `cwd`, duplicating the path | `build_results()` resolves `dataset_path` and `manifest_path` at `shared/skills/skill-auditor/scripts/run_evals.py:233`; `run_manifest_command()` resolves confined script paths at line 143 |
| REVIEW_A_03 | FIXABLE | `validate_schema.py` accepted `decision: {}` and `fresh_commands: []` | Validator checked top-level shape only; schema had no nested required fields for verification-result | `validate()` now delegates to recursive `validate_value()` at `shared/skills/skill-auditor/scripts/validate_schema.py:84`; nested schema lives in `shared/skills/skill-auditor/schemas/verification-result.schema.json` |
| REVIEW_B_01 | FIXABLE | Manifest accepted `../../escape.py` and `rm -rf /` as contract content | `validate_script()` only checked nonempty strings for `path` and `verification_command` | `validate_verification_command()` and `validate_script_path()` enforce command policy and scripts-dir confinement at `shared/skills/skill-auditor/scripts/validate_manifest.py:89` |
| REVIEW_B_02 | FIXABLE | Eval dataset self-reported `observed_decision` | Runner compared two static dataset fields instead of deriving observed output | `DECISION_BY_CATEGORY` and `run_case()` derive observed decisions at `shared/skills/skill-auditor/scripts/run_evals.py:15` and line 208 |

## Hypothesis Verification

| Issue | Hypothesis | Verification | Result |
| --- | --- | --- | --- |
| REVIEW_A_01 | Upstream validation is absent in aggregation | Mutated audit artifact still reached PASS in the original review report; added invalid audit and invalid plan e2e regression | Confirmed |
| REVIEW_A_01 | Coverage token check alone caused the false confidence | Added fake fresh command regression against coverage evidence | Confirmed |
| REVIEW_A_02 | Failure comes from relative path plus changed `cwd` | Original review report reproduced `command exit 2` with repo-relative CLI paths | Confirmed |
| REVIEW_A_02 | Manifest command itself was invalid | Absolute-path eval run passed before this fix, so command definition was valid | Excluded |
| REVIEW_A_03 | Schema file lacked nested contract requirements | Mutated `verification-result.json` passed before recursive validator and nested schema update | Confirmed |
| REVIEW_A_03 | Consumer validation covered the same contract | Consumer validation only tracks declared field consumers, not nested shape | Excluded |
| REVIEW_B_01 | Path confinement was not validated | `path-escape.json` passed before path confinement checks | Confirmed |
| REVIEW_B_01 | Verification command policy was not validated | `bad-verification-command.json` passed before command policy checks | Confirmed |
| REVIEW_B_02 | Dataset was carrying the runner result | Dataset cases contained `observed_decision` beside `expected_decision` | Confirmed |
| REVIEW_B_02 | Manifest command evidence was the source of eval PASS | Fixture cases without manifest commands also passed from static decision comparison | Excluded |

## Fix Summary

- Added RED regressions in `tests/test-skill-auditor-evals.sh`, `tests/test-skill-auditor-runtime-artifacts.sh`, and `tests/test-skill-auditor-end-to-end.sh`.
- Removed `observed_decision` from eval datasets and negative eval fixtures.
- Made `run_evals.py` derive observed decisions and resolve manifest/script paths to absolute confined paths.
- Made `validate_manifest.py` enforce scripts-dir confinement and `bash tests/test-skill-auditor-*.sh` proof command policy.
- Made `validate_schema.py` recursively validate the local schema subset.
- Expanded `verification-result.schema.json` with nested required fields, nonempty arrays, PASS result contracts, eval summary contract, coverage contract, and decision contract.
- Made `build_verification_result.py` validate upstream audit, plan, eval, rendered view freshness, and fresh command coverage evidence before emitting `verified`.
- Added manifest negative fixtures for path escape and unsafe verification command.

## RED Evidence

- `bash tests/test-skill-auditor-evals.sh`
  - Exit: 1
  - Output: `trigger-existing-skill-audit forbidden fields: ['observed_decision']`
- `bash tests/test-skill-auditor-runtime-artifacts.sh`
  - Exit: 1
  - Output: `[FAIL] manifest path escape unexpectedly passed`
- `bash tests/test-skill-auditor-end-to-end.sh`
  - Exit: 1
  - Output: `[FAIL] invalid verification-result nested contract unexpectedly passed`
- Review report prior reproduction for `REVIEW_A_02`
  - Command: `python3 shared/skills/skill-auditor/scripts/run_evals.py shared/skills/skill-auditor/evals/evals.json shared/skills/skill-auditor/scripts/manifest.json --out <tmp>`
  - Output: `permission-denied-audit-write command exit 2, expected 0`

## GREEN Evidence

- `bash tests/test-skill-auditor-evals.sh`: `[PASS] skill-auditor evals`
- `bash tests/test-skill-auditor-runtime-artifacts.sh`: `[PASS] skill-auditor runtime artifacts`
- `bash tests/test-skill-auditor-end-to-end.sh`: `[PASS] skill-auditor end-to-end`

## Full Regression Evidence

- `bash tests/test-skill-auditor-contract.sh`: exit 0
- `bash tests/test-skill-auditor-migration.sh`: `[PASS] skill-auditor migration`
- `bash tests/test-install-smoke.sh`: `[PASS] install/uninstall smoke`
- `bash tests/test-install-systematic.sh`: `Systematic tests passed: 19, skipped: 0`
- `bash tests/test-codex-skill-adapter.sh`: `[PASS] codex skill adapter`
- `bash tests/test-runtime-integrity.sh`: `[PASS] runtime integrity`
- `bash tests/test-skill-context-budget.sh`: exit 0; `skill-auditor ... PASS`; existing `design` and `tech-lead` WARN retained outside this change scope
- `python3 tools/community/check_task_plan_consistency.py docs/skill-auditor/2026-04-16-course-derived-methodology/tasks.md docs/skill-auditor/2026-04-16-course-derived-methodology/plan.md`: `[PASS] tasks-plan consistency (8 tasks, 86 plan steps)`
- `python3 -m py_compile shared/skills/skill-auditor/scripts/run_evals.py shared/skills/skill-auditor/scripts/validate_manifest.py shared/skills/skill-auditor/scripts/validate_schema.py shared/skills/skill-auditor/scripts/build_verification_result.py`: exit 0
- Banned token scan for `shared/skills/skill-auditor` and the phase doc dir: exit 0
- `git diff --check`: exit 0

## Four Questions

| Issue | Root cause | Coverage completeness | New risk control | Test added |
| --- | --- | --- | --- | --- |
| REVIEW_A_01 | Aggregator trusted upstream artifacts | Covers invalid audit, invalid plan, fake fresh command, eval summary validation | Aggregator now fails closed before writing verification result | End-to-end negative checks |
| REVIEW_A_02 | Relative paths were reused after `cwd` changed | Covers repo-relative CLI invocation | Paths resolve before subprocess launch; script path is confined | Eval relative-path regression |
| REVIEW_A_03 | Schema validation was shallow | Covers empty decision and empty fresh commands | Recursive validator plus nested verification schema | End-to-end nested schema mutation |
| REVIEW_B_01 | Manifest contract lacked path and command policy | Covers path escape and unsafe command text | Path normalization and proof command allowlist | Runtime artifact negative fixtures |
| REVIEW_B_02 | Dataset self-reported observed output | Covers forbidden dataset field and derived result output | Runner-owned decision derivation | Eval dataset lint and result assertion |

## Impact Range

- Runtime scripts touched: eval runner, manifest validator, schema validator, verification-result builder.
- Runtime schemas touched: verification-result schema only.
- Test surface touched: skill-auditor eval, runtime artifact, and end-to-end gates.
- Data touched: eval dataset and eval negative fixtures.
- External integration touched: none.
