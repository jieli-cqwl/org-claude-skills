#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/shared/skills/skill-quality-audit/scripts/validate_empirical_baseline.py"
PLAN="$ROOT/shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/plan.json"
LIFECYCLE="$ROOT/shared/skills/skill-quality-audit/evals/lifecycle-review.json"
REPORT_FIXTURE="$ROOT/shared/skills/skill-quality-audit/evals/fixtures/reports/valid-report.json"
RESEARCH_REPORT="$ROOT/shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/with_skill/skill-audit-report.json"
RESEARCH_SUMMARY="$ROOT/shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/with_skill/audit-summary.md"

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
            alignment_ref = output_dir / "skill-audit-alignment.json"
            alignment = {
                "artifact_type": "skill-audit-alignment",
                "stage": "confirmed",
                "target_skill": case["target_skill"],
                "target_capability_claims": [
                    {
                        "target_capability_id": "TGT-001",
                        "label": "Empirical fixture target capability",
                        "source": "user_supplied",
                        "confidence": "high",
                        "refs": [case["target_skill"]],
                    }
                ],
                "current_capability_profile": [
                    {
                        "current_capability_id": "CUR-001",
                        "label": "Empirical fixture current capability",
                        "status": "supported",
                        "evidence_refs": ["EV-001"],
                    }
                ],
                "evidence": [
                    {
                        "evidence_id": "EV-001",
                        "type": "runtime",
                        "ref": str(formal_report_ref),
                        "claim": "Generated empirical formal report fixture for the case target.",
                    }
                ],
                "assumptions_or_unknowns": [],
                "capability_match_draft": {
                    "gaps": [
                        {
                            "gap_id": "GAP-001",
                            "target_capability_id": "TGT-001",
                            "current_capability_ids": ["CUR-001"],
                            "status": "matched",
                            "evidence_refs": ["EV-001"],
                        }
                    ]
                },
                "user_confirmation": {
                    "level": "G1",
                    "status": "confirmed",
                    "confirmed_scope_ref": "user_scope:empirical-baseline-fixture",
                    "confirmed_target_capability_ids": ["TGT-001"],
                    "accepted_assumption_ids": [],
                },
            }
            alignment_ref.write_text(json.dumps(alignment, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            report["capability_baseline_ref"] = str(alignment_ref)
            report["confirmed_target_capability_ids"] = ["TGT-001"]
            report["validation"] = {
                "status": "PASS",
                "alignment": {
                    "status": "PASS",
                    "command": "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_alignment.py " + str(alignment_ref),
                    "output": "[PASS] skill audit alignment valid",
                },
                "report": {
                    "status": "PASS",
                    "command": "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py " + str(formal_report_ref),
                    "output": "[PASS] skill audit report valid",
                },
            }
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

python3 - "$TMP_DIR/plan.json" "$RESEARCH_REPORT" "$RESEARCH_SUMMARY" "$TMP_DIR/bad-stale-plan.json" <<'PY'
import json
import sys
from pathlib import Path

plan_path, report_src, summary_src, dst = map(Path, sys.argv[1:])
plan = json.loads(plan_path.read_text(encoding="utf-8"))
case = next(item for item in plan["cases"] if item["id"] == "research-artifact-triage-audit")
summary_ref = Path(case["with_skill"]["summary_ref"])
summary = json.loads(summary_ref.read_text(encoding="utf-8"))
bad_dir = summary_ref.parent / "bad-stale"
bad_dir.mkdir()
bad_report = bad_dir / "formal-report.json"
bad_summary = bad_dir / "audit-summary.md"
bad_summary_ref = bad_dir / "summary.json"
report = json.loads(report_src.read_text(encoding="utf-8"))
report["artifact_paths"]["report_json"] = str(bad_report)
report["artifact_paths"]["summary_markdown"] = str(bad_summary)
report["validation"]["report"]["command"] = (
    "python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py "
    + str(bad_report)
)
report["findings"][1]["evidence_checks"][3]["expected_snippet"] = "definitely not present in the current fixture line"
bad_report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
bad_summary.write_text(summary_src.read_text(encoding="utf-8"), encoding="utf-8")
summary["formal_report_ref"] = str(bad_report)
bad_summary_ref.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
case["with_skill"]["summary_ref"] = str(bad_summary_ref)
dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-stale-plan.json" "$TMP_DIR/lifecycle.json" --require-complete >"$TMP_DIR/bad-stale.out" 2>&1; then
  fail "stale evidence in with_skill formal report must fail complete baseline"
fi
grep -Fq "formal_report_ref failed validate_skill_audit_report.py" "$TMP_DIR/bad-stale.out" \
  || fail "stale evidence failure should identify formal_report_ref validation"
grep -Fq "expected_snippet" "$TMP_DIR/bad-stale.out" \
  || fail "stale evidence failure should identify expected_snippet"

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

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/bad-missing-formal-plan.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
plan = json.loads(src.read_text(encoding="utf-8"))
summary_ref = Path(plan["cases"][0]["with_skill"]["summary_ref"])
summary = json.loads(summary_ref.read_text(encoding="utf-8"))
bad_summary_ref = summary_ref.parent / "bad-missing-formal" / "summary.json"
bad_summary_ref.parent.mkdir()
summary.pop("formal_report_ref", None)
bad_summary_ref.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
plan["cases"][0]["with_skill"]["summary_ref"] = str(bad_summary_ref)
dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-missing-formal-plan.json" "$TMP_DIR/lifecycle.json" --require-complete >"$TMP_DIR/bad-missing-formal.out" 2>&1; then
  fail "with_skill summary missing formal_report_ref must fail"
fi
grep -Fq "formal_report_ref" "$TMP_DIR/bad-missing-formal.out" \
  || fail "missing formal report failure should mention formal_report_ref"

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

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/bad-empty-raw-plan.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
plan = json.loads(src.read_text(encoding="utf-8"))
summary_ref = Path(plan["cases"][0]["without_skill"]["summary_ref"])
summary = json.loads(summary_ref.read_text(encoding="utf-8"))
bad_summary_ref = summary_ref.parent / "bad-empty-raw" / "summary.json"
bad_summary_ref.parent.mkdir()
empty_raw = bad_summary_ref.parent / "raw-output.md"
empty_raw.write_text("", encoding="utf-8")
summary["raw_output_ref"] = str(empty_raw)
bad_summary_ref.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
plan["cases"][0]["without_skill"]["summary_ref"] = str(bad_summary_ref)
dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-empty-raw-plan.json" "$TMP_DIR/lifecycle.json" --require-complete >"$TMP_DIR/bad-empty-raw.out" 2>&1; then
  fail "summary with empty raw_output_ref file must fail"
fi
grep -Fq "raw_output_ref" "$TMP_DIR/bad-empty-raw.out" \
  || fail "empty raw output failure should mention raw_output_ref"

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

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/lifecycle.json" "$TMP_DIR/bad-missing-summary-lifecycle.json" <<'PY'
import json
import sys
from pathlib import Path

plan_path, lifecycle_path, dst = map(Path, sys.argv[1:])
plan = json.loads(plan_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))
missing = plan["cases"][0]["with_skill"]["summary_ref"]
lifecycle["evidence_refs"] = [ref for ref in lifecycle["evidence_refs"] if ref != missing]
dst.write_text(json.dumps(lifecycle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/plan.json" "$TMP_DIR/bad-missing-summary-lifecycle.json" --require-complete >"$TMP_DIR/bad-missing-summary.out" 2>&1; then
  fail "summary_ref missing from lifecycle.evidence_refs must fail"
fi
grep -Fq "lifecycle.evidence_refs" "$TMP_DIR/bad-missing-summary.out" \
  || fail "missing summary lifecycle failure should mention lifecycle.evidence_refs"

python3 - "$TMP_DIR/plan.json" "$TMP_DIR/lifecycle.json" "$TMP_DIR/bad-delta-ref-plan.json" "$TMP_DIR/bad-delta-ref-lifecycle.json" <<'PY'
import json
import sys
from pathlib import Path

plan_path, lifecycle_path, plan_dst, lifecycle_dst = map(Path, sys.argv[1:])
plan = json.loads(plan_path.read_text(encoding="utf-8"))
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))
delta_ref = Path(plan["delta_review_ref"])
bad_delta_ref = delta_ref.with_name("bad-delta-ref-review.json")
bad_delta_ref.write_text(delta_ref.read_text(encoding="utf-8"), encoding="utf-8")
plan["delta_review_ref"] = str(bad_delta_ref)
lifecycle["evidence_refs"].append(str(bad_delta_ref))
plan_dst.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
lifecycle_dst.write_text(json.dumps(lifecycle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" "$TMP_DIR/bad-delta-ref-plan.json" "$TMP_DIR/bad-delta-ref-lifecycle.json" --require-complete >"$TMP_DIR/bad-delta-ref.out" 2>&1; then
  fail "plan/lifecycle delta_review_ref mismatch must fail"
fi
grep -Fq "human_read_delta_review.delta_review_ref" "$TMP_DIR/bad-delta-ref.out" \
  || fail "delta ref mismatch failure should mention human_read_delta_review.delta_review_ref"

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
