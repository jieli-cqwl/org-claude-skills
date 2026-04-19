# Skill Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build `skill-harness` as the active Skill engineering保障入口, with lightweight LLM runtime guidance and deterministic engineering gates for evidence, JSON upgrade, Darwin candidates, content order, and migration.

**Architecture:** `SKILL.md` defines the LLM-facing runtime contract and routes detail into focused references. Engineering checks live in a small Python checker plus shell tests and fixtures. Install/runtime exposure moves from `skill-auditor` to `skill-harness`; old source is archived and removed from active Skill discovery.

**Tech Stack:** Markdown Skill files, Bash contract tests, Python 3 standard library JSON/path checks, existing `install.sh`, existing `tools/community/check_task_plan_consistency.py`.

---

## File Boundaries

- Create: `shared/skills/skill-harness/SKILL.md`
- Create: `shared/skills/skill-harness/agents/openai.yaml`
- Create: `shared/skills/skill-harness/references/audit-method.md`
- Create: `shared/skills/skill-harness/references/json-upgrade-gate.md`
- Create: `shared/skills/skill-harness/references/darwin-candidate-contract.md`
- Create: `shared/skills/skill-harness/references/content-order-contract.md`
- Create: `shared/skills/skill-harness/references/runtime-noise-contract.md`
- Create: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py`
- Create: `shared/skills/skill-harness/scripts/manifest.json`
- Create: `tests/test-skill-harness-contract.sh`
- Create: `tests/test-skill-harness-gates.sh`
- Create: `tests/test-skill-harness-migration.sh`
- Create: `tests/fixtures/skill-harness/cases/*.json`
- Modify: `install.sh`
- Modify: `tests/run-all.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `tests/test-skill-context-budget.sh`
- Modify: `tests/test-skill-quality-standard.sh`
- Modify: `shared/reference/Skill质量标准.md`
- Move: `shared/skills/skill-auditor/**` to `docs/archive/skill-auditor/runtime-source-2026-04-19/**`
- Create: `docs/archive/skill-auditor/runtime-source-2026-04-19/README.md`
- Create: `docs/skill-harness/2026-04-19-best-practice-baseline/verify-change-report.md`

### Task 1: Runtime Entry And References [T1]

Context: This task defines the LLM-controlled surface first. The active Skill must load as `skill-harness`, keep the default path as structured Markdown, and make JSON an explicit upgrade rather than a default artifact.

Files:
- Create: `tests/test-skill-harness-contract.sh`
- Create: `shared/skills/skill-harness/SKILL.md`
- Create: `shared/skills/skill-harness/agents/openai.yaml`
- Create: `shared/skills/skill-harness/references/audit-method.md`
- Create: `shared/skills/skill-harness/references/json-upgrade-gate.md`
- Create: `shared/skills/skill-harness/references/darwin-candidate-contract.md`
- Create: `shared/skills/skill-harness/references/content-order-contract.md`
- Create: `shared/skills/skill-harness/references/runtime-noise-contract.md`

1. [T1] Write the failing contract test.

Create `tests/test-skill-harness-contract.sh` with assertions for:

```bash
SKILL_DIR="$ROOT/shared/skills/skill-harness"
SKILL_FILE="$SKILL_DIR/SKILL.md"
[ -f "$SKILL_FILE" ] || fail "missing skill-harness SKILL.md"
grep -Fq 'name: skill-harness' "$SKILL_FILE" || fail "frontmatter name must be skill-harness"
grep -Fq 'allowed-tools: Read, Glob, Grep, Bash' "$SKILL_FILE" || fail "allowed tools must stay read-first"
grep -Fq 'LLM can propose transitions; engineering must authorize transitions' "$SKILL_FILE" || fail "missing core transition principle"
grep -Fq 'Default output: structured Markdown findings' "$SKILL_FILE" || fail "default audit output must be Markdown"
grep -Fq 'JSON upgrade gate' "$SKILL_FILE" || fail "missing JSON upgrade gate"
grep -Fq 'Correctness PASS / Practice FAIL' "$SKILL_FILE" || fail "missing delivery-owner calibration verdict"
grep -Fq 'references/json-upgrade-gate.md' "$SKILL_FILE" || fail "missing JSON reference route"
grep -Fq 'references/darwin-candidate-contract.md' "$SKILL_FILE" || fail "missing Darwin reference route"
grep -Fq 'references/content-order-contract.md' "$SKILL_FILE" || fail "missing content order route"
grep -Fq 'references/runtime-noise-contract.md' "$SKILL_FILE" || fail "missing runtime noise route"
```

2. [T1] Run the RED command.

Run: `bash tests/test-skill-harness-contract.sh`
Expected: FAIL with `missing skill-harness SKILL.md`.

3. [T1] Create the `skill-harness` `SKILL.md`.

The file must contain these sections in this order:

```markdown
---
name: skill-harness
description: Audit existing Skills and Darwin candidates against Skill Harness runtime contracts. Use when checking Skill correctness, runtime boundaries, evidence chains, JSON upgrade need, content order, or migration from skill-auditor.
allowed-tools: Read, Glob, Grep, Bash
---

# skill-harness

## HARD-GATE

## Role

## Default Flow

## JSON Upgrade Gate

## Darwin Candidate Gate

## Output Contract

## Completion Check

## References
```

4. [T1] Fill the HARD-GATE section with exact runtime limits.

Use this content:

```markdown
- NO write action from audit mode. Return findings and required file scope instead.
- NO FAIL finding without `file:line`, evidence, impact, recommendation, and proof command.
- NO JSON fact source unless a machine consumer, cross-round state, Darwin gate, hook, validator, runner, release gate, or derived report consumes it.
- NO Markdown/HTML as machine fact source after JSON upgrade.
- NO active alias or runtime compatibility entry for retired Skill names.
- NO Darwin candidate self-certification; verify boundary, order, evidence, permissions, and proof command independently.
- NO manifest command claim unless the command exists and has an owner, allowed arguments, timeout, output root, and failure state.
```

5. [T1] Fill the flow, output, and references.

The default flow must include:

```markdown
Default output: structured Markdown findings.
Fields: `overall_verdict`, `finding_severity`, `dimension`, `file:line`, `evidence`, `impact`, `recommendation`, `proof_command`.
```

The references list must route:

```markdown
- Audit dimensions and finding shape: `references/audit-method.md`
- JSON upgrade and fact source rule: `references/json-upgrade-gate.md`
- Darwin candidate gate: `references/darwin-candidate-contract.md`
- Content order gate: `references/content-order-contract.md`
- Runtime noise policy: `references/runtime-noise-contract.md`
```

6. [T1] Create focused references.

Each reference must include `Trigger:`, `Read:`, `Expect:`, `Consume:`, `Evidence:`, and `Sync:` fields. `json-upgrade-gate.md` must include `consumer`, `read purpose`, `validation`, and `drop condition`. `darwin-candidate-contract.md` must include content order, permission boundary, evidence chain, runtime noise, behavior benefit, and rollback boundary checks.

7. [T1] Create the Codex adapter.

Create `shared/skills/skill-harness/agents/openai.yaml` with:

```yaml
name: skill-harness
short_description: Audit Skill runtime contracts and evidence gates.
default_prompt: Use $skill-harness to audit the target Skill or Darwin candidate.
```

8. [T1] Run the GREEN command.

Run: `bash tests/test-skill-harness-contract.sh`
Expected: `[PASS] skill-harness contract`.

9. [T1] Commit.

Run:

```bash
git add shared/skills/skill-harness tests/test-skill-harness-contract.sh
git commit -m "feat: add skill-harness runtime contract"
```

### Task 2: Deterministic Gates And Fixtures [T2]

Context: This task gives engineering the first enforceable surface. It keeps the checker small: fixtures declare sample id, input class, expected verdict, and failure code; the checker validates contract behavior without becoming a new platform.

Files:
- Create: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py`
- Create: `shared/skills/skill-harness/scripts/manifest.json`
- Create: `tests/test-skill-harness-gates.sh`
- Create: `tests/fixtures/skill-harness/cases/good-markdown-audit.json`
- Create: `tests/fixtures/skill-harness/cases/no-evidence-fail.json`
- Create: `tests/fixtures/skill-harness/cases/missing-command.json`
- Create: `tests/fixtures/skill-harness/cases/active-alias.json`
- Create: `tests/fixtures/skill-harness/cases/markdown-fact-source.json`
- Create: `tests/fixtures/skill-harness/cases/darwin-tail-hard-gate.json`
- Create: `tests/fixtures/skill-harness/cases/json-without-consumer.json`
- Create: `tests/fixtures/skill-harness/cases/delivery-owner-practice-risk.json`

1. [T2] Write the failing gate test.

Create `tests/test-skill-harness-gates.sh` with:

```bash
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
CASES="$ROOT/tests/fixtures/skill-harness/cases"
[ -x "$CHECKER" ] || fail "missing executable checker"
python3 "$CHECKER" "$CASES/good-markdown-audit.json"
python3 "$CHECKER" "$CASES/delivery-owner-practice-risk.json"
expect_fail "no evidence FAIL" python3 "$CHECKER" "$CASES/no-evidence-fail.json"
expect_fail "missing manifest command" python3 "$CHECKER" "$CASES/missing-command.json"
expect_fail "active alias" python3 "$CHECKER" "$CASES/active-alias.json"
expect_fail "markdown fact source" python3 "$CHECKER" "$CASES/markdown-fact-source.json"
expect_fail "tail hard gate" python3 "$CHECKER" "$CASES/darwin-tail-hard-gate.json"
expect_fail "json without consumer" python3 "$CHECKER" "$CASES/json-without-consumer.json"
grep -Fq '"check-contract"' "$ROOT/shared/skills/skill-harness/scripts/manifest.json" || fail "manifest must expose check-contract"
```

2. [T2] Run the RED command.

Run: `bash tests/test-skill-harness-gates.sh`
Expected: FAIL with `missing executable checker`.

3. [T2] Implement fixture shape.

Every fixture must use this shape:

```json
{
  "sample_id": "good-markdown-audit",
  "mode": "human_markdown_audit",
  "overall_verdict": "PASS",
  "finding_severity": "INFO",
  "dimension": "Correctness",
  "failure_code": "",
  "fact_source": "markdown",
  "json_consumer": "",
  "file_line": "shared/skills/example/SKILL.md:1",
  "evidence": ["shared/skills/example/SKILL.md:1"],
  "impact": "No blocking issue.",
  "proof_command": "bash tests/test-skill-harness-gates.sh",
  "manifest_command_exists": true,
  "active_alias": false,
  "hard_gate_position": "early",
  "expected_result": "pass"
}
```

4. [T2] Implement checker rules.

`check_skill_harness_contract.py` must fail when:

```text
finding_severity is FAIL and evidence is empty -> NEED_EVIDENCE
manifest_command_exists is false -> MISSING_COMMAND
active_alias is true -> ACTIVE_ALIAS
fact_source is markdown and json_consumer is not empty -> MARKDOWN_FACT_SOURCE
hard_gate_position is tail -> CONTENT_ORDER
fact_source is json and json_consumer is empty -> JSON_WITHOUT_CONSUMER
sample_id is delivery-owner-practice-risk and verdict is not Correctness PASS / Practice FAIL -> CALIBRATION_MISMATCH
```

5. [T2] Add the script manifest.

Create `shared/skills/skill-harness/scripts/manifest.json` with command id `check-contract`, path `scripts/check_skill_harness_contract.py`, timeout `10`, output limit `12000`, output root `.` and allowed input root `tests/fixtures/skill-harness/cases`.

6. [T2] Run the GREEN command.

Run: `bash tests/test-skill-harness-gates.sh`
Expected: `[PASS] skill-harness gates`.

7. [T2] Commit.

Run:

```bash
git add shared/skills/skill-harness/scripts tests/test-skill-harness-gates.sh tests/fixtures/skill-harness
git commit -m "test: add skill-harness engineering gates"
```

### Task 3: Runtime Exposure Migration [T3]

Context: This task changes active installation and runtime discovery. The target runtime exposes `skill-harness`; `skill-auditor` stops being an active Skill entry.

Files:
- Modify: `install.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `tests/test-skill-context-budget.sh`
- Modify: `tests/run-all.sh`

1. [T3] Update install manual-only lists and completeness checks.

Replace active checks for `skill-auditor` with `skill-harness` in `install.sh`:

```text
low_frequency_manual_only_skills: skill-harness
runtime_target_complete claude: skills/skill-harness/SKILL.md exists, skills/skill-auditor absent
runtime_target_complete codex: skills/skill-harness/SKILL.md exists, skill-harness adapter absent after manual-only pruning, skills/skill-auditor absent
quick_check claude: ~/.claude/skills/skill-harness/SKILL.md exists, ~/.claude/skills/skill-auditor absent
quick_check codex: ~/.codex/skills/skill-harness/SKILL.md exists, skill-harness adapter absent, skill-auditor absent, skill-harness declares manual-only
```

2. [T3] Update source layout and adapter tests.

`tests/test-single-source-layout.sh` must require `shared/skills/skill-harness/SKILL.md` and reject `shared/skills/skill-auditor`. `tests/test-codex-skill-adapter.sh` must assert Codex installs `skill-harness/SKILL.md`, prunes `skill-harness/agents/openai.yaml`, and does not install `skill-auditor`.

3. [T3] Update context budget.

`tests/test-skill-context-budget.sh` must audit `skill-harness` in the core skill list. Keep the `skill-harness` line budget at `200` unless the final `SKILL.md` is shorter than `150`, then set it to `150`.

4. [T3] Add new tests to `tests/run-all.sh`.

Add syntax and shellcheck entries for:

```text
tests/test-skill-harness-contract.sh
tests/test-skill-harness-gates.sh
tests/test-skill-harness-migration.sh
```

Add runtime steps after `skill format unification test`:

```text
skill-harness contract test
skill-harness gates test
skill-harness migration test
```

5. [T3] Run targeted commands.

Run:

```bash
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
bash tests/test-skill-context-budget.sh
bash tests/test-install-smoke.sh
```

Expected: all exit 0.

6. [T3] Commit.

Run:

```bash
git add install.sh tests/test-single-source-layout.sh tests/test-codex-skill-adapter.sh tests/test-skill-context-budget.sh tests/run-all.sh
git commit -m "chore: expose skill-harness runtime"
```

### Task 4: Archive Legacy Source And Active References [T4]

Context: This task removes legacy runtime noise while preserving historical material. Old `skill-auditor` files stay available as archive evidence, not as active discovery input.

Files:
- Move: `shared/skills/skill-auditor/**` to `docs/archive/skill-auditor/runtime-source-2026-04-19/**`
- Create: `docs/archive/skill-auditor/runtime-source-2026-04-19/README.md`
- Modify: `shared/reference/Skill质量标准.md`
- Modify: `tests/test-skill-quality-standard.sh`
- Create: `tests/test-skill-harness-migration.sh`

1. [T4] Write the failing migration test.

Create `tests/test-skill-harness-migration.sh` with:

```bash
[ -d "$ROOT/shared/skills/skill-harness" ] || fail "missing active skill-harness source"
[ ! -d "$ROOT/shared/skills/skill-auditor" ] || fail "skill-auditor must not remain active runtime source"
[ -d "$ROOT/docs/archive/skill-auditor/runtime-source-2026-04-19" ] || fail "missing skill-auditor archive"
grep -Fq 'ARCHIVE_ONLY' "$ROOT/docs/archive/skill-auditor/runtime-source-2026-04-19/README.md" || fail "archive must classify legacy source"
if rg -n 'skill-auditor|skill-optimizer' "$ROOT/shared/skills" "$ROOT/shared/reference" "$ROOT/install.sh" "$ROOT/tests" \
  -g '!tests/fixtures/**' \
  -g '!tests/test-skill-harness-migration.sh' \
  >/tmp/skill_harness_legacy_hits.out 2>&1; then
  cat /tmp/skill_harness_legacy_hits.out >&2
  fail "legacy skill name leaked into active source"
fi
```

2. [T4] Run the RED command.

Run: `bash tests/test-skill-harness-migration.sh`
Expected: FAIL with `skill-auditor must not remain active runtime source`.

3. [T4] Move legacy source to archive.

Run:

```bash
mkdir -p docs/archive/skill-auditor/runtime-source-2026-04-19
git mv shared/skills/skill-auditor/* docs/archive/skill-auditor/runtime-source-2026-04-19/
rmdir shared/skills/skill-auditor
```

4. [T4] Add archive README.

Create `docs/archive/skill-auditor/runtime-source-2026-04-19/README.md` with:

```markdown
# skill-auditor runtime source archive

Classification: ARCHIVE_ONLY
Archived on: 2026-04-19
Replacement: `shared/skills/skill-harness`

This directory preserves the former runtime source for historical evidence and migration review. It is not an active Skill discovery source, install source, adapter source, or runtime reference path.

Allowed consumers:
- Migration review
- Regression fixture design
- Historical implementation audit

Exit condition:
- Keep archived while historical reports reference the former implementation.
```

5. [T4] Update quality standard references.

In `shared/reference/Skill质量标准.md`, replace active Harness role examples that name `skill-auditor` with `skill-harness`. Keep historical citations only inside archive paths.

6. [T4] Update skill quality standard test.

`tests/test-skill-quality-standard.sh` must point `MAPPING` to `shared/skills/skill-harness/references/audit-method.md` or `references/json-upgrade-gate.md` only for active mapping checks. Remove active references to `shared/skills/skill-optimizer`.

7. [T4] Run targeted commands.

Run:

```bash
bash tests/test-skill-harness-migration.sh
bash tests/test-skill-quality-standard.sh
bash tests/test-single-source-layout.sh
```

Expected: all exit 0.

8. [T4] Commit.

Run:

```bash
git add shared/reference/Skill质量标准.md tests/test-skill-quality-standard.sh tests/test-skill-harness-migration.sh docs/archive/skill-auditor/runtime-source-2026-04-19 shared/skills/skill-auditor
git commit -m "chore: archive skill-auditor runtime source"
```

### Task 5: Verification And Package [T5]

Context: This task proves the whole small-chain result and records the evidence. It does not add behavior beyond verification and report packaging.

Files:
- Modify: `docs/skill-harness/2026-04-19-best-practice-baseline/tasks.md`
- Create: `docs/skill-harness/2026-04-19-best-practice-baseline/verify-change-report.md`

1. [T5] Mark tasks complete after their commands pass.

Update `tasks.md` checkboxes to `[x]` only after the AC commands for each task exit 0.

2. [T5] Run task-plan consistency.

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-19-best-practice-baseline/tasks.md docs/skill-harness/2026-04-19-best-practice-baseline/plan.md
```

Expected: `[PASS] tasks-plan consistency (5 tasks,` followed by the plan step count.

3. [T5] Run targeted verification.

Run:

```bash
bash tests/test-skill-harness-contract.sh
bash tests/test-skill-harness-gates.sh
bash tests/test-skill-harness-migration.sh
bash tests/test-install-smoke.sh
git diff --check
```

Expected: every command exits 0.

4. [T5] Run full verification.

Run: `bash tests/run-all.sh`
Expected: `All tests passed`.

5. [T5] Create verify-change report.

Create `docs/skill-harness/2026-04-19-best-practice-baseline/verify-change-report.md` with:

```markdown
# verify-change report: skill-harness best-practice baseline

## Scope

- Runtime entry: `shared/skills/skill-harness`
- Migration: active runtime moves from `skill-auditor` to `skill-harness`
- Engineering gates: `tests/test-skill-harness-contract.sh`, `tests/test-skill-harness-gates.sh`, `tests/test-skill-harness-migration.sh`

## Evidence

| Command | Result |
| --- | --- |
| `python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-19-best-practice-baseline/tasks.md docs/skill-harness/2026-04-19-best-practice-baseline/plan.md` | PASS |
| `bash tests/test-skill-harness-contract.sh` | PASS |
| `bash tests/test-skill-harness-gates.sh` | PASS |
| `bash tests/test-skill-harness-migration.sh` | PASS |
| `bash tests/test-install-smoke.sh` | PASS |
| `git diff --check` | PASS |
| `bash tests/run-all.sh` | PASS |

## Residual Risk

No active runtime compatibility entry remains for the old Skill name. Historical archive and fixtures retain legacy names for evidence and regression coverage.
```

6. [T5] Commit.

Run:

```bash
git add docs/skill-harness/2026-04-19-best-practice-baseline/tasks.md docs/skill-harness/2026-04-19-best-practice-baseline/verify-change-report.md
git commit -m "docs: verify skill-harness small-chain"
```
