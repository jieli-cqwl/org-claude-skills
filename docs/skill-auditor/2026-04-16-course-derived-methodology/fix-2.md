# Fix 2 Report

## Input

- Source report: user-provided Claude review finding for `shared/skills/skill-auditor/references/quality-dimension-mapping.md:4-8`
- Work dir: `docs/skill-auditor/2026-04-16-course-derived-methodology`
- Round: 2
- Historical fix reports read: `docs/skill-auditor/2026-04-16-course-derived-methodology/fix-1.md`

## Environment Snapshot

- Branch: `main`
- Recent commits:
  - `b0fe79c chore: remove obsolete learning notes`
  - `1e1755c feat: enable auto-invocation for small-chain workflow skills`
  - `baed964 docs: add product skill dual-axis evaluation framework design`
  - `dae2b73 refactor: rename product manager review artifact`
  - `026bb47 docs: tighten assistant config navigation`
- Related dirty scope: `shared/skills/skill-auditor/references/quality-dimension-mapping.md`, `tests/test-skill-auditor-contract.sh`
- Existing unrelated dirty scope left untouched: `shared/reference/Skill质量标准.md`, `shared/skills/scan/`, other `skill-auditor` review cleanup files, and `docs/product-skill-eval/2026-04-17/`

## Issue Diagnosis

| Issue | failure_class | Symptom | Confirmed root cause | Static trace |
| --- | --- | --- | --- | --- |
| RUNTIME_PATH_01 | FIXABLE | Runtime reference instructed the LLM to read `shared/reference/Skill质量标准.md`, which does not exist after install | `shared/skills/skill-auditor/references/quality-dimension-mapping.md:4` and `:8` used a source-tree path in a file loaded by `SKILL.md` at runtime | `tests/test-skill-auditor-contract.sh:76-78` now locks the runtime path and rejects the source path |

## Hypothesis Verification

| Hypothesis | Verification | Result |
| --- | --- | --- |
| The runtime mapping file contains a source-tree path | `sed -n '1,180p' shared/skills/skill-auditor/references/quality-dimension-mapping.md` showed `shared/reference/Skill质量标准.md` in `Read` and `Sync` | Confirmed |
| The installed runtime contains the same `shared/reference` path | Runtime layout check showed references live under `~/.codex/reference/Skill质量标准.md` and `~/.claude/reference/Skill质量标准.md`, not under `shared/reference` | Excluded |
| Existing contract tests already guarded this path | Added the assertion first and ran `bash tests/test-skill-auditor-contract.sh`; it failed with missing `{{RUNTIME_HOME}}/reference/Skill质量标准.md` | Excluded |

## N > 1 Difference

- Fix 1 handled verifier, schema, manifest, and eval execution defects.
- Fix 2 handles a runtime reference-addressing regression introduced during later review cleanup.
- This round changed the guard location from script behavior to installed-skill reference contract.

## Fix Summary

- Restored `{{RUNTIME_HOME}}/reference/Skill质量标准.md` in `quality-dimension-mapping.md` `Read` and `Sync`.
- Added a contract test that requires the runtime path and rejects `shared/reference/Skill质量标准.md` inside the mapping file.

## RED Evidence

- Command: `bash tests/test-skill-auditor-contract.sh`
- Exit: 1
- Output: `[FAIL] missing required content: {{RUNTIME_HOME}}/reference/Skill质量标准.md`

## GREEN Evidence

- `bash tests/test-skill-auditor-contract.sh`: `[PASS] skill-auditor contract`
- `rg -n -F '{{RUNTIME_HOME}}/reference/Skill质量标准.md' shared/skills/skill-auditor/references/quality-dimension-mapping.md tests/test-skill-auditor-contract.sh`: found the runtime path in mapping lines 4 and 8, and in the contract assertion
- `rg -n 'shared/reference/Skill质量标准\.md' shared/skills/skill-auditor`: no matches

## Full Regression Evidence

- `bash tests/test-skill-auditor-runtime-artifacts.sh`: `[PASS] skill-auditor runtime artifacts`
- `bash tests/test-skill-auditor-end-to-end.sh`: `[PASS] skill-auditor end-to-end`
- `bash tests/test-skill-auditor-evals.sh`: `[PASS] skill-auditor evals`
- `bash tests/test-skill-auditor-migration.sh`: `[PASS] skill-auditor migration`
- `bash tests/test-skill-quality-standard.sh`: `[PASS] skill quality standard`
- `bash tests/test-skill-context-budget.sh`: exit 0; `skill-auditor ... PASS`; existing `design` and `tech-lead` warnings are outside this fix
- `python3 -m py_compile shared/skills/skill-auditor/scripts/build_verification_result.py shared/skills/skill-auditor/scripts/validate_semantics.py`: exit 0
- `git diff --check`: exit 0
- `git diff --check --cached`: exit 0

## Four Questions

| Question | Answer |
| --- | --- |
| Root cause | `quality-dimension-mapping.md:4` and `:8` used a repository source path in a runtime-loaded reference file. |
| Fix completeness | The only runtime reference to `shared/reference/Skill质量标准.md` under `shared/skills/skill-auditor` is removed, and contract test prevents reintroduction in the mapping file. |
| New risk control | The change affects one reference file and one shell contract test; full skill-auditor regression passed. |
| Test coverage | `tests/test-skill-auditor-contract.sh:76-78` now covers the runtime path contract. |

## Impact Range

- Runtime reference touched: `shared/skills/skill-auditor/references/quality-dimension-mapping.md`
- Test touched: `tests/test-skill-auditor-contract.sh`
- External integrations touched: none
