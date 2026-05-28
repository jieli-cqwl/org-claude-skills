#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="$ROOT/shared/skills/skill-quality-audit/references/claim-review-gate.md"
SKILL="$ROOT/shared/skills/skill-quality-audit/SKILL.md"
GATE_PLAN="$ROOT/tests/gate-plan.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$REF" ] || fail "missing claim-review-gate.md"
[ -f "$SKILL" ] || fail "missing skill-quality-audit SKILL.md"

python3 - "$REF" "$SKILL" "$GATE_PLAN" <<'PY'
import json
import re
import sys
from pathlib import Path

ref_path, skill_path, gate_plan_path = map(Path, sys.argv[1:])
ref = ref_path.read_text(encoding="utf-8")
skill = skill_path.read_text(encoding="utf-8")
gate_plan = json.loads(gate_plan_path.read_text(encoding="utf-8"))


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


for heading in (
    "## Low-Freedom Role Prompts",
    "### Claim Builder",
    "### Evidence Verifier",
    "### Severity Calibrator",
):
    require(heading in ref, f"missing role prompt heading: {heading}")

role_checks = {
    "Claim Builder": (
        "required premises",
        "Do not assign severity",
        "Do not decide whether the finding stays",
    ),
    "Evidence Verifier": (
        "current `path:line`",
        "direct refutations",
        "status: supported, refuted, or blocked",
    ),
    "Severity Calibrator": (
        "team use, runtime behavior, output correctness, validation, or downstream handoff",
        "Do not raise severity for clarity or style alone",
        "calibrated_severity",
    ),
}
for role, needles in role_checks.items():
    pattern = rf"### {re.escape(role)}\n(?P<body>.*?)(?=^### |\Z)"
    match = re.search(pattern, ref, re.S | re.M)
    require(match is not None, f"missing role body: {role}")
    body = match.group("body")
    for needle in needles:
        require(needle in body, f"{role} prompt missing: {needle}")

require(
    "Read `references/claim-review-gate.md` before retaining any P0/P1 finding." in skill,
    "SKILL.md must route P0/P1 retention through claim-review-gate",
)

step_ids = {step["id"] for step in gate_plan["steps"]}
require(
    "skill-quality-audit-claim-review-contract" in step_ids,
    "gate plan must include claim-review contract test",
)
PY

printf '[PASS] skill-quality-audit claim review contract\n'
