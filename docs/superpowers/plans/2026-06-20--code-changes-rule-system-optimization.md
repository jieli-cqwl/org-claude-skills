# Code Changes Rule System Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the Code Changes error-handling rule from prohibition-only guidance into a positive failure-semantics contract, with semantic regression coverage and no runtime-rule architecture redesign.

**Architecture:** Keep the current root-rule/reference split. Add one semantic contract check to the existing Code Changes rule shape test, make one minimal root-rule wording change, and verify that `shared/reference/error-handling.md` already carries the detailed continuation, fallback, retry, cleanup, and partial-success model.

**Tech Stack:** Bash test gates, embedded Python semantic checks, Markdown runtime rules and references, existing install/runtime smoke tests, and repository-local assertion-boundary checker.

## Global Constraints

- Communicate and report in Chinese.
- Do not rewrite the whole `shared/rules/code-changes.md` file.
- Do not redesign `shared/rules/`, `shared/reference/`, `shared/assistant.md`, install behavior, or runtime rendering.
- Do not freeze exact natural-language prose in tests.
- Do not use shell `assert_present`, `assert_absent`, `assert_any_present`, direct `grep`, or direct `rg` to lock Skill, Rule, Reference, or Agent Markdown body wording.
- Keep `shared/rules/code-changes.md` flat, with one lead sentence, no `##` headings, 18 to 26 bullets, and exactly one `- Test:` bullet.
- Treat `docs/reports/code-changes-rule-system-optimization-2026-06-19.md` as the design rationale, not as runtime truth.
- Do not touch unrelated dirty files. Before execution, inspect `git status --short` and preserve unrelated user changes.
- Do not commit unless the user explicitly requests commit work in the execution turn.

---

## Source Of Truth

- Design rationale: `docs/reports/code-changes-rule-system-optimization-2026-06-19.md`
- Root rule to change: `shared/rules/code-changes.md`
- Detailed reference to preserve: `shared/reference/error-handling.md`
- Shape and semantic test file: `tests/test-runtime-contract-catalog.sh`
- Test-boundary guard: `tests/test-test-assertion-boundary-contract.sh`
- Runtime smoke: `tests/test-install-runtime-smoke.sh`

## File Responsibility Map

- Modify `tests/test-runtime-contract-catalog.sh`: add a concept-level Code Changes check that fails when failure handling is expressed only as prohibitions and passes when the rule requires observable failure semantics plus no fake success.
- Modify `shared/rules/code-changes.md`: replace the current error-handling guardrail bullet with a positive-first failure-semantics bullet.
- Inspect `shared/reference/error-handling.md`: confirm it already contains the detailed model for fallback, downgrade, default values, exhausted retries, cleanup, and partial success. Only modify it if current content has drifted from that contract.
- Leave `shared/assistant.md` unchanged unless a test proves a missing or stale reference route. Current evidence says no assistant entry change is needed.

## Task 1: Add Failing Semantic Regression Test

**Files:**
- Modify: `tests/test-runtime-contract-catalog.sh`

**Interfaces:**
- Consumes: current `shared/rules/code-changes.md`
- Produces: a semantic check named `failure-semantics-positive-contract` inside the existing Code Changes Python rule-shape block.

- [ ] **Step 1: Inspect current test block**

Run:

```bash
sed -n '80,180p' tests/test-runtime-contract-catalog.sh
```

Expected: output includes the Python block that reads `shared/rules/code-changes.md`, validates title, flat shape, bullet count, reference set, and `semantic_checks`.

- [ ] **Step 2: Add the failing semantic check**

Inside the Code Changes Python block, immediately after `text = rule.read_text(encoding="utf-8")`, add:

```python
lower_text = text.lower()
```

Then extend the existing `semantic_checks = [` list by adding this tuple after `existing-artifact-constraint-before-delete`:

```python
    (
        "failure-semantics-positive-contract",
        ("failure semantics" in lower_text)
        and any(
            term in lower_text
            for term in (
                "propagate",
                "explicit failure",
                "failure/result",
                "partial failure",
                "partial-failure",
            )
        )
        and any(
            term in lower_text
            for term in (
                "observable",
                "visible",
                "failure remains",
                "failure state",
            )
        )
        and any(
            term in lower_text
            for term in (
                "fake success",
                "report fake success",
                "convert failure into success",
            )
        ),
    ),
```

Rationale: this checks concepts, not one frozen sentence. The current rule already has `observable failure states` and `convert failure into success`, but it does not state `failure semantics` or a positive action such as propagation, explicit failure/result, or visible partial failure.

- [ ] **Step 3: Prove the new test fails for the current rule**

Run:

```bash
bash tests/test-runtime-contract-catalog.sh
```

Expected: command fails with a message containing:

```text
failure-semantics-positive-contract
```

If the command fails for any other reason, stop and classify the failure as either an unrelated pre-existing workspace issue or a real impact of this test change before proceeding.

- [ ] **Step 4: Run the test assertion-boundary checker on the changed test file**

Run:

```bash
python3 tools/community/check_test_signal_assertions.py --repo-root "$PWD" --scan-root tests/test-runtime-contract-catalog.sh
```

Expected: exits 0. If it flags the new check as low-signal prose locking, replace the check with broader concept clusters rather than exact sentence matching.

## Task 2: Rewrite The Root Error-handling Bullet

**Files:**
- Modify: `shared/rules/code-changes.md`

**Interfaces:**
- Consumes: failing `failure-semantics-positive-contract` test from Task 1.
- Produces: one positive-first root bullet that preserves failure semantics and still forbids fake success.

- [ ] **Step 1: Inspect the current rule**

Run:

```bash
sed -n '1,80p' shared/rules/code-changes.md
```

Expected: output includes this current bullet:

```markdown
- Do not swallow errors, log-and-continue after failure, return fake defaults, or convert failure into success.
```

- [ ] **Step 2: Replace only the error-handling bullet**

Replace that bullet with:

```markdown
- Preserve failure semantics: propagate errors, return explicit failure/result states, or expose visible partial failure when the contract allows continuation; do not hide failed defaults or report fake success.
```

Do not change the lead sentence, bullet order, reference-route bullets, or self-test bullet in this task.

- [ ] **Step 3: Verify the root rule shape and semantic test now pass**

Run:

```bash
bash tests/test-runtime-contract-catalog.sh
```

Expected:

```text
[PASS] runtime contract inline
```

- [ ] **Step 4: Check line length and diff scope**

Run:

```bash
git diff -- shared/rules/code-changes.md tests/test-runtime-contract-catalog.sh
```

Expected:

- `shared/rules/code-changes.md` changes exactly one bullet.
- `tests/test-runtime-contract-catalog.sh` adds `lower_text` and one semantic tuple.
- No unrelated wording, structure, reference route, or install behavior changes appear in this diff.

## Task 3: Confirm Reference Layer Still Owns Detailed Error Semantics

**Files:**
- Inspect: `shared/reference/error-handling.md`
- Modify only if drift is found: `shared/reference/error-handling.md`

**Interfaces:**
- Consumes: new root bullet from Task 2.
- Produces: either a no-edit decision with evidence, or a narrow reference patch that restores missing detailed semantics.

- [ ] **Step 1: Inspect the reference**

Run:

```bash
sed -n '1,220p' shared/reference/error-handling.md
```

Expected: output includes these concepts:

- failure visible, diagnosable, and recoverable
- no packaging failure as success
- fallback, downgrade, and default values name valid conditions and preserve business semantics
- exhausted retries return visible failure or manual intervention
- failure logs include diagnostic context and exclude secrets
- cleanup on failure paths
- partial success exposes the resulting failure state
- no overall success after side-effect failure unless partial success is explicitly allowed and visible

- [ ] **Step 2: Decide whether reference edit is needed**

If all expected concepts are present, do not edit `shared/reference/error-handling.md`.

If any expected concept is missing because the file has drifted, add only the missing concept to the matching existing section:

```markdown
- Continue-after-failure is valid only for contract-defined partial success, best-effort noncritical side effects, cleanup, rollback, or documented degraded mode, and the result must still expose the failure state.
```

Do not create a new section and do not duplicate the root rule wording.

- [ ] **Step 3: Verify reference graph and decision rules**

Run:

```bash
bash tests/test-reference-decision-rules.sh
bash tests/test-reference-graph-hygiene.sh
```

Expected: both commands exit 0.

## Task 4: Prove Runtime Install And Test-boundary Integrity

**Files:**
- Verify: `shared/rules/code-changes.md`
- Verify: `shared/reference/error-handling.md`
- Verify: `tests/test-runtime-contract-catalog.sh`

**Interfaces:**
- Consumes: Tasks 1 through 3.
- Produces: current direct evidence that the runtime rule contract, reference graph, test-boundary contract, and install smoke path still pass.

- [ ] **Step 1: Run targeted rule/reference/runtime checks**

Run:

```bash
bash tests/test-runtime-contract-catalog.sh
bash tests/test-reference-decision-rules.sh
bash tests/test-reference-graph-hygiene.sh
bash tests/test-test-assertion-boundary-contract.sh
bash tests/test-install-runtime-smoke.sh
```

Expected: every command exits 0. `tests/test-runtime-contract-catalog.sh` prints `[PASS] runtime contract inline`.

- [ ] **Step 2: Run quick regression**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: exits 0. If unrelated dirty workspace changes cause a failure, capture the exact failing test and report it separately instead of expanding this task.

- [ ] **Step 3: Run whitespace and assertion-signal checks**

Run:

```bash
git diff --check -- tests/test-runtime-contract-catalog.sh shared/rules/code-changes.md shared/reference/error-handling.md
python3 tools/community/check_test_signal_assertions.py --repo-root "$PWD" --scan-root tests/test-runtime-contract-catalog.sh
```

Expected: both commands exit 0.

- [ ] **Step 4: Inspect final scope**

Run:

```bash
git diff -- tests/test-runtime-contract-catalog.sh shared/rules/code-changes.md shared/reference/error-handling.md
git status --short
```

Expected:

- In-scope diff is limited to the semantic test and the root error-handling bullet, plus `shared/reference/error-handling.md` only if Task 3 found drift.
- Unrelated dirty files remain unstaged and untouched.
- No `shared/assistant.md`, install script, runtime architecture, or community mirror file changed.

## Completion Criteria

The implementation is complete only when all of these are true:

- The new semantic test fails against the original prohibition-only root wording.
- The root rule expresses the positive failure-semantics contract.
- The root rule still forbids hidden defaults and fake success.
- `shared/reference/error-handling.md` remains the detailed owner for fallback, retry, cleanup, and partial-success nuance.
- `tests/test-runtime-contract-catalog.sh` passes after the root-rule change.
- `tests/test-test-assertion-boundary-contract.sh` passes, proving the new check did not violate the Markdown prose assertion boundary.
- `bash tests/run-all.sh --quick` passes, or any failure is proven unrelated and reported as blocking broader completion.

## Out Of Scope

- Full Code Changes rule rewrite.
- New eval harness for agent behavior.
- Runtime rule architecture redesign.
- Assistant entrypoint changes.
- Installation workflow changes.
- Community mirror changes.
- Commit, push, release, or local runtime install unless separately requested.

## Execution Handoff

Recommended execution mode: inline execution in the current session is sufficient because the file ownership is narrow and ordered. Use subagent-driven execution only if the user wants an independent reviewer for the semantic-test design before editing runtime rules.
