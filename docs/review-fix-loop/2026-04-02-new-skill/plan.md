# Review Fix Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add a claude-only `review-fix-loop` skill that automates adversarial review -> fix -> re-review with stash baseline protection, fail-closed JSON validation, and install/runtime guardrails.

**Architecture:** Keep the skill claude-only because the fixer role is the current Claude session while the reviewer is an external Codex CLI call. Put repeatable logic into small helper scripts for baseline capture and review-result validation, keep orchestration in `SKILL.md`, and enforce output completeness through a transcript-based completion gate.

**Tech Stack:** Markdown skill source, Bash hooks, Python 3 helper scripts, git CLI, shell regression tests

---

### Task 1: Claude-Only Boundary And Install Contracts [T1]

Files:
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `install.sh`
- Test: `tests/test-single-source-layout.sh`
- Test: `tests/test-runtime-integrity.sh`
- Test: `tests/test-codex-skill-adapter.sh`

1. [T1] Write the failing boundary assertions for the new claude-only skill.

```bash
test -f "$ROOT/claude/skills/review-fix-loop/SKILL.md" || fail "missing claude-only skill source: review-fix-loop"
test -f "$TMP_HOME/.claude/skills/review-fix-loop/SKILL.md" || fail "missing claude-only skill review-fix-loop"
test ! -e "$TMP_HOME/.codex/skills/review-fix-loop" || fail "codex runtime should not install claude-only skill review-fix-loop"
```

2. [T1] Run the targeted tests to confirm they fail before implementation.

```bash
bash tests/test-single-source-layout.sh
bash tests/test-runtime-integrity.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: FAIL because `claude/skills/review-fix-loop/` and the related install/runtime wiring do not exist yet.

3. [T1] Add the claude-only source-tree allowlist and Claude quick-check wiring in `install.sh`.

```bash
test -f "$CLAUDE_DIR/skills/review-fix-loop/SKILL.md" || fail "Quick Check 失败: ~/.claude/skills/review-fix-loop/SKILL.md 不存在"
```

4. [T1] Re-run the same tests and confirm the boundary checks become green once the skill source exists.

```bash
bash tests/test-single-source-layout.sh
bash tests/test-runtime-integrity.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: PASS once the claude-only source and install/runtime assertions are in place.

### Task 2: Baseline Snapshot And Review Validation Helpers [T2]

Files:
- Create: `claude/skills/review-fix-loop/scripts/capture_baseline.py`
- Create: `claude/skills/review-fix-loop/scripts/validate_review_json.py`
- Create: `tests/test-review-fix-loop-skill.sh`
- Test: `tests/test-review-fix-loop-skill.sh`

1. [T2] Write the failing helper-script tests first with temp repos and temp JSON fixtures.

```bash
python3 "$ROOT/claude/skills/review-fix-loop/scripts/capture_baseline.py" --help
python3 "$ROOT/claude/skills/review-fix-loop/scripts/validate_review_json.py" --help
```

Expected: FAIL because the scripts do not exist yet.

2. [T2] Add dirty-worktree baseline tests that prove a new stash SHA is created and the index is restored.

```bash
python3 "$ROOT/claude/skills/review-fix-loop/scripts/capture_baseline.py" create --repo "$REPO_DIR" > "$TMP_ROOT/baseline.json"
python3 - "$TMP_ROOT/baseline.json" <<'PY'
import json, pathlib
data = json.loads(pathlib.Path(__import__("sys").argv[1]).read_text())
assert data["baseline_kind"] == "stash"
assert data["stash_sha"]
assert data["restore_command"].startswith("git checkout -- . && git stash apply --index ")
PY
```

3. [T2] Add clean-worktree baseline tests that prove no stash is created.

```bash
python3 "$ROOT/claude/skills/review-fix-loop/scripts/capture_baseline.py" create --repo "$REPO_DIR" > "$TMP_ROOT/clean.json"
python3 - "$TMP_ROOT/clean.json" <<'PY'
import json, pathlib
data = json.loads(pathlib.Path(__import__("sys").argv[1]).read_text())
assert data["baseline_kind"] == "head"
assert data["stash_sha"] is None
PY
```

4. [T2] Add failing validation tests for invalid top-level JSON, contradictory verdicts, bad paths, bad ranges, bad severity, and unlocatable high-severity findings.

```bash
python3 "$ROOT/claude/skills/review-fix-loop/scripts/validate_review_json.py" --repo "$REPO_DIR" --input "$TMP_ROOT/invalid.json"
```

Expected: non-zero exit for fail-closed cases; zero exit with warnings only for skip-able medium/low cases.

5. [T2] Implement the helper scripts with machine-readable JSON output.

```python
result = {
    "status": "ok",
    "baseline_kind": "stash",
    "head_sha": head_sha,
    "stash_sha": stash_sha,
    "restore_command": restore_command,
}
```

```python
validated = {
    "verdict": verdict,
    "summary": severity_counts,
    "valid_findings": sorted_findings,
    "warnings": warnings,
}
```

6. [T2] Run the helper-script test suite and confirm it passes.

```bash
bash tests/test-review-fix-loop-skill.sh
```

Expected: PASS.

### Task 3: Skill Source, References, And Completion Gate [T3]

Files:
- Create: `claude/skills/review-fix-loop/SKILL.md`
- Create: `claude/skills/review-fix-loop/references/execution-spec.md`
- Create: `claude/skills/review-fix-loop/references/review-schema.md`
- Create: `claude/skills/review-fix-loop/scripts/completion_check.sh`

1. [T3] Write the skill source using the `/new-skills` template and keep orchestration concise.

```md
## HARD-GATE
- NO loop start without baseline capture output.
- NO auto-fix on invalid/contradictory review JSON.
- NO completion without final summary block.
```

2. [T3] Move long details into references: Codex CLI command template, JSON contract, fail-closed rules, round-output template, and final-output template.

```bash
{ cat "$SKILL_DIR/references/review-schema.md"; } | codex exec --json -c model_reasoning_effort="medium" -
```

3. [T3] Implement the transcript-based completion gate.

```bash
grep -q '=== 循环结束 ===' "$TRANSCRIPT_PATH" || add_failure "缺少最终输出块"
grep -q '结果：' "$TRANSCRIPT_PATH" || add_failure "缺少结果字段"
grep -q '总轮次：' "$TRANSCRIPT_PATH" || add_failure "缺少总轮次字段"
```

4. [T3] Re-run the boundary and helper tests so the new skill source and hook script are exercised together.

```bash
bash tests/test-single-source-layout.sh
bash tests/test-review-fix-loop-skill.sh
```

Expected: PASS.

### Task 4: Design Sync And Final Regression [T4]

Files:
- Modify: `docs/review-fix-loop/2026-04-02-new-skill/design.md`
- Test: `tests/test-review-fix-loop-skill.sh`
- Test: `tests/test-single-source-layout.sh`
- Test: `tests/test-runtime-integrity.sh`
- Test: `tests/test-codex-skill-adapter.sh`

1. [T4] Sync the design doc to the final executable contract if the implementation uses Codex CLI prompt bridging instead of the original slash-command phrasing.

```md
- 自动循环调用外部 Codex 对抗评审（通过 `codex exec --json` 的固定 JSON 契约）
```

2. [T4] Run the targeted regression suite plus install/runtime checks.

```bash
bash tests/test-review-fix-loop-skill.sh
bash tests/test-single-source-layout.sh
bash tests/test-runtime-integrity.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: PASS.

3. [T4] Run the task/plan consistency checker and confirm the planning artifacts stay aligned.

```bash
python3 tools/community/check_task_plan_consistency.py \
  docs/review-fix-loop/2026-04-02-new-skill/tasks.md \
  docs/review-fix-loop/2026-04-02-new-skill/plan.md
```

Expected: `[PASS] tasks-plan consistency (...)`.
