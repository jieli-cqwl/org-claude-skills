# Test Signal Governance Phase 2-4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggressively reduce low-value test assets so the repository keeps only tests that protect real user paths, release paths, role/contract boundaries, upstream mirror integrity, or runtime gates.

**Architecture:** Treat `obra/superpowers` as the default testing practice benchmark: fewer tests, more real behavior, explicit slow-lane integration checks, and no broad prose-freeze gates. Add only repository-specific coverage where this repo has unique risks: first-party role handoffs, canonical artifacts, completion gates, runtime install/sync, and `community/superpowers` mirror integrity.

**Tech Stack:** Bash, Python 3, jq, ripgrep (`rg`), GitHub Actions YAML, existing shell/Python test suite, existing `tests/run-all.sh` tier runner.

---

## Operating Rule

Every test starts as a delete candidate. Keep, rewrite, or move it only when it can answer all four questions:

1. Which real user path, release path, role/contract boundary, mirror boundary, or runtime gate does it protect?
2. What real quality risk does a failure represent?
3. Why is that risk not already covered by a harder test?
4. Which gate should own it: `quick`, `full`, `release`, or manual/local-only?

Allowed dispositions:

- `Keep`: protects a critical real path with low cost and actionable failure.
- `Rewrite`: risk is real, but current assertion shape is brittle or prose-heavy.
- `Move`: useful but too slow, too broad, or too static for `quick`.
- `Delete`: cannot prove real risk, duplicates stronger coverage, or only freezes prose.

## File Structure

- Create `docs/reports/test-signal-inventory.md`
  - Owns the test asset disposition matrix.
  - Records why each first-batch test is kept, rewritten, moved, or deleted.
  - Prevents future context loss and makes deletions reviewable.
- Modify `tests/run-all.sh`
  - Convert ad-hoc quick exclusions into explicit classifier predicates that reflect real gate ownership.
  - Remove deleted tests from `SYNTAX_SHELL_FILES` and `FULL_TESTS`.
  - Add move-only tests to the quick exclusion classifier without treating `full` as a junk drawer.
- Modify `tests/test-run-all-runner-contract.sh`
  - Stop freezing exact global step counts.
  - Test tier invariants: `release` and `full` cover comprehensive gates, `quick` excludes declared slow/static candidates, deleted tests are absent from every executable plan.
- Delete first-batch low-value tests:
  - `tests/test-doc-management-rule-contract.sh`
  - `tests/test-skill-refiner-agent-loop.sh`
  - `tests/test-product-capability-structure-redesign.sh`
- Move first-batch quick noise to full/release-only:
  - `tests/test-product-eval-contract.sh`
  - `tests/test-product-context-signal-quality.sh`
  - `tests/test-developer-process-compliance-contract.sh`
  - `tests/test-standard-chain-skill-structure.sh`
  - `tests/test-release-metadata.sh`
- Rewrite first-batch brittle contract tests:
  - `tests/test-review-fix-redesign-contract.sh`
  - `tests/test-product-role-split-contract.sh`
  - `tests/test-product-stability-guidance-contract.sh`

## Success Criteria

1. `docs/reports/test-signal-inventory.md` exists and records the first batch with `Keep / Rewrite / Move / Delete` disposition, protected risk, gate owner, and evidence.
2. Deleted tests are absent from `tests/run-all.sh` syntax checks and executable plans.
3. Moved tests are absent from `bash tests/run-all.sh --quick --list` but present in `--full --list` and `--release --list`.
4. Rewritten tests stop locking broad prose and instead check executable schema, manifest, fixture, or policy behavior.
5. `tests/test-run-all-runner-contract.sh` asserts tier invariants without exact global `steps=N` coupling.
6. `bash tests/run-all.sh --quick --list` shows a smaller, higher-signal quick plan than the current 98-step quick plan.
7. Targeted changed tests pass.
8. `bash tests/run-all.sh --quick` passes.
9. A pipefail-safe profile run succeeds and shows no install/runtime-heavy or deleted prose tests in quick.
10. No deleted test is merely removed from execution while still left as dead test code.

---

## Task 1: Write the first-batch disposition matrix

**Files:**
- Create: `docs/reports/test-signal-inventory.md`
- Test: `test -f docs/reports/test-signal-inventory.md && rg -n "test-doc-management-rule-contract|test-superpowers-upstream-fidelity|Disposition" docs/reports/test-signal-inventory.md`

- [ ] **Step 1: Create the report with the hard deletion rule**

Write `docs/reports/test-signal-inventory.md` with this content:

```markdown
# Test Signal Inventory

This report records test asset disposition for the test signal governance cleanup.

## Decision rule

Every test starts as a delete candidate. A test is kept only when it protects a real user path, release path, role/contract boundary, upstream mirror boundary, or runtime gate, and when its failure is actionable.

## Disposition values

- Keep: protect a critical real path with low cost and actionable failure.
- Rewrite: risk is real, but the current test shape freezes prose or duplicates weak checks.
- Move: useful outside quick; belongs in full/release or manual/local-only validation.
- Delete: no proven real risk, duplicate of harder coverage, or prose freeze without a consumer contract.

## First execution batch

| Test file | Disposition | Gate owner | Protected risk | Evidence | Action |
| --- | --- | --- | --- | --- | --- |
| `tests/test-superpowers-upstream-fidelity.sh` | Keep | quick/full/release | `community/superpowers` mirror pollution or local overlay drift | Runs upstream fidelity checker with negative fixtures | Keep in quick |
| `tests/test-context-contract-validator.sh` | Keep | quick/full/release | Invalid canonical refs or context registry drift pass validation | Runs validator with valid and invalid fixtures | Keep in quick |
| `tests/test-context-contract-hook.sh` | Keep | quick/full/release | Runtime hooks fail to block bad context or unsafe handler paths | Runs hook wrapper and negative cases | Keep in quick |
| `tests/test-standard-chain-readiness-gate.sh` | Keep | quick/full/release | Standard-chain closeout passes with missing or failed artifacts | Runs readiness gate against golden and mutated fixtures | Keep in quick |
| `tests/test-release-metadata.sh` | Move | release | Release metadata, changelog, version, or notes drift | Runs release metadata validator | Exclude from quick; run release-specific only |
| `tests/test-doc-management-rule-contract.sh` | Delete | none | Not proven | Freezes rule-document prose with no executable validator path | Delete file and runner references |
| `tests/test-skill-refiner-agent-loop.sh` | Delete | none | Not proven | Freezes skill-refiner prose while harder completion/evidence gates exist | Delete file and runner references |
| `tests/test-product-capability-structure-redesign.sh` | Delete | none | Not proven | Duplicates product role/stability structure through broad prose checks | Delete file and runner references |
| `tests/test-product-eval-contract.sh` | Move | full/release | Eval assets or runner output contract drift | Useful static/eval asset check, not a quick user-path gate | Exclude from quick |
| `tests/test-product-context-signal-quality.sh` | Move | full/release | Product prompt signal quality drift | Mostly prose/noise scan; not quick-critical | Exclude from quick pending rewrite/delete |
| `tests/test-developer-process-compliance-contract.sh` | Move | full/release | Developer process guidance drift | Mostly static prose checks; runtime proof tests are harder | Exclude from quick pending rewrite/delete |
| `tests/test-standard-chain-skill-structure.sh` | Move | full/release | Standard-chain role/contract structure drift | Static skill-structure check; validators cover harder runtime boundaries | Exclude from quick pending rewrite/delete |
| `tests/test-review-fix-redesign-contract.sh` | Rewrite | full/release until rewritten | Review loop loses fail-close or structured findings | Current test freezes skill prose; risk should be covered by fixture/policy behavior | Shrink to executable contract checks |
| `tests/test-product-role-split-contract.sh` | Rewrite | full/release until rewritten | Product Director/Manager boundary drift | Current test mixes real manifest/schema checks with prose freezes | Keep only schema/manifest/lock-field checks |
| `tests/test-product-stability-guidance-contract.sh` | Rewrite | full/release until rewritten | Product Director output templates or completion gate drift | Current test mixes jq manifest checks with broad prose freezes | Keep only template/manifest/gate checks |

## Current first-batch target

- Delete 3 files.
- Move 5 files out of quick.
- Rewrite 3 files to executable contracts.
- Keep hard-signal runtime/mirror/context tests in quick.
```

- [ ] **Step 2: Verify the report exists and contains required entries**

Run:

```bash
test -f docs/reports/test-signal-inventory.md
rg -n "Disposition|test-doc-management-rule-contract|test-superpowers-upstream-fidelity|test-product-role-split-contract" docs/reports/test-signal-inventory.md
```

Expected: command exits 0 and prints matching lines.

---

## Task 2: Lock runner behavior before deleting or moving tests

**Files:**
- Modify: `tests/test-run-all-runner-contract.sh`
- Test: `tests/test-run-all-runner-contract.sh`

- [ ] **Step 1: Replace exact step-count assertions with relational tier assertions**

Edit `tests/test-run-all-runner-contract.sh` so it no longer asserts exact global counts such as:

```bash
assert_contains "steps=114" "$full_plan" "full plan"
assert_contains "excluded_count=16" "$quick_plan" "quick plan"
assert_contains "steps=114" "$release_plan" "release plan"
```

Replace them with checks that parse counts and assert relationships:

```bash
full_steps="$(grep '^steps=' <<<"$full_plan" | cut -d= -f2)"
quick_steps="$(grep '^steps=' <<<"$quick_plan" | cut -d= -f2)"
release_steps="$(grep '^steps=' <<<"$release_plan" | cut -d= -f2)"
quick_excluded_count="$(grep '^excluded_count=' <<<"$quick_plan" | cut -d= -f2)"

[ "$full_steps" -gt "$quick_steps" ] || fail "full plan should have more steps than quick plan"
[ "$release_steps" -eq "$full_steps" ] || fail "release plan should match full plan step count"
[ "$quick_excluded_count" -ge 17 ] || fail "quick excluded count should not shrink below the post-cleanup floor"
```

- [ ] **Step 2: Add assertions for deleted tests being absent from all executable plans**

Add this helper:

```bash
assert_absent_from_all_plans() {
  local test_file="$1"

  assert_not_contains "$test_file" "$quick_plan" "quick plan"
  assert_not_contains "$test_file" "$full_plan" "full plan"
  assert_not_contains "$test_file" "$release_plan" "release plan"
}
```

After `release_plan` is assigned, add:

```bash
assert_absent_from_all_plans "tests/test-doc-management-rule-contract.sh"
assert_absent_from_all_plans "tests/test-skill-refiner-agent-loop.sh"
assert_absent_from_all_plans "tests/test-product-capability-structure-redesign.sh"
```

- [ ] **Step 3: Add assertions for moved tests being full/release-only**

After quick/full/release plans are assigned, add:

```bash
for moved_test in \
  "tests/test-product-eval-contract.sh" \
  "tests/test-product-context-signal-quality.sh" \
  "tests/test-developer-process-compliance-contract.sh" \
  "tests/test-standard-chain-skill-structure.sh" \
  "tests/test-release-metadata.sh"
do
  assert_contains "excluded: $moved_test" "$quick_plan" "quick plan"
  assert_not_contains "bash $ROOT/$moved_test" "$quick_plan" "quick plan"
  assert_contains "bash $ROOT/$moved_test" "$full_plan" "full plan"
  assert_contains "bash $ROOT/$moved_test" "$release_plan" "release plan"
done
```

- [ ] **Step 4: Run the runner contract and confirm RED**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
```

Expected: FAIL because `tests/run-all.sh` still includes deleted tests and does not yet move the five move-only tests out of quick.

---

## Task 3: Remove deleted tests from runner and filesystem

**Files:**
- Delete: `tests/test-doc-management-rule-contract.sh`
- Delete: `tests/test-skill-refiner-agent-loop.sh`
- Delete: `tests/test-product-capability-structure-redesign.sh`
- Modify: `tests/run-all.sh`
- Test: `tests/test-run-all-runner-contract.sh`

- [ ] **Step 1: Remove deleted tests from `SYNTAX_SHELL_FILES`**

In `tests/run-all.sh`, delete these entries from `SYNTAX_SHELL_FILES`:

```bash
  "tests/test-doc-management-rule-contract.sh"
  "tests/test-skill-refiner-agent-loop.sh"
  "tests/test-product-capability-structure-redesign.sh"
```

- [ ] **Step 2: Remove deleted tests from `FULL_TESTS`**

In `tests/run-all.sh`, delete these entries from `FULL_TESTS`:

```bash
  "tests/test-doc-management-rule-contract.sh"
  "tests/test-skill-refiner-agent-loop.sh"
  "tests/test-product-capability-structure-redesign.sh"
```

- [ ] **Step 3: Remove deleted tests from `is_static_wording_test`**

In `tests/run-all.sh`, remove these case alternatives from `is_static_wording_test()`:

```bash
"tests/test-skill-refiner-agent-loop.sh"
"tests/test-product-capability-structure-redesign.sh"
"tests/test-doc-management-rule-contract.sh"
```

Keep still-existing rewrite candidates in the classifier until they are rewritten or moved:

```bash
"tests/test-product-stability-guidance-contract.sh"
"tests/test-standard-chain-cutover.sh"
"tests/test-product-role-split-contract.sh"
"tests/test-review-fix-redesign-contract.sh"
```

- [ ] **Step 4: Delete the files**

Run:

```bash
rm tests/test-doc-management-rule-contract.sh tests/test-skill-refiner-agent-loop.sh tests/test-product-capability-structure-redesign.sh
```

Expected: files are removed from the worktree.

- [ ] **Step 5: Verify no runner references remain**

Run:

```bash
if rg -n "test-doc-management-rule-contract|test-skill-refiner-agent-loop|test-product-capability-structure-redesign" tests/run-all.sh; then
  exit 1
fi
```

Expected: command exits 0 because no deleted test remains referenced.

- [ ] **Step 6: Run runner contract toward GREEN**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
```

Expected: may still FAIL until Task 4 moves full-only tests out of quick.

---

## Task 4: Move first-batch quick noise to full/release only

**Files:**
- Modify: `tests/run-all.sh`
- Test: `tests/test-run-all-runner-contract.sh`

- [ ] **Step 1: Add a `is_full_only_signal_test` classifier**

Insert after `is_static_wording_test()`:

```bash
is_full_only_signal_test() {
  case "$1" in
    "tests/test-product-eval-contract.sh"|"tests/test-product-context-signal-quality.sh"|"tests/test-developer-process-compliance-contract.sh"|"tests/test-standard-chain-skill-structure.sh"|"tests/test-release-metadata.sh")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
```

- [ ] **Step 2: Update quick skip logic**

Replace:

```bash
  if is_release_heavy_test "$test_file" || is_static_wording_test "$test_file"; then
    return 0
  fi
```

with:

```bash
  if is_release_heavy_test "$test_file" || is_static_wording_test "$test_file" || is_full_only_signal_test "$test_file"; then
    return 0
  fi
```

- [ ] **Step 3: Run runner contract to GREEN**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
```

Expected: PASS.

- [ ] **Step 4: Verify moved tests are absent from quick and present in full/release**

Run:

```bash
quick_plan="$(bash tests/run-all.sh --quick --list)"
full_plan="$(bash tests/run-all.sh --full --list)"
release_plan="$(bash tests/run-all.sh --release --list)"
for test_file in \
  tests/test-product-eval-contract.sh \
  tests/test-product-context-signal-quality.sh \
  tests/test-developer-process-compliance-contract.sh \
  tests/test-standard-chain-skill-structure.sh \
  tests/test-release-metadata.sh
do
  grep -F "excluded: $test_file" <<<"$quick_plan"
  ! grep -F "bash $(pwd)/$test_file" <<<"$quick_plan"
  grep -F "bash $(pwd)/$test_file" <<<"$full_plan"
  grep -F "bash $(pwd)/$test_file" <<<"$release_plan"
done
```

Expected: command exits 0.

---

## Task 5: Rewrite review-fix contract away from prose freeze

**Files:**
- Modify: `tests/test-review-fix-redesign-contract.sh`
- Test: `tests/test-review-fix-redesign-contract.sh`

- [ ] **Step 1: Identify hard checks to retain**

Keep checks that prove executable or machine-consumed contract shape:

```text
- script/manifest/hook registry paths exist when present
- scenario fixture tests execute
- schema or JSON fields used by downstream gates exist
- fail-close or review result policy is validated by executable fixture
```

Delete checks that only prove prose wording exists in `SKILL.md`, such as exact words for stash, AskUserQuestion, verdict, line-number phrasing, or narrative process labels unless a downstream script parses them.

- [ ] **Step 2: Replace broad `assert_contains` prose blocks with executable scenario delegation**

Ensure the test contains this hard dependency instead of repeating review prose:

```bash
bash "$ROOT/tests/test-review-fix-redesign-scenarios.sh"
```

Expected role: `test-review-fix-redesign-contract.sh` becomes a light wrapper for structural file existence plus executable scenarios, not a skill prose freeze.

- [ ] **Step 3: Run RED/GREEN locally**

Run before final edits if practical:

```bash
bash tests/test-review-fix-redesign-contract.sh
```

Expected before rewrite: PASS on old prose-freeze behavior.

After deleting prose locks and delegating to scenarios, run:

```bash
bash tests/test-review-fix-redesign-contract.sh
bash tests/test-review-fix-redesign-scenarios.sh
```

Expected: both PASS.

- [ ] **Step 4: Decide whether it can return to quick**

If the rewritten test is fast and behavior-backed, remove `tests/test-review-fix-redesign-contract.sh` from `is_static_wording_test()`. Otherwise keep it full/release-only and record that in `docs/reports/test-signal-inventory.md`.

---

## Task 6: Rewrite product role/stability tests to schema and gate checks

**Files:**
- Modify: `tests/test-product-role-split-contract.sh`
- Modify: `tests/test-product-stability-guidance-contract.sh`
- Modify: `docs/reports/test-signal-inventory.md`
- Test: both modified product tests

- [ ] **Step 1: For product role split, keep only machine-consumed boundaries**

In `tests/test-product-role-split-contract.sh`, retain checks for:

```text
- product-director and product-manager script manifests
- hook registry completion gate ownership
- template/schema fields that encode locked Director fields
- explicit absence of legacy `/product` entry only if an actual runtime registry would consume it
```

Remove broad `SKILL.md` or reference prose checks that only assert wording, headings, or recommendation phrasing.

- [ ] **Step 2: For product stability, keep only template/manifest/gate checks**

In `tests/test-product-stability-guidance-contract.sh`, retain checks for:

```text
- `shared/skills/product-director/templates/brief.template.json`
- `shared/skills/product-director/templates/phase-prd.template.json`
- `shared/skills/product-director/scripts/completion_check.sh`
- script manifest and hook registry jq checks
- jq checks for locked fields and required JSON shape
```

Remove broad conversation-guide, problem-guide, success-guide, scope-guide, risks-guide, and phase-guide prose freezes unless a script or schema parses the exact content.

- [ ] **Step 3: Run product tests**

Run:

```bash
bash tests/test-product-role-split-contract.sh
bash tests/test-product-stability-guidance-contract.sh
```

Expected: both PASS with fewer prose assertions.

- [ ] **Step 4: Update disposition matrix**

In `docs/reports/test-signal-inventory.md`, update the two product rows:

```markdown
| `tests/test-product-role-split-contract.sh` | Keep | full/release or quick if fast | Product Director/Manager machine boundary drift | Manifest, hook registry, and JSON template checks | Prose locks removed |
| `tests/test-product-stability-guidance-contract.sh` | Keep | full/release or quick if fast | Product Director output template or completion gate drift | jq manifest/template checks | Prose locks removed |
```

---

## Task 7: Re-evaluate quick after rewrites and choose return-to-quick candidates

**Files:**
- Modify: `tests/run-all.sh`
- Modify: `tests/test-run-all-runner-contract.sh`
- Modify: `docs/reports/test-signal-inventory.md`
- Test: runner contract and quick list

- [ ] **Step 1: List quick, full, and release plans**

Run:

```bash
bash tests/run-all.sh --quick --list > /tmp/test-signal-quick-after.txt
bash tests/run-all.sh --full --list > /tmp/test-signal-full-after.txt
bash tests/run-all.sh --release --list > /tmp/test-signal-release-after.txt
```

Expected: all commands exit 0.

- [ ] **Step 2: Check rewritten tests for quick eligibility**

A rewritten test may return to quick only if all are true:

```text
- It no longer freezes broad prose.
- It runs quickly enough for local feedback.
- It protects a real contract that often breaks during normal edits.
- It produces actionable failure output.
```

If eligible, remove the test from `is_static_wording_test()` and add runner contract assertions that it appears in quick.

If not eligible, keep it full/release-only and record the reason in the matrix.

- [ ] **Step 3: Run runner contract**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
```

Expected: PASS.

---

## Task 8: Run targeted and quick verification

**Files:**
- Test-only task

- [ ] **Step 1: Run changed targeted tests**

Run:

```bash
bash tests/test-run-all-runner-contract.sh
bash tests/test-review-fix-redesign-contract.sh
bash tests/test-review-fix-redesign-scenarios.sh
bash tests/test-product-role-split-contract.sh
bash tests/test-product-stability-guidance-contract.sh
```

Expected: all PASS.

- [ ] **Step 2: Run syntax and shellcheck through quick gate**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: PASS.

- [ ] **Step 3: Run pipefail-safe quick profile**

Run:

```bash
set -o pipefail; bash tests/run-all.sh --quick --profile 2>&1 | tee /tmp/org-run-all-quick-profile-phase2-4.log
```

Expected: PASS; no `[profile] FAIL` lines.

- [ ] **Step 4: Print slowest quick steps**

Run:

```bash
rg '^\[profile\]' /tmp/org-run-all-quick-profile-phase2-4.log | sort -nr -k3 | head -20
```

Expected: no deleted tests, no install/runtime-heavy tests, and fewer static prose tests than the previous 98-step quick gate.

---

## Task 9: Final diff and evidence review

**Files:**
- Test-only task

- [ ] **Step 1: Confirm deleted files are gone**

Run:

```bash
test ! -e tests/test-doc-management-rule-contract.sh
test ! -e tests/test-skill-refiner-agent-loop.sh
test ! -e tests/test-product-capability-structure-redesign.sh
```

Expected: command exits 0.

- [ ] **Step 2: Confirm no runner references deleted files**

Run:

```bash
if rg -n "test-doc-management-rule-contract|test-skill-refiner-agent-loop|test-product-capability-structure-redesign" tests/run-all.sh tests/test-run-all-runner-contract.sh; then
  exit 1
fi
```

Expected: command exits 0.

- [ ] **Step 3: Review changed files**

Run:

```bash
git diff --stat
git diff -- tests/run-all.sh tests/test-run-all-runner-contract.sh tests/test-review-fix-redesign-contract.sh tests/test-product-role-split-contract.sh tests/test-product-stability-guidance-contract.sh docs/reports/test-signal-inventory.md
```

Expected: diff matches this plan only: matrix creation, runner tier cleanup, first-batch deletion/move/rewrite, and verification updates.

---

## Self-Review Notes

- Spec coverage: the plan implements the aggressive default-delete strategy, superpowers-style behavior benchmark, first-batch deletion, quick/full/release cleanup, rewrite of brittle prose tests, and verification evidence.
- Placeholder scan: no TBD/TODO placeholders remain.
- Type/identifier consistency: all referenced paths match current repository paths observed in `tests/run-all.sh` and first-batch inventory.
- Scope guard: this plan intentionally handles the first execution batch. It does not claim all 128 shell tests are fully cleaned. Later batches should repeat the same disposition rule using the inventory matrix.
