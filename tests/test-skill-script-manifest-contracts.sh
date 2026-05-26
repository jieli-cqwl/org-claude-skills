#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/tools/community/validate_skill_script_manifests.py"
GATE_PLAN="$ROOT/tests/gate-plan.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$VALIDATOR" || fail "missing skill script manifest validator: $VALIDATOR"
python3 "$VALIDATOR" --repo-root "$ROOT"

python3 - "$GATE_PLAN" <<'PY'
import json
import sys
from pathlib import Path

plan = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
steps = {step.get("id"): step for step in plan.get("steps", [])}
step = steps.get("skill-script-manifest-contracts")
if not step:
    raise SystemExit("gate-plan missing skill-script-manifest-contracts")
if step.get("command") != ["bash", "tests/test-skill-script-manifest-contracts.sh"]:
    raise SystemExit("skill-script-manifest-contracts command mismatch")
if step.get("area") != "hooks-manifest" or step.get("tier") != "quick":
    raise SystemExit("skill-script-manifest-contracts must be quick hooks-manifest canary")
if "manifest" not in step.get("tags", []) or "canary" not in step.get("tags", []):
    raise SystemExit("skill-script-manifest-contracts missing manifest/canary tags")
PY

printf '[PASS] skill script manifest contracts\n'
