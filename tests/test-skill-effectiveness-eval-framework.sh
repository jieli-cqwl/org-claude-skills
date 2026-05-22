#!/usr/bin/env bash
# 文件职责：验证 first-party Skill eval 元数据和有效性复盘保持一致。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/skills/skill-refiner/references/quality-dimensions.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$STANDARD" || fail "missing skill standard"
test ! -f "$ROOT/shared/reference/Skill生命周期管理.md" || fail "Skill lifecycle management standard must be deleted"
test ! -f "$ROOT/shared/reference/Skill质量标准.md" || fail "retired skill quality standard must not remain active"
test ! -f "$ROOT/shared/reference/Skill能力有效性标准.md" || fail "retired skill capability standard must not remain active"
test ! -f "$ROOT/shared/reference/Skill标准.md" || fail "retired skill standard must not remain active (merged into quality-dimensions.md)"
test ! -d "$ROOT/shared/skills/skill-harness" || fail "retired skill-harness must not remain active"

python3 - "$ROOT" <<'PY'
import json
import re
import sys
from copy import deepcopy
from pathlib import Path

root = Path(sys.argv[1])
expected = {
    "product-director": "encoded_preference",
    "product-manager": "encoded_preference",
    "design": "mixed",
    "test-design": "mixed",
    "tech-lead": "encoded_preference",
    "developer": "mixed",
    "review": "mixed",
    "verify": "mixed",
    "qa": "mixed",
    "delivery-owner": "mixed",
    "fix": "mixed",
    "consistency-audit": "mixed",
    "skill-refiner": "mixed",
}
allowed_decisions = {"retain", "optimize", "retire"}


def frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"---\n(.*?)\n---", text, re.S)
    if not match:
        raise SystemExit(f"{path}: missing YAML frontmatter")
    data = {}
    for line in match.group(1).splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            data[key.strip()] = value.strip().strip('"')
    return data


def validate_retain_measurements(review: dict, eval_type: str, review_file: object) -> None:
    if review.get("decision") != "retain":
        return
    if eval_type in {"encoded_preference", "mixed"}:
        preference = review.get("encoded_preference", {})
        fidelity = preference.get("fidelity")
        if not isinstance(fidelity, (int, float)) or fidelity < 0.80:
            raise SystemExit(f"{review_file}: retain requires encoded_preference.fidelity >= 0.80")
        measurement_status = str(preference.get("measurement_status", ""))
        if "needs" in measurement_status or "defined_needs" in measurement_status:
            raise SystemExit(f"{review_file}: retain requires completed encoded_preference measurement_status")
    if eval_type in {"capability_uplift", "mixed"}:
        uplift = review.get("capability_uplift", {})
        with_avg = uplift.get("with_avg")
        uplift_value = uplift.get("uplift")
        if not isinstance(with_avg, (int, float)) or with_avg < 4.0:
            raise SystemExit(f"{review_file}: retain requires capability_uplift.with_avg >= 4.0")
        if not isinstance(uplift_value, (int, float)) or uplift_value < 1.0:
            raise SystemExit(f"{review_file}: retain requires capability_uplift.uplift >= 1.0")


def expect_retain_failure(review: dict, eval_type: str, expected_message: str) -> None:
    try:
        validate_retain_measurements(review, eval_type, "synthetic-retain-review.json")
    except SystemExit as exc:
        if expected_message not in str(exc):
            raise SystemExit(f"retain synthetic fixture failed with wrong message: {exc}") from exc
    else:
        raise SystemExit(f"retain synthetic fixture should fail: {expected_message}")


for skill, eval_type in expected.items():
    skill_dir = root / "shared" / "skills" / skill
    skill_file = skill_dir / "SKILL.md"
    eval_file = skill_dir / "evals" / "evals.json"
    review_file = skill_dir / "evals" / "lifecycle-review.json"

    if not skill_file.is_file():
        raise SystemExit(f"missing SKILL.md for {skill}")
    if frontmatter(skill_file).get("eval-type") != eval_type:
        raise SystemExit(f"{skill_file}: eval-type must be {eval_type}")
    if not eval_file.is_file():
        raise SystemExit(f"missing evals file for {skill}")
    if not review_file.is_file():
        raise SystemExit(f"missing effectiveness review for {skill}")

    evals = json.loads(eval_file.read_text(encoding="utf-8"))
    if evals.get("skill_name") != skill:
        raise SystemExit(f"{eval_file}: skill_name must be {skill}")
    if evals.get("eval_type") != eval_type:
        raise SystemExit(f"{eval_file}: eval_type must be {eval_type}")
    cases = evals.get("evals")
    if not isinstance(cases, list) or len(cases) < 3:
        raise SystemExit(f"{eval_file}: expected at least 3 evals")
    if eval_type in {"encoded_preference", "mixed"}:
        anchors = evals.get("preference_anchors")
        max_anchors = max(12, min(24, len(cases) + 4))
        if not isinstance(anchors, list) or not (5 <= len(anchors) <= max_anchors):
            raise SystemExit(f"{eval_file}: expected 5-{max_anchors} preference anchors")
        anchor_ids = {item.get("id") for item in anchors if isinstance(item, dict)}
        if len(anchor_ids) != len(anchors):
            raise SystemExit(f"{eval_file}: preference anchor ids must be unique")
    if eval_type in {"capability_uplift", "mixed"}:
        dimensions = evals.get("grader_dimensions")
        if not isinstance(dimensions, list) or not dimensions:
            raise SystemExit(f"{eval_file}: missing grader_dimensions")
    for case in cases:
        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id:
            raise SystemExit(f"{eval_file}: eval id must be a non-empty string")
        if not isinstance(case.get("prompt"), str) or not case["prompt"].strip():
            raise SystemExit(f"{eval_file}: eval {case_id} missing prompt")
        if not isinstance(case.get("expected_output"), str) or not case["expected_output"].strip():
            raise SystemExit(f"{eval_file}: eval {case_id} missing expected_output")
        if eval_type in {"encoded_preference", "mixed"}:
            expected_anchors = case.get("expected_anchors")
            if not isinstance(expected_anchors, list) or not expected_anchors:
                raise SystemExit(f"{eval_file}: eval {case_id} missing expected_anchors")
            unknown = sorted(set(expected_anchors) - anchor_ids)
            if unknown:
                raise SystemExit(f"{eval_file}: eval {case_id} unknown anchors {unknown}")
        if eval_type in {"capability_uplift", "mixed"}:
            run_modes = case.get("run_modes")
            if run_modes != ["with_skill", "without_skill"]:
                raise SystemExit(f"{eval_file}: eval {case_id} must run with and without skill")

    review = json.loads(review_file.read_text(encoding="utf-8"))
    if review.get("skill_name") != skill:
        raise SystemExit(f"{review_file}: skill_name must be {skill}")
    if review.get("eval_type") != eval_type:
        raise SystemExit(f"{review_file}: eval_type must be {eval_type}")
    if review.get("decision") not in allowed_decisions:
        raise SystemExit(f"{review_file}: decision must be retain/optimize/retire")
    if not isinstance(review.get("next_action"), str) or not review["next_action"].strip():
        raise SystemExit(f"{review_file}: next_action required")
    if not review.get("evidence_refs"):
        raise SystemExit(f"{review_file}: evidence_refs required")
    if "shared/reference/Skill生命周期管理.md" in review.get("evidence_refs", []):
        raise SystemExit(f"{review_file}: evidence_refs must not depend on removed Skill lifecycle standard")
    if eval_type in {"encoded_preference", "mixed"} and "encoded_preference" not in review:
        raise SystemExit(f"{review_file}: encoded_preference review data required")
    if eval_type in {"capability_uplift", "mixed"} and "capability_uplift" not in review:
        raise SystemExit(f"{review_file}: capability_uplift review data required")
    if skill == "test-design":
        if review.get("decision") != "optimize":
            raise SystemExit(f"{review_file}: test-design must stay optimize until empirical with/without results exist")
        capability = review.get("capability_uplift", {})
        if capability.get("measurement_status") != "pilot_empirical_sample_recorded":
            raise SystemExit(f"{review_file}: test-design capability_uplift must record pilot empirical sample")
        if capability.get("with_sample_size") != 6 or capability.get("without_sample_size") != 6:
            raise SystemExit(f"{review_file}: test-design empirical sample size must be 6/6")
        if capability.get("with_avg") != 1.0:
            raise SystemExit(f"{review_file}: test-design with_skill avg must be 1.0")
        if not isinstance(capability.get("uplift"), (int, float)) or capability.get("uplift") <= 0:
            raise SystemExit(f"{review_file}: test-design uplift must be positive")
        for summary_ref in capability.get("summary_refs", []):
            if not (root / summary_ref).is_file():
                raise SystemExit(f"{review_file}: missing test-design capability summary ref {summary_ref}")
        preference = review.get("encoded_preference", {})
        if preference.get("measurement_status") != "pilot_empirical_sample_recorded":
            raise SystemExit(f"{review_file}: test-design encoded preference must record pilot empirical sample")
        if preference.get("anchor_count") != len(evals.get("preference_anchors", [])):
            raise SystemExit(f"{review_file}: test-design anchor_count must match evals.json")
        if preference.get("eval_count") != len(cases):
            raise SystemExit(f"{review_file}: test-design eval_count must match evals.json")
        if preference.get("fidelity") != 1.0:
            raise SystemExit(f"{review_file}: test-design pilot anchor fidelity must be 1.0")
        if preference.get("sample_size") != 6:
            raise SystemExit(f"{review_file}: test-design pilot anchor fidelity sample_size must be 6")
        if preference.get("anchor_passed") != preference.get("anchor_total"):
            raise SystemExit(f"{review_file}: test-design pilot anchors must all pass")
        for summary_ref in preference.get("summary_refs", []):
            if not (root / summary_ref).is_file():
                raise SystemExit(f"{review_file}: missing test-design anchor fidelity ref {summary_ref}")
        pilot = review.get("pilot_empirical", {})
        if pilot.get("measurement_status") != "pilot_empirical_sample_recorded":
            raise SystemExit(f"{review_file}: test-design pilot_empirical required")
        if pilot.get("with_skill", {}).get("infra_failures") != 0:
            raise SystemExit(f"{review_file}: test-design with_skill infra_failures must be 0")
        if pilot.get("without_skill", {}).get("infra_failures") != 0:
            raise SystemExit(f"{review_file}: test-design without_skill infra_failures must be 0")
    if skill in {"product-director", "product-manager"} and eval_type in {"encoded_preference", "mixed"}:
        used_anchors = {
            anchor
            for case in cases
            for anchor in case.get("expected_anchors", [])
        }
        unused_anchors = sorted(anchor_ids - used_anchors)
        if unused_anchors:
            raise SystemExit(f"{eval_file}: unused preference anchors {unused_anchors}")
    validate_retain_measurements(review, eval_type, review_file)

synthetic_retain = {
    "decision": "retain",
    "encoded_preference": {"fidelity": 0.91, "measurement_status": "completed_empirical_run"},
    "capability_uplift": {"with_avg": 4.2, "uplift": 1.1},
}
validate_retain_measurements(synthetic_retain, "mixed", "synthetic-retain-review.json")

low_fidelity_retain = deepcopy(synthetic_retain)
low_fidelity_retain["encoded_preference"]["fidelity"] = 0.79
expect_retain_failure(low_fidelity_retain, "mixed", "fidelity >= 0.80")

unmeasured_retain = deepcopy(synthetic_retain)
unmeasured_retain["encoded_preference"]["measurement_status"] = "needs_empirical_baseline"
expect_retain_failure(unmeasured_retain, "mixed", "completed encoded_preference measurement_status")

low_with_avg_retain = deepcopy(synthetic_retain)
low_with_avg_retain["capability_uplift"]["with_avg"] = 3.99
expect_retain_failure(low_with_avg_retain, "mixed", "capability_uplift.with_avg >= 4.0")

low_uplift_retain = deepcopy(synthetic_retain)
low_uplift_retain["capability_uplift"]["uplift"] = 0.99
expect_retain_failure(low_uplift_retain, "mixed", "capability_uplift.uplift >= 1.0")
PY

printf '[PASS] skill effectiveness eval framework\n'
