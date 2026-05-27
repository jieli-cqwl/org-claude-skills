#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py"
VALID="$ROOT/tests/fixtures/skill-quality-audit/reports/valid-report.json"
FIT_VALID="$ROOT/shared/skills/skill-quality-audit/evals/fixtures/reports/valid-report.json"
MISSING_REPAIR="$ROOT/tests/fixtures/skill-quality-audit/reports/p1-missing-repair-target.json"
BAD_VERDICT="$ROOT/tests/fixtures/skill-quality-audit/reports/instruction-low-score-invalid-verdict.json"
CLASSIFIER="$ROOT/shared/skills/skill-quality-audit/scripts/classify_audit_artifact.py"

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
[ -f "$CLASSIFIER" ] || fail "missing classify_audit_artifact.py"
validator_lines="$(wc -l < "$VALIDATOR" | tr -d ' ')"
[ "$validator_lines" -le 400 ] || fail "validate_skill_audit_report.py must stay within 400 lines"
[ -f "$VALID" ] || fail "missing valid report fixture"
[ -f "$FIT_VALID" ] || fail "missing fit valid report fixture"

python3 "$VALIDATOR" "$VALID"
python3 "$VALIDATOR" "$FIT_VALID"

python3 - "$VALID" "$TMP_DIR/root-file-line-evidence.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0]["evidence"] = "AGENTS.md:1 provides root-level evidence for this contract fixture."
data["findings"][0]["evidence_checks"][0] = {
    "path": "AGENTS.md",
    "line": 1,
    "expected_snippet": "# AGENTS.md",
    "claim": "Root-level file references with line numbers are valid evidence.",
}
data["findings"][0]["claim_review"]["refutation_check"] = "AGENTS.md:1 was checked for a direct refutation."
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$VALIDATOR" "$TMP_DIR/root-file-line-evidence.json"

python3 - "$VALID" "$TMP_DIR/object-target-skill.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["target_skill"] = {
    "slug": "example",
    "path": "shared/skills/example",
}
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/object-target-skill.json" >"$TMP_DIR/object-target-skill.out" 2>&1; then
  fail "target_skill object must fail"
fi
grep -Fq "target_skill" "$TMP_DIR/object-target-skill.out" \
  || fail "target_skill object failure should mention target_skill"

python3 - "$VALID" "$TMP_DIR/absolute-artifact-paths.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["artifact_paths"] = {
    "report_json": "/tmp/research-skill-audit-report.json",
    "summary_markdown": "/tmp/research-skill-audit-summary.md",
}
data["validation"]["command"] = "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py /tmp/research-skill-audit-report.json"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$VALIDATOR" "$TMP_DIR/absolute-artifact-paths.json"

cat >"$TMP_DIR/transcript.md" <<'EOF'
 ▐▛███▜▌ Claude Code
⏺ Verdict
fit
EOF
if python3 "$VALIDATOR" "$TMP_DIR/transcript.md" >"$TMP_DIR/transcript.out" 2>&1; then
  fail "transcript markdown must not validate as a formal audit report"
fi
grep -Fq "invalid JSON" "$TMP_DIR/transcript.out" \
  || fail "transcript failure should make the missing JSON artifact explicit"
python3 "$CLASSIFIER" "$TMP_DIR/transcript.md" >"$TMP_DIR/transcript-kind.out"
grep -Fq "artifact_type=transcript" "$TMP_DIR/transcript-kind.out" \
  || fail "classifier should identify Claude transcript artifacts"
python3 "$CLASSIFIER" "$VALID" >"$TMP_DIR/formal-kind.out"
grep -Fq "artifact_type=formal_json" "$TMP_DIR/formal-kind.out" \
  || fail "classifier should identify formal JSON reports"

python3 - "$VALID" "$TMP_DIR/missing-validation.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data.pop("validation", None)
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/missing-validation.json" >"$TMP_DIR/missing-validation.out" 2>&1; then
  fail "formal report without validation must fail"
fi
grep -Fq "validation" "$TMP_DIR/missing-validation.out" \
  || fail "missing validation failure should mention validation"

python3 - "$VALID" "$TMP_DIR/not-run-validation.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["validation"]["status"] = "NOT_RUN"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/not-run-validation.json" >"$TMP_DIR/not-run-validation.out" 2>&1; then
  fail "formal report without validator PASS must fail"
fi
grep -Fq "validation.status" "$TMP_DIR/not-run-validation.out" \
  || fail "not-run validation failure should mention validation.status"

if python3 "$VALIDATOR" "$MISSING_REPAIR" >"$TMP_DIR/missing-repair.out" 2>&1; then
  fail "P1 finding without repair_target must fail"
fi
grep -Fq "repair_target" "$TMP_DIR/missing-repair.out" \
  || fail "missing repair_target failure should be explicit"

python3 - "$VALID" "$TMP_DIR/missing-claim-review.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0].pop("claim_review", None)
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/missing-claim-review.json" >"$TMP_DIR/missing-claim-review.out" 2>&1; then
  fail "P1 finding without claim_review must fail"
fi
grep -Fq "claim_review" "$TMP_DIR/missing-claim-review.out" \
  || fail "missing claim_review failure should be explicit"

python3 - "$VALID" "$TMP_DIR/empty-required-claims.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0]["claim_review"]["required_claims"] = []
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/empty-required-claims.json" >"$TMP_DIR/empty-required-claims.out" 2>&1; then
  fail "P1 finding with empty required_claims must fail"
fi
grep -Fq "required_claims" "$TMP_DIR/empty-required-claims.out" \
  || fail "empty required_claims failure should be explicit"

python3 - "$VALID" "$TMP_DIR/empty-optional-claim-review.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["verdict"] = "conditional"
data["findings"][0]["severity"] = "P2"
data["findings"][0]["evidence_level"] = "E2"
data["findings"][0]["claim_review"] = {}
data["findings"][0]["severity_calibration"] = {}
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/empty-optional-claim-review.json" >"$TMP_DIR/empty-optional-claim-review.out" 2>&1; then
  fail "non-P1 finding with empty optional claim_review must fail"
fi
grep -Fq "claim_review" "$TMP_DIR/empty-optional-claim-review.out" \
  || fail "empty optional claim_review failure should be explicit"

python3 - "$VALID" "$TMP_DIR/severity-overclaim.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0]["severity_calibration"]["calibrated_severity"] = "P2"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/severity-overclaim.json" >"$TMP_DIR/severity-overclaim.out" 2>&1; then
  fail "P1 finding whose severity calibration downgrades it must fail"
fi
grep -Fq "severity_calibration" "$TMP_DIR/severity-overclaim.out" \
  || fail "severity calibration failure should be explicit"

if python3 "$VALIDATOR" "$BAD_VERDICT" >"$TMP_DIR/bad-verdict.out" 2>&1; then
  fail "Instruction Contract score below 5 must force unfit"
fi
grep -Fq "Instruction Contract" "$TMP_DIR/bad-verdict.out" \
  || fail "bad verdict failure should mention Instruction Contract"

python3 - "$VALID" "$TMP_DIR/blocked-valid.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["verdict"] = "blocked"
data["overall_score"] = 0
data["verdict_reason"] = "Scoring is blocked because a required target surface could not be inspected."
for item in data["scope_evidence"]:
    if item["surface"] == "SKILL.md":
        item["status"] = "blocked"
        item["evidence"] = "Required target SKILL.md could not be inspected."
for item in data["dimension_scores"]:
    item["score"] = 0
    item["evidence_level"] = "E1"
    item["reason"] = "Not scored because required target evidence is blocked."
data["findings"] = []
data["repair_handoff"] = [
    {
        "target": "shared/skills/example/SKILL.md",
        "action": "Restore access to the blocked target surface and rerun the audit.",
        "owner": "audit coordinator",
    }
]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$VALIDATOR" "$TMP_DIR/blocked-valid.json"

python3 - "$VALID" "$TMP_DIR/blocked-without-blocking-evidence.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["verdict"] = "blocked"
data["overall_score"] = 0
data["verdict_reason"] = "This fixture is intentionally invalid because blocked needs blocked scope evidence or P0 evidence."
data["findings"] = []
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/blocked-without-blocking-evidence.json" >"$TMP_DIR/blocked-without-blocking-evidence.out" 2>&1; then
  fail "blocked verdict without blocked scope or P0 evidence must fail"
fi
grep -Fq "blocked scope evidence or a P0 finding" "$TMP_DIR/blocked-without-blocking-evidence.out" \
  || fail "blocked verdict failure should mention blocked scope or P0 evidence"

python3 - "$VALID" "$TMP_DIR/missing-dimension.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["dimension_scores"] = [
    item
    for item in data["dimension_scores"]
    if item["dimension"] != "Noise And Maintainability"
]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/missing-dimension.json" >"$TMP_DIR/missing-dimension.out" 2>&1; then
  fail "report missing one required dimension must fail"
fi
grep -Fq "Noise And Maintainability" "$TMP_DIR/missing-dimension.out" \
  || fail "missing dimension failure should name the missing dimension"

python3 - "$VALID" "$TMP_DIR/missing-scope.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["scope_evidence"] = [
    item
    for item in data["scope_evidence"]
    if item["surface"] != "downstream consumers"
]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/missing-scope.json" >"$TMP_DIR/missing-scope.out" 2>&1; then
  fail "report missing one required scope surface must fail"
fi
grep -Fq "downstream consumers" "$TMP_DIR/missing-scope.out" \
  || fail "missing scope failure should name the missing surface"

python3 - "$VALID" "$TMP_DIR/vague-finding-evidence.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0]["evidence"] = "SKILL.md says the handoff is incomplete."
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/vague-finding-evidence.json" >"$TMP_DIR/vague-finding-evidence.out" 2>&1; then
  fail "P1 finding without file:line evidence must fail"
fi
grep -Fq "file:line" "$TMP_DIR/vague-finding-evidence.out" \
  || fail "vague finding evidence failure should mention file:line"

python3 - "$VALID" "$TMP_DIR/missing-evidence-checks.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0].pop("evidence_checks", None)
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/missing-evidence-checks.json" >"$TMP_DIR/missing-evidence-checks.out" 2>&1; then
  fail "P1 finding without structured evidence checks must fail"
fi
grep -Fq "evidence_checks" "$TMP_DIR/missing-evidence-checks.out" \
  || fail "missing evidence checks failure should mention evidence_checks"

python3 - "$VALID" "$TMP_DIR/stale-evidence-check.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0]["evidence_checks"][0]["expected_snippet"] = "co_creation_summary"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/stale-evidence-check.json" >"$TMP_DIR/stale-evidence-check.out" 2>&1; then
  fail "P1 finding whose cited line does not contain expected evidence must fail"
fi
grep -Fq "expected_snippet" "$TMP_DIR/stale-evidence-check.out" \
  || fail "stale evidence check failure should mention expected_snippet"

python3 - "$VALID" "$TMP_DIR/low-finding-evidence-level.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0]["evidence_level"] = "E1"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/low-finding-evidence-level.json" >"$TMP_DIR/low-finding-evidence-level.out" 2>&1; then
  fail "P1 finding with evidence_level below E2 must fail"
fi
grep -Fq "E2" "$TMP_DIR/low-finding-evidence-level.out" \
  || fail "low finding evidence level failure should mention E2"

python3 - "$VALID" "$TMP_DIR/vague-scope-evidence.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
for item in data["scope_evidence"]:
    if item["surface"] == "downstream consumers":
        item["evidence"] = "tests and runtime surface consume the package."
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/vague-scope-evidence.json" >"$TMP_DIR/vague-scope-evidence.out" 2>&1; then
  fail "checked scope evidence without active file or directory must fail"
fi
grep -Fq "active file or directory" "$TMP_DIR/vague-scope-evidence.out" \
  || fail "vague scope evidence failure should mention active file or directory"

python3 - "$FIT_VALID" "$TMP_DIR/fit-low-evidence-level.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
for item in data["dimension_scores"]:
    if item["dimension"] == "Instruction Contract":
        item["evidence_level"] = "E2"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/fit-low-evidence-level.json" >"$TMP_DIR/fit-low-evidence-level.out" 2>&1; then
  fail "fit verdict with deciding dimension below E3 must fail"
fi
grep -Fq "Instruction Contract evidence_level E3" "$TMP_DIR/fit-low-evidence-level.out" \
  || fail "fit low evidence level failure should name the dimension and E3"

python3 - "$FIT_VALID" "$TMP_DIR/e4-without-command.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
for item in data["dimension_scores"]:
    if item["dimension"] == "Instruction Contract":
        item["evidence_level"] = "E4"
data["executed_verification"] = []
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/e4-without-command.json" >"$TMP_DIR/e4-without-command.out" 2>&1; then
  fail "E4 evidence without executed verification must fail"
fi
grep -Fq "executed_verification" "$TMP_DIR/e4-without-command.out" \
  || fail "E4 without command failure should mention executed_verification"

printf '[PASS] skill-quality-audit report contract\n'
