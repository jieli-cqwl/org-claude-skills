# Anthropic Skill-Creator Official Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a thin local wrapper that runs the Anthropic `skill-creator` official improvement loop against `shared/skills/developer`.

**Architecture:** Keep `community/anthropic/skills/skill-creator` read-only and put local orchestration under `tools/eval/anthropic_skill_creator`. The wrapper creates Anthropic-compatible workspaces, delegates benchmark/viewer/trigger optimization to official scripts, and uses focused local code only for repo paths, old/new execution, and grading.

**Tech Stack:** Bash, Python 3.14 stdlib, existing `codex` CLI for eval execution/grading, official Anthropic `skill-creator` Python scripts.

---

### Task 1: Config, Paths, and Dry Run [T1]

Context: Establish the adapter boundary without running expensive evals. This task proves config and official paths can be resolved and validates the upstream `skill-creator` directory.

Files:
- Create: `tools/eval/anthropic_skill_creator/README.md`
- Create: `tools/eval/anthropic_skill_creator/configs/developer.json`
- Create: `tools/eval/anthropic_skill_creator/run_developer_improvement.sh`
- Create: `tools/eval/anthropic_skill_creator/scripts/paths.py`
- Test: `tests/test-anthropic-skill-creator-adapter.sh`

1. [T1] Write the failing dry-run contract test.

```bash
OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/anthropic-adapter.XXXXXX")"
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --dry-run --output-dir "$OUT_DIR" >"$OUT_DIR/dry-run.out"
rg -n 'skill_name=developer' "$OUT_DIR/dry-run.out"
rg -n 'official_skill_creator=' "$OUT_DIR/dry-run.out"
test ! -d "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/old_skill/run-1/outputs"
```

2. [T1] Run the test to verify it fails.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: FAIL because the adapter files do not exist.

3. [T1] Implement config and path helpers.

Create `developer.json` with `skill_name`, `skill_path`, `evals_path`, `official_skill_creator_path`, `default_output_dir`, `executor_timeout_sec`, `judge_timeout_sec`, and `trigger_eval_set`.

Implement `paths.py` with functions `repo_root()`, `load_config()`, `resolve_repo_path()`, `write_json()`, `run_command()`, and `validate_official_skill_creator()`.

4. [T1] Implement `run_developer_improvement.sh`.

Parse `--dry-run`, `--output-dir`, `--trigger-only`, `--eval-only`, `--model`, and `--judge-model`. For dry-run, call the Python orchestrator in dry-run mode and print resolved paths.

5. [T1] Run the dry-run test.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: Dry-run assertions pass and the next failing assertion identifies the missing snapshot behavior.

### Task 2: Snapshot and Metadata [T2]

Context: Anthropic existing-skill improvement requires an `old_skill` baseline and `new_skill` candidate. The adapter must create these inputs without mutating the real developer skill.

Files:
- Create: `tools/eval/anthropic_skill_creator/scripts/prepare_workspace.py`
- Modify: `tools/eval/anthropic_skill_creator/scripts/paths.py`
- Test: `tests/test-anthropic-skill-creator-adapter.sh`

1. [T2] Add a failing test for snapshot and metadata.

```bash
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --dry-run --output-dir "$OUT_DIR"
python3 - <<'PY' "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/eval_metadata.json"
import json, sys
from pathlib import Path
metadata = json.loads(Path(sys.argv[1]).read_text())
assert metadata["eval_id"] == "happy-path-canonical-task"
assert metadata["assertions"]
PY
test -d "$OUT_DIR/iteration-1/skill-snapshot/shared/skills/developer"
test -f "$OUT_DIR/iteration-1/snapshot_metadata.json"
```

2. [T2] Run the test to verify it fails.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: FAIL because workspace preparation does not exist yet.

3. [T2] Implement eval loading and directory planning.

`prepare_workspace.py` loads `shared/skills/developer/evals/evals.json`, creates sanitized eval directory names, writes `eval_metadata.json`, and writes `snapshot_metadata.json`.

4. [T2] Implement old snapshot creation.

If `git status --porcelain -- shared/skills/developer` is non-empty, export `HEAD:shared/skills/developer` into `skill-snapshot/shared/skills/developer`; otherwise copy the current filesystem skill. Always copy current filesystem skill into a candidate workspace for `new_skill`.

5. [T2] Run the snapshot test.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: Snapshot and metadata assertions pass.

### Task 3: Existing Skill Eval, Grading, Benchmark, Review [T3]

Context: This task creates the official old/new output loop and hands aggregation/viewer generation to Anthropic scripts.

Files:
- Create: `tools/eval/anthropic_skill_creator/scripts/run_existing_skill_eval.py`
- Create: `tools/eval/anthropic_skill_creator/scripts/grade_runs.py`
- Modify: `tools/eval/anthropic_skill_creator/run_developer_improvement.sh`
- Test: `tests/test-anthropic-skill-creator-adapter.sh`

1. [T3] Add a failing fake-codex full-run test.

Create a fake `codex` in the test that writes `response.md` for executor calls and emits schema-compatible JSON for judge calls. Assert:

```bash
test -f "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/old_skill/run-1/outputs/response.md"
test -f "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/new_skill/run-1/grading.json"
test -s "$OUT_DIR/iteration-1/benchmark.json"
test -s "$OUT_DIR/iteration-1/review.html"
```

2. [T3] Run the test to verify it fails.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: FAIL because eval execution and grading are missing.

3. [T3] Implement executor prompts.

`run_existing_skill_eval.py` runs `codex exec` in isolated temp workspaces containing either old or new developer skill plus declared eval files. Each run writes `outputs/response.md`, `outputs/transcript.md`, `executor.log`, and `timing.json`.

4. [T3] Implement grading.

`grade_runs.py` builds the strict judge prompt from eval prompt, expected output, assertions, and actual response; it writes official-compatible `grading.json` with `text`, `passed`, `evidence`, and `summary.pass_rate`.

5. [T3] Call official benchmark and viewer scripts.

After all run directories exist, call `python -m scripts.aggregate_benchmark <iteration-dir> --skill-name developer` from the official `skill-creator` directory, then call `eval-viewer/generate_review.py` with `--static <iteration-dir>/review.html`.

6. [T3] Run the full fake-codex test.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: Benchmark and review artifacts exist and are non-empty.

### Task 4: Trigger Eval and Description Loop [T4]

Context: Anthropic `skill-creator` includes description trigger testing and optimization. This task wires the official scripts without applying the result.

Files:
- Create: `tools/eval/anthropic_skill_creator/scripts/run_trigger_loop.py`
- Modify: `tools/eval/anthropic_skill_creator/configs/developer.json`
- Modify: `tools/eval/anthropic_skill_creator/run_developer_improvement.sh`
- Test: `tests/test-anthropic-skill-creator-adapter.sh`

1. [T4] Add a failing fake-claude trigger test.

Use a fake `claude` that emits stream-json events containing the temporary command name for should-trigger queries and emits no trigger for should-not-trigger queries. Assert:

```bash
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --trigger-only --output-dir "$OUT_DIR"
test -s "$OUT_DIR/trigger/eval-set.json"
find "$OUT_DIR/trigger/results" -name results.json -print -quit | rg .
find "$OUT_DIR/trigger/results" -name report.html -print -quit | rg .
```

2. [T4] Run the test to verify it fails.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: FAIL because trigger wrapper is missing.

3. [T4] Implement trigger eval-set generation.

`run_trigger_loop.py` writes `trigger/eval-set.json` from config and validates that it contains both `should_trigger=true` and `should_trigger=false` entries.

4. [T4] Invoke official scripts.

Run official `python -m scripts.run_eval` for trigger results and official `python -m scripts.run_loop` with `--results-dir <trigger/results>` and `--report <trigger/report.html>`. Do not write to `shared/skills/developer/SKILL.md`.

5. [T4] Run the trigger test.

Run: `bash tests/test-anthropic-skill-creator-adapter.sh`
Expected: Trigger outputs exist and the developer `SKILL.md` checksum is unchanged.

### Task 5: Docs, Verification, and Completion State [T5]

Context: Close the pilot as a repeatable local capability with clear usage docs and direct verification commands.

Files:
- Modify: `tools/eval/anthropic_skill_creator/README.md`
- Modify: `docs/anthropic-skill-creator-adapter/2026-04-22-official-adapter/tasks.md`
- Test: `tests/test-anthropic-skill-creator-adapter.sh`

1. [T5] Add README usage examples.

Document dry-run, eval-only, trigger-only, full run, output directory, and official upstream boundary. Include the no-auto-writeback rule for optimized descriptions.

2. [T5] Run syntax and unit checks.

Run:

```bash
bash -n tools/eval/anthropic_skill_creator/run_developer_improvement.sh
python3 -m py_compile tools/eval/anthropic_skill_creator/scripts/*.py
bash tests/test-anthropic-skill-creator-adapter.sh
```

Expected: all commands pass.

3. [T5] Run official upstream validation.

Run:

```bash
python3 community/anthropic/skills/skill-creator/scripts/quick_validate.py community/anthropic/skills/skill-creator
```

Expected: `Skill is valid!`

4. [T5] Mark tasks complete only after the corresponding evidence exists.

Update `tasks.md` checkboxes from `[ ]` to `[x]` after T1-T5 evidence passes. Do not mark a task complete before its commands have passed.
