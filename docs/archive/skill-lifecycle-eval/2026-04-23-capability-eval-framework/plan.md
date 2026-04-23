# Skill Lifecycle Capability Eval Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add a repeatable D9 lifecycle evaluation framework so first-party standard-chain skills declare why they exist, carry eval scenarios, and have evidence-backed lifecycle review records.

**Architecture:** Keep the framework as documentation, metadata, and deterministic validation. Do not create a new skill or modify `skill-creator`; extend the existing quality standard, first-party skill eval files, and skill-harness guidance while preserving current runtime boundaries.

**Tech Stack:** Markdown reference docs, YAML frontmatter, JSON eval/review metadata, Bash contract tests, Python JSON validation embedded in shell tests, existing `tests/run-all.sh` orchestration.

---

### Task 1: D9 Standards And Lifecycle Rules [T1]

Context: This task establishes the canonical D9 language. It is docs-first but test-protected because downstream skill metadata depends on exact fields and lifecycle states.

Files:
- Create: `shared/reference/Skill能力有效性标准.md`
- Create: `shared/reference/Skill生命周期管理.md`
- Modify: `shared/reference/Skill质量标准.md`
- Create: `tests/test-skill-lifecycle-eval-framework.sh`

1. [T1] Write the failing lifecycle framework test.

Create `tests/test-skill-lifecycle-eval-framework.sh` with assertions for the two new reference files, D9 registration in `Skill质量标准.md`, expected standard-chain skill list, and the metadata/review contract that later tasks will satisfy.

```bash
#!/usr/bin/env bash
# 文件职责：验证 Skill D9 能力有效性标准、生命周期闭环和标准链 skill eval 元数据。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/reference/Skill质量标准.md"
CAPABILITY="$ROOT/shared/reference/Skill能力有效性标准.md"
LIFECYCLE="$ROOT/shared/reference/Skill生命周期管理.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in $file: $needle"
}

test -f "$CAPABILITY" || fail "missing capability standard"
test -f "$LIFECYCLE" || fail "missing lifecycle management standard"
test -f "$STANDARD" || fail "missing quality standard"

dimension_count="$(grep -Ec '^\| D[1-9] \|' "$STANDARD")"
[ "$dimension_count" = "9" ] || fail "standard must define exactly 9 dimensions, got $dimension_count"

assert_present 'D9 | 存在合理性' "$STANDARD"
assert_present '## D9 存在合理性' "$STANDARD"
assert_present 'eval-type' "$CAPABILITY"
assert_present 'capability_uplift' "$CAPABILITY"
assert_present 'encoded_preference' "$CAPABILITY"
assert_present 'mixed' "$CAPABILITY"
assert_present 'with-skill' "$CAPABILITY"
assert_present 'without-skill' "$CAPABILITY"
assert_present '偏好锚点' "$CAPABILITY"
assert_present 'Gate 1: 上线门禁' "$LIFECYCLE"
assert_present 'Gate 2: 模型升级触发' "$LIFECYCLE"
assert_present 'Gate 3: 定期复审' "$LIFECYCLE"
assert_present 'Gate 4: 退役协议' "$LIFECYCLE"

python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
expected = {
    "product-director": "encoded_preference",
    "product-manager": "encoded_preference",
    "design": "mixed",
    "test-design": "mixed",
    "tech-lead": "encoded_preference",
    "developer": "mixed",
    "review": "mixed",
    "verify": "mixed",
    "qa": "mixed",
    "delivery-owner": "encoded_preference",
    "fix": "mixed",
    "consistency-audit": "mixed",
}
allowed_decisions = {"retain", "optimize", "retire"}

def frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"---\n(.*?)\n---", text, re.S)
    if not match:
        raise SystemExit(f"{path}: missing YAML frontmatter")
    data = {}
    for line in match.group(1).splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            data[key.strip()] = value.strip().strip('"')
    return data

for skill, eval_type in expected.items():
    skill_dir = root / "shared" / "skills" / skill
    skill_file = skill_dir / "SKILL.md"
    eval_file = skill_dir / "evals" / "evals.json"
    review_file = skill_dir / "evals" / "lifecycle-review.json"

    if not skill_file.is_file():
        raise SystemExit(f"missing SKILL.md for {skill}")
    if frontmatter(skill_file).get("eval-type") != eval_type:
        raise SystemExit(f"{skill_file}: eval-type must be {eval_type}")
    if not eval_file.is_file():
        raise SystemExit(f"missing evals file for {skill}")
    if not review_file.is_file():
        raise SystemExit(f"missing lifecycle review for {skill}")

    evals = json.loads(eval_file.read_text(encoding="utf-8"))
    if evals.get("skill_name") != skill:
        raise SystemExit(f"{eval_file}: skill_name must be {skill}")
    if evals.get("eval_type") != eval_type:
        raise SystemExit(f"{eval_file}: eval_type must be {eval_type}")
    cases = evals.get("evals")
    if not isinstance(cases, list) or len(cases) < 3:
        raise SystemExit(f"{eval_file}: expected at least 3 evals")
    if eval_type in {"encoded_preference", "mixed"}:
        anchors = evals.get("preference_anchors")
        if not isinstance(anchors, list) or not (5 <= len(anchors) <= 10):
            raise SystemExit(f"{eval_file}: expected 5-10 preference anchors")
        anchor_ids = {item.get("id") for item in anchors if isinstance(item, dict)}
        if len(anchor_ids) != len(anchors):
            raise SystemExit(f"{eval_file}: preference anchor ids must be unique")
    if eval_type in {"capability_uplift", "mixed"}:
        dimensions = evals.get("grader_dimensions")
        if not isinstance(dimensions, list) or not dimensions:
            raise SystemExit(f"{eval_file}: missing grader_dimensions")
    for case in cases:
        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id:
            raise SystemExit(f"{eval_file}: eval id must be a non-empty string")
        if not isinstance(case.get("prompt"), str) or not case["prompt"].strip():
            raise SystemExit(f"{eval_file}: eval {case_id} missing prompt")
        if not isinstance(case.get("expected_output"), str) or not case["expected_output"].strip():
            raise SystemExit(f"{eval_file}: eval {case_id} missing expected_output")
        if eval_type in {"encoded_preference", "mixed"}:
            expected_anchors = case.get("expected_anchors")
            if not isinstance(expected_anchors, list) or not expected_anchors:
                raise SystemExit(f"{eval_file}: eval {case_id} missing expected_anchors")
            unknown = sorted(set(expected_anchors) - anchor_ids)
            if unknown:
                raise SystemExit(f"{eval_file}: eval {case_id} unknown anchors {unknown}")
        if eval_type in {"capability_uplift", "mixed"}:
            run_modes = case.get("run_modes")
            if run_modes != ["with_skill", "without_skill"]:
                raise SystemExit(f"{eval_file}: eval {case_id} must run with and without skill")

    review = json.loads(review_file.read_text(encoding="utf-8"))
    if review.get("skill_name") != skill:
        raise SystemExit(f"{review_file}: skill_name must be {skill}")
    if review.get("eval_type") != eval_type:
        raise SystemExit(f"{review_file}: eval_type must be {eval_type}")
    if review.get("decision") not in allowed_decisions:
        raise SystemExit(f"{review_file}: decision must be retain/optimize/retire")
    if not review.get("evidence_refs"):
        raise SystemExit(f"{review_file}: evidence_refs required")
    if eval_type in {"encoded_preference", "mixed"} and "encoded_preference" not in review:
        raise SystemExit(f"{review_file}: encoded_preference review data required")
    if eval_type in {"capability_uplift", "mixed"} and "capability_uplift" not in review:
        raise SystemExit(f"{review_file}: capability_uplift review data required")
PY

printf '[PASS] skill lifecycle eval framework\n'
```

2. [T1] Run the new test to verify RED.

Run: `bash tests/test-skill-lifecycle-eval-framework.sh`

Expected: FAIL with `missing capability standard`.

3. [T1] Create `shared/reference/Skill能力有效性标准.md`.

Write a concise D9 standard that defines `eval-type`, the three allowed type values, Capability Uplift with/without protocol, Encoded Preference anchor fidelity protocol, mixed handling, conclusion rules, and the difference between empirical review and initial readiness review.

4. [T1] Create `shared/reference/Skill生命周期管理.md`.

Write the four gates from the design: launch, model upgrade, quarterly review, and retirement protocol. State that retirement always requires human confirmation and that first-run missing empirical data routes to `optimize`, not fake `retain`.

5. [T1] Update `shared/reference/Skill质量标准.md`.

Add D9 to the quality dimension table after D8, add a `## D9 存在合理性` section, update L2/L3 wording from D1-D8 to D1-D9 where appropriate, and update the finding dimension enum to include D9.

6. [T1] Run the lifecycle test again.

Run: `bash tests/test-skill-lifecycle-eval-framework.sh`

Expected: FAIL later on missing `eval-type` or missing lifecycle eval metadata, proving the D9 docs exist and the next task is now the blocker.

### Task 2: 12 Skill Eval Metadata And Review Records [T2]

Context: This task adds the lifecycle metadata for the exact 12 skills listed in `design.md`. It does not change runtime behavior; it only adds frontmatter metadata, eval scenario fields, and review records.

Files:
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/review/SKILL.md`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/fix/SKILL.md`
- Modify: `shared/skills/consistency-audit/SKILL.md`
- Modify or create: `shared/skills/*/evals/evals.json` for the 12 skills
- Create: `shared/skills/*/evals/lifecycle-review.json` for the 12 skills

1. [T2] Add `eval-type` to each target `SKILL.md` frontmatter.

Use these values:

```text
product-director: encoded_preference
product-manager: encoded_preference
design: mixed
test-design: mixed
tech-lead: encoded_preference
developer: mixed
review: mixed
verify: mixed
qa: mixed
delivery-owner: encoded_preference
fix: mixed
consistency-audit: mixed
```

2. [T2] Extend or create each `evals/evals.json`.

For `encoded_preference`, add top-level `eval_type`, `preference_anchors`, and per-case `expected_anchors`.

For `mixed`, add top-level `eval_type`, `preference_anchors`, `grader_dimensions`, and per-case `expected_anchors` plus `run_modes: ["with_skill", "without_skill"]`.

Keep existing `expected_output`, `files`, and `expectations` fields so `tests/test-standard-chain-skill-evals.sh` remains compatible.

3. [T2] Create each `evals/lifecycle-review.json`.

Use `decision: "optimize"` for this first pass unless empirical with/without and fidelity data already exists. Record that the framework metadata is ready and first empirical lifecycle run is still required before any `retain` or `retire` decision.

Example shape:

```json
{
  "skill_name": "developer",
  "eval_type": "mixed",
  "review_date": "2026-04-23",
  "decision": "optimize",
  "decision_label": "优化",
  "evidence_refs": [
    "shared/skills/developer/SKILL.md",
    "shared/skills/developer/evals/evals.json",
    "shared/reference/Skill能力有效性标准.md"
  ],
  "capability_uplift": {
    "measurement_status": "needs_empirical_baseline",
    "with_avg": null,
    "without_avg": null,
    "uplift": null,
    "next_run": "Run with_skill and without_skill modes through the local eval runner before retain/retire."
  },
  "encoded_preference": {
    "measurement_status": "anchors_defined_needs_fidelity_run",
    "anchor_count": 6,
    "eval_count": 3,
    "fidelity": null,
    "next_run": "Grade expected_anchors across all eval outputs before retain/retire."
  }
}
```

4. [T2] Run lifecycle and existing eval contract tests.

Run: `bash tests/test-skill-lifecycle-eval-framework.sh`

Expected: PASS after all 12 skills are updated.

Run: `bash tests/test-standard-chain-skill-evals.sh`

Expected: PASS, proving existing standard-chain eval contract remains compatible.

### Task 3: skill-harness D9 Guidance [T3]

Context: `skill-harness` remains read-only and human-readable by default. This task wires D9 into its audit guidance and method reference without turning lifecycle review JSON into a mandatory machine fact source for every audit.

Files:
- Modify: `shared/skills/skill-harness/SKILL.md`
- Modify: `shared/skills/skill-harness/references/audit-method.md`
- Modify: `tests/test-skill-lifecycle-eval-framework.sh`

1. [T3] Extend the lifecycle framework test for skill-harness routing.

Add assertions that `shared/skills/skill-harness/SKILL.md` and `shared/skills/skill-harness/references/audit-method.md` mention `D9 存在合理性`, `Skill能力有效性标准.md`, `eval-type`, and `lifecycle-review.json`.

2. [T3] Run the test to verify RED.

Run: `bash tests/test-skill-lifecycle-eval-framework.sh`

Expected: FAIL on missing skill-harness D9 routing text.

3. [T3] Update `shared/skills/skill-harness/SKILL.md`.

Add a short D9 audit clause to the default flow or references section:

```markdown
When auditing first-party skills for lifecycle readiness, include D9 存在合理性 checks from `shared/reference/Skill能力有效性标准.md`: `eval-type`, matching `evals/evals.json`, required anchors or grader dimensions, latest `evals/lifecycle-review.json`, and evidence-backed retain/optimize/retire routing.
```

4. [T3] Update `shared/skills/skill-harness/references/audit-method.md`.

Add D9 to the audit expectations and explain that D9 findings usually map to `Verification` and `Evolution` unless a specific runtime field has a machine consumer.

5. [T3] Run targeted skill-harness tests.

Run: `bash tests/test-skill-lifecycle-eval-framework.sh`

Expected: PASS.

Run: `bash tests/test-skill-harness-contract.sh`

Expected: PASS.

Run: `bash tests/test-skill-harness-gates.sh`

Expected: PASS.

Run: `bash tests/test-skill-harness-responsibility-contract.sh`

Expected: PASS.

### Task 4: Validation, Run-All Wiring, And Closeout Evidence [T4]

Context: This task connects the new deterministic test to repository regression orchestration and records small-chain evidence. It does not archive until verify-change passes.

Files:
- Modify: `tests/run-all.sh`
- Modify: `docs/skill-lifecycle-eval/2026-04-23-capability-eval-framework/tasks.md`
- Create: `docs/skill-lifecycle-eval/2026-04-23-capability-eval-framework/verify-change-report.md`

1. [T4] Add the new test to `tests/run-all.sh`.

Add `tests/test-skill-lifecycle-eval-framework.sh` to `SYNTAX_SHELL_FILES` and `FULL_TESTS` near the other skill quality and standard-chain eval tests.

2. [T4] Run final targeted verification.

Run these commands and record their results in `verify-change-report.md`:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-lifecycle-eval/2026-04-23-capability-eval-framework/tasks.md docs/skill-lifecycle-eval/2026-04-23-capability-eval-framework/plan.md
bash tests/test-skill-lifecycle-eval-framework.sh
bash tests/test-skill-quality-standard.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-skill-harness-contract.sh
bash tests/test-skill-harness-gates.sh
bash tests/test-skill-harness-responsibility-contract.sh
bash tests/run-all.sh --quick
git diff --check
```

Expected: every command exits 0.

3. [T4] Update `tasks.md` checkboxes only after task evidence is available.

Change `- [ ]` to `- [x]` for T1-T4 after each task has passed its task-specific verification. Do not mark a task complete before its AC command passes.

4. [T4] Create `verify-change-report.md`.

Include:

```markdown
# Verify Change Report

## Status
- PASS

## CRITICAL
- none

## WARNING
- First empirical lifecycle eval runs are still required before any skill can move from optimize to retain/retire.

## SUGGESTION
- Use `tools/eval/scripts/run_standard_chain_local_eval.py` as the first empirical runner for the metadata seeded here.

## Evidence
- [commands and exact PASS summaries]
```

5. [T4] Run small-chain consistency after updating task checkboxes.

Run: `python3 tools/community/check_task_plan_consistency.py docs/skill-lifecycle-eval/2026-04-23-capability-eval-framework/tasks.md docs/skill-lifecycle-eval/2026-04-23-capability-eval-framework/plan.md`

Expected: PASS.
