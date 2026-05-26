#!/usr/bin/env bash
# 文件职责：验证 developer 有效性复审 harder eval 集已覆盖可区分 Skill 价值的场景。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVAL_FILE="$ROOT/shared/skills/developer/evals/evals.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$EVAL_FILE" || fail "missing developer evals: $EVAL_FILE"

python3 - "$EVAL_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))

required = {
    "multi-ac-report-evidence-index": {
        "anchors": {"PA-1", "PA-2", "PA-5", "PA-6"},
        "phrases": ["tdd_evidence_index", "reviewable_anchor", "每条 AC"],
    },
    "scope-conflict-shared-file": {
        "anchors": {"PA-3", "PA-4"},
        "phrases": ["范围外", "delivery-owner", "不能擅自"],
    },
    "regression-failure-blocks-completion": {
        "anchors": {"PA-4", "PA-6"},
        "phrases": ["全量回归", "不能宣称完成", "developer-report.json"],
    },
    "report-schema-missing-evidence-fields": {
        "anchors": {"PA-2", "PA-5", "PA-6"},
        "phrases": ["developer-report.json", "tdd_evidence_index", "reviewable_anchor"],
    },
}

evals = data.get("evals")
if not isinstance(evals, list):
    raise SystemExit(f"{path}: evals must be a list")

by_id = {case.get("id"): case for case in evals if isinstance(case, dict)}
missing = sorted(set(required) - set(by_id))
if missing:
    raise SystemExit(f"{path}: missing developer effectiveness harder evals: {', '.join(missing)}")

for case_id, spec in required.items():
    case = by_id[case_id]
    if case.get("run_modes") != ["with_skill", "without_skill"]:
        raise SystemExit(f"{path}: {case_id} must run with and without skill")
    anchors = set(case.get("expected_anchors", []))
    missing_anchors = sorted(spec["anchors"] - anchors)
    if missing_anchors:
        raise SystemExit(f"{path}: {case_id} missing anchors {missing_anchors}")
    text = "\n".join(
        [
            str(case.get("prompt", "")),
            "\n".join(str(item) for item in case.get("expectations", [])),
        ]
    )
    for phrase in spec["phrases"]:
        if phrase not in text:
            raise SystemExit(f"{path}: {case_id} missing phrase {phrase!r}")

print("[PASS] developer effectiveness review evals")
PY
