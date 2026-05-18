#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/product-director-runtime-ab.XXXXXX")"
trap 'rm -rf "$OUT_DIR"' EXIT

python3 "$ROOT/tools/eval/scripts/product_director_runtime_ab_eval.py" --out-dir "$OUT_DIR" >"$OUT_DIR/stdout.json"

python3 - "$OUT_DIR/ab-evaluation.json" "$OUT_DIR/ab-evaluation.md" <<'PY'
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
report = Path(sys.argv[2]).read_text(encoding="utf-8")
score = summary["score"]

expected = {
    "status": "pass",
    "old_ref": "29e4de6c^",
    "new_ref": "29e4de6c",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"unexpected {key}: {summary.get(key)!r}")

required_scores = {
    "total_checks": 11,
    "new_desired_checks": 11,
    "old_desired_checks": 3,
    "old_to_new_improvements": 8,
    "improvement_checks_passed": 8,
    "improvement_checks_total": 8,
    "preserved_checks_passed": 3,
    "preserved_checks_total": 3,
}
for key, value in required_scores.items():
    if score.get(key) != value:
        raise SystemExit(f"unexpected score {key}: {score.get(key)!r}")

required_checks = {
    "role-identity",
    "legacy-step-noise-removed",
    "no-dispatch-blocking",
    "semantic-ledger-checkpoints",
    "technical-scenario-boundary",
    "implementation-defect-boundary",
    "downstream-consumption-language",
    "timebox-meaning-clarified",
    "first-principles-preserved",
    "success-standard-gate-preserved",
    "canonical-output-contract-preserved",
}
actual_checks = {check["id"] for check in summary["checks"]}
missing = sorted(required_checks - actual_checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")

if "未证明" not in report or "模型真实输出 A/B" not in report:
    raise SystemExit("report must state evidence boundary explicitly")
PY
