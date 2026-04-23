#!/usr/bin/env bash
# 文件职责：验证 Skill D9 能力有效性标准、生命周期闭环和标准链 skill eval 元数据。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/reference/Skill质量标准.md"
CAPABILITY="$ROOT/shared/reference/Skill能力有效性标准.md"
LIFECYCLE="$ROOT/shared/reference/Skill生命周期管理.md"
HARNESS="$ROOT/shared/skills/skill-harness/SKILL.md"
HARNESS_METHOD="$ROOT/shared/skills/skill-harness/references/audit-method.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in $file: $needle"
}

test -f "$CAPABILITY" || fail "missing capability standard"
test -f "$LIFECYCLE" || fail "missing lifecycle management standard"
test -f "$STANDARD" || fail "missing quality standard"
test -f "$HARNESS" || fail "missing skill-harness"
test -f "$HARNESS_METHOD" || fail "missing skill-harness audit method"

dimension_count="$(grep -Ec '^\| D[1-9] \|' "$STANDARD")"
[ "$dimension_count" = "9" ] || fail "standard must define exactly 9 dimensions, got $dimension_count"

assert_present 'D9 | 存在合理性' "$STANDARD"
assert_present '## D9 存在合理性' "$STANDARD"
assert_present 'eval-type' "$CAPABILITY"
assert_present 'capability_uplift' "$CAPABILITY"
assert_present 'encoded_preference' "$CAPABILITY"
assert_present 'mixed' "$CAPABILITY"
assert_present 'with-skill' "$CAPABILITY"
assert_present 'without-skill' "$CAPABILITY"
assert_present '偏好锚点' "$CAPABILITY"
assert_present 'Gate 1: 上线门禁' "$LIFECYCLE"
assert_present 'Gate 2: 模型升级触发' "$LIFECYCLE"
assert_present 'Gate 3: 定期复审' "$LIFECYCLE"
assert_present 'Gate 4: 退役协议' "$LIFECYCLE"
assert_present 'D9 存在合理性' "$HARNESS"
assert_present 'Skill能力有效性标准.md' "$HARNESS"
assert_present 'eval-type' "$HARNESS"
assert_present 'lifecycle-review.json' "$HARNESS"
assert_present 'D9 存在合理性' "$HARNESS_METHOD"
assert_present 'Skill能力有效性标准.md' "$HARNESS_METHOD"
assert_present 'eval-type' "$HARNESS_METHOD"
assert_present 'lifecycle-review.json' "$HARNESS_METHOD"

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
    "delivery-owner": "encoded_preference",
    "fix": "mixed",
    "consistency-audit": "mixed",
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
        measured_delta = uplift.get("measured_delta")
        if not isinstance(measured_delta, (int, float)) or measured_delta <= 0:
            raise SystemExit(f"{review_file}: retain requires positive capability_uplift.measured_delta")


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
        raise SystemExit(f"missing lifecycle review for {skill}")

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
        if not isinstance(anchors, list) or not (5 <= len(anchors) <= 10):
            raise SystemExit(f"{eval_file}: expected 5-10 preference anchors")
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
    if not review.get("evidence_refs"):
        raise SystemExit(f"{review_file}: evidence_refs required")
    if eval_type in {"encoded_preference", "mixed"} and "encoded_preference" not in review:
        raise SystemExit(f"{review_file}: encoded_preference review data required")
    if eval_type in {"capability_uplift", "mixed"} and "capability_uplift" not in review:
        raise SystemExit(f"{review_file}: capability_uplift review data required")
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
    "capability_uplift": {"measured_delta": 0.12},
}
validate_retain_measurements(synthetic_retain, "mixed", "synthetic-retain-review.json")

low_fidelity_retain = deepcopy(synthetic_retain)
low_fidelity_retain["encoded_preference"]["fidelity"] = 0.79
expect_retain_failure(low_fidelity_retain, "mixed", "fidelity >= 0.80")

unmeasured_retain = deepcopy(synthetic_retain)
unmeasured_retain["encoded_preference"]["measurement_status"] = "needs_empirical_baseline"
expect_retain_failure(unmeasured_retain, "mixed", "completed encoded_preference measurement_status")

zero_uplift_retain = deepcopy(synthetic_retain)
zero_uplift_retain["capability_uplift"]["measured_delta"] = 0
expect_retain_failure(zero_uplift_retain, "mixed", "positive capability_uplift.measured_delta")
PY

printf '[PASS] skill lifecycle eval framework\n'
