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
! grep -Eq 'Formal Gate|Quick Review' "$SKILL" \
  || fail "skill-quality-audit must not expose Quick/Formal mode selection to users"
grep -Fq 'Default behavior:' "$SKILL" \
  || fail "skill-quality-audit must define default audit behavior"
grep -Fq 'produce a formal QA report in the same run' "$SKILL" \
  || fail "skill-quality-audit must default to a one-run formal audit"
grep -Fq 'Do NOT ask the user for report paths' "$SKILL" \
  || fail "skill-quality-audit must not require user-provided report paths"
grep -Fq 'fall back to `/tmp`' "$SKILL" \
  || fail "skill-quality-audit must define artifact path fallback"
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
if "overview审查.md" not in prompt_text:
    raise SystemExit("test prompts must cover transcript triage from overview审查.md")
if "Formal Gate" in prompt_text or "Quick Review" in prompt_text:
    raise SystemExit("test prompts must not expose old mode names")
PY

printf '[PASS] skill-quality-audit runtime contract\n'
