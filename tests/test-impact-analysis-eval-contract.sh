#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/tools/eval/scripts/validate_impact_analysis_eval.py"
CASE_PACK="$ROOT/tests/fixtures/impact-analysis-eval/cases.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$VALIDATOR" || fail "missing impact analysis eval validator: $VALIDATOR"
test -f "$CASE_PACK" || fail "missing impact analysis eval case pack: $CASE_PACK"

if rg -n 'MERGED_DUPLICATE' "$VALIDATOR" "$CASE_PACK" >/dev/null 2>&1; then
  fail "impact analysis eval must not allow merged denominator records"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/impact-analysis-eval-contract.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 "$VALIDATOR" "$CASE_PACK" >"$TMP_DIR/pass.json"
python3 - "$TMP_DIR/pass.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["status"] == "pass"
assert payload["case_count"] == 8
assert payload["rubric_count"] == 8
assert payload["pilot_status"] == "team_pilot_ready"
assert payload["pilot_sample_size"] == "3-5 real tasks before hard-gate adoption"
assert payload["parallel_safe"] == ["case_execution", "independent_grading"]
PY

python3 - "$VALIDATOR" "$CASE_PACK" "$TMP_DIR" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

validator = Path(sys.argv[1])
case_pack = Path(sys.argv[2])
tmp_dir = Path(sys.argv[3])
mutated = json.loads(case_pack.read_text(encoding="utf-8"))
mutated["atom_record_schema"] = mutated["atom_record_schema"][:-1]
mutated_path = tmp_dir / "cases-mutated-atom-schema.json"
try:
    mutated_path.write_text(json.dumps(mutated, ensure_ascii=False), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(validator), str(mutated_path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
finally:
    mutated_path.unlink(missing_ok=True)

if result.returncode == 0:
    raise SystemExit("mutated atom schema should fail")
payload = json.loads(result.stdout)
if "atom_record_schema drifted" not in "\n".join(payload.get("errors", [])):
    raise SystemExit(f"mutated failure should mention atom schema drift: {payload}")
PY

python3 - "$VALIDATOR" "$CASE_PACK" "$TMP_DIR" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

validator = Path(sys.argv[1])
case_pack = Path(sys.argv[2])
tmp_dir = Path(sys.argv[3])
mutated = json.loads(case_pack.read_text(encoding="utf-8"))
mutated["cases"] = mutated["cases"][:-1]
mutated_path = tmp_dir / "cases-mutated.json"
try:
    mutated_path.write_text(json.dumps(mutated, ensure_ascii=False), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(validator), str(mutated_path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
finally:
    mutated_path.unlink(missing_ok=True)

if result.returncode == 0:
    raise SystemExit("mutated case pack should fail")
payload = json.loads(result.stdout)
if "case ids" not in "\n".join(payload.get("errors", [])):
    raise SystemExit(f"mutated failure should mention case ids: {payload}")
PY

python3 - "$VALIDATOR" "$CASE_PACK" "$TMP_DIR" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

validator = Path(sys.argv[1])
case_pack = Path(sys.argv[2])
tmp_dir = Path(sys.argv[3])
mutated = json.loads(case_pack.read_text(encoding="utf-8"))
mutated["cases"][0]["expected_focus"].append(mutated["cases"][0]["expected_focus"][0])
mutated_path = tmp_dir / "cases-duplicate-focus.json"
try:
    mutated_path.write_text(json.dumps(mutated, ensure_ascii=False), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(validator), str(mutated_path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
finally:
    mutated_path.unlink(missing_ok=True)

if result.returncode == 0:
    raise SystemExit("duplicate expected_focus should fail")
payload = json.loads(result.stdout)
if "duplicate focus" not in "\n".join(payload.get("errors", [])):
    raise SystemExit(f"mutated failure should mention duplicate focus: {payload}")
PY

python3 - "$VALIDATOR" "$CASE_PACK" "$TMP_DIR" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

validator = Path(sys.argv[1])
case_pack = Path(sys.argv[2])
tmp_dir = Path(sys.argv[3])
mutated = json.loads(case_pack.read_text(encoding="utf-8"))
for item in mutated["rubric"]:
    if item.get("id") == "R4":
        item["requires"] = [
            value
            for value in item["requires"]
            if value != "文件名、函数名、脚本名不是功能影响项"
        ]
        break
mutated_path = tmp_dir / "cases-missing-r4-redline.json"
try:
    mutated_path.write_text(json.dumps(mutated, ensure_ascii=False), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(validator), str(mutated_path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
finally:
    mutated_path.unlink(missing_ok=True)

if result.returncode == 0:
    raise SystemExit("mutated rubric should fail")
payload = json.loads(result.stdout)
errors = "\n".join(payload.get("errors", []))
if "missing requires" not in errors or "文件名、函数名、脚本名不是功能影响项" not in errors:
    raise SystemExit(f"mutated failure should mention missing R4 redline: {payload}")
PY

printf '[PASS] impact analysis eval contract\n'
