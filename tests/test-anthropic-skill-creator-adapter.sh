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
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output_path="$2"
      shift 2
      ;;
    --output-schema)
      is_judge=1
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$is_judge" = "1" ]; then
  cat <<'JSON'
{
  "expectations": [
    {
      "text": "解析 work_dir、AC 和文件范围，并说明必须读取 canonical design/tasks/test-cases 或 registry",
      "passed": true,
      "evidence": "synthetic response includes canonical input parsing"
    },
    {
      "text": "按 AC 执行 RED -> GREEN -> REFACTOR",
      "passed": true,
      "evidence": "synthetic response includes RED/GREEN/REFACTOR"
    }
  ],
  "notes": [],
  "optimization_findings": []
}
JSON
  exit 0
fi

test -n "$output_path"
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

PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --eval-only --output-dir "$OUT_DIR"
test -f "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/old_skill/run-1/outputs/response.md" || fail "missing old_skill response"
test -f "$OUT_DIR/iteration-1/eval-happy-path-canonical-task/new_skill/run-1/grading.json" || fail "missing new_skill grading"
test -s "$OUT_DIR/iteration-1/benchmark.json" || fail "missing benchmark json"
test -s "$OUT_DIR/iteration-1/benchmark.md" || fail "missing benchmark md"
test -s "$OUT_DIR/iteration-1/review.html" || fail "missing review html"

PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" --trigger-only --output-dir "$OUT_DIR" --model fake-model
test -s "$OUT_DIR/trigger/eval-set.json" || fail "missing trigger eval-set"
find "$OUT_DIR/trigger/results" -name results.json -print -quit | rg . >/dev/null || fail "missing trigger results.json"
find "$OUT_DIR/trigger/results" -name report.html -print -quit | rg . >/dev/null || fail "missing trigger report.html"

CURRENT_SKILL_SHA="$(shasum -a 256 "$ROOT/shared/skills/developer/SKILL.md" | awk '{print $1}')"
test "$CURRENT_SKILL_SHA" = "$ORIGINAL_SKILL_SHA" || fail "developer SKILL.md changed during adapter run"

echo "[PASS] anthropic skill-creator adapter"
