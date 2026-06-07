#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALIGNMENT_VALIDATOR="$ROOT/shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py"
REPORT_VALIDATOR="$ROOT/shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py"
VALID_REPORT="$ROOT/tests/fixtures/skill-quality-audit/reports/valid-report.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

[ -f "$ALIGNMENT_VALIDATOR" ] || fail "missing validate_skill_audit_alignment.py"
[ -f "$REPORT_VALIDATOR" ] || fail "missing validate_skill_audit_report.py"
[ -f "$VALID_REPORT" ] || fail "missing valid report fixture"

cat >"$TMP_DIR/valid-alignment.json" <<'JSON'
{
  "artifact_type": "skill-audit-alignment",
  "stage": "confirmed",
  "target_skill": "shared/skills/skill-quality-audit/evals/fixtures/target-skills/good-skill",
  "target_capability_claims": [
    {
      "target_capability_id": "TGT-001",
      "label": "Audit existing Skills for team-use readiness",
      "source": "repo_contract",
      "confidence": "high",
      "refs": ["shared/skills/skill-quality-audit/references/team-use-readiness.md:38"]
    }
  ],
  "current_capability_profile": [
    {
      "current_capability_id": "CUR-001",
      "label": "Produces validator-backed formal reports",
      "status": "supported",
      "evidence_refs": ["EV-001"]
    }
  ],
  "evidence": [
    {
      "evidence_id": "EV-001",
      "type": "path_line",
      "path": "tests/fixtures/skill-quality-audit/evidence-target.md",
      "line": 2,
      "expected_snippet": "Handoff target: separate implementation window owns repair output.",
      "claim": "Current file evidence exists for the handoff capability gap fixture."
    }
  ],
  "assumptions_or_unknowns": [],
  "capability_match_draft": {
    "gaps": [
      {
        "gap_id": "GAP-001",
        "target_capability_id": "TGT-001",
        "current_capability_ids": ["CUR-001"],
        "status": "partial",
        "evidence_refs": ["EV-001"]
      }
    ]
  },
  "user_confirmation": {
    "level": "G1",
    "status": "confirmed",
    "confirmed_scope_ref": "repo_contract:skill-quality-audit.team-use-readiness",
    "confirmed_target_capability_ids": ["TGT-001"],
    "accepted_assumption_ids": []
  }
}
JSON

python3 "$ALIGNMENT_VALIDATOR" "$TMP_DIR/valid-alignment.json"

expect_reject_alignment() {
  local name="$1"
  local expected="$2"
  local out="$TMP_DIR/$name.out"
  if python3 "$ALIGNMENT_VALIDATOR" "$TMP_DIR/$name.json" >"$out" 2>&1; then
    fail "$name alignment must fail"
  fi
  grep -Fq "$expected" "$out" \
    || fail "$name failure should mention: $expected"
}

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/pre-confirmation-verdict.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["stage"] = "awaiting_user_confirmation"
data["user_confirmation"]["status"] = "pending"
data["user_confirmation"]["confirmed_target_capability_ids"] = []
data["verdict"] = "fit"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "pre-confirmation-verdict" "pre-confirmation alignment must not contain verdict"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/supported-with-user-scope.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["evidence"][0] = {
    "evidence_id": "EV-001",
    "type": "user_scope",
    "ref": "chat:target",
    "claim": "User wants this to be ready."
}
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "supported-with-user-scope" "supported current capability requires current evidence"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/g1-inferred-target.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["target_capability_claims"][0]["source"] = "inferred"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "g1-inferred-target" "G1 confirmed scope requires user_supplied or repo_contract target claims"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/g3-confirmed.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["user_confirmation"]["level"] = "G3"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "g3-confirmed" "G3 cannot be confirmed for formal audit"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/confirmed-target-without-gap.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["target_capability_claims"].append({
    "target_capability_id": "TGT-002",
    "label": "Second confirmed target must have a match row",
    "source": "repo_contract",
    "confidence": "high",
    "refs": ["shared/skills/skill-quality-audit/references/team-use-readiness.md:43"],
})
data["user_confirmation"]["confirmed_target_capability_ids"].append("TGT-002")
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "confirmed-target-without-gap" "confirmed target capabilities require capability_match_draft gaps"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/gap-without-evidence.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["capability_match_draft"]["gaps"][0]["evidence_refs"] = []
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "gap-without-evidence" "GAP-001.evidence_refs must be non-empty"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/gap-with-user-scope-evidence.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["evidence"].append({
    "evidence_id": "EV-USER-SCOPE",
    "type": "user_scope",
    "ref": "chat:scope",
    "claim": "The user wants this capability audited."
})
data["capability_match_draft"]["gaps"][0]["evidence_refs"] = ["EV-USER-SCOPE"]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "gap-with-user-scope-evidence" "GAP-001.evidence_refs must cite current evidence"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/supported-with-historical-audit.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["evidence"][0] = {
    "evidence_id": "EV-001",
    "type": "runtime",
    "ref": "shared/skills/skill-quality-audit/evals/dogfood/self-audit/skill-audit-report.json",
    "claim": "Historical self-audit says this capability worked before."
}
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "supported-with-historical-audit" "supported current capability cannot rely on historical audit evidence"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/supported-with-generic-old-audit-report.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["evidence"][0] = {
    "evidence_id": "EV-001",
    "type": "runtime",
    "ref": "docs/tmp/old-skill-quality-audit-report.json",
    "claim": "An old audit report claimed the current capability was supported."
}
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "supported-with-generic-old-audit-report" "supported current capability cannot rely on historical audit evidence"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/stale-path-line.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["evidence"][0]["expected_snippet"] = "not present on the cited line"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_reject_alignment "stale-path-line" "expected_snippet"

python3 - "$VALID_REPORT" "$TMP_DIR/formal-with-alignment.json" "$TMP_DIR/valid-alignment.json" "$TMP_DIR/formal-with-alignment.md" <<'PY'
import json
import sys
from pathlib import Path

src, dst, alignment, summary = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["capability_baseline_ref"] = str(alignment)
data["confirmed_target_capability_ids"] = ["TGT-001"]
for finding in data["findings"]:
    finding["confirmed_gap_refs"] = ["GAP-001"]
data["artifact_paths"]["report_json"] = str(dst)
data["artifact_paths"]["summary_markdown"] = str(summary)
data["validation"] = {
    "status": "PASS",
    "alignment": {
        "status": "PASS",
        "command": "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py " + str(alignment),
        "output": "[PASS] skill audit alignment valid",
    },
    "report": {
        "status": "PASS",
        "command": "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py " + str(dst),
        "output": "[PASS] skill audit report valid",
    },
}
summary.write_text(
    Path("tests/fixtures/skill-quality-audit/reports/valid-report.md").read_text(
        encoding="utf-8"
    ),
    encoding="utf-8",
)
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$REPORT_VALIDATOR" "$TMP_DIR/formal-with-alignment.json"

python3 - "$TMP_DIR/formal-with-alignment.json" "$TMP_DIR/formal-missing-baseline.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data.pop("capability_baseline_ref", None)
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$REPORT_VALIDATOR" "$TMP_DIR/formal-missing-baseline.json" >"$TMP_DIR/formal-missing-baseline.out" 2>&1; then
  fail "formal report without capability_baseline_ref must fail"
fi
grep -Fq "capability_baseline_ref" "$TMP_DIR/formal-missing-baseline.out" \
  || fail "missing baseline failure should mention capability_baseline_ref"

python3 - "$TMP_DIR/formal-with-alignment.json" "$TMP_DIR/formal-missing-gap-ref.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0].pop("confirmed_gap_refs", None)
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$REPORT_VALIDATOR" "$TMP_DIR/formal-missing-gap-ref.json" >"$TMP_DIR/formal-missing-gap-ref.out" 2>&1; then
  fail "formal finding without confirmed_gap_refs must fail"
fi
grep -Fq "confirmed_gap_refs" "$TMP_DIR/formal-missing-gap-ref.out" \
  || fail "missing gap ref failure should mention confirmed_gap_refs"

python3 - "$TMP_DIR/formal-with-alignment.json" "$TMP_DIR/formal-unknown-gap-ref.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["findings"][0]["confirmed_gap_refs"] = ["GAP-404"]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$REPORT_VALIDATOR" "$TMP_DIR/formal-unknown-gap-ref.json" >"$TMP_DIR/formal-unknown-gap-ref.out" 2>&1; then
  fail "formal finding with unknown confirmed gap must fail"
fi
grep -Fq "unknown confirmed_gap_refs" "$TMP_DIR/formal-unknown-gap-ref.out" \
  || fail "unknown gap ref failure should mention confirmed_gap_refs"

python3 - "$TMP_DIR/valid-alignment.json" "$TMP_DIR/two-target-alignment.json" "$TMP_DIR/formal-with-alignment.json" "$TMP_DIR/formal-unreported-gap-target.json" <<'PY'
import json
import sys
from pathlib import Path

alignment_src, alignment_dst, report_src, report_dst = map(Path, sys.argv[1:])
alignment = json.loads(alignment_src.read_text(encoding="utf-8"))
alignment["target_capability_claims"].append({
    "target_capability_id": "TGT-002",
    "label": "Second confirmed target",
    "source": "repo_contract",
    "confidence": "high",
    "refs": ["shared/skills/skill-quality-audit/references/team-use-readiness.md:43"],
})
alignment["capability_match_draft"]["gaps"].append({
    "gap_id": "GAP-002",
    "target_capability_id": "TGT-002",
    "current_capability_ids": ["CUR-001"],
    "status": "partial",
    "evidence_refs": ["EV-001"],
})
alignment_dst.write_text(json.dumps(alignment, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

report = json.loads(report_src.read_text(encoding="utf-8"))
report["capability_baseline_ref"] = str(alignment_dst)
report["confirmed_target_capability_ids"] = ["TGT-001"]
report["findings"][0]["confirmed_gap_refs"] = ["GAP-002"]
report["validation"]["alignment"]["command"] = (
    "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py "
    + str(alignment_dst)
)
report_dst.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$REPORT_VALIDATOR" "$TMP_DIR/formal-unreported-gap-target.json" >"$TMP_DIR/formal-unreported-gap-target.out" 2>&1; then
  fail "formal finding whose gap target is not in report confirmed_target_capability_ids must fail"
fi
grep -Fq "does not point to a report-confirmed target capability" "$TMP_DIR/formal-unreported-gap-target.out" \
  || fail "unreported gap target failure should mention report-confirmed target capability"

python3 - "$TMP_DIR/formal-with-alignment.json" "$TMP_DIR/formal-target-mismatch.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["target_skill"] = "shared/skills/another-target"
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$REPORT_VALIDATOR" "$TMP_DIR/formal-target-mismatch.json" >"$TMP_DIR/formal-target-mismatch.out" 2>&1; then
  fail "formal report whose baseline target differs from report target must fail"
fi
grep -Fq "target_skill must match" "$TMP_DIR/formal-target-mismatch.out" \
  || fail "target mismatch failure should mention target_skill"

printf '[PASS] skill-quality-audit alignment contract\n'
