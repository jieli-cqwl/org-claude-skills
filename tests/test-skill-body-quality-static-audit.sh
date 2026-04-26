#!/usr/bin/env bash
# File role: prove skill-harness can statically audit Skill body quality signals.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_body_quality.py"
GOOD="$ROOT/tests/fixtures/skill-body-quality/good"
GOOD_EXTERNAL="$ROOT/tests/fixtures/skill-body-quality/good-external-contract"
BAD="$ROOT/tests/fixtures/skill-body-quality/bad"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-body-quality.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CHECKER" ] || fail "missing checker"

python3 "$CHECKER" "$GOOD" >"$TMP_DIR/good.json"
python3 - "$TMP_DIR/good.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["artifact_type"] == "skill-body-quality-static-audit"
assert data["status"] == "static_pass"
assert data["finding_count"] == 0
print("[PASS] good fixture static audit")
PY

python3 "$CHECKER" "$GOOD_EXTERNAL" >"$TMP_DIR/good-external.json"
python3 - "$TMP_DIR/good-external.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["artifact_type"] == "skill-body-quality-static-audit"
assert data["status"] == "static_pass"
assert data["finding_count"] == 0
print("[PASS] external resource contract static audit")
PY

set +e
python3 "$CHECKER" "$BAD" >"$TMP_DIR/bad.json"
bad_rc=$?
set -e
[ "$bad_rc" -eq 1 ] || fail "bad fixture must exit with static_fail"

python3 - "$TMP_DIR/bad.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
codes = {finding["code"] for finding in data["findings"]}
required = {
    "HARD_GATE_MISSING",
    "GOAL_CONTRACT_MISSING",
    "SOP_ACTIONS_MISSING",
    "PROGRESSIVE_LOADING_CONTRACT_INCOMPLETE",
    "COMPLEX_FLOW_UNSTRUCTURED",
    "VERIFICATION_MISSING",
    "VAGUE_INSTRUCTION_UNBOUNDED",
}
missing = sorted(required - codes)
if missing:
    raise SystemExit(f"missing finding codes: {missing}")
for finding in data["findings"]:
    assert finding["dimension"] in {"D1", "D2", "D5", "D6", "D8"}
    assert finding["file_ref"].startswith("tests/fixtures/skill-body-quality/bad/SKILL.md:")
    assert finding["evidence_refs"]
    assert finding["impact"]
    assert finding["recommendation"]
    assert finding["verification"].startswith("python3 shared/skills/skill-harness/scripts/check_skill_body_quality.py ")
assert data["status"] == "static_fail"
print("[PASS] bad fixture static audit")
PY

grep -Fq '"check-body-quality"' "$ROOT/shared/skills/skill-harness/scripts/manifest.json" \
  || fail "manifest must expose check-body-quality"
grep -Fq 'check_skill_body_quality.py <skill-path>' "$ROOT/shared/skills/skill-harness/SKILL.md" \
  || fail "skill-harness must route the body quality checker"

printf '[PASS] skill body quality static audit\n'
