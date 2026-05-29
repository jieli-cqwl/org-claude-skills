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

assert_absent 'Co-creation Mode|Finalization Mode' "$DIRECTOR"

python3 - "$DIRECTOR" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
for forbidden_heading in [
    "默认工作模式",
    "暂停输出协议",
    "Key Principles",
]:
    if re.search(rf"^## {re.escape(forbidden_heading)}$", text, re.M):
        raise SystemExit(f"unexpected section: {forbidden_heading}")
match = re.search(r"^## HARD-GATE\n\n(?P<body>.*?)(?=^## )", text, re.M | re.S)
if not match:
    raise SystemExit("missing HARD-GATE section")
body = match.group("body").strip()
for forbidden in [
    "技术债",
    "schema",
    "hook",
    "runtime",
    "contract",
    "product-director-ledger",
    "brief.json",
    "phase-prd.json",
    "\n- ",
]:
    if forbidden in body:
        raise SystemExit(f"HARD-GATE too heavy, contains: {forbidden}")

flow = re.search(r"```dot\n(?P<body>digraph product_director_flow .*?)\n```", text, re.S)
if not flow:
    raise SystemExit("missing product_director_flow")
flow_body = flow.group("body")
for expected in [
    '"Explore demand context" -> "Ask one clarifying question"',
    '"Ask one clarifying question" -> "Propose 2-3 baseline options"',
    '"Propose 2-3 baseline options" -> "Recommend one baseline"',
    '"Recommend one baseline" -> "Present baseline sections"',
    '"Present baseline sections" -> "User approves baseline?"',
    '"User approves baseline?" -> "Final artifacts"',
    '"Final artifacts" -> "Self-review and gates"',
    '"Self-review and gates" -> "Handoff"',
]:
    if expected not in flow_body:
        raise SystemExit(f"flow missing edge: {expected}")
for forbidden in [
    "问题澄清已闭合？",
    "目标与投入已闭合？",
    "业务语义已闭合？",
    "风险与未知项已闭合？",
    "收到产品总监确认？",
]:
    if forbidden in flow_body:
        raise SystemExit(f"flow still too detailed: {forbidden}")
edge_count = flow_body.count("->")
if edge_count > 10:
    raise SystemExit(f"flow too long: {edge_count} edges")

PY

assert_json_ok "$EVALS"
python3 - "$EVALS" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
evals = {item.get("id"): item for item in data.get("evals", [])}
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
