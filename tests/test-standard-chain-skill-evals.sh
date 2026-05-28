#!/usr/bin/env bash
# 文件职责：验证 standard-chain main skill 均沉淀 skill-creator 风格本地 eval。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHAIN="$ROOT/contracts/standard-chain.yaml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

read_standard_chain_skills() {
  awk '
    /^  - name: / { name=$3 }
    /position: main/ { print name }
  ' "$CHAIN"
}

test -f "$CHAIN" || fail "missing standard-chain contract: $CHAIN"

STANDARD_CHAIN_SKILLS=()
while IFS= read -r skill; do
  STANDARD_CHAIN_SKILLS+=("$skill")
done < <(read_standard_chain_skills)

[ "${#STANDARD_CHAIN_SKILLS[@]}" -eq 10 ] || fail "expected 10 standard-chain main skills, got ${#STANDARD_CHAIN_SKILLS[@]}: ${STANDARD_CHAIN_SKILLS[*]}"

for skill in "${STANDARD_CHAIN_SKILLS[@]}"; do
  eval_file="$ROOT/shared/skills/$skill/evals/evals.json"
  test -f "$eval_file" || fail "missing skill-creator evals for standard-chain skill: $eval_file"

  python3 - "$skill" "$eval_file" <<'PY'
import json
import sys
from pathlib import Path

skill_name = sys.argv[1]
path = Path(sys.argv[2])
root = path.parents[4]
skill_root = path.parents[1]

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    raise SystemExit(f"{path}: invalid JSON: {exc}") from exc

if data.get("skill_name") != skill_name:
    raise SystemExit(f"{path}: skill_name must be {skill_name!r}")

evals = data.get("evals")
if not isinstance(evals, list) or len(evals) < 3:
    raise SystemExit(f"{path}: expected at least 3 eval cases")

seen_ids = set()
for index, case in enumerate(evals, start=1):
    if not isinstance(case, dict):
        raise SystemExit(f"{path}: eval #{index} must be an object")

    case_id = case.get("id")
    if not isinstance(case_id, (int, str)) or (isinstance(case_id, str) and not case_id.strip()):
        raise SystemExit(f"{path}: eval #{index} must have a non-empty string or integer id")
    if case_id in seen_ids:
        raise SystemExit(f"{path}: duplicate eval id {case_id!r}")
    seen_ids.add(case_id)

    for field in ("prompt",):
        value = case.get(field)
        if not isinstance(value, str) or not value.strip():
            raise SystemExit(f"{path}: eval {case_id!r} missing non-empty {field}")

    files = case.get("files")
    if not isinstance(files, list):
        raise SystemExit(f"{path}: eval {case_id!r} files must be a list")
    for file_ref in files:
        if not isinstance(file_ref, str) or not file_ref.strip():
            raise SystemExit(f"{path}: eval {case_id!r} contains an empty file ref")
        if Path(file_ref).is_absolute():
            raise SystemExit(f"{path}: eval {case_id!r} file ref must be relative: {file_ref}")
        candidates = [skill_root / file_ref, root / file_ref]
        if not any(candidate.exists() for candidate in candidates):
            raise SystemExit(f"{path}: eval {case_id!r} file ref does not exist: {file_ref}")

    expectations = case.get("expectations")
    if not isinstance(expectations, list) or not expectations:
        raise SystemExit(f"{path}: eval {case_id!r} expectations must be a non-empty list")
    for expectation in expectations:
        if not isinstance(expectation, str) or not expectation.strip():
            raise SystemExit(f"{path}: eval {case_id!r} contains an empty expectation")
PY
done

python3 - "$ROOT/shared/skills/test-design/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))

eval_text = json.dumps(data.get("evals", []), ensure_ascii=False)
if "本 eval 不要求实际写文件" in eval_text or "不要求实际写文件" in eval_text:
    raise SystemExit(f"{path}: test-design eval prompts must not contain eval-only no-write wording")
if "要求先执行 design" in eval_text or "要求先回到 design" in eval_text:
    raise SystemExit(f"{path}: test-design evals must wait for user decision instead of forcing design routing")

required_eval_ids = {
    "missing-design-blocks-test-design",
    "developer-self-test-obligations",
    "qa-handoff-obligations",
    "typed-gap-routes-to-owner",
    "specialty-design-minimal-expansion",
    "three-view-review-convergence",
}
actual_eval_ids = {case.get("id") for case in data.get("evals", [])}
missing_eval_ids = sorted(required_eval_ids - actual_eval_ids)
if missing_eval_ids:
    raise SystemExit(f"{path}: missing test-design governance evals {missing_eval_ids}")

required_anchor_terms = {
    "测试义务",
    "assertion_target",
    "evidence_expectation",
    "QA handoff obligation",
    "blocking typed gap",
    "三视角 reviewer",
    "max10轮",
    "专项测试",
}
anchor_text = "\n".join(anchor.get("anchor", "") for anchor in data.get("preference_anchors", []))
missing_anchor_terms = sorted(term for term in required_anchor_terms if term not in anchor_text)
if missing_anchor_terms:
    raise SystemExit(f"{path}: missing test-design preference anchor terms {missing_anchor_terms}")

expected_dimensions = {
    "role_boundary",
    "developer_consumability",
    "qa_handoff",
    "typed_gap_routing",
    "specialty_minimal_expansion",
    "reviewer_convergence",
}
dimensions = set(data.get("grader_dimensions", []))
missing_dimensions = sorted(expected_dimensions - dimensions)
if missing_dimensions:
    raise SystemExit(f"{path}: missing test-design grader dimensions {missing_dimensions}")

case_by_id = {case.get("id"): case for case in data.get("evals", [])}
missing_design_case = case_by_id.get("missing-design-blocks-test-design", {})
missing_design_text = "\n".join(missing_design_case.get("expectations", []))
for term in ("design 责任方", "等待用户裁决"):
    if term not in missing_design_text:
        raise SystemExit(f"{path}: missing-design-blocks-test-design must include {term!r}")

field_expectations = {
    "developer-self-test-obligations": [
        "product refs",
        "design refs",
        "assertion_target",
        "evidence_expectation",
    ],
    "qa-handoff-obligations": [
        "obligation_id",
        "qa_stage",
        "evidence_expectation",
        "browser_required",
    ],
    "specialty-design-minimal-expansion": [
        "source_ref",
        "QA handoff",
        "typed gap",
    ],
    "three-view-review-convergence": [
        "reviewer_verdicts",
        "convergence_evidence",
        "CONFIRMATION",
        "只重提 FAIL 视角",
        "test_quality",
        "product",
        "architecture",
        "issue_ledger",
    ],
}
for case_id, required_terms in field_expectations.items():
    case = case_by_id.get(case_id)
    text = "\n".join(case.get("expectations", []))
    missing_terms = sorted(term for term in required_terms if term not in text)
    if missing_terms:
        raise SystemExit(f"{path}: eval {case_id!r} missing contract terms {missing_terms}")
PY

python3 - "$ROOT/shared/skills/delivery-owner/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
review = json.loads((path.parent / "lifecycle-review.json").read_text(encoding="utf-8"))

required_eval_ids = {
    "missing-tech-lead-plan-blocks",
    "dispatch-with-task-packet",
    "developer-verifier-fail-loop-reruns",
    "stale-evidence-after-fix",
    "qa-fixer-fail-loop-reruns",
    "scope-ac-conflict-escalates",
    "no-increment-follow-up-reroutes",
    "qa-pass-dispatches-commit",
}
actual_eval_ids = {case.get("id") for case in data.get("evals", [])}
missing_eval_ids = sorted(required_eval_ids - actual_eval_ids)
if missing_eval_ids:
    raise SystemExit(f"{path}: missing delivery-owner flow evals {missing_eval_ids}")

encoded_preference = review.get("encoded_preference", {})
if encoded_preference.get("anchor_count") != len(data.get("preference_anchors", [])):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: delivery-owner anchor_count drift")
if encoded_preference.get("eval_count") != len(data.get("evals", [])):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: delivery-owner eval_count drift")

case_by_id = {case.get("id"): case for case in data.get("evals", [])}
field_expectations = {
    "missing-tech-lead-plan-blocks": [
        "NEEDS_BASELINE",
        "tech-lead",
        "task scope",
        "不得创建 task",
        "不得派 developer agent",
    ],
    "dispatch-with-task-packet": [
        "developer agent responsibility",
        "task_ref",
        "expected_evidence",
        "stop_condition",
        "forbidden_actions",
        "不得自己实现",
    ],
    "developer-verifier-fail-loop-reruns": [
        "verifier agent FAIL",
        "不进入 QA",
        "回派 developer agent",
        "developer packet",
        "task_ref",
        "role",
        "goal",
        "input_refs",
        "expected_evidence",
        "stop_condition",
        "forbidden_actions",
        "再次调度 verifier agent",
        "current_gap",
        "progress_signal",
        "consecutive_no_progress_count",
        "next_owner",
        "resume_condition",
        "连续 2 轮",
        "暂停给用户决策",
    ],
    "stale-evidence-after-fix": [
        "freshness",
        "不能直接 /commit",
        "fresh evidence",
        "证据失效原因",
    ],
    "qa-fixer-fail-loop-reruns": [
        "qa agent FAIL",
        "可复现缺陷",
        "调度 fixer agent",
        "fixer packet",
        "task_ref",
        "role",
        "goal",
        "input_refs",
        "expected_evidence",
        "stop_condition",
        "forbidden_actions",
        "root cause",
        "minimal fix",
        "fix-result.json",
        "重跑受影响 verifier agent、fresh code-reviewer agent 和 qa agent",
        "current_gap",
        "progress_signal",
        "consecutive_no_progress_count",
        "stale_evidence_refs",
        "next_owner",
        "resume_condition",
        "用户授权明确后才调度 /commit",
    ],
    "scope-ac-conflict-escalates": [
        "scope/AC/技术基线",
        "暂停给用户决策",
        "用户决策包",
        "不得让 developer agent 自行扩大 scope",
    ],
    "no-increment-follow-up-reroutes": [
        "无增量循环",
        "不继续催同一个 owner",
        "progress_signal=no_progress",
        "consecutive_no_progress_count=2",
        "decision_needed",
        "required_user_answer",
        "resume_condition",
        "next_action_after_decision",
    ],
    "qa-pass-dispatches-commit": [
        "developer agent / verifier agent / qa agent",
        "用户提交授权",
        "调度 /commit",
        "不直接提交代码",
    ],
}
for case_id, required_terms in field_expectations.items():
    case = case_by_id.get(case_id)
    text = "\n".join(case.get("expectations", []))
    missing_terms = sorted(term for term in required_terms if term not in text)
    if missing_terms:
        raise SystemExit(f"{path}: eval {case_id!r} missing contract terms {missing_terms}")
PY

python3 - "$ROOT/shared/skills/product-manager/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
review = json.loads((path.parent / "lifecycle-review.json").read_text(encoding="utf-8"))

encoded_preference = review.get("encoded_preference", {})
if encoded_preference.get("anchor_count") != len(data.get("preference_anchors", [])):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: product-manager anchor_count drift")
if encoded_preference.get("eval_count") != len(data.get("evals", [])):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: product-manager eval_count drift")
if encoded_preference.get("sample_size", 0) > encoded_preference.get("eval_count", 0):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: product-manager sample_size exceeds eval_count")
PY

python3 - "$ROOT/shared/skills/product-director/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
review = json.loads((path.parent / "lifecycle-review.json").read_text(encoding="utf-8"))

encoded_preference = review.get("encoded_preference", {})
if encoded_preference.get("anchor_count") != len(data.get("preference_anchors", [])):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: product-director anchor_count drift")
if encoded_preference.get("eval_count") != len(data.get("evals", [])):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: product-director eval_count drift")
if encoded_preference.get("sample_size", 0) > encoded_preference.get("eval_count", 0):
    raise SystemExit(f"{path.parent / 'lifecycle-review.json'}: product-director sample_size exceeds eval_count")
PY

python3 - "$ROOT/shared/skills/product-manager/test-prompts.json" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
text = json.dumps(data, ensure_ascii=False)
legacy_migration_terms = re.compile(r"migration candidate|re-signoff|lock snapshot", re.IGNORECASE)
if legacy_migration_terms.search(text):
    raise SystemExit(f"{path}: product-manager active test prompts must not require legacy migration workflow")
PY

python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/community"))
from canonical_test_case_rules import assert_test_cases_contract

feature_dir = root / "tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature"
registry = json.loads((feature_dir / "phase-1/artifact-registry.json").read_text(encoding="utf-8"))
active_revision = next(
    revision
    for revision in registry["revisions"]
    if revision["revision_id"] == registry["active_revision_id"]
)
unit_entries = [
    entry
    for entry in active_revision["entries"]
    if entry.get("artifact_type") == "unit-definition"
    and entry.get("artifact_path") == "units/UNIT-1.json"
    and entry.get("active_for_consumption") is True
]
if not unit_entries:
    raise SystemExit("delivery-owner positive fixture missing active unit-definition entry for units/UNIT-1.json")
paths = [
    feature_dir / "brief.json",
    feature_dir / "phase-1/phase-prd.json",
    feature_dir / "phase-1/design.json",
    feature_dir / "phase-1/units/UNIT-1.json",
    feature_dir / "phase-1/unit-1/test-cases.json",
]
artifacts = [json.loads(path.read_text(encoding="utf-8")) for path in paths]
assert_test_cases_contract(artifacts[-1], artifacts)
PY

printf '[PASS] standard-chain skill evals contract\n'
