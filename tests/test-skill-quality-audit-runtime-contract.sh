#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-quality-audit/SKILL.md"
AGENT="$ROOT/shared/skills/skill-quality-audit/agents/openai.yaml"
SURFACE="$ROOT/contracts/skill-runtime-surface.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SKILL" ] || fail "missing skill-quality-audit SKILL.md"
[ -f "$AGENT" ] || fail "missing skill-quality-audit agents/openai.yaml"

grep -q '^name: skill-quality-audit$' "$SKILL" \
  || fail "skill name must be skill-quality-audit"
grep -q '^description: "Use when ' "$SKILL" \
  || fail "description must describe trigger conditions"
grep -q '^allowed-tools: Read, Write, Glob, Grep, Agent, Bash(python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py:\*), Bash(python3 shared/skills/skill-quality-audit/scripts/classify_audit_artifact.py:\*)$' "$SKILL" \
  || fail "skill-quality-audit must allow audit outputs, agent claim review, and only approved Bash scripts"
! grep -Eq '^allowed-tools:.*(^|, )Bash(,|$)' "$SKILL" \
  || fail "skill-quality-audit must not expose unrestricted Bash"
! grep -Eq 'allowed-tools:.*(Edit|MultiEdit)' "$SKILL" \
  || fail "skill-quality-audit must not have edit tools"
grep -Fq 'Write only audit output artifacts' "$SKILL" \
  || fail "skill-quality-audit must restrict Write to audit output artifacts"
python3 - "$SKILL" <<'PY'
import sys
import json
import re
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = text.splitlines()
h2_labels = [
    line[3:].strip().lower().replace(" ", "").replace("-", "")
    for line in lines
    if line.startswith("## ")
]
if "whentouse" in h2_labels:
    raise SystemExit("unexpected-trigger-section")
if not h2_labels or h2_labels[0] != "hardgate":
    raise SystemExit("missing-leading-hardgate")
if "auditrun" not in h2_labels:
    raise SystemExit("missing-audit-run")
policy_match = re.search(r"```json artifact_path_policy\n(.*?)\n```", text, re.S)
if not policy_match:
    raise SystemExit("missing-artifact-path-policy")
policy = json.loads(policy_match.group(1))
if policy.get("default_root") != "docs/tmp":
    raise SystemExit("default audit artifacts must be discoverable under docs/tmp")
if policy.get("fallback_root") != "/tmp":
    raise SystemExit("fallback audit artifact root must remain /tmp")
if policy.get("report_template") != "skill-quality-audit-<target-slug>-report.json":
    raise SystemExit("report artifact template drift")
if policy.get("summary_template") != "skill-quality-audit-<target-slug>-summary.md":
    raise SystemExit("summary artifact template drift")
PY
[ -d "$ROOT/docs/tmp" ] || fail "docs/tmp must exist for default audit artifacts"
python3 - "$ROOT/shared/skills/skill-quality-audit/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path

evals = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
anchors = {item["id"]: item["anchor"] for item in evals["preference_anchors"]}
required_anchor_ids = {"SQA-07", "SQA-08", "SQA-09", "SQA-10"}
missing_anchor_ids = sorted(required_anchor_ids - anchors.keys())
if missing_anchor_ids:
    raise SystemExit(f"missing anchors: {missing_anchor_ids}")
if "docs/tmp" not in anchors["SQA-09"] or "fall back to /tmp" not in anchors["SQA-09"]:
    raise SystemExit("SQA-09 must prefer docs/tmp and keep /tmp fallback")
default_case = next(
    item for item in evals["evals"] if item["id"] == "default-formal-audit-artifacts"
)
light_case = next(item for item in evals["evals"] if item["id"] == "explicit-light-scan")
if "SQA-07" not in default_case.get("expected_anchors", []):
    raise SystemExit("default audit eval must cover formal artifact behavior")
if "SQA-10" not in light_case.get("expected_anchors", []):
    raise SystemExit("light scan eval must cover severity-label prohibition")
PY

grep -Fq 'allow_implicit_invocation: false' "$AGENT" \
  || fail "skill-quality-audit must disable implicit invocation for Codex"

python3 - "$SURFACE" <<'PY'
import json
import sys
from pathlib import Path

surface = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
skills = surface["skills"]
if "skill-quality-audit" not in skills:
    raise SystemExit("skill-quality-audit missing from runtime surface")
entry = skills["skill-quality-audit"]
if entry.get("mode") != "manual":
    raise SystemExit("skill-quality-audit must be manual")
if entry.get("owner") != "first-party":
    raise SystemExit("skill-quality-audit owner must be first-party")
if "skill-refiner" in skills:
    raise SystemExit("skill-refiner must not remain in runtime surface")
PY

python3 - "$ROOT/shared/skills/skill-quality-audit/evals/evals.json" "$ROOT/shared/skills/skill-quality-audit/test-prompts.json" <<'PY'
import json
import sys
from pathlib import Path

evals = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
prompts = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
required_sample_cases = [
    "positive-formal-audit",
    "light-scan-non-final",
    "audit-artifact-triage",
    "near-miss-should-not-trigger",
    "without-skill-baseline",
    "negative-stale-evidence",
    "negative-missing-handoff",
    "negative-p0-p1-claim-review",
    "repair-handoff-replay",
]
sample_matrix = evals.get("sample_matrix")
if not isinstance(sample_matrix, list):
    raise SystemExit("evals.sample_matrix missing")
sample_by_id = {item.get("id"): item for item in sample_matrix if isinstance(item, dict)}
missing_sample_cases = [case_id for case_id in required_sample_cases if case_id not in sample_by_id]
if missing_sample_cases:
    raise SystemExit(f"sample_matrix missing cases: {missing_sample_cases}")
required_fields = {
    "target_skill_type",
    "prompt",
    "expected_anchors",
    "grader_dimensions",
    "pass_threshold",
    "failure_blocking_level",
    "sample_out_boundary",
}
for case_id in required_sample_cases:
    case = sample_by_id[case_id]
    missing_fields = sorted(required_fields - set(case))
    if missing_fields:
        raise SystemExit(f"sample_matrix {case_id} missing fields: {missing_fields}")
    if not case["expected_anchors"]:
        raise SystemExit(f"sample_matrix {case_id} expected_anchors must be non-empty")
    if not case["grader_dimensions"]:
        raise SystemExit(f"sample_matrix {case_id} grader_dimensions must be non-empty")
    if not isinstance(case["pass_threshold"], (int, float)) or not 0 <= case["pass_threshold"] <= 1:
        raise SystemExit(f"sample_matrix {case_id} pass_threshold must be 0..1")
    if case["failure_blocking_level"] not in {"P0", "P1", "P2", "P3"}:
        raise SystemExit(f"sample_matrix {case_id} failure_blocking_level must be a severity")
default_evals = [item for item in evals["evals"] if item["id"] == "default-formal-audit-artifacts"]
if not default_evals:
    raise SystemExit("default-formal-audit-artifacts eval missing")
default_text = " ".join(default_evals[0]["expectations"])
if "same run" not in default_text or "artifact paths automatically" not in default_text:
    raise SystemExit("default audit eval must require one-run formal report with automatic paths")
light_evals = [item for item in evals["evals"] if item["id"] == "explicit-light-scan"]
if not light_evals:
    raise SystemExit("explicit-light-scan eval missing")
light_text = " ".join(light_evals[0]["expectations"])
if "severity labels" not in light_text or "P0/P1/P2/P3" not in light_text:
    raise SystemExit("light scan eval must forbid severity labels")
prompt_text = " ".join(item["prompt"] for item in prompts["prompts"])
if "shared/skills/skill-quality-audit/evals/fixtures/artifacts/overview-transcript.md" not in prompt_text:
    raise SystemExit("test prompts must cover transcript triage from the stable overview transcript fixture")
prompt_ids = {item["id"] for item in prompts["prompts"]}
for prompt_id in ("near-miss-should-not-trigger", "negative-stale-evidence", "repair-handoff-replay"):
    if prompt_id not in prompt_ids:
        raise SystemExit(f"test prompts must include {prompt_id}")
if "Formal Gate" in prompt_text or "Quick Review" in prompt_text:
    raise SystemExit("test prompts must not expose old mode names")
PY

printf '[PASS] skill-quality-audit runtime contract\n'
