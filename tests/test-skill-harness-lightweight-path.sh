#!/usr/bin/env bash
# File role: prove the default skill-harness path stays lightweight and read-first.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-harness/SKILL.md"
MANIFEST="$ROOT/shared/skills/skill-harness/scripts/manifest.json"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
GOOD="$ROOT/tests/fixtures/skill-harness/cases/good-markdown-audit.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

grep -Fq 'Default output: structured Markdown findings' "$SKILL" || fail "default output must remain Markdown"
grep -Fq 'JSON only through the JSON upgrade gate' "$SKILL" || fail "JSON must remain consumer-triggered"
grep -Fq 'baseline smoke' "$SKILL" || fail "missing baseline smoke boundary"
python3 - "$SKILL" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = [line for line in text.splitlines() if line.startswith("Active/default audit output uses these fields:")]
if len(lines) != 1:
    raise SystemExit("default field declaration must be unique")
blocked = {
    "authority_proof_refs",
    "decision_payload_digest",
    "active_plan_version_ref",
    "active_tasks_version_ref",
}
for field in blocked:
    if field in lines[0]:
        raise SystemExit(f"default output includes conditional user-decision field: {field}")
print("[PASS] lightweight default fields")
PY
python3 - "$MANIFEST" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
paths = {script["path"] for script in data["scripts"]}
blocked = {"scripts/render_report.py", "hooks/hook_adapter.py"}
bad = paths & blocked
if bad:
    raise SystemExit(f"default manifest includes consumer-triggered command: {sorted(bad)}")
print("[PASS] lightweight manifest")
PY
python3 "$CHECKER" "$GOOD"
printf '[PASS] skill-harness lightweight path\n'
