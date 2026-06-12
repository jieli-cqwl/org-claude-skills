#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DIRECTOR="$ROOT/shared/skills/product-director/SKILL.md"
EVALS="$ROOT/shared/skills/product-director/evals/evals.json"
GRADER="$ROOT/tools/eval/graders/product-director-thinking-grader.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_json_ok() {
  local file="$1"
  jq empty "$file" >/dev/null 2>&1 || fail "invalid JSON: ${file#"$ROOT"/}"
}

python3 - "$DIRECTOR" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
flow = re.search(r"```dot\n(?P<body>digraph product_director_flow .*?)\n```", text, re.S)
if not flow:
    raise SystemExit("missing product_director_flow")
flow_body = flow.group("body")
for expected in [
    '"Explore demand context" -> "Current stage facts closed?"',
    '"Ask one blocking fact" -> "Current stage facts closed?"',
    '"Current stage facts closed?" -> "Ask one blocking fact" [label="no"]',
    '"Current stage facts closed?" -> "Director recommendation" [label="yes"]',
    '"Director recommendation" -> "Present baseline sections"',
    '"Present baseline sections" -> "User approves baseline?"',
    '"User approves baseline?" -> "Ask one blocking fact" [label="revise upstream"]',
    '"User approves baseline?" -> "Final artifacts" [label="confirmed"]',
    '"Final artifacts" -> "Self-review baseline"',
    '"Self-review baseline" -> "Final gates"',
    '"Final gates" -> "Handoff to product-manager" [label="pass"]',
    '"Final gates" -> "Blocked" [label="environment missing"]',
]:
    if expected not in flow_body:
        raise SystemExit(f"flow missing edge: {expected}")
for forbidden in [
    "Check closed-fact fast path",
    "fast path",
    "快路径",
]:
    if forbidden in flow_body:
        raise SystemExit(f"flow must not contain separate closed-facts branch: {forbidden}")
edge_count = flow_body.count("->")
if edge_count > 13:
    raise SystemExit(f"flow too long: {edge_count} edges")

PY

assert_json_ok "$EVALS"
python3 - "$EVALS" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
evals = {item.get("id"): item for item in data.get("evals", [])}
required_eval_ids = {
    "success-gap-stays-in-success-stage",
    "target-metrics-gap-blocks-direct-recommendation",
    "closed-facts-missing-nongoals-still-recommends",
    "fully-closed-facts-asks-confirmation",
    "finalization-env-blocks-not-user-confirmation",
    "director-handoff-pm-only",
}
missing = sorted(required_eval_ids - set(evals))
if missing:
    raise SystemExit(f"missing product-director hardening evals: {missing}")
for case_id in sorted(required_eval_ids):
    case = evals[case_id]
    if not case.get("expectations"):
        raise SystemExit(f"{case_id} must include expectations")
    if not case.get("expected_anchors"):
        raise SystemExit(f"{case_id} must include expected anchors")

case = evals.get("partial-answer-stays-in-problem-clarification")
if not case:
    raise SystemExit("missing eval: partial-answer-stays-in-problem-clarification")
if case.get("expected_anchors") != ["PA-1", "PA-2", "PA-3", "PA-7", "PA-15"]:
    raise SystemExit("partial-answer eval anchors drift")
if len(case.get("expectations", [])) < 6:
    raise SystemExit("partial-answer eval must cover interaction behavior")

case = evals.get("missing-finalization-deps-still-co-creates")
if not case:
    raise SystemExit("missing eval: missing-finalization-deps-still-co-creates")
text = "\n".join(
    [case.get("prompt", "")]
    + case.get("expectations", [])
    + case.get("expected_anchors", [])
)
for phrase in [
    "Director baseline 共创",
    "继续执行 Checklist 的下一步",
    "一个推动用户确认 baseline 的澄清问题",
    "PA-15",
]:
    if phrase not in text:
        raise SystemExit(f"eval missing phrase: {phrase}")

anchors = {item.get("id"): item.get("anchor", "") for item in data.get("preference_anchors", [])}
all_text = json.dumps(data, ensure_ascii=False)
for forbidden in ["fast path", "fast-path", "快路径", "closed-fact fast path"]:
    if forbidden in all_text:
        raise SystemExit(f"product-director evals must not preserve direct-path terminology: {forbidden}")
pa15 = anchors.get("PA-15", "")
for phrase in [
    "完成 Director baseline 共创",
    "收到用户明确回复 `产品总监确认`",
    "继续执行 Checklist 的下一步",
]:
    if phrase not in pa15:
        raise SystemExit(f"PA-15 missing phrase: {phrase}")
PY

printf '[PASS] product-director co-creation contract\n'
