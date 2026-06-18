#!/usr/bin/env bash
# Verify test-design review happens after generated owner self-checked payload, before final freeze.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/test-design/SKILL.md"

python3 - "$SKILL" <<'PY'
import re
import sys
from pathlib import Path

skill_path = Path(sys.argv[1])
text = skill_path.read_text(encoding="utf-8")


def section(title: str) -> str:
    pattern = re.compile(
        rf"^{re.escape(title)}\n\n(?P<body>.*?)(?=^\d+(?:\.\d+)?\. |\Z)",
        re.M | re.S,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"missing section: {title}")
    return match.group("body")


flow_match = re.search(r"```dot\n(?P<body>.*?)\n```", text, re.S)
if not flow_match:
    raise SystemExit("missing dot flow")
flow = flow_match.group("body")

required_edges = [
    '"TD-S7 Gap Routing" -> "TD-S7.5 Generate Review Payload"',
    '"TD-S7.5 Generate Review Payload" -> "TD-S7.6 Owner Self-Check"',
    '"TD-S7.6 Owner Self-Check" -> "TD-S8 Three-View Review"',
    '"TD-S8 Three-View Review" -> "TD-G1 Freeze test-cases.json"',
]
for edge in required_edges:
    if edge not in flow:
        raise SystemExit(f"missing review-flow edge: {edge}")

review_payload = section("7.5. Generate Review Payload")
owner_self_check = section("7.6. Owner Self-Check")
three_view_review = section("8. Three-View Review")
freeze = section("9. Freeze")

for required in [
    "$TMPDIR/test-cases-review.json",
    "review_digest.py --review-payload",
    "reviewed_test_cases_digest",
    "review_conclusion / issue_ledger",
]:
    if required not in review_payload:
        raise SystemExit(f"Generate Review Payload missing: {required}")

if not re.search(r"不含 `review_conclusion / issue_ledger`", review_payload):
    raise SystemExit("review payload must exclude post-review fields before review")

if "可送审状态" not in owner_self_check:
    raise SystemExit("Owner Self-Check must establish review-ready state")

for forbidden in ["临时对话材料", "候选片段", "未自检内容"]:
    if forbidden not in owner_self_check or forbidden not in three_view_review:
        raise SystemExit(f"review boundary must forbid {forbidden}")

if "reviewed_test_cases_digest` 绑定的已生成 review payload" not in three_view_review:
    raise SystemExit("Three-View Review must review the generated digest-bound payload")

if "修正 `test-cases.json`" in three_view_review:
    raise SystemExit("Three-View Review must not imply FAIL fixes mutate final test-cases.json before freeze")

if "测试设计内容" not in three_view_review or "重新生成 review payload" not in three_view_review:
    raise SystemExit("FAIL handling must repair test design content and regenerate review payload")

if "写入 `{unit_work_dir}/test-cases.json`" not in freeze:
    raise SystemExit("Freeze must remain the formal test-cases.json write step")

if "review_digest.py --check" not in freeze:
    raise SystemExit("Freeze must verify final artifact digest")
PY

printf '[PASS] test-design review flow contract\n'
