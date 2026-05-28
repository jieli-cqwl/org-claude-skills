#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py"
PLAN="$ROOT/shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json"
LIFECYCLE="$ROOT/shared/skills/skill-quality-audit/evals/lifecycle-review.json"
REPORT_FIXTURE="$ROOT/shared/skills/skill-quality-audit/evals/fixtures/reports/valid-report.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

[ -f "$SCRIPT" ] || fail "missing validate_empirical_baseline.py"

python3 "$SCRIPT" "$PLAN" "$LIFECYCLE"

python3 - "$PLAN" "$LIFECYCLE" "$TMP_DIR" "$REPORT_FIXTURE" <<'PY'
import json
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
lifecycle_path = Path(sys.argv[2])
tmp = Path(sys.argv[3])
report_fixture = Path(sys.argv[4])

plan = json.loads(plan_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))
plan["delta_review_ref"] = str(tmp / "delta-review.json")

summaries = []
for case in plan["cases"]:
    case_root = tmp / case["id"]
    for run_mode in ("with_skill", "without_skill"):
        output_dir = case_root / run_mode
        output_dir.mkdir(parents=True)
        summary_ref = output_dir / "summary.json"
        raw_output_ref = output_dir / "raw-output.md"
        case[run_mode]["output_dir"] = str(output_dir)
        case[run_mode]["summary_ref"] = str(summary_ref)
        formal_report_ref = output_dir / "formal-report.json"
        if run_mode == "with_skill":
            report = json.loads(report_fixture.read_text(encoding="utf-8"))
            report["target_skill"] = case["target_skill"]
            report["artifact_paths"]["report_json"] = str(formal_report_ref)
            report["artifact_paths"]["summary_markdown"] = str(output_dir / "audit-summary.md")
            report["validation"]["command"] = (
                "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py "
                + str(formal_report_ref)
            )
            (output_dir / "audit-summary.md").write_text(
                "# Skill Audit Summary\n\nNo P0/P1 findings.\n",
                encoding="utf-8",
            )
            formal_report_ref.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        raw_output_ref.write_text(
            f"# Raw Output\n\ncase={case['id']}\nmode={run_mode}\n",
            encoding="utf-8",
        )
        summary = {
            "artifact_type": "skill-quality-audit-empirical-run-summary",
            "case_id": case["id"],
            "run_mode": run_mode,
            "target_skill": case["target_skill"],
            "graded": True,
            "pass_rate": 1.0 if run_mode == "with_skill" else 0.6,
            "anchor_passed": 5 if run_mode == "with_skill" else 3,
            "anchor_total": 5,
            "infra_failures": 0,
            "readiness_checks": {
                name: "PASS" if run_mode == "with_skill" else "PARTIAL"
                for name in case["readiness_checks"]
            },
            "validator_status": "PASS" if run_mode == "with_skill" else "NOT_APPLICABLE",
            "formal_report_ref": str(formal_report_ref) if run_mode == "with_skill" else None,
            "raw_output_ref": str(raw_output_ref),
            "repair_handoff_quality": "actionable" if run_mode == "with_skill" else "partial",
        }
        summary_ref.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        summaries.append(summary_ref)

delta = {
    "artifact_type": "skill-quality-audit-empirical-delta-review",
    "measurement_status": "completed_human_delta_review",
    "reviewed_cases": [
        {
            "case_id": case["id"],
            "with_skill_summary_ref": case["with_skill"]["summary_ref"],
            "without_skill_summary_ref": case["without_skill"]["summary_ref"],
            "finding": "with_skill improves evidence integrity and repair handoff quality.",
        }
        for case in plan["cases"]
    ],
    "team_ready_gate": {
        "with_skill_anchor_fidelity": 1.0,
        "infra_failures": 0,
        "without_skill_delta_observed": True,
        "validator_pass_for_with_skill_reports": True,
    },
    "conclusion": "team-ready",
}
Path(plan["delta_review_ref"]).write_text(json.dumps(delta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

lifecycle["evidence_refs"] = lifecycle.get("evidence_refs", []) + [
    str(path) for path in summaries
] + [plan["delta_review_ref"]]
lifecycle["capability_uplift"].update(
    {
        "measurement_status": "pilot_empirical_sample_recorded",
        "with_avg": 1.0,
        "without_avg": 0.6,
        "uplift": 0.4,
        "with_sample_size": len(plan["cases"]),
        "without_sample_size": len(plan["cases"]),
    }
)
lifecycle["encoded_preference"].update(
    {
        "measurement_status": "pilot_empirical_sample_recorded",
        "fidelity": 1.0,
        "sample_size": len(plan["cases"]),
        "anchor_passed": 10,
        "anchor_total": 10,
    }
)
lifecycle["human_read_delta_review"] = {
    "measurement_status": "completed_human_delta_review",
    "delta_review_ref": plan["delta_review_ref"],
    "conclusion": "team-ready",
}

(tmp / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(tmp / "lifecycle.json").write_text(json.dumps(lifecycle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$SCRIPT" "$TMP_DIR/plan.json" "$TMP_DIR/lifecycle.json" --require-complete

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/bad-plan.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
plan = json.loads(src.read_text(encoding="utf-8"))
summary_ref = Path(plan["cases"][0]["with_skill"]["summary_ref"])
summary = json.loads(summary_ref.read_text(encoding="utf-8"))
bad_summary_ref = summary_ref.parent / "bad" / "summary.json"
bad_summary_ref.parent.mkdir()
summary["validator_status"] = "FAIL"
bad_summary_ref.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
plan["cases"][0]["with_skill"]["summary_ref"] = str(bad_summary_ref)
dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-plan.json" "$TMP_DIR/lifecycle.json" --require-complete >"$TMP_DIR/bad-validator.out" 2>&1; then
  fail "with_skill summary without validator PASS must fail"
fi
grep -Fq "validator_status" "$TMP_DIR/bad-validator.out" \
  || fail "bad validator failure should mention validator_status"

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/bad-raw-plan.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
plan = json.loads(src.read_text(encoding="utf-8"))
summary_ref = Path(plan["cases"][0]["without_skill"]["summary_ref"])
summary = json.loads(summary_ref.read_text(encoding="utf-8"))
bad_summary_ref = summary_ref.parent / "bad-raw" / "summary.json"
bad_summary_ref.parent.mkdir()
summary.pop("raw_output_ref", None)
bad_summary_ref.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
plan["cases"][0]["without_skill"]["summary_ref"] = str(bad_summary_ref)
dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-raw-plan.json" "$TMP_DIR/lifecycle.json" --require-complete >"$TMP_DIR/bad-raw.out" 2>&1; then
  fail "summary without raw_output_ref must fail"
fi
grep -Fq "raw_output_ref" "$TMP_DIR/bad-raw.out" \
  || fail "bad raw output failure should mention raw_output_ref"

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/bad-formal-plan.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
plan = json.loads(src.read_text(encoding="utf-8"))
summary_ref = Path(plan["cases"][0]["with_skill"]["summary_ref"])
summary = json.loads(summary_ref.read_text(encoding="utf-8"))
bad_dir = summary_ref.parent / "bad-formal"
bad_dir.mkdir()
bad_summary_ref = bad_dir / "summary.json"
bad_report = bad_dir / "formal-report.json"
bad_report.write_text('{"artifact_type":"skill-audit-report"}\n', encoding="utf-8")
summary["formal_report_ref"] = str(bad_report)
bad_summary_ref.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
plan["cases"][0]["with_skill"]["summary_ref"] = str(bad_summary_ref)
dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-formal-plan.json" "$TMP_DIR/lifecycle.json" --require-complete >"$TMP_DIR/bad-formal.out" 2>&1; then
  fail "with_skill summary with invalid formal report must fail"
fi
grep -Fq "formal_report_ref" "$TMP_DIR/bad-formal.out" \
  || fail "bad formal report failure should mention formal_report_ref"

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/lifecycle.json" "$TMP_DIR/bad-fidelity-plan.json" "$TMP_DIR/bad-fidelity-lifecycle.json" <<'PY'
import json
import sys
from pathlib import Path

plan_path, lifecycle_path, plan_dst, lifecycle_dst = map(Path, sys.argv[1:])
plan = json.loads(plan_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))
delta_ref = Path(plan["delta_review_ref"])
delta = json.loads(delta_ref.read_text(encoding="utf-8"))
bad_delta_ref = delta_ref.with_name("bad-fidelity-delta-review.json")
delta["team_ready_gate"]["with_skill_anchor_fidelity"] = 0.9
bad_delta_ref.write_text(json.dumps(delta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
plan["delta_review_ref"] = str(bad_delta_ref)
lifecycle["human_read_delta_review"]["delta_review_ref"] = str(bad_delta_ref)
lifecycle["evidence_refs"] = [
    str(bad_delta_ref) if ref == str(delta_ref) else ref
    for ref in lifecycle["evidence_refs"]
]
plan_dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
lifecycle_dst.write_text(json.dumps(lifecycle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-fidelity-plan.json" "$TMP_DIR/bad-fidelity-lifecycle.json" --require-complete >"$TMP_DIR/bad-fidelity.out" 2>&1; then
  fail "delta review anchor fidelity mismatch must fail"
fi
grep -Fq "with_skill_anchor_fidelity" "$TMP_DIR/bad-fidelity.out" \
  || fail "bad fidelity failure should mention with_skill_anchor_fidelity"

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/lifecycle.json" "$TMP_DIR/bad-lifecycle.json" <<'PY'
import json
import sys
from pathlib import Path

plan_path, lifecycle_path, dst = map(Path, sys.argv[1:])
plan = json.loads(plan_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))
delta_ref = Path(plan["delta_review_ref"])
delta = json.loads(delta_ref.read_text(encoding="utf-8"))
delta["reviewed_cases"] = delta["reviewed_cases"][:1]
delta_ref.write_text(json.dumps(delta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
dst.write_text(json.dumps(lifecycle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/plan.json" "$TMP_DIR/bad-lifecycle.json" --require-complete >"$TMP_DIR/bad-delta.out" 2>&1; then
  fail "delta review missing a case must fail"
fi
grep -Fq "reviewed_cases" "$TMP_DIR/bad-delta.out" \
  || fail "bad delta failure should mention reviewed_cases"

printf '[PASS] skill-quality-audit empirical baseline validator\n'
