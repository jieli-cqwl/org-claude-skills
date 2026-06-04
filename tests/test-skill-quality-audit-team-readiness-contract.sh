#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-quality-audit/SKILL.md"
READINESS="$ROOT/shared/skills/skill-quality-audit/references/team-use-readiness.md"
INSTRUCTION="$ROOT/shared/skills/skill-quality-audit/references/instruction-contract.md"
GATE_PLAN="$ROOT/tests/gate-plan.json"
EVALS="$ROOT/shared/skills/skill-quality-audit/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/skill-quality-audit/evals/lifecycle-review.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SKILL" ] || fail "missing skill-quality-audit SKILL.md"
[ -f "$INSTRUCTION" ] || fail "missing instruction-contract.md"

python3 - "$SKILL" "$READINESS" "$INSTRUCTION" "$GATE_PLAN" "$EVALS" "$LIFECYCLE" <<'PY'
import json
import re
import sys
from pathlib import Path

(
    skill_path,
    readiness_path,
    instruction_path,
    gate_plan_path,
    evals_path,
    lifecycle_path,
) = map(Path, sys.argv[1:])


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def section_body(text: str, heading: str) -> str:
    pattern = rf"^## {re.escape(heading)}\n(?P<body>.*?)(?=^## |\Z)"
    match = re.search(pattern, text, re.S | re.M)
    require(match is not None, f"missing section: {heading}")
    return match.group("body")


require(readiness_path.is_file(), "missing team-use readiness acceptance reference")
readiness = readiness_path.read_text(encoding="utf-8")
skill = skill_path.read_text(encoding="utf-8")
instruction = instruction_path.read_text(encoding="utf-8")
gate_plan = json.loads(gate_plan_path.read_text(encoding="utf-8"))
evals = json.loads(evals_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))

require(
    "# Team-Use Readiness Acceptance" in readiness,
    "readiness reference must declare its contract title",
)
contract_match = re.search(r"```json readiness_contract\n(.*?)\n```", readiness, re.S)
require(contract_match is not None, "readiness reference must expose json readiness_contract")
try:
    readiness_contract = json.loads(contract_match.group(1))
except json.JSONDecodeError as exc:
    fail(f"readiness_contract must be valid JSON: {exc}")
require(
    readiness_contract.get("contract_id") == "skill-quality-audit.team-use-readiness",
    "readiness contract id must be stable",
)
require(
    readiness_contract.get("verdict_scope") == "repository_custom_team_use_readiness",
    "readiness verdict scope must stay repository-custom",
)
require(
    readiness_contract.get("official_certification") is False,
    "readiness contract must not claim OpenAI official certification",
)
require(
    readiness_contract.get("generic_agent_skills_compliance") is False,
    "readiness contract must not claim generic Agent Skills compliance",
)
require(
    readiness_contract.get("target_users") == ["team_members"],
    "readiness contract must target team members",
)
require(
    readiness_contract.get("target_activity") == "audit_existing_skills",
    "readiness contract must target audits of existing Skills",
)
require(
    readiness_contract.get("allowed_verdicts") == ["fit", "conditional", "unfit", "blocked"],
    "readiness contract must preserve formal verdict vocabulary",
)
require(
    "repair_handoff" in readiness_contract.get("required_outputs", []),
    "readiness contract must require repair handoff",
)
require(
    [source.get("id") for source in readiness_contract.get("source_boundaries", [])]
    == [
        "openai_codex_skills_doc",
        "open_agent_skills_specification",
        "repository_custom_contract",
    ],
    "readiness contract must preserve source-boundary layers",
)
require(
    "references/team-use-readiness.md" in skill,
    "SKILL.md must route final readiness verdicts through team-use readiness reference",
)
require(
    "team-use readiness" in skill.lower(),
    "SKILL.md completion verification must name team-use readiness",
)

capabilities = (
    "Scenario Capability",
    "Structure-Content Coherence",
    "Evidence Integrity",
    "Repairable Handoff",
    "Attention Economy",
)
for capability in capabilities:
    body = section_body(readiness, capability)
    for field in ("Success standard:", "Failure mode:", "Required evidence:"):
        require(field in body, f"{capability} must include {field}")

lower_readiness = readiness.lower()
for term in ("brainstorming", "checklist", "structure", "content"):
    require(term in lower_readiness, f"readiness reference must cover {term}")
require(
    "checklist is not evidence by itself" in lower_readiness,
    "readiness reference must prevent checklist-as-proof audits",
)

lower_instruction = instruction.lower()
require(
    "classification is diagnostic" in lower_instruction,
    "instruction contract must state classification is diagnostic",
)
require(
    "finding exists only when" in lower_instruction,
    "instruction contract must gate findings on behavioral impact, not categories",
)

step_ids = {step["id"] for step in gate_plan["steps"]}
require(
    "skill-quality-audit-team-readiness-contract" in step_ids,
    "gate plan must include team-readiness contract test",
)

encoded = lifecycle.get("encoded_preference", {})
require(
    encoded.get("anchor_count") == len(evals.get("preference_anchors", [])),
    "lifecycle anchor_count must match evals preference_anchors",
)
require(
    encoded.get("eval_count") == len(evals.get("evals", [])),
    "lifecycle eval_count must match evals",
)
PY

printf '[PASS] skill-quality-audit team readiness contract\n'
