#!/usr/bin/env bash
# File responsibility: verify the Anthropic skill-creator local adapter can
# plan, run, grade, benchmark, render, and trigger-test the developer pilot.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

SCRIPT="$ROOT/tools/eval/anthropic_skill_creator/run_developer_improvement.sh"
OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/anthropic-skill-adapter.XXXXXX")"
FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/anthropic-skill-adapter-bin.XXXXXX")"
ORIGINAL_SKILL_SHA="$(shasum -a 256 "$ROOT/shared/skills/developer/SKILL.md" | awk '{print $1}')"
trap 'rm -rf "$OUT_DIR" "$FAKE_BIN"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

output_path=""
is_judge=0
prompt=""
workdir=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output_path="$2"
      shift 2
      ;;
    -C)
      workdir="$2"
      shift 2
      ;;
    --output-schema)
      is_judge=1
      shift 2
      ;;
    --sandbox|--color|--model|-c)
      shift 2
      ;;
    --ephemeral|--skip-git-repo-check)
      shift
      ;;
    exec)
      shift
      ;;
    *)
      prompt="$1"
      shift
      ;;
  esac
done

case "$prompt" in
  *"Expected outcome:"*)
    printf 'executor prompt leaked expected outcome\n' >&2
    exit 23
    ;;
esac

if [ "$is_judge" = "1" ]; then
  PROMPT="$prompt" python3 - <<'PY'
import json
import os

prompt = os.environ["PROMPT"]
expectations = []
collect = False
for line in prompt.splitlines():
    stripped = line.strip()
    if stripped == "Expectations:":
        collect = True
        continue
    if collect and not stripped:
        break
    if collect and stripped.startswith("- "):
        text = stripped[2:]
        expectations.append({
            "text": text,
            "passed": True,
            "evidence": f"synthetic response covers: {text}",
        })
print(json.dumps({
    "expectations": expectations,
    "notes": [],
    "optimization_findings": [],
}, ensure_ascii=False))
PY
  exit 0
fi

test -n "$output_path"
case "$output_path" in
  "$workdir"/*)
    ;;
  *)
    printf 'executor output path escaped workspace: %s not under %s\n' "$output_path" "$workdir" >&2
    exit 24
    ;;
esac
mkdir -p "$(dirname "$output_path")"
cat > "$output_path" <<'MD'
我会读取 canonical design/tasks/test-cases，解析 work_dir、AC 和文件范围。
执行顺序是 RED -> GREEN -> REFACTOR，并输出 developer-report.json。
MD
SH
chmod +x "$FAKE_BIN/codex"

cat > "$FAKE_BIN/claude" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

query=""
text_output=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p)
      if [ "$#" -gt 1 ] && [ "${2#--}" = "$2" ]; then
        query="$2"
        shift 2
      else
        shift
      fi
      ;;
    --output-format)
      if [ "$2" = "text" ]; then
        text_output=1
      fi
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$text_output" = "1" ]; then
  printf '<new_description>Use this skill when implementing assigned standard-chain developer tasks with canonical AC, TDD evidence, file-scope control, and developer-report output.</new_description>\n'
  exit 0
fi

command_file="$(find .claude/commands -maxdepth 1 -name '*-skill-*.md' -print 2>/dev/null | sort | tail -n 1)"
command_name="$(basename "$command_file" .md)"
case "$query" in
  *"解释一下"*|*"review"*|*"QA"*)
    printf '{"type":"result"}\n'
    ;;
  *)
    printf '{"type":"stream_event","event":{"type":"content_block_start","content_block":{"type":"tool_use","name":"Skill"}}}\n'
    printf '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"%s"}}}\n' "$command_name"
    ;;
esac
SH
chmod +x "$FAKE_BIN/claude"

DRY_OUT="$OUT_DIR/dry-run.out"
bash "$SCRIPT" --dry-run --output-dir "$OUT_DIR" >"$DRY_OUT"
assert_present 'skill_name=developer' "$DRY_OUT"
assert_present 'official_skill_creator=' "$DRY_OUT"
test ! -d "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/old_skill/run-1/outputs" || fail "dry-run must not create run outputs"
test -d "$OUT_DIR/iteration-1/skill-snapshot/shared/skills/developer" || fail "missing developer skill snapshot"
test -f "$OUT_DIR/iteration-1/snapshot_metadata.json" || fail "missing snapshot metadata"
test -f "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/eval_metadata.json" || fail "missing eval metadata"

python3 - <<'PY' "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/eval_metadata.json"
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert metadata["eval_id"] == "happy-path-canonical-task", metadata
assert metadata["assertions"], metadata
PY

PYTHONPATH="$ROOT/tools/eval/anthropic_skill_creator/scripts" python3 - <<'PY'
from grade_runs import judge_schema

schema = judge_schema(["configured one", "configured two"])
text_schema = schema["properties"]["expectations"]["items"]["properties"]["text"]
assert text_schema["enum"] == ["configured one", "configured two"], text_schema
PY

MISSING_MODEL_OUT="$OUT_DIR/missing-model"
if PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --eval-only --output-dir "$MISSING_MODEL_OUT" >"$OUT_DIR/missing-model.out" 2>"$OUT_DIR/missing-model.err"; then
  fail "eval-only accepted missing --model"
fi
assert_present 'model is required for eval/trigger/full runs' "$OUT_DIR/missing-model.err"

PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --eval-only --output-dir "$OUT_DIR" --model fake-model --reasoning-effort low --judge-reasoning-effort low
test -f "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/old_skill/run-1/outputs/response.md" || fail "missing old_skill response"
test -f "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/new_skill/run-1/grading.json" || fail "missing new_skill grading"
test -s "$OUT_DIR/iteration-1/benchmark.json" || fail "missing benchmark json"
test -s "$OUT_DIR/iteration-1/benchmark.md" || fail "missing benchmark md"
test -s "$OUT_DIR/iteration-1/review.html" || fail "missing review html"
test -s "$OUT_DIR/iteration-1/runtime_metadata.json" || fail "missing runtime metadata"
! rg -n '<model-name>' "$OUT_DIR/iteration-1/benchmark.json" "$OUT_DIR/iteration-1/benchmark.md" "$OUT_DIR/iteration-1/review.html" >/dev/null || fail "benchmark metadata kept placeholder model"

python3 - <<'PY' "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/new_skill/run-1/grading.json" "$OUT_DIR/iteration-1/runtime_metadata.json" "$OUT_DIR/iteration-1/benchmark.json"
import json
import sys
from pathlib import Path

grading = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert grading["summary"]["total"] == 4, grading
runtime = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
assert runtime["executor_reasoning_effort"] == "low", runtime
assert runtime["judge_reasoning_effort"] == "low", runtime
benchmark = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
assert benchmark["metadata"]["executor_model"] == "fake-model / reasoning=low", benchmark["metadata"]
PY

BAD_BIN="$OUT_DIR/bad-bin"
BAD_RUN="$OUT_DIR/bad-judge-run"
mkdir -p "$BAD_BIN" "$BAD_RUN/outputs"
cat > "$BAD_BIN/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{
  "expectations": [
    {
      "text": "not configured",
      "passed": true,
      "evidence": "wrong expectation"
    }
  ],
  "notes": [],
  "optimization_findings": []
}
JSON
SH
chmod +x "$BAD_BIN/codex"
printf 'response\n' > "$BAD_RUN/outputs/response.md"
if PATH="$BAD_BIN:$PATH" PYTHONPATH="$ROOT/tools/eval/anthropic_skill_creator/scripts" python3 - <<'PY' "$BAD_RUN" >"$OUT_DIR/bad-judge.out" 2>"$OUT_DIR/bad-judge.err"
import sys
from pathlib import Path

from grade_runs import grade_run

grade_run(
    "developer",
    {
        "id": "bad-judge",
        "prompt": "prompt",
        "expected_output": "expected",
        "expectations": ["configured one", "configured two"],
    },
    Path(sys.argv[1]),
    30,
    None,
    None,
)
PY
then
  fail "judge expectation mismatch accepted"
fi

PYTHONPATH="$ROOT/tools/eval/anthropic_skill_creator/scripts" python3 - <<'PY'
from grade_runs import validate_judged_expectations

def expect_rejected(name, eval_case, judged):
    try:
        validate_judged_expectations(eval_case, judged)
    except ValueError:
        return
    raise AssertionError(f"{name} accepted")


expect_rejected(
    "duplicate configured expectation",
    {"expectations": ["duplicate", "duplicate"]},
    {"expectations": [{"text": "duplicate", "passed": True, "evidence": "x"}]},
)
expect_rejected(
    "missing judged expectation",
    {"expectations": ["configured one", "configured two"]},
    {"expectations": [{"text": "configured one", "passed": True, "evidence": "x"}]},
)
expect_rejected(
    "duplicate judged expectation",
    {"expectations": ["configured one"]},
    {
        "expectations": [
            {"text": "configured one", "passed": True, "evidence": "x"},
            {"text": "configured one", "passed": True, "evidence": "y"},
        ]
    },
)
PY

PYTHONPATH="$ROOT/tools/eval/anthropic_skill_creator/scripts" python3 - <<'PY' "$ROOT"
import shutil
import sys
import tempfile
from pathlib import Path

from run_existing_skill_eval import copy_case_files

root = Path(sys.argv[1])
workspace = Path(tempfile.mkdtemp(prefix="anthropic-copy-case-test."))
try:
    skill_root = workspace / "shared" / "skills" / "developer"
    shutil.copytree(root / "shared" / "skills" / "developer", skill_root)
    copy_case_files(skill_root, {"files": ["SKILL.md"]}, workspace)
    assert (workspace / "SKILL.md").is_file()
    try:
        copy_case_files(skill_root, {"files": ["../AGENTS.md"]}, workspace)
    except ValueError:
        pass
    else:
        raise AssertionError("path traversal accepted")
    outside = workspace.parent / f"{workspace.name}.outside"
    outside.write_text("outside", encoding="utf-8")
    refs = skill_root / "references"
    refs.mkdir(exist_ok=True)
    (refs / "safe.md").write_text("safe", encoding="utf-8")
    (refs / "outside-link").symlink_to(outside)
    try:
        copy_case_files(skill_root, {"files": ["references"]}, workspace)
    except ValueError:
        pass
    else:
        raise AssertionError("nested symlink accepted")
finally:
    outside = workspace.parent / f"{workspace.name}.outside"
    outside.unlink(missing_ok=True)
    shutil.rmtree(workspace, ignore_errors=True)
PY

PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --trigger-only --output-dir "$OUT_DIR" --model fake-model
test -s "$OUT_DIR/trigger/eval-set.json" || fail "missing trigger eval-set"
assert_present '^returncode=' "$OUT_DIR/trigger/run_eval.log"
assert_present '^\[stdout\]' "$OUT_DIR/trigger/run_eval.log"
assert_present '^\[stderr\]' "$OUT_DIR/trigger/run_eval.log"
assert_present '^returncode=' "$OUT_DIR/trigger/run_loop.log"
assert_present '^\[stdout\]' "$OUT_DIR/trigger/run_loop.log"
assert_present '^\[stderr\]' "$OUT_DIR/trigger/run_loop.log"
find "$OUT_DIR/trigger/results" -name results.json -print -quit | rg . >/dev/null || fail "missing trigger results.json"
find "$OUT_DIR/trigger/results" -name report.html -print -quit | rg . >/dev/null || fail "missing trigger report.html"

mkdir -p "$OUT_DIR/iteration-9" "$OUT_DIR/iteration-10"
touch "$OUT_DIR/iteration-9/benchmark.json" "$OUT_DIR/iteration-10/benchmark.json"
ITER_OUT="$OUT_DIR/iteration-order.out"
bash "$SCRIPT" --dry-run --output-dir "$OUT_DIR" >"$ITER_OUT"
assert_present 'iteration-11' "$ITER_OUT"
test -d "$OUT_DIR/iteration-11/skill-snapshot/shared/skills/developer" || fail "iteration-11 snapshot missing"

CURRENT_SKILL_SHA="$(shasum -a 256 "$ROOT/shared/skills/developer/SKILL.md" | awk '{print $1}')"
test "$CURRENT_SKILL_SHA" = "$ORIGINAL_SKILL_SHA" || fail "developer SKILL.md changed during adapter run"

echo "[PASS] anthropic skill-creator adapter"
