# Skill-quality-audit Team Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `skill-quality-audit` to "usable for team Skill audits under this repository's custom team-use readiness contract" without claiming OpenAI official certification, generic Agent Skills compliance, or universal readiness for every Skill type.

**Architecture:** Fix evidence freshness and fail-closed validation first, then expand empirical samples, then tighten the Skill body and runtime integration. Deterministic checks live in schema, scripts, fixtures, tests, and gate plans; the model remains responsible only for semantic judgment, risk attribution, and repair tradeoffs.

**Tech Stack:** Markdown Skill instructions, JSON audit artifacts, Python validators, Bash contract tests, JSON fixtures, `tests/gate-plan.json`, `tests/run-focused.sh`, runtime surface contract.

---

## Current Blocking Facts

- Current formal report validation is not enough to claim readiness: `validate_skill_audit_report.py` passes for the self-audit report, but that only proves the report contract.
- Current empirical plan validation is not enough to claim readiness: `validate_empirical_baseline.py` without `--require-complete` only proves the baseline plan shape.
- Current complete empirical readiness is blocked: `validate_empirical_baseline.py --require-complete ...` fails because `RESEARCH-P1-002.evidence_checks[3]` references a stale snippet at `tests/test-research-skill-contract.sh:196`.
- Current static body/package checks warn on `COMPLEX_FLOW_UNSTRUCTURED` at `shared/skills/skill-quality-audit/SKILL.md:34`.
- Current anti-noise static check passes, but that does not prove semantic audit capability.
- `bash tests/run-focused.sh skill-quality-audit --list` is only a profile listing. It is never proof that the focused gates pass.

## Standard Source Namespace

Keep these source layers separate in every implementation, report, and readiness claim:

| Layer | What It Can Prove | What It Cannot Prove |
| --- | --- | --- |
| OpenAI Codex Skills doc | Codex Skill authoring model, `SKILL.md`, required `name`/`description`, progressive disclosure, `description` as trigger metadata. | Team-use readiness, this repo's report schema, empirical baseline, or mandatory scripts/evals/assets for all Skills. |
| Open agent skills specification | Frontmatter and portable Skill package conventions. | OpenAI official certification or this repo's custom readiness verdict. |
| This repository's custom contract | `team-use readiness`, report validator, empirical baseline, runtime surface, static body/anti-noise gates. | Generic Agent Skills compliance or readiness for all future Skill classes outside the tested boundary. |

Required readiness wording:

> This conclusion is limited to this repository's custom team-use readiness contract. It does not represent OpenAI official certification or generic Agent Skills compliance.

`scripts/`, `evals/`, `assets/`, and `agents/openai.yaml` are optional in the official Skill model. They are in scope here only because `skill-quality-audit` currently has repository consumers that depend on them.

## Completion Definition

This plan is complete only when all of these are true:

- Current stale empirical evidence is rebuilt or rejected through a fresh, consistent empirical run chain.
- `validate_empirical_baseline.py --require-complete` passes against current artifacts.
- The sample matrix covers positive, light-scan, artifact-triage, near-miss, without-skill, negative stale evidence, missing handoff, P0/P1 claim review, and repair handoff replay cases.
- Fail-closed tests reject stale evidence, missing raw output, broken formal report refs, mismatched lifecycle refs, missing E4 supports, and broken P0/P1 evidence checks.
- `COMPLEX_FLOW_UNSTRUCTURED` is resolved by a minimal flow/state table, or explicitly accepted by the owner as a non-blocking residual risk with evidence. Silent carryover is not allowed.
- Runtime/install/adapter checks align for `skill-quality-audit` only; no installer or adapter architecture rewrite is included.
- All final commands listed in "Task 8: Final Verification And Review Loops" are run fresh, with command, exit code, log path, and PASS/FAIL result recorded.
- Two consecutive review rounds find no new target-scope issue before claiming team-use readiness.

## Non-Goals

- Do not define or rewrite OpenAI official Skill standards.
- Do not turn optional official Skill directories into global requirements.
- Do not audit every Skill in the repository.
- Do not rewrite installer, runtime, orchestrator, or adapter architecture.
- Do not add schema fields, gates, or docs without a real consumer.
- Do not loosen schema, validators, fixtures, or baseline gates to get green output.
- Do not convert model semantic judgment into deterministic control flow.
- Do not fix target-outside findings discovered during review; record them as residual or follow-up only.

## File Responsibility Map

- `docs/superpowers/plans/2026-06-04--skill-quality-audit-team-readiness.md`: execution contract for this work.
- `shared/skills/skill-quality-audit/SKILL.md`: audit workflow body, hard gates, state table, output contract route.
- `shared/skills/skill-quality-audit/references/*.md`: repository-specific readiness, instruction, runtime, claim review, noise, benchmark references.
- `shared/skills/skill-quality-audit/contracts/skill-audit-report.schema.json`: JSON report structural authority.
- `shared/skills/skill-quality-audit/scripts/skill_audit_report_contract.py`: shared report validation rules.
- `shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py`: formal report validator.
- `shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py`: empirical baseline validator.
- `shared/skills/skill-quality-audit/evals/evals.json`: preference anchors and test scenarios.
- `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/**`: fresh empirical run artifacts.
- `shared/skills/skill-quality-audit/evals/lifecycle-review.json`: lifecycle evidence summary; never a source of truth unless validators can re-open the referenced artifacts.
- `tests/test-skill-quality-audit-*.sh`: package, runtime, readiness, claim review, report, validator, baseline, cleanup, and instruction contracts.
- `tests/gate-plan.json`: focused profile and gate registration.
- `contracts/skill-runtime-surface.json`: active runtime mode and execution contract.
- `install.sh` and `tools/skills/apply_skill_runtime_surface.py`: install/runtime policy application.
- `tools/skill_quality/*.py`: static package, body, and anti-noise checks.

## Task-To-Criterion Map

| Success Criterion | Tasks |
| --- | --- |
| Standard source boundaries are explicit | Task 1 |
| Fresh empirical chain replaces stale evidence | Task 2 |
| Complete empirical baseline fails closed | Task 3 |
| Sample matrix covers target behavior and negatives | Task 4 |
| Report validator rejects freshness and handoff regressions | Task 5 |
| Skill body complex-flow warning is resolved | Task 6 |
| Runtime/install/adapter surfaces are aligned | Task 7 |
| Final evidence and review loops close the readiness claim | Task 8 |

## Task 1: Add Source-Boundary And Readiness Contract

**Files:**
- Modify: `shared/skills/skill-quality-audit/references/team-use-readiness.md`
- Modify: `shared/skills/skill-quality-audit/references/runtime-integration.md`
- Modify: `shared/skills/skill-quality-audit/SKILL.md`
- Test: `tests/test-skill-quality-audit-team-readiness-contract.sh`
- Test: `tests/test-skill-quality-audit-runtime-contract.sh`

- [ ] **Step 1: Write the failing structured contract assertions**

Extend `tests/test-skill-quality-audit-team-readiness-contract.sh` with assertions that parse a machine-readable fenced block from the readiness reference instead of locking Markdown prose. This preserves the repository rule against low-signal natural-language assertions on Skill/Rule/Reference bodies.

Required test shape:

```python
match = re.search(r"```json readiness_contract\n(.*?)\n```", readiness, re.S)
require(match, "readiness reference must expose json readiness_contract")
contract = json.loads(match.group(1))

require(contract["contract_id"] == "skill-quality-audit.team-use-readiness")
require(contract["verdict_scope"] == "repository_custom_team_use_readiness")
require(contract["official_certification"] is False)
require(contract["generic_agent_skills_compliance"] is False)
require(contract["target_users"] == ["team_members"])
require(contract["target_activity"] == "audit_existing_skills")
require(contract["allowed_verdicts"] == ["fit", "conditional", "unfit", "blocked"])
require("repair_handoff" in contract["required_outputs"])
require(
    [source["id"] for source in contract["source_boundaries"]]
    == [
        "openai_codex_skills_doc",
        "open_agent_skills_specification",
        "repository_custom_contract",
    ]
)
```

The test may still check headings or fenced-block presence, but it must not assert exact explanatory prose from the Markdown body.

Run:

```bash
bash tests/test-skill-quality-audit-team-readiness-contract.sh
```

Expected: FAIL until the readiness reference carries the source-boundary wording and usable definition.

- [ ] **Step 2: Update readiness reference**

In `shared/skills/skill-quality-audit/references/team-use-readiness.md`, add a short "Source Boundary" section with this structured contract block:

````md
## Source Boundary

```json readiness_contract
{
  "contract_id": "skill-quality-audit.team-use-readiness",
  "verdict_scope": "repository_custom_team_use_readiness",
  "official_certification": false,
  "generic_agent_skills_compliance": false,
  "target_users": ["team_members"],
  "target_activity": "audit_existing_skills",
  "allowed_verdicts": ["fit", "conditional", "unfit", "blocked"],
  "required_outputs": ["formal_report", "repair_handoff", "validation_evidence"],
  "source_boundaries": [
    {
      "id": "openai_codex_skills_doc",
      "can_prove": ["codex_skill_authoring_model", "progressive_disclosure", "description_trigger_metadata"],
      "cannot_prove": ["team_use_readiness", "repository_report_schema", "mandatory_optional_directories"]
    },
    {
      "id": "open_agent_skills_specification",
      "can_prove": ["portable_skill_package_conventions"],
      "cannot_prove": ["openai_official_certification", "repository_custom_readiness"]
    },
    {
      "id": "repository_custom_contract",
      "can_prove": ["report_schema", "empirical_baseline", "runtime_surface", "static_quality_gates"],
      "cannot_prove": ["generic_agent_skills_compliance", "readiness_for_untested_skill_classes"]
    }
  ]
}
```

Below the block, explain the same boundary in human-readable prose. Tests should parse the JSON block and should not pin that prose verbatim.
````

- [ ] **Step 3: Route final verdicts through the boundary**

In `shared/skills/skill-quality-audit/SKILL.md`, update the readiness reference route so final readiness verdicts must preserve source labels and the non-certification warning.

Do not add a new reference file unless a test or downstream consumer needs it.

- [ ] **Step 4: Verify**

Run:

```bash
bash tests/test-skill-quality-audit-team-readiness-contract.sh
bash tests/test-skill-quality-audit-runtime-contract.sh
```

Expected: both pass.

## Task 2: Rebuild Fresh Empirical Baseline Chain

**Files:**
- Modify: `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/with_skill/*`
- Modify: `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/without_skill/*`
- Modify: `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/with_skill/*`
- Modify: `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/without_skill/*`
- Modify: `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/delta-review.json`
- Modify: `shared/skills/skill-quality-audit/evals/lifecycle-review.json`
- Test: `shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py`
- Test: `shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py`

- [ ] **Step 1: Prove the current failure**

Run:

```bash
python3 shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json \
  shared/skills/skill-quality-audit/evals/lifecycle-review.json \
  --require-complete
```

Expected: FAIL with the stale `RESEARCH-P1-002` evidence snippet at `tests/test-research-skill-contract.sh:196`.

- [ ] **Step 2: Create a fresh run contract**

Use one run id for all artifacts in this rebuild:

```text
run_id: 2026-06-04-sqa-fresh-baseline-001
profile: skill-quality-audit
source_boundary: repository custom team-use readiness
```

Each empirical summary must include or point to the same run id. If the existing schema does not have a run-id field, place it in `raw-output.md`, `summary.json` descriptive fields, and `delta-review.json` without changing validator-required fields. Do not add schema fields unless Task 3 first adds tests and validator support.

- [ ] **Step 3: Re-run or reconstruct with current evidence**

For each case and mode, regenerate:

```text
raw-output.md
summary.json
audit-summary.md for with_skill
skill-audit-report.json for with_skill
```

Every P0/P1 `evidence_checks` item must re-open the current file and line. For `RESEARCH-P1-002`, either:

- keep the finding only if current `path:line` evidence still supports every required claim; or
- remove/downgrade it if current files refute or no longer support the claim.

Do not keep a finding because the historical report had it.

- [ ] **Step 4: Refresh delta review and lifecycle refs**

Update `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/delta-review.json` so it covers exactly the fresh summary refs.

Update `shared/skills/skill-quality-audit/evals/lifecycle-review.json` so `evidence_refs`, capability metrics, encoded preference metrics, and human delta review point to the fresh chain.

- [ ] **Step 5: Verify the fresh reports**

Run:

```bash
python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/with_skill/skill-audit-report.json

python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/with_skill/skill-audit-report.json

python3 shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json \
  shared/skills/skill-quality-audit/evals/lifecycle-review.json \
  --require-complete
```

Expected: all pass.

## Task 3: Add Freshness And Chain-Consistency Negative Gates

**Files:**
- Modify: `shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py`
- Modify: `tests/test-skill-quality-audit-empirical-baseline-validator.sh`
- Modify: `tests/test-skill-quality-audit-empirical-baseline-contract.sh`

- [ ] **Step 1: Add red tests for stale evidence**

In `tests/test-skill-quality-audit-empirical-baseline-validator.sh`, create a temp with-skill formal report whose `evidence_checks` path/line points to an existing file but whose `expected_snippet` does not match.

The existing report validator already catches this. The empirical baseline validator must surface it through `formal_report_ref failed validate_skill_audit_report.py`.

Expected assertion shape:

```bash
if python3 "$SCRIPT" "$TMP_DIR/bad-stale-plan.json" "$TMP_DIR/lifecycle.json" --require-complete >"$TMP_DIR/bad-stale.out" 2>&1; then
  fail "stale evidence in with_skill formal report must fail complete baseline"
fi
grep -Fq "formal_report_ref failed validate_skill_audit_report.py" "$TMP_DIR/bad-stale.out" \
  || fail "stale evidence failure should identify formal_report_ref validation"
```

Run:

```bash
bash tests/test-skill-quality-audit-empirical-baseline-validator.sh
```

Expected: FAIL until the fixture and validator path prove stale evidence fail-closed.

- [ ] **Step 2: Add red tests for chain mismatch**

Add negative temp plans/lifecycles for:

```text
summary_ref not listed in lifecycle.evidence_refs
delta_review_ref mismatch between plan and lifecycle
with_skill summary formal_report_ref missing
raw_output_ref missing or empty
reviewed_cases missing one plan case
```

Every negative test must assert the failing field name appears in output.

- [ ] **Step 3: Implement minimal validator hardening**

In `validate_empirical_baseline.py`, keep existing validation structure. Add only checks needed for the red tests:

```python
def require_ref_in_lifecycle(ref: str, refs: list[Any], label: str) -> None:
    require(ref in refs, f"lifecycle.evidence_refs missing {label}: {ref}")
```

Use it in complete-mode validation for every summary ref and `delta_review_ref`. Do not add a persistent cache or external dependency.

- [ ] **Step 4: Verify**

Run:

```bash
bash tests/test-skill-quality-audit-empirical-baseline-validator.sh
bash tests/test-skill-quality-audit-empirical-baseline-contract.sh
python3 shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json \
  shared/skills/skill-quality-audit/evals/lifecycle-review.json \
  --require-complete
```

Expected: tests pass and complete validator passes on the fresh baseline.

## Task 4: Add Deterministic Sample Matrix

**Files:**
- Modify: `shared/skills/skill-quality-audit/evals/evals.json`
- Modify: `shared/skills/skill-quality-audit/test-prompts.json`
- Modify: `tests/test-skill-quality-audit-runtime-contract.sh`
- Modify: `tests/test-skill-quality-audit-empirical-baseline-contract.sh`

- [ ] **Step 1: Add red matrix requirements**

Extend the eval/runtime contract tests to require these case classes in active evals or test prompts:

```text
positive-formal-audit
light-scan-non-final
audit-artifact-triage
near-miss-should-not-trigger
without-skill-baseline
negative-stale-evidence
negative-missing-handoff
negative-p0-p1-claim-review
repair-handoff-replay
```

Each case must include or map to:

```text
target_skill_type
prompt
expected_anchors
grader_dimensions
pass_threshold
failure_blocking_level
sample_out_boundary
```

Run:

```bash
bash tests/test-skill-quality-audit-runtime-contract.sh
bash tests/test-skill-quality-audit-empirical-baseline-contract.sh
```

Expected: FAIL until eval metadata includes the sample matrix.

- [ ] **Step 2: Extend eval metadata without overclaiming**

Update `shared/skills/skill-quality-audit/evals/evals.json`.

For each new case, keep expected anchors concrete and observable. Example case shape:

```json
{
  "id": "negative-stale-evidence",
  "target_skill_type": "audit-report-fixture",
  "prompt": "Validate a skill-quality-audit report whose P1 evidence_checks cite a stale path:line snippet.",
  "expectations": [
    "Rejects the report through the validator path.",
    "Does not convert stale evidence into a readiness claim."
  ],
  "expected_anchors": ["SQA-11"],
  "grader_dimensions": ["evidence_backed_findings"],
  "pass_threshold": 1.0,
  "failure_blocking_level": "P0",
  "sample_out_boundary": "This case proves stale evidence rejection for audit reports; it does not prove all empirical samples are fresh."
}
```

If existing eval structure cannot accept new fields without breaking consumers, add a parallel `sample_matrix` object and update tests to read that object. Do not silently add fields that active readers reject.

- [ ] **Step 3: Update test prompts**

Add prompts that exercise:

```text
near-miss should-not-trigger language
negative stale evidence fixture
repair handoff replay
```

The prompts must not say or imply that `skill-quality-audit` should auto-invoke; runtime remains manual.

- [ ] **Step 4: Verify**

Run:

```bash
bash tests/test-skill-quality-audit-runtime-contract.sh
bash tests/test-skill-quality-audit-empirical-baseline-contract.sh
```

Expected: both pass.

## Task 5: Harden Formal Report Validator Regressions

**Files:**
- Modify: `shared/skills/skill-quality-audit/scripts/skill_audit_report_contract.py`
- Modify: `shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py`
- Modify: `tests/test-skill-quality-audit-report-contract.sh`
- Modify: `tests/test-skill-quality-audit-validator-hardening.sh`
- Modify fixtures under `tests/fixtures/skill-quality-audit/reports/` only when a test owns the fixture.

- [ ] **Step 1: Add red tests for summary handoff integrity**

Add negative cases proving:

```text
P0/P1 finding is absent from summary
summary omits evidence_checks path:line
summary omits repair_target
summary omits verification_hint
```

Use temp copies of existing valid fixtures rather than mutating committed valid fixtures.

- [ ] **Step 2: Add red tests for E4 support**

Create a temp report with one dimension set to `E4` and no matching PASS `executed_verification.supports`.

Expected failure:

```text
E4 evidence requires matching PASS executed_verification supports
```

- [ ] **Step 3: Keep validator changes minimal**

If current validator already catches the red cases, keep implementation unchanged and treat the task as proof hardening. If it misses a case, add the smallest check in `skill_audit_report_contract.py` or `validate_skill_audit_report.py`.

Do not weaken the validator to accommodate old dogfood artifacts. Refresh the artifacts instead.

- [ ] **Step 4: Verify**

Run:

```bash
bash tests/test-skill-quality-audit-report-contract.sh
bash tests/test-skill-quality-audit-validator-hardening.sh
```

Expected: both pass.

## Task 6: Resolve `COMPLEX_FLOW_UNSTRUCTURED`

**Files:**
- Modify: `shared/skills/skill-quality-audit/SKILL.md`
- Test: `python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit/SKILL.md`
- Test: `python3 tools/skill_quality/check_skill_package_quality.py shared/skills/skill-quality-audit`
- Test: `python3 tools/skill_quality/check_skill_anti_noise.py --path shared/skills/skill-quality-audit`

- [ ] **Step 1: Prove current warning**

Run:

```bash
python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit/SKILL.md
```

Expected: `static_warn` with `COMPLEX_FLOW_UNSTRUCTURED` at `shared/skills/skill-quality-audit/SKILL.md:34`.

- [ ] **Step 2: Add minimal state table**

Add a compact state table near the `Audit Run` section. It must cover:

```md
| State | Entry Condition | Required Action | Output | Stop / Failure Exit |
| --- | --- | --- | --- | --- |
| classify existing artifact | Input path is an audit artifact | Run classifier, then validate only formal JSON | artifact_type or validator result | Transcript/recap becomes lead only; no verdict |
| light scan | User explicitly asks quick/non-final | Return candidate risks only | Non-final risk list | No severity, readiness, JSON, or validator claim |
| default formal audit | Target Skill is provided and no light-scan request | Collect scope, write report/summary, run validator | JSON report, summary, validation output | Block if scope missing or validator fails |
| missing output parent | User supplied missing parent dir | Fall back to `/tmp` and record fallback | Safe artifact paths | Do not ask user to rerun only for paths |
| P0/P1 candidate | Finding may affect team use/runtime/output/validation/handoff | Run claim review and severity calibration | Supported finding or deletion/downgrade | Refuted/blocked finding cannot enter final P0/P1 |
```

Keep it short. Do not add a new reference unless this table becomes too large.

- [ ] **Step 3: Verify static checks**

Run:

```bash
python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit/SKILL.md
python3 tools/skill_quality/check_skill_package_quality.py shared/skills/skill-quality-audit
python3 tools/skill_quality/check_skill_anti_noise.py --path shared/skills/skill-quality-audit
```

Expected: body/package no longer emit `COMPLEX_FLOW_UNSTRUCTURED`; anti-noise remains `static_pass`.

If the warning remains, do not claim readiness. Either improve the table or record explicit owner acceptance as residual risk after proving it does not affect the audit path.

## Task 7: Recheck Runtime, Install, And Adapter Surface

**Files:**
- Inspect only unless tests fail:
  - `contracts/skill-runtime-surface.json`
  - `shared/skills/skill-quality-audit/agents/openai.yaml`
  - `install.sh`
  - `tools/skills/apply_skill_runtime_surface.py`
  - `tests/test-skill-quality-audit-runtime-contract.sh`
  - `tests/test-skill-quality-audit-old-refiner-cleanup.sh`
  - `tests/test-install-runtime.sh`
  - `tests/test-install-runtime-smoke.sh`
  - `tests/test-install-runtime-quick-canary.sh`

- [ ] **Step 1: Run focused runtime checks**

Run:

```bash
bash tests/run-focused.sh install-runtime
bash tests/run-focused.sh codex-runtime
bash tests/test-skill-quality-audit-runtime-contract.sh
bash tests/test-skill-quality-audit-old-refiner-cleanup.sh
```

Expected: all pass.

- [ ] **Step 2: Run install dry-run**

Run:

```bash
bash install.sh --target all --dry-run
```

Expected: exits 0 and reports only dry-run planned writes. It must not mutate runtime.

- [ ] **Step 3: Fix only target-scope failures**

If a failure is specific to `skill-quality-audit`, make the smallest change in the owning file. If the failure is broader installer/runtime architecture, stop and report out-of-scope unless the user expands scope.

- [ ] **Step 4: Verify**

Run the commands from Steps 1 and 2 again.

Expected: all pass.

## Task 8: Final Verification And Review Loops

**Files:**
- Modify only if previous tasks reveal target-scope failures.
- Record logs under a task-appropriate location only if the repository already has an active log convention for this workstream. Otherwise record command, exit code, and key output in the final handoff.

- [ ] **Step 1: Run final validators**

Run:

```bash
python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py \
  shared/skills/skill-quality-audit/evals/dogfood/self-audit/skill-audit-report.json

python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/with_skill/skill-audit-report.json

python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/with_skill/skill-audit-report.json

python3 shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json \
  shared/skills/skill-quality-audit/evals/lifecycle-review.json

python3 shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py \
  shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json \
  shared/skills/skill-quality-audit/evals/lifecycle-review.json \
  --require-complete
```

Expected: all pass.

- [ ] **Step 2: Run package/static gates**

Run:

```bash
python3 tools/skill_quality/check_skill_package_quality.py shared/skills/skill-quality-audit
python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit
python3 tools/skill_quality/check_skill_anti_noise.py --path shared/skills/skill-quality-audit
```

Expected: no blocking failure. `COMPLEX_FLOW_UNSTRUCTURED` must be gone or explicitly accepted as residual risk with owner evidence.

- [ ] **Step 3: Run focused and install gates**

Run:

```bash
bash tests/run-focused.sh skill-quality-audit
bash tests/run-focused.sh install-runtime
bash tests/run-focused.sh codex-runtime
bash install.sh --target all --dry-run
```

Expected: all pass. `--list` output is not acceptable evidence.

- [ ] **Step 4: Run quick and full gates**

Run:

```bash
bash tests/run-all.sh --quick
bash tests/run-all.sh
```

Expected: both pass, or any failure is reported with target-scope classification. Do not use full green to claim readiness beyond the `skill-quality-audit` team-use audit boundary.

- [ ] **Step 5: Run review loop 1**

Before the review, restate:

```text
Goal: team-use readiness for skill-quality-audit under this repository's custom contract.
Success standard: current validators, empirical complete gate, runtime/install gates, quick/full gates, and repair handoff evidence pass.
Scope: skill-quality-audit package, validators, eval artifacts, tests, runtime surface consumers.
Known non-goals: no official certification claim, no all-Skill readiness claim, no installer/runtime rewrite.
Evidence: list command, exit code, key PASS output, and artifact refs.
Risk: stale evidence, sample overclaim, static warning, runtime drift, lifecycle mismatch.
```

Fix only target-scope issues with direct evidence.

- [ ] **Step 6: Run review loop 2**

Repeat the same review after loop 1 fixes. If no new target-scope issue appears, readiness may be claimed with this exact wording:

```text
skill-quality-audit is ready for team Skill audits under this repository's custom team-use readiness contract.
This does not represent OpenAI official certification, generic Agent Skills compliance, or readiness for every Skill type outside the tested boundary.
```

If a new target-scope issue appears, fix it and restart the two-round count.

## Execution Notes

- Use `PYTHONDONTWRITEBYTECODE=1` for Python verification commands when the run should avoid `.pyc` churn.
- Do not use historical audit/self-audit/lifecycle claims as current facts unless current validators re-open their referenced files and pass.
- Keep each implementation task in a focused commit if the user asks for commits. Do not commit without explicit approval.
- Do not stage unrelated dirty files. Before any commit, inspect `git status --short` and `git diff`.
