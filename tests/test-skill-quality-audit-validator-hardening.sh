#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py"
SKILL="$ROOT/shared/skills/skill-quality-audit/SKILL.md"
VALID="$ROOT/tests/fixtures/skill-quality-audit/reports/valid-report.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

[ -f "$VALIDATOR" ] || fail "missing validate_skill_audit_report.py"
[ -f "$SKILL" ] || fail "missing skill-quality-audit SKILL.md"
[ -f "$VALID" ] || fail "missing valid report fixture"

python3 "$VALIDATOR" "$VALID" >/dev/null

declare -a MISSED_REJECTIONS=()

expect_reject() {
  local name="$1"
  local report="$2"
  local expected="$3"
  local out="$TMP_DIR/$name.out"

  if python3 "$VALIDATOR" "$report" >"$out" 2>&1; then
    MISSED_REJECTIONS+=("$name")
    return
  fi
  grep -Fq "$expected" "$out" \
    || fail "$name failure should mention: $expected"
}

python3 - "$VALID" "$TMP_DIR/missing-summary.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["artifact_paths"]["summary_markdown"] = "tests/fixtures/skill-quality-audit/reports/does-not-exist.md"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject "missing-summary" "$TMP_DIR/missing-summary.json" "summary_markdown"

python3 - "$VALID" "$TMP_DIR/title-only-summary.json" "$TMP_DIR/title-only-summary.md" <<'PY'
import json
import sys
from pathlib import Path

src, dst, summary = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["artifact_paths"]["summary_markdown"] = str(summary)
summary.write_text(
    "# Audit Summary\n\n- F-001 / P1 / Handoff target is incomplete.\n",
    encoding="utf-8",
)
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject "title-only-summary" "$TMP_DIR/title-only-summary.json" "summary_markdown"

python3 - "$VALID" "$TMP_DIR" <<'PY'
import json
import sys
from pathlib import Path

src, tmp = Path(sys.argv[1]), Path(sys.argv[2])
base = json.loads(src.read_text(encoding="utf-8"))
summaries = {
    "summary-missing-finding": "\n".join(
        [
            "# Skill Audit Summary",
            "",
            "Verdict: conditional.",
            "",
            "No high-severity finding details are included here.",
        ]
    ),
    "summary-missing-evidence-ref": "\n".join(
        [
            "# Skill Audit Summary",
            "",
            "Finding F-001 / P1 / Handoff target is incomplete.",
            "Impact: The editing window may not know which file or test proves repair.",
            "Repair target: shared/skills/skill-quality-audit/evals/fixtures/target-skills/good-skill/SKILL.md Output Contract",
            "Verification hint: Run the target skill package quality checker after adding consumer and verification.",
        ]
    ),
    "summary-missing-repair-target": "\n".join(
        [
            "# Skill Audit Summary",
            "",
            "Finding F-001 / P1 / Handoff target is incomplete.",
            "Evidence: tests/fixtures/skill-quality-audit/evidence-target.md:2 names a repair output but no consumer.",
            "Impact: The editing window may not know which file or test proves repair.",
            "Verification hint: Run the target skill package quality checker after adding consumer and verification.",
        ]
    ),
    "summary-missing-verification-hint": "\n".join(
        [
            "# Skill Audit Summary",
            "",
            "Finding F-001 / P1 / Handoff target is incomplete.",
            "Evidence: tests/fixtures/skill-quality-audit/evidence-target.md:2 names a repair output but no consumer.",
            "Impact: The editing window may not know which file or test proves repair.",
            "Repair target: shared/skills/skill-quality-audit/evals/fixtures/target-skills/good-skill/SKILL.md Output Contract",
        ]
    ),
}
for name, body in summaries.items():
    data = json.loads(json.dumps(base))
    summary = tmp / f"{name}.md"
    report = tmp / f"{name}.json"
    summary.write_text(body + "\n", encoding="utf-8")
    data["artifact_paths"]["summary_markdown"] = str(summary)
    report.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject "summary-missing-finding" "$TMP_DIR/summary-missing-finding.json" "summary_markdown for P1 finding F-001"
expect_reject "summary-missing-evidence-ref" "$TMP_DIR/summary-missing-evidence-ref.json" "evidence_checks path:line"
expect_reject "summary-missing-repair-target" "$TMP_DIR/summary-missing-repair-target.json" "repair_target"
expect_reject "summary-missing-verification-hint" "$TMP_DIR/summary-missing-verification-hint.json" "verification_hint"

python3 - "$VALID" "$TMP_DIR/nonexistent-scope.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
for item in data["scope_evidence"]:
    if item["surface"] == "SKILL.md":
        item["evidence"] = "shared/skills/does-not-exist/SKILL.md"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject "nonexistent-scope" "$TMP_DIR/nonexistent-scope.json" "does not exist"

python3 - "$VALID" "$TMP_DIR/p2-missing-handoff.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
finding = data["findings"][0]
finding["severity"] = "P2"
finding["evidence_level"] = "E2"
finding.pop("repair_target", None)
finding.pop("verification_hint", None)
finding.pop("evidence_checks", None)
finding.pop("claim_review", None)
finding.pop("severity_calibration", None)
data["repair_handoff"] = []
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject "p2-missing-handoff" "$TMP_DIR/p2-missing-handoff.json" "repair_target"

python3 - "$VALID" "$TMP_DIR/e4-unmatched-verification.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
for item in data["dimension_scores"]:
    if item["dimension"] == "Instruction Contract":
        item["evidence_level"] = "E4"
data["executed_verification"] = [
    {
        "id": "unrelated-runtime-check",
        "command": "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py tests/fixtures/skill-quality-audit/reports/valid-report.json",
        "status": "PASS",
        "output": "[PASS] skill audit report valid",
        "evidence": "This proves only the report shape, not the Instruction Contract claim.",
    }
]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject "e4-unmatched-verification" "$TMP_DIR/e4-unmatched-verification.json" "dimension:Instruction Contract"

if ((${#MISSED_REJECTIONS[@]})); then
  printf '[FAIL] validator accepted invalid reports: %s\n' "${MISSED_REJECTIONS[*]}" >&2
  exit 1
fi

python3 - "$SKILL" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"<HARD-GATE>\n(?P<body>.*?)\n</HARD-GATE>", text, re.S)
if not match:
    raise SystemExit("[FAIL] missing <HARD-GATE> block")

body = match.group("body")
lines = [line.strip() for line in body.splitlines() if line.strip()]
errors = []
do_not_lines = [line for line in lines if line.startswith("Do NOT")]
if len(lines) > 8 or len(do_not_lines) > 6:
    errors.append("HARD-GATE must stay focused on blocking invariants")

detail_terms = (
    "summary",
    "P2/P3",
    "light scan",
    "shell commands",
    "score-only",
    "Generate default artifacts",
    "fall back",
)
for term in detail_terms:
    if term.lower() in body.lower():
        errors.append(f"HARD-GATE contains non-gate detail: {term}")

required_signals = (
    "modify target Skill files",
    "validators pass",
    "scope evidence",
    "P0/P1",
    "E4",
)
for signal in required_signals:
    if signal not in body:
        errors.append(f"HARD-GATE missing core invariant: {signal}")

if errors:
    raise SystemExit("[FAIL] " + "; ".join(errors))
PY

printf '[PASS] skill-quality-audit validator hardening\n'
