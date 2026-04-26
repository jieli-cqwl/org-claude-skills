# Small-Chain Closeout Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add deterministic automation for small-chain closeout after implementation, using PR auto-merge as the integration authority and archive only after merge evidence.

**Architecture:** Keep long-running model work out of hooks. Add a script helper that reads managed small-chain artifacts, validates gates, delegates PR state to `gh`, and reuses existing registry/archive helpers for lifecycle updates. Existing hooks remain enforcement-only.

**Tech Stack:** Python 3 standard library, bash tests, existing `runtime_yaml.py`, existing `check_task_plan_consistency.py`, existing `update_active_doc_scope.py`, git, GitHub CLI.

---

### Task 1: Closeout Automation Contract Tests [T1]

Context: This task defines the observable contract before implementation. The test must use temporary fixtures and a fake `gh` executable so it does not depend on network access or a real GitHub repository.

Files:
- Create: `tests/test-small-chain-closeout-automation.sh`
- Read: `tools/community/check_task_plan_consistency.py`
- Read: `tools/community/update_active_doc_scope.py`

1. [T1] Write the failing shell test

Create `tests/test-small-chain-closeout-automation.sh` with this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Fq "$pattern" "$file" || fail "missing pattern: $pattern"
}

copy_runtime() {
  local target="$1"
  mkdir -p "$target/tools/community" "$target/contracts" "$target/docs"
  cp "$ROOT/tools/community/runtime_yaml.py" "$target/tools/community/runtime_yaml.py"
  cp "$ROOT/tools/community/check_task_plan_consistency.py" "$target/tools/community/check_task_plan_consistency.py"
  cp "$ROOT/tools/community/update_active_doc_scope.py" "$target/tools/community/update_active_doc_scope.py"
  cp "$ROOT/tools/community/validate_context_contract.py" "$target/tools/community/validate_context_contract.py"
  cp "$ROOT/tools/community/canonical_ref_resolver.py" "$target/tools/community/canonical_ref_resolver.py"
  cp "$ROOT/contracts/context-artifact-ownership.yaml" "$target/contracts/context-artifact-ownership.yaml"
}
```

2. [T1] Add fixture creation for a managed small-chain workset

Append fixture setup that creates:

```text
contracts/active-doc-scope.yaml
docs/sample-feature/worklog.md
docs/sample-feature/CHANGELOG.md
docs/sample-feature/2026-04-26-sample/design.md
docs/sample-feature/2026-04-26-sample/tasks.md
docs/sample-feature/2026-04-26-sample/plan.md
docs/sample-feature/2026-04-26-sample/verify-change-report.md
```

The valid fixture must use checked tasks, a matching `[T1]` plan step, and a verify report whose Status is PASS and CRITICAL is `none`.

3. [T1] Add fake `gh` coverage

Add a fake `gh` script under `$TMP_DIR/bin/gh` that records commands to `$TMP_DIR/gh.log` and returns:

```bash
https://github.example/org/repo/pull/42
```

for `gh pr create`, returns success for `gh pr merge --auto`, and returns `MERGED` for `gh pr view --json state --jq .state`.

4. [T1] Add assertions for fail-closed and happy paths

The test must assert:

```bash
if python3 "$ROOT/tools/community/small_chain_closeout.py" create-pr --repo-root "$fixture" --feature docs/sample-feature >/tmp/out 2>&1; then
  fail "missing helper should fail before implementation"
fi
```

After implementation, the same test will assert:

```bash
PATH="$TMP_DIR/bin:$PATH" python3 "$ROOT/tools/community/small_chain_closeout.py" create-pr --repo-root "$fixture" --feature docs/sample-feature >"$TMP_DIR/create-pr.out"
assert_present "decision: wait_for_merge" "$TMP_DIR/create-pr.out"
assert_present "gh pr create" "$TMP_DIR/gh.log"
assert_present "gh pr merge --auto" "$TMP_DIR/gh.log"
```

It must also mutate `tasks.md` to an incomplete state and assert `decision: block`, then restore the fixture and run `archive`, asserting that the workset moved under `docs/archive/sample-feature/2026-04-26-sample`, the registry entry became `legacy`, and `validate_context_contract.py` passes.

5. [T1] Run the test to verify RED

Run: `bash tests/test-small-chain-closeout-automation.sh`

Expected: FAIL because `tools/community/small_chain_closeout.py` is missing.

### Task 2: Deterministic Closeout Helper [T2]

Context: This task implements only mechanical state transitions. It must not call model runtimes, spawn agents, bypass `verify-change`, or merge directly into a protected branch.

Files:
- Create: `tools/community/small_chain_closeout.py`
- Modify: `tests/test-small-chain-closeout-automation.sh`

1. [T2] Create the CLI skeleton

Create `tools/community/small_chain_closeout.py` with:

```python
#!/usr/bin/env python3
"""Automate deterministic small-chain closeout gates."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from runtime_yaml import load_yaml
```

Add subcommands `status`, `create-pr`, and `archive`, each requiring `--repo-root` and `--feature`.

2. [T2] Implement fixed decision output

Add helpers that emit exactly:

```text
decision: block
reason: <reason>
path: <path>
expected: <expected>
actual: <actual>
next_action: <next_action>
```

for failures, and `decision: create_pr`, `decision: wait_for_merge`, `decision: archive`, or `decision: done` for successful route states.

3. [T2] Implement artifact loading and validation

Read `contracts/active-doc-scope.yaml`, locate one active entry for `--feature`, resolve `primary_workset_relpath`, and require these files:

```text
design.md
tasks.md
plan.md
verify-change-report.md
```

Run `tools/community/check_task_plan_consistency.py` through `subprocess.run`. Parse `tasks.md` and block if any task line matches `- [ ] T`.

4. [T2] Implement verify report parsing

Accept only reports with `## Status` containing `PASS` and `## CRITICAL` containing `none`. Block on missing report, `FAIL`, or any non-none CRITICAL content.

5. [T2] Implement PR auto-merge

For `create-pr`, call:

```bash
gh pr create --title "Small-chain closeout: <feature-name>" --body-file <generated temp body>
gh pr merge --auto --squash <pr-url>
```

Emit `decision: wait_for_merge` and `pr_url: <url>` when both commands succeed. Block with fixed output when `gh` is missing or returns non-zero.

6. [T2] Implement archive

For `archive`, require `gh pr view --json state --jq .state` to return `MERGED`, unless `--merged` is explicitly provided for local validated fixtures. Then:

```text
move docs/<feature>/<workset> -> docs/archive/<feature-name>/<workset>
copy docs/<feature>/worklog.md -> archived workset/worklog.md
append docs/<feature>/CHANGELOG.md
run tools/community/update_active_doc_scope.py archive
run tools/community/validate_context_contract.py
```

Emit `decision: done` and `archived_to: <archive-ref>`.

7. [T2] Run GREEN for targeted tests

Run: `bash tests/test-small-chain-closeout-automation.sh`

Expected: PASS.

8. [T2] Refactor for code rules

Keep `tools/community/small_chain_closeout.py` under 400 lines, functions at 5 or fewer parameters, and external calls behind short helpers with timeout and captured output.

Run: `python3 -m py_compile tools/community/small_chain_closeout.py`

Expected: exit 0.

### Task 3: Contract and Documentation Sync [T3]

Context: The behavior change must be visible where users and runtime contracts already learn the small-chain closeout route.

Files:
- Modify: `README.md`
- Modify: `contracts/small-chain.yaml`
- Modify: `contracts/superpowers-boundary.yaml`

1. [T3] Update small-chain contract

Add an `automation:` section to `contracts/small-chain.yaml` that states:

```yaml
automation:
  helper: tools/community/small_chain_closeout.py
  integration_policy: pr_auto_merge
  post_verify_route:
    - create_pr
    - enable_auto_merge
    - wait_for_merge
    - archive_after_merge
  archive_requires:
    - verify_change_pass
    - no_critical_findings
    - merged_on_target_branch
```

2. [T3] Update superpowers boundary

Add closeout policy fields to `contracts/superpowers-boundary.yaml`:

```yaml
  automation_helper: tools/community/small_chain_closeout.py
  integration_policy: pr_auto_merge
  auto_merge_authority: ci_and_branch_protection
```

3. [T3] Update README

Add a short section under Small Chain explaining:

```text
After verify-change PASS, run the helper to create a PR and enable GitHub auto-merge. CI and branch protection decide whether the PR merges. Archive is only allowed after merge evidence exists.
```

4. [T3] Add assertions to the targeted test

Extend `tests/test-small-chain-closeout-automation.sh` with `grep` checks for:

```text
tools/community/small_chain_closeout.py
pr_auto_merge
ci_and_branch_protection
archive_after_merge
```

5. [T3] Run contract visibility tests

Run: `bash tests/test-small-chain-closeout-automation.sh`

Expected: PASS.

Run: `bash tests/test-small-chain-boundary.sh`

Expected: PASS.

### Task 4: Proving Commands and Worklog Update [T4]

Context: This task closes the implementation workset and prepares it for `verify-change`. It must not claim archive, because this change itself has not yet gone through PR auto-merge.

Files:
- Modify: `docs/feature--small-chain--automation/worklog.md`
- Modify: `docs/feature--small-chain--automation/2026-04-26-closeout-orchestrator/tasks.md`

1. [T4] Run targeted automation tests

Run: `bash tests/test-small-chain-closeout-automation.sh`

Expected: PASS.

2. [T4] Run existing small-chain and boundary regressions

Run:

```bash
bash tools/validate-contracts.sh
bash tests/test-small-chain-boundary.sh
bash tests/test-superpowers-boundary.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: all PASS.

3. [T4] Update task completion state

After T1-T3 are implemented and verified, mark T1-T4 as `[x]` in `tasks.md`.

4. [T4] Append worklog record

Append a new latest record to `docs/feature--small-chain--automation/worklog.md`:

```markdown
## 2026-04-26 HH:MM

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: verify-preflight
- scope_ref: 2026-04-26-closeout-orchestrator/tasks.md#T4
- handoff_status: done
- state_ref: 2026-04-26-closeout-orchestrator/tasks.md#T4
- next: Implementation tasks are complete; next step is verify-change.
- next_ref: 2026-04-26-closeout-orchestrator/plan.md#T4
```

5. [T4] Validate context and task-plan consistency

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/feature--small-chain--automation/2026-04-26-closeout-orchestrator/tasks.md docs/feature--small-chain--automation/2026-04-26-closeout-orchestrator/plan.md
python3 tools/community/validate_context_contract.py --repo-root .
```

Expected: both PASS.
