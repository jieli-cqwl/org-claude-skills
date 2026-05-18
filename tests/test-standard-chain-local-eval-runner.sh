#!/usr/bin/env bash
# 文件职责：验证 standard-chain skill-local eval runner 能执行、评分并暴露失败项。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
RUNNER="$ROOT/tools/eval/scripts/run_standard_chain_local_eval.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

test -f "$RUNNER" || fail "missing local eval runner: $RUNNER"

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-local-eval.XXXXXX")"
FAKE_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-fake-codex.XXXXXX")"
DRY_RUN_OUT="$(mktemp "${TMPDIR:-/tmp}/standard-chain-local-eval-dry.XXXXXX.out")"
trap 'rm -rf "$OUT_DIR" "$FAKE_CODEX_BIN"; rm -f "$DRY_RUN_OUT"' EXIT

python3 "$RUNNER" --skills product-director --dry-run >"$DRY_RUN_OUT"
director_eval_count="$(jq '.evals | length' "$ROOT/shared/skills/product-director/evals/evals.json")"
assert_present "^product-director: ${director_eval_count} evals$" "$DRY_RUN_OUT"
assert_present 'scenario-baseline-new-business' "$DRY_RUN_OUT"

cat > "$FAKE_CODEX_BIN/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

output_path=""
workspace=""
is_judge=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -C)
      workspace="$2"
      shift 2
      ;;
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
      "text": "复述目标、边界和预期产物",
      "passed": true,
      "evidence": "synthetic response mentioned the target"
    },
    {
      "text": "只验证一个最会改变判断的关键事实并暂停",
      "passed": false,
      "evidence": "synthetic response omitted the key fact pause"
    }
  ],
  "notes": ["关键事实暂停表达缺失"],
  "optimization_findings": [
    {
      "issue": "Scenario baseline key fact pause is too easy to omit",
      "suggested_change": "Strengthen the eval expectation and skill wording around verifying one key fact before freezing."
    }
  ],
  "anchor_results": [
    {
      "id": "PA-1",
      "passed": true,
      "evidence": "synthetic response respected the intake baseline"
    },
    {
      "id": "PA-5",
      "passed": true,
      "evidence": "synthetic response refused to rewrite Director locked fields"
    }
  ]
}
JSON
  exit 0
fi

test -n "$output_path"
case "$output_path" in
  *files-copy*)
    test -f tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json
    ;;
  *without-skill*)
    test -n "$workspace"
    test ! -e "$workspace/shared/skills/product-manager/SKILL.md"
    ;;
  *)
    test -n "$workspace"
    test -f "$workspace/shared/skills/product-manager/SKILL.md"
    ;;
esac
mkdir -p "$(dirname "$output_path")"
printf '我会先复述目标和边界，然后只确认一个关键事实。\n' > "$output_path"
SH
chmod +x "$FAKE_CODEX_BIN/codex"

PATH="$FAKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-manager \
  --eval-ids handoff-validation-first \
  --runs-per-eval 1 \
  --run-mode with_skill \
  --output-dir "$OUT_DIR" \
  --allow-failures

WITHOUT_SKILL_OUT_DIR="$OUT_DIR/without-skill"
PATH="$FAKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-manager \
  --eval-ids handoff-validation-first \
  --runs-per-eval 1 \
  --run-mode without_skill \
  --output-dir "$WITHOUT_SKILL_OUT_DIR" \
  --allow-failures
test -f "$WITHOUT_SKILL_OUT_DIR/product-manager/handoff-validation-first/without_skill/run-1/outputs/response.md" || fail "without_skill output did not create response output"

REL_OUT_DIR="tmp-standard-chain-local-eval-relative"
rm -rf "$REL_OUT_DIR"
PATH="$FAKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-manager \
  --eval-ids handoff-validation-first \
  --runs-per-eval 1 \
  --run-mode with_skill \
  --output-dir "$REL_OUT_DIR" \
  --allow-failures
test -f "$REL_OUT_DIR/product-manager/handoff-validation-first/with_skill/run-1/outputs/response.md" || fail "relative output dir did not create response output"
rm -rf "$REL_OUT_DIR"

RUN_DIR="$OUT_DIR/product-manager/handoff-validation-first/with_skill/run-1"
test -f "$RUN_DIR/outputs/response.md" || fail "missing response output"
test -f "$RUN_DIR/grading.json" || fail "missing grading output"
test -f "$OUT_DIR/summary.json" || fail "missing summary json"
test -f "$OUT_DIR/summary.md" || fail "missing summary markdown"
if [ -d "$OUT_DIR/_workspaces" ]; then
  fail "runner must not retain copied workspaces by default"
fi

FILES_OUT_DIR="$OUT_DIR/files-copy"
PATH="$FAKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills design \
  --eval-ids alternatives-and-runtime-scan \
  --runs-per-eval 1 \
  --output-dir "$FILES_OUT_DIR" \
  --allow-failures
test -f "$FILES_OUT_DIR/design/alternatives-and-runtime-scan/with_skill/run-1/eval_metadata.json" || fail "missing metadata for files-copy run"
python3 - <<'PY' "$FILES_OUT_DIR/design/alternatives-and-runtime-scan/with_skill/run-1/eval_metadata.json"
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text())
files = metadata["files"]
assert "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" in files, files
PY

python3 - <<'PY' "$OUT_DIR"
import sys
from pathlib import Path

from tools.eval.scripts.standard_chain_local_eval.workspace import (
    build_executor_prompt,
    copy_case_files,
    prepare_workspace,
)

workspace = prepare_workspace("developer", Path(sys.argv[1]), "without_skill")
try:
    copy_case_files("developer", {"id": "skill-leak", "files": ["SKILL.md"]}, workspace, "without_skill")
except ValueError as exc:
    assert "without_skill cannot copy target skill files" in str(exc), exc
else:
    raise AssertionError("without_skill copied target SKILL.md")

case = {
    "id": "prompt-leak",
    "prompt": "现场事实，不包含答案。",
    "expected_output": "EXPECTED_SENTINEL_SHOULD_NOT_REACH_EXECUTOR",
    "files": [],
}
visible_prompt = build_executor_prompt("delivery-owner", case, "with_skill")
assert "Expected outcome:" in visible_prompt
assert "EXPECTED_SENTINEL_SHOULD_NOT_REACH_EXECUTOR" in visible_prompt
hidden_prompt = build_executor_prompt("delivery-owner", case, "with_skill", include_expected_outcome=False)
assert "Expected outcome:" not in hidden_prompt
assert "EXPECTED_SENTINEL_SHOULD_NOT_REACH_EXECUTOR" not in hidden_prompt
PY

python3 - <<'PY' "$RUN_DIR/eval_metadata.json" "$RUN_DIR/grading.json" "$OUT_DIR/summary.json"
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text())
grading = json.loads(Path(sys.argv[2]).read_text())
summary = json.loads(Path(sys.argv[3]).read_text())

assert metadata["expected_anchors"] == ["PA-1", "PA-5"], metadata
anchor_definitions = metadata["preference_anchor_definitions"]
assert [item["id"] for item in anchor_definitions] == ["PA-1", "PA-5"], anchor_definitions
expectations = grading["expectations"]
assert expectations, "missing expectations"
for expectation in expectations:
    assert set(["text", "passed", "evidence"]).issubset(expectation), expectation
anchor_results = grading["anchor_results"]
assert [item["id"] for item in anchor_results] == ["PA-1", "PA-5"], anchor_results
assert grading["preference_anchor_summary"] == {
    "passed": 2,
    "failed": 0,
    "total": 2,
    "fidelity": 1.0,
}, grading["preference_anchor_summary"]
assert grading["summary"]["failed"] == 1, grading["summary"]
assert summary["summary"]["failed_expectations"] == 1, summary["summary"]
assert summary["runs"][0]["run_mode"] == "with_skill", summary["runs"][0]
assert summary["runs"][0]["anchor_total"] == 2, summary["runs"][0]
assert summary["runs"][0]["anchor_passed"] == 2, summary["runs"][0]
assert summary["runs"][0]["anchor_fidelity"] == 1.0, summary["runs"][0]
assert summary["runs"][0]["failed_expectations"] == ["只验证一个最会改变判断的关键事实并暂停"], summary["runs"][0]
assert summary["optimization_findings"][0]["issue"] == "Scenario baseline key fact pause is too easy to omit"
PY

assert_present 'Scenario baseline key fact pause is too easy to omit' "$OUT_DIR/summary.md"

FAKE_FAIL_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-fake-fail-codex.XXXXXX")"
trap 'rm -rf "$OUT_DIR" "$FAKE_CODEX_BIN" "$FAKE_FAIL_CODEX_BIN"; rm -f "$DRY_RUN_OUT"' EXIT
cat > "$FAKE_FAIL_CODEX_BIN/codex" <<'SH'
#!/usr/bin/env bash
printf 'synthetic executor failure\n' >&2
exit 7
SH
chmod +x "$FAKE_FAIL_CODEX_BIN/codex"

PATH="$FAKE_FAIL_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-manager \
  --eval-ids handoff-validation-first \
  --runs-per-eval 1 \
  --output-dir "$OUT_DIR" \
  --allow-failures
python3 - <<'PY' "$OUT_DIR/summary.json"
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
assert summary["summary"]["infra_failures"] == 0, summary["summary"]
assert summary["summary"]["failed_expectations"] == 1, summary["summary"]
PY

FAIL_OUT_DIR="$OUT_DIR/infra-failure"
PATH="$FAKE_FAIL_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-director \
  --eval-ids scenario-baseline-new-business \
  --runs-per-eval 1 \
  --output-dir "$FAIL_OUT_DIR" \
  --allow-failures
test -f "$FAIL_OUT_DIR/summary.json" || fail "missing summary json for infra failure"
test -f "$FAIL_OUT_DIR/product-director/scenario-baseline-new-business/with_skill/run-1/grading.json" || fail "missing grading json for infra failure"
assert_present 'pass rate: N/A' "$FAIL_OUT_DIR/summary.md"
python3 - <<'PY' "$FAIL_OUT_DIR/summary.json" "$FAIL_OUT_DIR/product-director/scenario-baseline-new-business/with_skill/run-1/grading.json"
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
grading = json.loads(Path(sys.argv[2]).read_text())
run = summary["runs"][0]
assert summary["summary"]["infra_failures"] == 1, summary["summary"]
assert summary["summary"]["pass_rate"] is None, summary["summary"]
assert run["status"] == "infra_failure", run
assert run["graded"] is False, run
assert run["pass_rate"] is None, run
assert "executor exited 7" in run["infra_failure"], run
assert grading["summary"]["graded"] is False, grading["summary"]
assert grading["summary"]["pass_rate"] is None, grading["summary"]
PY

FAKE_DELETE_RUN_DIR_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-fake-delete-run-dir-codex.XXXXXX")"
trap 'rm -rf "$OUT_DIR" "$FAKE_CODEX_BIN" "$FAKE_FAIL_CODEX_BIN" "$FAKE_DELETE_RUN_DIR_CODEX_BIN"; rm -f "$DRY_RUN_OUT"' EXIT
cat > "$FAKE_DELETE_RUN_DIR_CODEX_BIN/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

output_path=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

test -n "$output_path"
rm -rf "$(dirname "$(dirname "$output_path")")"
printf 'synthetic executor removed its run dir\n' >&2
exit 7
SH
chmod +x "$FAKE_DELETE_RUN_DIR_CODEX_BIN/codex"

DELETE_RUN_DIR_OUT="$OUT_DIR/delete-run-dir-infra"
PATH="$FAKE_DELETE_RUN_DIR_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-director \
  --eval-ids scenario-baseline-new-business \
  --runs-per-eval 1 \
  --output-dir "$DELETE_RUN_DIR_OUT" \
  --allow-failures
DELETE_RUN_DIR_RUN="$DELETE_RUN_DIR_OUT/product-director/scenario-baseline-new-business/with_skill/run-1"
test -f "$DELETE_RUN_DIR_RUN/executor.log" || fail "missing executor log after run dir deletion"
test -f "$DELETE_RUN_DIR_RUN/grading.json" || fail "missing grading json after run dir deletion"
assert_present 'synthetic executor removed its run dir' "$DELETE_RUN_DIR_RUN/executor.log"
python3 - <<'PY' "$DELETE_RUN_DIR_OUT/summary.json" "$DELETE_RUN_DIR_RUN/grading.json"
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
grading = json.loads(Path(sys.argv[2]).read_text())
run = summary["runs"][0]
assert summary["summary"]["infra_failures"] == 1, summary["summary"]
assert run["status"] == "infra_failure", run
assert "executor exited 7" in run["infra_failure"], run
assert grading["summary"]["graded"] is False, grading["summary"]
PY

FAKE_TIMEOUT_AFTER_RESPONSE_CODEX_BIN="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-fake-timeout-after-response-codex.XXXXXX")"
trap 'rm -rf "$OUT_DIR" "$FAKE_CODEX_BIN" "$FAKE_FAIL_CODEX_BIN" "$FAKE_DELETE_RUN_DIR_CODEX_BIN" "$FAKE_TIMEOUT_AFTER_RESPONSE_CODEX_BIN"; rm -f "$DRY_RUN_OUT"' EXIT
cat > "$FAKE_TIMEOUT_AFTER_RESPONSE_CODEX_BIN/codex" <<'SH'
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
      "text": "复述目标、边界和预期产物",
      "passed": true,
      "evidence": "synthetic response is complete despite executor timeout"
    }
  ],
  "notes": [],
  "optimization_findings": [],
  "anchor_results": []
}
JSON
  exit 0
fi

test -n "$output_path"
mkdir -p "$(dirname "$output_path")"
printf '完整响应已经写入，但进程尾部超时。\n' > "$output_path"
sleep 5
SH
chmod +x "$FAKE_TIMEOUT_AFTER_RESPONSE_CODEX_BIN/codex"

TIMEOUT_AFTER_RESPONSE_OUT="$OUT_DIR/timeout-after-response"
PATH="$FAKE_TIMEOUT_AFTER_RESPONSE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-manager \
  --eval-ids handoff-validation-first \
  --runs-per-eval 1 \
  --output-dir "$TIMEOUT_AFTER_RESPONSE_OUT" \
  --timeout-sec 1 \
  --allow-failures
TIMEOUT_AFTER_RESPONSE_RUN="$TIMEOUT_AFTER_RESPONSE_OUT/product-manager/handoff-validation-first/with_skill/run-1"
test -f "$TIMEOUT_AFTER_RESPONSE_RUN/outputs/response.md" || fail "missing response output after executor timeout"
test -f "$TIMEOUT_AFTER_RESPONSE_RUN/grading.json" || fail "missing grading json after executor timeout with response"
assert_present 'TimeoutExpired' "$TIMEOUT_AFTER_RESPONSE_RUN/executor.log"
python3 - <<'PY' "$TIMEOUT_AFTER_RESPONSE_OUT/summary.json" "$TIMEOUT_AFTER_RESPONSE_RUN/grading.json"
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
grading = json.loads(Path(sys.argv[2]).read_text())
run = summary["runs"][0]
assert summary["summary"]["infra_failures"] == 0, summary["summary"]
assert run["status"] == "graded", run
assert grading["summary"]["failed"] == 0, grading["summary"]
PY

SETUP_FAIL_OUT_DIR="$OUT_DIR/workspace-setup-failure"
mkdir -p "$SETUP_FAIL_OUT_DIR/_workspaces/with_skill"
: > "$SETUP_FAIL_OUT_DIR/_workspaces/with_skill/product-director"
PATH="$FAKE_CODEX_BIN:$PATH" python3 "$RUNNER" \
  --skills product-director \
  --eval-ids scenario-baseline-new-business \
  --runs-per-eval 1 \
  --output-dir "$SETUP_FAIL_OUT_DIR" \
  --allow-failures
test -f "$SETUP_FAIL_OUT_DIR/summary.json" || fail "missing summary json for workspace setup failure"
python3 - <<'PY' "$SETUP_FAIL_OUT_DIR/summary.json"
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
run = summary["runs"][0]
assert summary["summary"]["infra_failures"] == 1, summary["summary"]
assert summary["summary"]["pass_rate"] is None, summary["summary"]
assert run["status"] == "infra_failure", run
assert run["graded"] is False, run
assert "Not a directory" in run["infra_failure"] or "not a directory" in run["infra_failure"], run
PY

printf '[PASS] standard-chain local eval runner contract\n'
