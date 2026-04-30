#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PREFLIGHT="$ROOT/shared/skills/product-manager/scripts/preflight_check.sh"
PREFLIGHT_PY="$ROOT/shared/skills/product-manager/scripts/preflight_check.py"
MANIFEST="$ROOT/shared/skills/product-manager/scripts/manifest.json"
SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
BRIEF_TEMPLATE="$ROOT/shared/skills/product-manager/templates/brief.template.json"
PHASE_TEMPLATE="$ROOT/shared/skills/product-manager/templates/phase-prd.template.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_json_status() {
  local path="$1"
  local expected="$2"
  python3 - "$path" "$expected" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = sys.argv[2]
actual = payload.get("status")
if actual != expected:
    raise SystemExit(f"expected status {expected}, got {actual}: {payload}")
PY
}

assert_failure_reason_contains() {
  local path="$1"
  local needle="$2"
  python3 - "$path" "$needle" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
needle = sys.argv[2]
reason = str(payload.get("reason", ""))
if payload.get("status") != "BLOCKED" or needle not in reason:
    raise SystemExit(f"expected BLOCKED reason containing {needle!r}, got {payload}")
PY
}

copy_fixtures() {
  local target="$1"
  mkdir -p "$target/feature/phase-1"
  cp "$BRIEF_TEMPLATE" "$target/feature/brief.json"
  cp "$PHASE_TEMPLATE" "$target/feature/phase-1/phase-prd.json"
}

assert_file "$PREFLIGHT"
assert_file "$PREFLIGHT_PY"
assert_file "$MANIFEST"
assert_file "$SKILL"
python3 -m py_compile "$PREFLIGHT_PY"

python3 - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
scripts = {script.get("id"): script for script in manifest.get("scripts", [])}
preflight = scripts.get("preflight-check")
if not preflight:
    raise SystemExit("manifest missing preflight-check")
if preflight.get("path") != "scripts/preflight_check.sh":
    raise SystemExit("preflight-check path drift")
for arg in ("--brief", "--phase-prd", "--phase-dir", "--help", "-h"):
    if arg not in preflight.get("allowed_args", []):
        raise SystemExit(f"preflight-check missing allowed arg {arg}")
PY

assert_present 'preflight_check\.sh --brief "\$BRIEF_JSON" --phase-prd "\$PHASE_PRD_JSON"' "$SKILL"
assert_present 'preflight_check\.sh --phase-dir "\$PHASE_DIR"' "$SKILL"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
copy_fixtures "$TMP_DIR"

PASS_OUT="$TMP_DIR/pass.json"
bash "$PREFLIGHT" \
  --brief "$TMP_DIR/feature/brief.json" \
  --phase-prd "$TMP_DIR/feature/phase-1/phase-prd.json" >"$PASS_OUT"
assert_json_status "$PASS_OUT" "PASS"

PHASE_DIR_OUT="$TMP_DIR/phase-dir-pass.json"
bash "$PREFLIGHT" --phase-dir "$TMP_DIR/feature/phase-1" >"$PHASE_DIR_OUT"
assert_json_status "$PHASE_DIR_OUT" "PASS"

BAD_STATUS_DIR="$TMP_DIR/bad-status"
copy_fixtures "$BAD_STATUS_DIR"
python3 - "$BAD_STATUS_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["director_confirmation"]["status"] = "pending"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
BAD_STATUS_OUT="$TMP_DIR/bad-status.json"
if bash "$PREFLIGHT" --phase-dir "$BAD_STATUS_DIR/feature/phase-1" >"$BAD_STATUS_OUT"; then
  fail "preflight must block unpassed director_confirmation.status"
fi
assert_failure_reason_contains "$BAD_STATUS_OUT" "director_confirmation.status"

DRIFT_DIR="$TMP_DIR/drift"
copy_fixtures "$DRIFT_DIR"
python3 - "$DRIFT_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["phase_goal"] = "silently expanded phase goal"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
DRIFT_OUT="$TMP_DIR/drift.json"
if bash "$PREFLIGHT" --phase-dir "$DRIFT_DIR/feature/phase-1" >"$DRIFT_OUT"; then
  fail "preflight must block Director-owned field drift"
fi
assert_failure_reason_contains "$DRIFT_OUT" "locked_fields"

MARKDOWN_OUT="$TMP_DIR/markdown.json"
printf '# legacy brief\n' >"$TMP_DIR/feature/brief.md"
if bash "$PREFLIGHT" \
  --brief "$TMP_DIR/feature/brief.md" \
  --phase-prd "$TMP_DIR/feature/phase-1/phase-prd.json" >"$MARKDOWN_OUT"; then
  fail "preflight must reject non-canonical brief paths"
fi
assert_failure_reason_contains "$MARKDOWN_OUT" "canonical JSON"

printf '[PASS] product-manager preflight contract\n'
