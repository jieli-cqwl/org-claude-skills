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
! grep -Eiq '^description:.*(audits|scores|reports|workflow|five-step|评分|审查流程)' "$SKILL" \
  || fail "description must not summarize workflow"
grep -q '^allowed-tools: Read, Glob, Grep, Bash(python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py:\*)$' "$SKILL" \
  || fail "skill-quality-audit must restrict Bash to the report validator"
! grep -Eq '^allowed-tools:.*(^|, )Bash(,|$)' "$SKILL" \
  || fail "skill-quality-audit must not expose unrestricted Bash"
! grep -Eq 'allowed-tools:.*(Write|Edit|MultiEdit)' "$SKILL" \
  || fail "skill-quality-audit must not have write/edit tools"
! grep -Eiq 'edit target|rewrite target|execute remediation|执行落地|策略制定后.*修改' "$SKILL" \
  || fail "skill-quality-audit must not claim modification authority"
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

printf '[PASS] skill-quality-audit runtime contract\n'
