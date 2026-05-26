# Skill Quality Audit Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire active `skill-refiner` and replace it with `skill-quality-audit`, a read-only Skill QA capability that audits existing Skills, scores them with evidence, and hands off precise repair targets without modifying target files.

**Architecture:** Build a new first-party skill package from the useful audit standards in `skill-refiner`, but do not inherit its modification workflow, ledgers, result schema, or historical dogfood baggage. Keep semantic audit guidance in the new Skill and references; keep deterministic report validation in scripts/schema; keep installation and runtime routing in existing contracts and gates.

**Tech Stack:** Markdown Skill package, JSON Schema-compatible Python validator, Bash regression tests, existing `tools/skill_quality/*` static checkers, `contracts/skill-runtime-surface.json`, `install.sh`, `tests/gate-plan.json`, and `tests/run-all.sh`.

---

## Success Criteria

- `shared/skills/skill-quality-audit/SKILL.md` exists and is the active first-party skill quality audit entry.
- `skill-quality-audit` is read-only at runtime: no `Write`, `Edit`, or target-modification authority in frontmatter, flow, report fields, or eval expectations.
- Active `skill-refiner` runtime entry is removed: no active install/runtime/gate/test path requires `shared/skills/skill-refiner`.
- No active test, gate, runtime, README, or `shared/skills/*/evals/**` path keeps retired `skill-refiner` names as current truth; no `tests/fixtures/skill-auditor/**` residue remains.
- Reusable audit standards are migrated, rewritten, or referenced under `skill-quality-audit`; old modification-only assets are not carried forward.
- The new audit report contract uses 10-point dimension scoring, severity (`P0` to `P3`), evidence levels (`E0` to `E4`), and repair handoff fields.
- `Instruction Contract` is a first-class audit dimension with sentence-level and keyword-level review rules.
- `Benchmark Mechanism Alignment` is supported without requiring target skills to imitate `brainstorming` text or structure.
- Every P0/P1 finding in sample reports has `evidence`, `impact`, `repair_target`, and `verification_hint`.
- `Instruction Contract < 7` caps overall verdict at `conditional`; `< 5` forces `unfit`.
- Focused tests prove schema validation, read-only runtime surface, old active reference cleanup, and report quality.
- `bash tests/run-all.sh --quick` passes after targeted tests pass.

## Non-Goals

- Do not implement a target Skill modifier in `skill-quality-audit`.
- Do not keep `skill-refiner` as an alias, compatibility entry, or parallel active skill.
- Do not bulk-edit historical `tools/eval/results/**` or `docs/reports/**` snapshots unless an active test/runtime path consumes them.
- Do not convert every old `skill-refiner` dogfood output into new fixtures.
- Do not give score-only verdicts without evidence-backed findings.
- Do not require every target Skill to look like `brainstorming`; only compare mechanism quality.
- Do not touch the standard-chain field-contract cleanup files from the separate active window unless a direct conflict blocks this plan.

## Concurrency Note

Before implementation, run `git status --short`. At the time this plan was written, another window had changes in shared files including `install.sh`, `tests/gate-plan.json`, `tests/run-all.sh`, and standard-chain contracts. If those files are still dirty, either execute this plan after that work lands or merge carefully from the current working tree. Do not overwrite unrelated changes.

## File Map

**Create**
- `shared/skills/skill-quality-audit/SKILL.md` - read-only Skill QA entry.
- `shared/skills/skill-quality-audit/agents/openai.yaml` - Codex manual-only adapter policy.
- `shared/skills/skill-quality-audit/references/audit-dimensions.md` - canonical dimensions, weights, score anchors, verdict rules.
- `shared/skills/skill-quality-audit/references/instruction-contract.md` - sentence and keyword audit method.
- `shared/skills/skill-quality-audit/references/benchmark-mechanism-alignment.md` - how to extract mechanisms from strong Skills such as `brainstorming`.
- `shared/skills/skill-quality-audit/references/noise-taxonomy.md` - migrated and tightened noise rules.
- `shared/skills/skill-quality-audit/references/runtime-integration.md` - runtime surface and active reference audit guidance.
- `shared/skills/skill-quality-audit/contracts/skill-audit-report.schema.json` - machine-readable report contract.
- `shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py` - validates audit report JSON.
- `shared/skills/skill-quality-audit/test-prompts.json` - pressure prompts for the new skill.
- `shared/skills/skill-quality-audit/evals/evals.json` - eval metadata for read-only audit behavior.
- `shared/skills/skill-quality-audit/evals/fixtures/*` - small target Skill fixtures.
- `tests/test-skill-quality-audit-report-contract.sh` - validates report schema and negative fixtures.
- `tests/test-skill-quality-audit-runtime-contract.sh` - validates read-only package and active routing.
- `tests/test-skill-quality-audit-old-refiner-cleanup.sh` - validates active `skill-refiner` removal.
- `tests/test-skill-quality-audit-instruction-contract.sh` - validates instruction contract fixtures.

**Modify**
- `contracts/skill-runtime-surface.json` - add `skill-quality-audit`; remove `skill-refiner`.
- `README.md` - point Skill quality guidance to `skill-quality-audit`.
- `install.sh` - require `skill-quality-audit` in the Claude and Codex runtime quick checks that explicitly enumerate first-party shared skills; keep retired `skill-auditor` absent.
- `tests/run-all.sh` - remove `skill-refiner` syntax/py_compile entries; add new validator/test entries.
- `tests/gate-plan.json` - replace `skill-refiner` profile/area tests with `skill-quality-audit`.
- `tests/run-focused.sh` - replace focused profile text and area routing.
- `contracts/episode-package.schema.json` - replace active enum/reference if it still lists `skill-refiner`.
- `tools/skill_quality/check_skill_body_quality.py` - only if deterministic instruction-signal checks need to recognize new fixtures or terms.
- `tools/skill_quality/manifest.json` - only if a new deterministic checker is added.
- Active tests under `tests/*skill-refiner*.sh` - delete, replace, or rewrite as new `skill-quality-audit` tests.
- Active research/product/design eval references that still use `skill-refiner` as the audit contract - rename, rewrite, or delete according to whether they remain current evidence.

**Delete after migration**
- `shared/skills/skill-refiner/` active package.
- Active `skill-refiner` gate-plan entries and run-all references.
- Unconsumed root artifacts such as `skill-refiner-result.json` and `refinement-ledger.json` if no active consumer remains.
- `tests/fixtures/skill-auditor/**` entries that are not migrated to `tests/fixtures/skill-quality-audit/**`.

---

### Task 1: Add Failing Contract Tests For The New Audit Skill

**Files:**
- Create: `tests/test-skill-quality-audit-report-contract.sh`
- Create: `tests/test-skill-quality-audit-runtime-contract.sh`
- Create: `tests/test-skill-quality-audit-old-refiner-cleanup.sh`
- Create: `tests/test-skill-quality-audit-instruction-contract.sh`
- Create: `tests/fixtures/skill-quality-audit/reports/valid-report.json`
- Create: `tests/fixtures/skill-quality-audit/reports/p1-missing-repair-target.json`
- Create: `tests/fixtures/skill-quality-audit/reports/instruction-low-score-invalid-verdict.json`

- [ ] **Step 1: Write the report contract test**

Create `tests/test-skill-quality-audit-report-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py"
VALID="$ROOT/tests/fixtures/skill-quality-audit/reports/valid-report.json"
MISSING_REPAIR="$ROOT/tests/fixtures/skill-quality-audit/reports/p1-missing-repair-target.json"
BAD_VERDICT="$ROOT/tests/fixtures/skill-quality-audit/reports/instruction-low-score-invalid-verdict.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$VALIDATOR" ] || fail "missing validate_skill_audit_report.py"
[ -f "$VALID" ] || fail "missing valid report fixture"

python3 "$VALIDATOR" "$VALID"

if python3 "$VALIDATOR" "$MISSING_REPAIR" >/tmp/skill-quality-audit-missing-repair.out 2>&1; then
  fail "P1 finding without repair_target must fail"
fi
grep -Fq "repair_target" /tmp/skill-quality-audit-missing-repair.out \
  || fail "missing repair_target failure should be explicit"

if python3 "$VALIDATOR" "$BAD_VERDICT" >/tmp/skill-quality-audit-bad-verdict.out 2>&1; then
  fail "Instruction Contract score below 5 must force unfit"
fi
grep -Fq "Instruction Contract" /tmp/skill-quality-audit-bad-verdict.out \
  || fail "bad verdict failure should mention Instruction Contract"

printf '[PASS] skill-quality-audit report contract\n'
```

- [ ] **Step 2: Write the runtime contract test**

Create `tests/test-skill-quality-audit-runtime-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-quality-audit/SKILL.md"
AGENT="$ROOT/shared/skills/skill-quality-audit/agents/openai.yaml"
SURFACE="$ROOT/contracts/skill-runtime-surface.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SKILL" ] || fail "missing skill-quality-audit SKILL.md"
[ -f "$AGENT" ] || fail "missing skill-quality-audit agents/openai.yaml"

grep -q '^name: skill-quality-audit$' "$SKILL" \
  || fail "skill name must be skill-quality-audit"
grep -q '^description: "Use when ' "$SKILL" \
  || fail "description must describe trigger conditions"
! grep -Eiq '^description:.*(audits|scores|reports|workflow|five-step|评分|审查流程)' "$SKILL" \
  || fail "description must not summarize workflow"
grep -q '^allowed-tools: Read, Glob, Grep, Bash$' "$SKILL" \
  || fail "skill-quality-audit must be read-only"
! grep -Eq 'allowed-tools:.*(Write|Edit|MultiEdit)' "$SKILL" \
  || fail "skill-quality-audit must not have write/edit tools"
! grep -Eiq 'modify target|edit target|rewrite target|execute remediation|执行落地|策略制定后.*修改' "$SKILL" \
  || fail "skill-quality-audit must not claim modification authority"
grep -Fq 'allow_implicit_invocation: false' "$AGENT" \
  || fail "skill-quality-audit must disable implicit invocation for Codex"

python3 - "$SURFACE" <<'PY'
import json
import sys
from pathlib import Path

surface = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
skills = surface["skills"]
if "skill-quality-audit" not in skills:
    raise SystemExit("skill-quality-audit missing from runtime surface")
entry = skills["skill-quality-audit"]
if entry.get("mode") != "manual":
    raise SystemExit("skill-quality-audit must be manual")
if entry.get("owner") != "first-party":
    raise SystemExit("skill-quality-audit owner must be first-party")
if "skill-refiner" in skills:
    raise SystemExit("skill-refiner must not remain in runtime surface")
PY

printf '[PASS] skill-quality-audit runtime contract\n'
```

- [ ] **Step 3: Write the old refiner cleanup test**

Create `tests/test-skill-quality-audit-old-refiner-cleanup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ ! -e "$ROOT/shared/skills/skill-refiner" ] \
  || fail "active shared/skills/skill-refiner must be removed"
[ ! -e "$ROOT/tests/fixtures/skill-auditor" ] \
  || fail "retired tests/fixtures/skill-auditor must be removed or migrated"

ACTIVE_PATHS=(
  "$ROOT/README.md"
  "$ROOT/contracts"
  "$ROOT/install.sh"
  "$ROOT/tests"
  "$ROOT/shared/skills"
  "$ROOT/tests/gate-plan.json"
  "$ROOT/tests/run-all.sh"
  "$ROOT/tests/run-focused.sh"
)

if rg -n 'skill-refiner|skill-refiner-result|refinement-ledger|validate_refinement_result' "${ACTIVE_PATHS[@]}" \
  --glob '!tests/test-skill-quality-audit-*.sh' \
  --glob '!tests/fixtures/skill-quality-audit/**' \
  --glob '!docs/reports/**' \
  --glob '!tools/eval/results/**'; then
  fail "active references to retired skill-refiner remain"
fi

printf '[PASS] skill-quality-audit old refiner cleanup\n'
```

- [ ] **Step 4: Write the instruction contract test**

Create `tests/test-skill-quality-audit-instruction-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-quality-audit/SKILL.md"
INSTRUCTION_REF="$ROOT/shared/skills/skill-quality-audit/references/instruction-contract.md"
REPORT_REF="$ROOT/shared/skills/skill-quality-audit/references/audit-dimensions.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

grep -Fq 'Instruction Contract' "$SKILL" \
  || fail "SKILL.md must make Instruction Contract a first-class dimension"
grep -Fq 'sentence-level' "$INSTRUCTION_REF" \
  || fail "instruction contract reference must define sentence-level audit"
grep -Fq 'keyword-level' "$INSTRUCTION_REF" \
  || fail "instruction contract reference must define keyword-level audit"
grep -Fq 'Trigger' "$INSTRUCTION_REF" \
  || fail "instruction sentence categories must include Trigger"
grep -Fq 'Action' "$INSTRUCTION_REF" \
  || fail "instruction sentence categories must include Action"
grep -Fq 'Gate' "$INSTRUCTION_REF" \
  || fail "instruction sentence categories must include Gate"
grep -Fq 'repair_target' "$REPORT_REF" \
  || fail "audit dimensions must require repair_target"
grep -Fq 'Instruction Contract < 7' "$REPORT_REF" \
  || fail "audit dimensions must encode Instruction Contract verdict cap"

printf '[PASS] skill-quality-audit instruction contract\n'
```

- [ ] **Step 5: Create minimal report fixtures**

Create `tests/fixtures/skill-quality-audit/reports/valid-report.json` with:

```json
{
  "artifact_type": "skill-audit-report",
  "schema_version": "1.0.0",
  "target": {
    "skill_name": "minimal-good",
    "path": "tests/fixtures/skill-quality-audit/target-skills/minimal-good"
  },
  "audit_scope": {
    "included": ["SKILL.md"],
    "excluded": []
  },
  "evidence_sources": [
    {
      "id": "ev-skill-md",
      "level": "E2",
      "path": "tests/fixtures/skill-quality-audit/target-skills/minimal-good/SKILL.md",
      "summary": "Target SKILL.md and runtime metadata were read."
    }
  ],
  "overall_verdict": "conditional",
  "overall_score": 7,
  "dimension_scores": [
    {
      "dimension": "Instruction Contract",
      "score": 7,
      "rationale": "Main flow has executable actions but failure handling is thin.",
      "evidence_refs": ["ev-skill-md"]
    }
  ],
  "findings": [
    {
      "id": "F-001",
      "severity": "P2",
      "dimension": "Instruction Contract",
      "evidence_level": "E2",
      "evidence": "Completion step says return structured evidence without required fields.",
      "impact": "Modifier does not know which output fields to preserve.",
      "repair_target": "Define required report fields and blocked state.",
      "verification_hint": "Run validate_skill_audit_report.py against a sample report."
    }
  ],
  "missing_evidence": [],
  "repair_backlog": [
    {
      "finding_id": "F-001",
      "owner": "skill-modifier",
      "target_state": "Output contract names required fields and validator command."
    }
  ]
}
```

Create negative fixtures by copying the valid fixture and:

- In `p1-missing-repair-target.json`, set `findings[0].severity` to `P1` and remove `repair_target`.
- In `instruction-low-score-invalid-verdict.json`, set `dimension_scores[0].score` to `4` and keep `overall_verdict` as `conditional`.

- [ ] **Step 6: Run the failing tests**

Run:

```bash
bash tests/test-skill-quality-audit-report-contract.sh
bash tests/test-skill-quality-audit-runtime-contract.sh
bash tests/test-skill-quality-audit-old-refiner-cleanup.sh
bash tests/test-skill-quality-audit-instruction-contract.sh
```

Expected: all fail because the new skill package and validator do not exist yet.

---

### Task 2: Implement The Audit Report Contract And Validator

**Files:**
- Create: `shared/skills/skill-quality-audit/contracts/skill-audit-report.schema.json`
- Create: `shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py`
- Modify: `tests/fixtures/skill-quality-audit/reports/*.json`

- [ ] **Step 1: Create the JSON schema**

Create `shared/skills/skill-quality-audit/contracts/skill-audit-report.schema.json` with these top-level required fields:

```json
[
  "artifact_type",
  "schema_version",
  "target",
  "audit_scope",
  "evidence_sources",
  "overall_verdict",
  "overall_score",
  "dimension_scores",
  "findings",
  "missing_evidence",
  "repair_backlog"
]
```

Use these enums:

```json
{
  "overall_verdict": ["fit", "conditional", "unfit", "blocked"],
  "severity": ["P0", "P1", "P2", "P3"],
  "evidence_level": ["E0", "E1", "E2", "E3", "E4"],
  "dimension": [
    "Reachability",
    "Trigger",
    "Scenario Value",
    "Responsibility",
    "Input Contract",
    "Output Contract",
    "Field Contract",
    "Instruction Contract",
    "Flow And Gates",
    "Resource Layering",
    "Determinism",
    "Evidence",
    "Benchmark Mechanism Alignment"
  ]
}
```

- [ ] **Step 2: Implement the Python validator**

Create `shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py`.

Required behavior:

- Parse one JSON file path argument.
- Require `artifact_type == "skill-audit-report"`.
- Require `schema_version == "1.0.0"`.
- Require `overall_score` and every dimension score to be integers from 0 to 10.
- Require every P0/P1/P2 finding to include non-empty `evidence`, `impact`, `repair_target`, and `verification_hint`.
- Require P0/P1 findings to use `evidence_level` of at least `E2`, otherwise fail with `P0/P1 findings require evidence level E2 or higher`.
- If any finding has `severity == "P0"`, require `overall_verdict` to be `blocked` or `unfit`.
- If `Instruction Contract` score is below 7, forbid `overall_verdict == "fit"`.
- If `Instruction Contract` score is below 5, require `overall_verdict == "unfit"` or `blocked`.
- Reject unknown dimensions, severities, evidence levels, and extra top-level fields.
- Print `[PASS] skill audit report valid: <path>` on success.

- [ ] **Step 3: Verify validator behavior**

Run:

```bash
python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py tests/fixtures/skill-quality-audit/reports/valid-report.json
bash tests/test-skill-quality-audit-report-contract.sh
python3 -m py_compile shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py
```

Expected: all pass after Task 2.

---

### Task 3: Build The Read-Only Skill Package

**Files:**
- Create: `shared/skills/skill-quality-audit/SKILL.md`
- Create: `shared/skills/skill-quality-audit/agents/openai.yaml`
- Create: `shared/skills/skill-quality-audit/references/audit-dimensions.md`
- Create: `shared/skills/skill-quality-audit/references/instruction-contract.md`
- Create: `shared/skills/skill-quality-audit/references/benchmark-mechanism-alignment.md`
- Create: `shared/skills/skill-quality-audit/references/noise-taxonomy.md`
- Create: `shared/skills/skill-quality-audit/references/runtime-integration.md`

- [ ] **Step 1: Write `SKILL.md` frontmatter and hard gates**

Create `shared/skills/skill-quality-audit/SKILL.md` with frontmatter:

```markdown
---
name: skill-quality-audit
user-invocable: true
disable-model-invocation: true
description: "Use when assessing whether an existing Skill is unclear, noisy, poorly triggered, weakly validated, unsafe to install, or not ready for team use."
eval-type: mixed
argument-hint: "[skill path or skill name]"
allowed-tools: Read, Glob, Grep, Bash
---
```

Add hard gates:

```markdown
## HARD-GATE

1. NO target file modification, rewrite, migration, deletion, or patching.
2. NO finding without evidence, impact, and repair target.
3. NO P0/P1 finding with evidence below E2.
4. NO fit verdict when Instruction Contract score is below 7.
5. NO conditional verdict when Instruction Contract score is below 5.
6. NO total-score pass when any P0 finding exists.
7. NO benchmark imitation: extract mechanism quality, not wording or structure.
```

- [ ] **Step 2: Add Codex manual-only adapter**

Create `shared/skills/skill-quality-audit/agents/openai.yaml`:

```yaml
policy:
  allow_implicit_invocation: false
```

- [ ] **Step 3: Write the five-step flow**

In `SKILL.md`, define exactly five steps:

1. Scope Evidence - locate target and active evidence surface.
2. Model Capability - define real scenario, team value, expected capability, and non-goals.
3. Audit Contracts - audit trigger, responsibility, inputs, outputs, fields, instructions, flow, resources, determinism, evidence, runtime, and benchmark mechanisms.
4. Score Verdict - assign dimension scores, severity, evidence levels, and verdict.
5. Handoff Report - output findings and repair backlog only.

Each step must state:

- input
- action
- output
- stop condition
- consumer

`Scope Evidence` must explicitly inspect this evidence surface when present:

- target `SKILL.md`
- target `agents/openai.yaml`
- `references/`
- `scripts/`
- `templates/` and `assets/`
- `contracts/` and schemas
- `test-prompts.json`
- `evals/` and fixtures
- `contracts/skill-runtime-surface.json`
- `install.sh`
- `tests/run-all.sh`
- `tests/gate-plan.json`
- `tests/run-focused.sh`
- `README.md`
- downstream skills or contracts that consume the target output

If a class is absent, record it in `missing_evidence` or `audit_scope.excluded`; do not silently ignore it.

- [ ] **Step 4: Write `audit-dimensions.md`**

Create `shared/skills/skill-quality-audit/references/audit-dimensions.md` with:

- 13 dimensions from the schema.
- Evidence level definitions:
  - `E0`: not gathered; may only appear in `missing_evidence`
  - `E1`: single file evidence
  - `E2`: cross-file or cross-contract evidence
  - `E3`: script, schema, hook, or test evidence
  - `E4`: real scenario, with/without eval, or live pilot evidence
- Weight guidance:
  - `Instruction Contract`: 20 percent
  - `Scenario Value`: 15 percent
  - `Input/Output/Field Contract`: combined 15 percent
  - all other dimensions: supporting weights, not hard pass gates
- Score anchors:
  - `0`: missing or opposite of target
  - `1-2`: harmful
  - `3-4`: weak and guess-heavy
  - `5-6`: usable but unstable
  - `7`: basically usable with clear repair gap
  - `8`: team pilot ready
  - `9`: stable team use with evidence
  - `10`: benchmark quality
- Calibration bands for every dimension:
  - `9-10`: benchmark or stable team-use quality
  - `7-8`: usable with bounded repair gaps
  - `5-6`: partially usable but unstable or under-evidenced
  - `0-4`: missing, harmful, or mostly guess-based
- Verdict rules:
  - P0 forces `blocked` or `unfit`
  - Instruction Contract < 7 caps verdict at `conditional`
  - Instruction Contract < 5 forces `unfit` or `blocked`
- Required P0/P1/P2 fields:
  - `evidence`
  - `impact`
  - `repair_target`
  - `verification_hint`

- [ ] **Step 5: Write `instruction-contract.md`**

Create `shared/skills/skill-quality-audit/references/instruction-contract.md`.

It must define sentence-level audit categories:

- Trigger
- Action
- Condition
- Gate
- Output
- Evidence
- Reference Route
- Failure Handling
- Necessary Why

It must define keyword-level audit targets:

- vague quality words: `clear`, `high quality`, `complete`, `reasonable`, `sufficient`, `optimize`, `polish`
- weak verbs: `consider`, `focus on`, `pay attention`, `try to`, `may`, `can`
- broad objects: `related files`, `necessary materials`, `downstream`, `context`
- hidden conditions: `when needed`, `as appropriate`, `if necessary`

It must require the seven repair questions:

1. Who executes this?
2. When does it execute?
3. What exact action is required?
4. What is the object?
5. What is the observable completion state?
6. What happens on failure?
7. Who consumes the result?

It must define the 10-point Instruction Contract scoring breakdown:

- 2 points: action is explicit
- 2 points: condition or branch is explicit
- 2 points: object and output are explicit
- 1 point: force level is explicit and not mixed
- 1 point: failure handling is explicit
- 1 point: evidence or verification is explicit
- 1 point: no unconsumed noise, duplicated instruction, or contradiction

- [ ] **Step 6: Write `benchmark-mechanism-alignment.md`**

Create `shared/skills/skill-quality-audit/references/benchmark-mechanism-alignment.md`.

It must state that `brainstorming` is a mechanism benchmark, not a wording template.

List benchmark mechanisms:

- strong trigger
- hard implementation gate
- terminal state
- user confirmation points
- anti-pattern that blocks common shortcuts
- progressive disclosure
- step order with causality
- output and transition clarity

Add audit instruction: compare target skill against these mechanisms only when relevant to its scenario.

- [ ] **Step 7: Write migrated references**

Create `noise-taxonomy.md` and `runtime-integration.md` by migrating only current audit-useful material from `shared/skills/skill-refiner/references/noise-taxonomy.md` and `runtime-integration.md`.

Delete or rewrite any text that implies:

- optimization workflow
- execution landing
- strategy confirmation
- refinement ledger
- `skill-refiner-result.json`
- retain upgrade
- dogfood lifecycle

- [ ] **Step 8: Verify Task 3**

Run:

```bash
bash tests/test-skill-quality-audit-runtime-contract.sh
bash tests/test-skill-quality-audit-instruction-contract.sh
python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit
```

Expected: all pass or, if the static body checker flags a real deterministic issue, fix the new skill text before continuing.

---

### Task 4: Add Test Prompts, Evals, And Dogfood Fixtures

**Files:**
- Create: `shared/skills/skill-quality-audit/test-prompts.json`
- Create: `shared/skills/skill-quality-audit/evals/evals.json`
- Create: `shared/skills/skill-quality-audit/evals/fixtures/noisy-skill/SKILL.md`
- Create: `shared/skills/skill-quality-audit/evals/fixtures/unclear-instruction-skill/SKILL.md`
- Create: `shared/skills/skill-quality-audit/evals/fixtures/benchmark-weak-skill/SKILL.md`
- Create: `shared/skills/skill-quality-audit/evals/dogfood/research-audit/skill-audit-report.json`

- [ ] **Step 1: Create test prompts**

Create `test-prompts.json` with prompts covering:

1. Audit an unclear skill without modifying it.
2. Identify sentence-level instruction ambiguity.
3. Identify runtime/install/test active references during a rename.
4. Compare a target skill with `brainstorming` mechanisms without copying structure.
5. Reject a score-only report with no evidence.

Each expected answer must require:

- read-only behavior
- 10-point score
- P severity
- evidence level
- repair target
- no patching

- [ ] **Step 2: Create eval metadata**

Create `evals/evals.json` with cases:

- `read-only-no-modification`
- `instruction-contract-low-score`
- `benchmark-mechanism-alignment`
- `active-runtime-reference-cleanup`
- `score-without-evidence-rejected`

Use `run_modes: ["with_skill", "without_skill"]`.

- [ ] **Step 3: Create target fixtures**

Create small target Skill fixtures:

- `noisy-skill`: contains vague words, duplicated background, and no output consumer.
- `unclear-instruction-skill`: contains steps such as `ensure quality` and `handle related files`.
- `benchmark-weak-skill`: has a workflow but no terminal state or user confirmation gate.

- [ ] **Step 4: Create one dogfood report**

Create `shared/skills/skill-quality-audit/evals/dogfood/research-audit/skill-audit-report.json` by auditing exactly `shared/skills/research`.

The report must:

- pass `validate_skill_audit_report.py`
- include at least one Instruction Contract score
- include at least one Benchmark Mechanism Alignment score
- include `missing_evidence` if no live with/without eval was run
- avoid claiming `fit` unless evidence supports it

- [ ] **Step 5: Verify Task 4**

Run:

```bash
jq empty shared/skills/skill-quality-audit/test-prompts.json
jq empty shared/skills/skill-quality-audit/evals/evals.json
python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py shared/skills/skill-quality-audit/evals/dogfood/research-audit/skill-audit-report.json
```

Expected: all pass.

---

### Task 5: Migrate Useful Old Assets And Delete Active Skill Refiner

**Files:**
- Delete: `shared/skills/skill-refiner/`
- Modify: `README.md`
- Modify: `contracts/episode-package.schema.json`
- Modify: active `shared/skills/*/evals/**/*.json` files that point to old `skill-refiner` as current truth
- Delete or rewrite: active `tests/*skill-refiner*.sh`
- Rename, delete, or rewrite: active cross-skill tests such as `tests/test-research-skill-refiner-eval.sh` when they encode the old audit contract or old name as current evidence
- Delete or migrate: `tests/fixtures/skill-auditor/**`
- Delete: root `skill-refiner-result.json` if unconsumed
- Delete: root `refinement-ledger.json` if unconsumed

- [ ] **Step 1: Confirm migrated assets exist**

Before deleting `shared/skills/skill-refiner/`, verify the new package includes migrated replacements for:

- quality dimensions
- instruction/noise audit
- runtime integration audit
- benchmark/strong-skill mechanism alignment
- report validator

Run:

```bash
test -f shared/skills/skill-quality-audit/references/audit-dimensions.md
test -f shared/skills/skill-quality-audit/references/instruction-contract.md
test -f shared/skills/skill-quality-audit/references/noise-taxonomy.md
test -f shared/skills/skill-quality-audit/references/runtime-integration.md
test -f shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py
```

Expected: all commands exit 0.

- [ ] **Step 2: Remove active `skill-refiner` package**

Delete `shared/skills/skill-refiner/`.

Do not move the full directory to another active path. If a historical archive is needed, put only a short migration note in `docs/archive/skill-refiner-retirement/README.md`; do not preserve old dogfood run trees in active docs.

- [ ] **Step 3: Clean active root artifacts**

Check only the root self-run artifacts:

```bash
for artifact in skill-refiner-result.json refinement-ledger.json; do
  if [ -e "$artifact" ]; then
    rg -n -F "$artifact" README.md contracts install.sh tests shared tools \
      --glob '!docs/reports/**' \
      --glob '!tools/eval/results/**' \
      --glob '!docs/archive/**' || true
  fi
done
```

If root `skill-refiner-result.json` and `refinement-ledger.json` exist and have no active consumer in the command output, delete them. Do not scan `docs/superpowers/plans/**` for this step; the implementation plan itself contains retired names as migration instructions.

- [ ] **Step 4: Migrate or delete old `skill-auditor` fixtures**

The old `skill-auditor` name is retired in `install.sh`. Do not revive it.

Move useful fixtures from:

```text
tests/fixtures/skill-auditor/**
```

to:

```text
tests/fixtures/skill-quality-audit/**
```

Rewrite artifact types from `skill-audit` or `skill-auditor-evals` to current `skill-audit-report` only when they match the new report schema. Delete fixtures that encode old command-manifest behavior unrelated to `skill-quality-audit`.

After migration, `tests/fixtures/skill-auditor/` must not exist. Keep installer checks that assert `skill-auditor` is retired; do not delete those retired-skill guards.

- [ ] **Step 5: Update README and active schemas**

Update `README.md` so the Skill quality line points to:

```text
shared/skills/skill-quality-audit/references/audit-dimensions.md
```

If `contracts/episode-package.schema.json` lists `skill-refiner` as an active skill enum, replace it with `skill-quality-audit` or remove it if skill audit is not a valid episode package category.

For `shared/skills/*/evals/**`, classify each old reference before editing:

- Current lifecycle or retain evidence consumed by active tests: rewrite to `skill-quality-audit` contract, or replace with a current non-audit evidence reference.
- Historical dogfood snapshots under the deleted `shared/skills/skill-refiner/` package: delete with the package.
- Historical result files under still-active skill packages: delete only if unconsumed; otherwise rewrite the active consumer first so no deleted schema or validator path remains.

- [ ] **Step 6: Verify old active cleanup**

Run:

```bash
bash tests/test-skill-quality-audit-old-refiner-cleanup.sh
```

Expected: pass.

---

### Task 6: Update Runtime Surface, Installer, And Gates

**Files:**
- Modify: `contracts/skill-runtime-surface.json`
- Modify: `install.sh`
- Modify: `tests/run-all.sh`
- Modify: `tests/gate-plan.json`
- Modify: `tests/run-focused.sh`
- Modify: `tests/test-skill-runtime-surface-contract.sh`
- Modify: `tests/test-install-retired-skill-cleanup.sh` only when it explicitly enumerates retired skill fixture paths or installed skill lists affected by this replacement.

- [ ] **Step 1: Update runtime surface**

In `contracts/skill-runtime-surface.json`:

- Add `skill-quality-audit`.
- Set `mode` to `manual`.
- Set `owner` to `first-party`.
- Reason: `Skill quality audits are high-impact QA and should be explicitly invoked.`
- Remove `skill-refiner`.
- Keep `skill-auditor` retired behavior in `install.sh`; do not add `skill-auditor`.

- [ ] **Step 2: Update installer checks**

In `install.sh`:

- Require `skill-quality-audit/SKILL.md` where first-party shared skills are explicitly checked for Claude and Codex runtimes.
- Keep checks that `skill-auditor` must not exist.
- Remove any `skill-refiner` install or quick-check expectation if present.

- [ ] **Step 3: Update run-all syntax and py_compile checks**

In `tests/run-all.sh`:

- Remove `shared/skills/skill-refiner/scripts/completion_check.sh`.
- Remove py_compile lines for:
  - `validate_refinement_result.py`
  - `validate_effect_evidence.py`
  - `validate_retain_evidence.py`
- Add:
  - `python3 -m py_compile "$ROOT/shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py"`
  - new shell tests from Task 1 in the gate plan, not necessarily the syntax list unless they are direct syntax targets.

- [ ] **Step 4: Update gate plan**

In `tests/gate-plan.json`:

- Replace profile `skill-refiner` with `skill-quality-audit`.
- Remove all active `skill-refiner-*` test entries.
- Rename or remove active cross-skill entries such as `research-skill-refiner-eval`; no gate id, area, command, or filename may keep `skill-refiner` as a current contract.
- Add test entries for:
  - `skill-quality-audit-report-contract`
  - `skill-quality-audit-runtime-contract`
  - `skill-quality-audit-old-refiner-cleanup`
  - `skill-quality-audit-instruction-contract`
- Use area `skill-quality-audit`.
- Mark these as `tier: "full"` unless they need quick coverage.

- [ ] **Step 5: Update focused runner text**

In `tests/run-focused.sh`, replace the help/profile entry:

```text
skill-refiner    Skill refiner package and eval contract checks.
```

with:

```text
skill-quality-audit    Skill quality audit package and report contract checks.
```

Ensure the focused runner can execute the new profile.

- [ ] **Step 6: Verify runtime and gate updates**

Run:

```bash
bash tests/test-skill-runtime-surface-contract.sh
bash tests/test-skill-quality-audit-runtime-contract.sh
bash tests/run-all.sh --list | rg 'skill-quality-audit'
if bash tests/run-all.sh --list | rg 'skill-refiner'; then
  echo "old skill-refiner still appears in run-all list" >&2
  exit 1
fi
```

Expected:

- runtime surface test passes
- runtime contract test passes
- run-all list includes new audit tests
- run-all list does not include old `skill-refiner`

---

### Task 7: Strengthen Deterministic Instruction Quality Signals When The Current Checker Misses The Fixture

**Files:**
- Modify: `tools/skill_quality/check_skill_body_quality.py` only if current checker cannot catch the new fixtures.
- Modify: `tools/skill_quality/manifest.json` only if a new checker command is introduced.
- Create or modify: `tests/fixtures/skill-body-quality/*` only for deterministic signals.
- Modify: `tests/test-skill-body-quality-static-audit.sh`

- [ ] **Step 1: Check current static checker coverage**

Run:

```bash
python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit
bash tests/test-skill-body-quality-static-audit.sh
```

Expected: existing checker should pass the new skill and existing fixtures.

- [ ] **Step 2: Add deterministic vague-instruction fixture only when Step 1 shows a checker gap**

If the current checker misses obvious unbounded vague terms, add a fixture under:

```text
tests/fixtures/skill-body-quality/bad-unbounded-instruction/SKILL.md
```

The bad fixture should include lines like:

```markdown
1. Ensure the final report is high quality.
2. Handle related files when needed.
3. Optimize the skill as appropriate.
```

Expected checker finding: unbounded vague instruction.

- [ ] **Step 3: Update checker only for deterministic cases**

If needed, extend `VAGUE_TERMS` and nearby criteria detection in `tools/skill_quality/check_skill_body_quality.py`.

Do not make the checker judge semantic quality, benchmark alignment, or whether a skill is valuable. Those remain model audit findings in `skill-quality-audit`.

- [ ] **Step 4: Verify deterministic checker**

Run:

```bash
bash tests/test-skill-body-quality-static-audit.sh
python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit
```

Expected: pass.

---

### Task 8: End-To-End Verification And Self-Review

**Files:**
- Verify all files changed by this plan.

- [ ] **Step 1: Run targeted tests**

Run:

```bash
bash tests/test-skill-quality-audit-report-contract.sh
bash tests/test-skill-quality-audit-runtime-contract.sh
bash tests/test-skill-quality-audit-old-refiner-cleanup.sh
bash tests/test-skill-quality-audit-instruction-contract.sh
bash tests/test-skill-runtime-surface-contract.sh
python3 -m py_compile shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py
```

Expected: all pass.

- [ ] **Step 2: Run package/static quality checks**

Run:

```bash
python3 tools/skill_quality/check_skill_body_quality.py shared/skills/skill-quality-audit
python3 tools/skill_quality/check_skill_package_quality.py shared/skills/skill-quality-audit
python3 tools/skill_quality/check_skill_anti_noise.py --path shared/skills/skill-quality-audit --scope active
```

Expected: all pass or report only target-boundary issues that must be fixed before completion.

- [ ] **Step 3: Run active reference scan**

Run:

```bash
rg -n 'skill-refiner|skill-refiner-result|refinement-ledger|validate_refinement_result' \
  README.md contracts install.sh tests shared/skills tools/skill_quality \
  --glob '!tests/test-skill-quality-audit-*.sh' \
  --glob '!tests/fixtures/skill-quality-audit/**' \
  --glob '!docs/reports/**' \
  --glob '!tools/eval/results/**' \
  --glob '!docs/archive/**'
```

Expected: no output.

Then run:

```bash
test ! -e tests/fixtures/skill-auditor
```

Expected: exits 0.

- [ ] **Step 4: Run quick gate**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: pass.

- [ ] **Step 5: Review git diff against scope**

Run:

```bash
git diff --stat
git diff -- README.md contracts/skill-runtime-surface.json install.sh tests/run-all.sh tests/gate-plan.json tests/run-focused.sh shared/skills/skill-quality-audit
```

Expected:

- Changes only support `skill-quality-audit` creation and `skill-refiner` active retirement.
- No standard-chain field-contract changes are introduced by this plan.
- No target Skill other than `skill-quality-audit` is modified except active references/tests needed for retirement.

---

## Implementation Order

1. Task 1 - write failing tests and fixtures.
2. Task 2 - implement report validator.
3. Task 3 - build the read-only skill package.
4. Task 4 - add prompts/evals/dogfood evidence.
5. Task 5 - migrate useful old assets and delete active `skill-refiner`.
6. Task 6 - update runtime/install/gate integration.
7. Task 7 - strengthen deterministic instruction checks only when Step 1 proves a deterministic checker gap.
8. Task 8 - full targeted and quick verification.

## Blockers And Stop Conditions

- Stop if `skill-quality-audit` needs `Write` or `Edit` to satisfy a test. That means the test is wrong or report generation needs a separate tool.
- Stop if a P0/P1 report can pass without `repair_target` or evidence level E2+.
- Stop if active runtime still references `skill-refiner`.
- Stop if an active cross-skill eval still points to a deleted `skill-refiner` schema, validator, result artifact, or test name.
- Stop if deleting `shared/skills/skill-refiner` breaks an active non-historical consumer not covered by this plan; update the consumer explicitly or ask for scope decision.
- Stop if quick gate failures come from the parallel standard-chain cleanup and cannot be separated from this change.

## Plan Self-Review

- Spec coverage: Covers read-only QA role, direct retirement, 10-point scoring, P severity, evidence levels, Instruction Contract, Benchmark Mechanism Alignment, active reference cleanup, runtime/install/test updates, and real dogfood evidence.
- Placeholder scan: No placeholder markers or unspecified "write tests" steps remain.
- Scope check: Plan is a single coherent subsystem replacement: old skill-quality modifier out, new skill-quality auditor in. It intentionally does not modify product/design standard-chain files.
- Risk: `install.sh`, `tests/gate-plan.json`, and `tests/run-all.sh` are shared with the other active window. Executor must coordinate dirty state before applying changes.
