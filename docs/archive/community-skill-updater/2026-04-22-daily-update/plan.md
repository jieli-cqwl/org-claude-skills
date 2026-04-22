# Community Skill Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a first-party `community-skill-updater` skill that automates daily external skill updates, local adapter sync, validation, installation, branch commit, worktree cleanup, and conversation reporting.

**Architecture:** Add a narrow first-party skill plus bundled Python scripts. Keep existing `tools/community/sync_*` scripts as the vendoring authority, and make the new updater orchestrate candidate selection, source lock edits, worktree execution, validation/install ordering, and summary generation.

**Tech Stack:** Markdown skill docs, Bash repository contract tests, Python 3 standard library scripts and unit tests, existing `install.sh`, existing `tools/community/sync_*` scripts, existing `tests/run-all.sh`.

---

### Task 1: Contract Tests And Runtime Exposure [T1]

Context: Lock the desired public shape before implementation. This task intentionally starts with failing tests so the missing skill, scripts, install exposure, and test runner registration are visible before code is added.

Files:
- Create: `tests/test-community-skill-updater-contract.sh`
- Modify: `tests/run-all.sh`
- Modify: `install.sh`
- Modify: `README.md`

1. [T1] Add a failing contract test for the new skill source

Create `tests/test-community-skill-updater-contract.sh` with this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  test -f "$path" || fail "missing file: ${path#"$ROOT"/}"
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

skill_dir="$ROOT/shared/skills/community-skill-updater"
skill_file="$skill_dir/SKILL.md"

assert_file "$skill_file"
assert_present '^name: community-skill-updater$' "$skill_file"
assert_present 'daily automated update flow' "$skill_file"
assert_present 'community/SOURCES.yaml' "$skill_file"
assert_present 'anthropic_skills' "$skill_file"
assert_present 'superpowers' "$skill_file"
assert_present 'vercel_skills' "$skill_file"
assert_present 'vercel_agent_browser' "$skill_file"
assert_present 'alchaincyf_darwin_skill' "$skill_file"
assert_present 'nextlevelbuilder_ui_ux_pro_max' "$skill_file"
assert_present 'OpenSpec' "$skill_file"
assert_present 'excluded from daily updates' "$skill_file"
assert_present 'bash install.sh --target all --check full' "$skill_file"
assert_present 'bash install.sh --target all' "$skill_file"
assert_present 'success removes the worktree' "$skill_file"
assert_present 'failure preserves the worktree' "$skill_file"
assert_present 'Source updates' "$skill_file"
assert_present 'Validation results' "$skill_file"
assert_present 'Install result' "$skill_file"

for script in check_candidates.py run_update.py summarize_changes.py community_skill_updater_lib.py; do
  assert_file "$skill_dir/scripts/$script"
done

assert_present '"community-skill-updater"' "$ROOT/install.sh"
assert_present 'tests/test-community-skill-updater-contract.sh' "$ROOT/tests/run-all.sh"
assert_present 'tests/test-community-skill-updater-scripts.py' "$ROOT/tests/run-all.sh"
assert_present 'community-skill-updater' "$ROOT/README.md"
assert_absent 'openspec.*default managed source' "$skill_file"

echo "[PASS] community-skill-updater contract"
```

2. [T1] Run the new contract test and verify RED

Run: `bash tests/test-community-skill-updater-contract.sh`

Expected: FAIL with `missing file: shared/skills/community-skill-updater/SKILL.md`.

3. [T1] Register the test in `tests/run-all.sh`

Add `tests/test-community-skill-updater-contract.sh` to `SYNTAX_SHELL_FILES` and `FULL_TESTS`. Add `tests/test-community-skill-updater-scripts.py` to `FULL_TESTS` after it is created in T2.

4. [T1] Add install exposure for the first-party skill

Add `"community-skill-updater"` to `local_manual_only_skills()` in `install.sh`. This keeps it first-party and manually invocable while allowing the later Codex heartbeat to call it explicitly.

5. [T1] Document the new updater in `README.md`

Add a short bullet under the first-party skills area explaining that `community-skill-updater` maintains external runtime skill sources, syncs local adapters, validates, installs, and reports in the conversation.

6. [T1] Run the contract test again

Run: `bash tests/test-community-skill-updater-contract.sh`

Expected: FAIL moves from missing source to the next missing implementation file until later tasks satisfy the contract.

### Task 2: Candidate Lookup Script [T2]

Context: Candidate lookup is the first deterministic part of the updater. It must read the lock file, exclude OpenSpec from default updates, classify source state, and support fixture-based tests without live network access.

Files:
- Create: `shared/skills/community-skill-updater/scripts/community_skill_updater_lib.py`
- Create: `shared/skills/community-skill-updater/scripts/check_candidates.py`
- Create: `tests/test-community-skill-updater-scripts.py`

1. [T2] Write candidate lookup tests before implementation

Create `tests/test-community-skill-updater-scripts.py` with `unittest` cases named:

```python
class CandidateLookupTests(unittest.TestCase):
    def test_managed_sources_exclude_openspec(self): ...
    def test_no_update_when_candidate_equals_locked_ref(self): ...
    def test_update_when_candidate_differs_from_locked_ref(self): ...
    def test_blocked_when_candidate_lookup_failed(self): ...
```

Use a temporary `SOURCES.yaml` fixture containing all current source names. Import functions from `shared/skills/community-skill-updater/scripts/community_skill_updater_lib.py` through `importlib.util.spec_from_file_location()` so the hyphenated skill directory does not need to be a Python package.

2. [T2] Run candidate tests and verify RED

Run: `python3 tests/test-community-skill-updater-scripts.py CandidateLookupTests`

Expected: FAIL because `community_skill_updater_lib.py` does not exist.

3. [T2] Implement source lock parsing and candidate classification

In `community_skill_updater_lib.py`, define:

```python
MANAGED_SOURCE_NAMES = (
    "anthropic_skills",
    "superpowers",
    "vercel_skills",
    "vercel_agent_browser",
    "alchaincyf_darwin_skill",
    "nextlevelbuilder_ui_ux_pro_max",
)

EXCLUDED_SOURCE_NAMES = ("openspec",)
```

Implement small dataclasses for `SourceLock`, `CandidateRef`, and `SourceStatus`. Add functions:

```python
def load_source_locks(lock_path: Path) -> dict[str, SourceLock]: ...
def classify_candidates(
    locks: dict[str, SourceLock],
    candidates: dict[str, CandidateRef],
) -> list[SourceStatus]: ...
def managed_locks(locks: dict[str, SourceLock]) -> dict[str, SourceLock]: ...
```

Each function must include a concise docstring explaining intent and failure conditions.

4. [T2] Implement `check_candidates.py`

Create a CLI that accepts:

```text
--repo-root <path>
--source-lock <path>
--candidate-fixture <json path>
--output-json <path>
```

When `--candidate-fixture` is provided, read candidates from JSON for deterministic tests. Without a fixture, use GitHub latest release lookup and `git ls-remote` fallback through helper functions in the library.

5. [T2] Run candidate tests and verify GREEN

Run: `python3 tests/test-community-skill-updater-scripts.py CandidateLookupTests`

Expected: PASS.

### Task 3: Update Orchestration Script [T3]

Context: The orchestrator turns candidate status into isolated repository work. It must keep source sync delegated to existing scripts and preserve failed worktrees for diagnosis.

Files:
- Modify: `shared/skills/community-skill-updater/scripts/community_skill_updater_lib.py`
- Create: `shared/skills/community-skill-updater/scripts/run_update.py`
- Modify: `tests/test-community-skill-updater-scripts.py`

1. [T3] Add orchestration tests before implementation

Add `RunUpdateTests` with cases named:

```python
class RunUpdateTests(unittest.TestCase):
    def test_branch_name_uses_date_and_suffix_on_conflict(self): ...
    def test_no_update_does_not_leave_worktree_or_branch(self): ...
    def test_update_runs_sync_validations_install_commit_and_cleanup_in_order(self): ...
    def test_failure_preserves_worktree_and_stops_before_install(self): ...
```

Use a fake command runner object that records commands and can fail at a named command. Use temp directories and fixture source locks; do not call real git or install commands in these unit tests.

2. [T3] Run orchestration tests and verify RED

Run: `python3 tests/test-community-skill-updater-scripts.py RunUpdateTests`

Expected: FAIL because `run_update.py` behavior is missing.

3. [T3] Implement branch and worktree planning helpers

Add library helpers:

```python
def make_update_branch_name(today: str, existing_branches: set[str]) -> str: ...
def make_worktree_path(worktree_root: Path, branch_name: str) -> Path: ...
def update_lock_text(text: str, statuses: Sequence[SourceStatus], captured_at: str) -> str: ...
```

`make_update_branch_name()` must return `codex/community-skill-update-YYYYMMDD` or append `-2`, `-3`, and so on if needed. `update_lock_text()` must update only managed source `ref` and `captured_at` values for statuses marked `update`.

4. [T3] Implement `run_update.py`

The CLI accepts:

```text
--repo-root <path>
--candidate-json <path>
--today YYYY-MM-DD
--dry-run
```

The real flow verifies `.worktrees/` is ignored, creates the worktree, writes the updated source lock, runs source-specific sync commands, runs validations, runs `bash install.sh --target all --check full`, then runs `bash install.sh --target all`, commits changed files, and removes the worktree after success.

5. [T3] Encode sync and validation command order

The command order must place repository validations before real install:

```text
python3 tools/community/source_lock_check.py
bash tests/test-community-tools.sh
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
bash tests/test-install-runtime-smoke.sh
bash install.sh --target all --check full
bash install.sh --target all
```

6. [T3] Run orchestration tests and verify GREEN

Run: `python3 tests/test-community-skill-updater-scripts.py RunUpdateTests`

Expected: PASS.

### Task 4: Skill Instructions And Summary Output [T4]

Context: The skill must be usable by Codex and Claude as a first-party manual skill and by a later heartbeat automation. The summary output is intentionally conversation-only.

Files:
- Create: `shared/skills/community-skill-updater/SKILL.md`
- Create: `shared/skills/community-skill-updater/scripts/summarize_changes.py`
- Modify: `tests/test-community-skill-updater-contract.sh`
- Modify: `tests/test-community-skill-updater-scripts.py`

1. [T4] Add summary tests before implementation

Add `SummaryTests` with cases named:

```python
class SummaryTests(unittest.TestCase):
    def test_success_summary_contains_required_sections(self): ...
    def test_blocked_summary_contains_failure_evidence_and_preserved_path(self): ...
```

Expected required sections are `Source updates`, `Upstream changes`, `Local adapter changes`, `Validation results`, `Install result`, and `Branch and commit`.

2. [T4] Run summary tests and verify RED

Run: `python3 tests/test-community-skill-updater-scripts.py SummaryTests`

Expected: FAIL because `summarize_changes.py` is missing.

3. [T4] Implement `summarize_changes.py`

Create a CLI that accepts `--result-json <path>` and writes a Markdown summary to stdout. The blocked summary must include failed phase, failed command, worktree path, and next action.

4. [T4] Write `SKILL.md`

The skill frontmatter must include:

```yaml
---
name: community-skill-updater
description: Daily automated update flow for external community skills in org-claude-skills. Use this whenever the user asks to update or check external skills, community skill sources, Anthropic/Vercel/Superpowers skill versions, local Codex adapters, or install updated skills into Claude Code and Codex.
disable-model-invocation: true
---
```

The body must define managed sources, OpenSpec exclusion, execution order, worktree success/failure cleanup, validation gates, install gate, and the conversation report format.

5. [T4] Run contract and summary tests

Run:

```bash
bash tests/test-community-skill-updater-contract.sh
python3 tests/test-community-skill-updater-scripts.py SummaryTests
```

Expected: PASS.

### Task 5: Repository Validation And Closeout Prep [T5]

Context: This task proves the updater integrates with repository conventions and that task-plan traceability remains valid before verify-change.

Files:
- Modify: `docs/community-skill-updater/2026-04-22-daily-update/tasks.md`
- Modify: `docs/community-skill-updater/2026-04-22-daily-update/plan.md`

1. [T5] Run task-plan consistency check

Run:

```bash
python3 tools/community/check_task_plan_consistency.py \
  docs/community-skill-updater/2026-04-22-daily-update/tasks.md \
  docs/community-skill-updater/2026-04-22-daily-update/plan.md
```

Expected: PASS.

2. [T5] Run targeted updater tests

Run:

```bash
bash tests/test-community-skill-updater-contract.sh
python3 tests/test-community-skill-updater-scripts.py
```

Expected: PASS.

3. [T5] Run related repository integration tests

Run:

```bash
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
bash tests/test-community-tools.sh
```

Expected: PASS.

4. [T5] Run quick regression

Run: `bash tests/run-all.sh --quick`

Expected: PASS, or fail only on a clearly identified pre-existing blocker unrelated to `community-skill-updater`.

5. [T5] Update task statuses after commands pass

Mark T1-T5 checked in `tasks.md` only after the matching AC commands have fresh evidence. Do not mark a task complete on implementation alone.
