#!/usr/bin/env bash
# 文件职责：验证 lifecycle empirical review 聚合器能从本地 eval summary 生成保守 review 证据。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/tools/eval/scripts/update_lifecycle_review.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$SCRIPT" || fail "missing lifecycle review updater: $SCRIPT"

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-lifecycle-empirical-review.XXXXXX")"
ERR_OUT="$(mktemp "${TMPDIR:-/tmp}/skill-lifecycle-empirical-review.XXXXXX.err")"
trap 'rm -rf "$OUT_DIR"; rm -f "$ERR_OUT"' EXIT

PM_WITH="$OUT_DIR/product-manager-with-summary.json"
DEV_WITH="$OUT_DIR/developer-with-summary.json"
DEV_WITHOUT="$OUT_DIR/developer-without-summary.json"
DEV_INFRA_FAILURE="$OUT_DIR/developer-infra-failure-summary.json"

cat > "$PM_WITH" <<'JSON'
{
  "runs": [
    {
      "skill_name": "product-manager",
      "eval_id": "handoff-validation-first",
      "run_mode": "with_skill",
      "graded": true,
      "pass_rate": 1.0,
      "anchor_passed": 2,
      "anchor_total": 3
    },
    {
      "skill_name": "product-manager",
      "eval_id": "director-lock-drift-blocking",
      "run_mode": "with_skill",
      "graded": true,
      "pass_rate": 0.5,
      "anchor_passed": 1,
      "anchor_total": 1
    }
  ],
  "summary": {
    "infra_failures": 0
  }
}
JSON

cat > "$DEV_WITH" <<'JSON'
{
  "runs": [
    {
      "skill_name": "developer",
      "eval_id": "ambiguous-missing-design",
      "run_mode": "with_skill",
      "graded": true,
      "pass_rate": 1.0,
      "anchor_passed": 1,
      "anchor_total": 2
    },
    {
      "skill_name": "developer",
      "eval_id": "interface-tweak-out-of-scope",
      "run_mode": "with_skill",
      "graded": true,
      "pass_rate": 0.5,
      "anchor_passed": 0,
      "anchor_total": 0
    }
  ],
  "summary": {
    "infra_failures": 0
  }
}
JSON

cat > "$DEV_WITHOUT" <<'JSON'
{
  "runs": [
    {
      "skill_name": "developer",
      "eval_id": "ambiguous-missing-design",
      "run_mode": "without_skill",
      "graded": true,
      "pass_rate": 0.5,
      "anchor_passed": 0,
      "anchor_total": 0
    }
  ],
  "summary": {
    "infra_failures": 0
  }
}
JSON

cat > "$DEV_INFRA_FAILURE" <<'JSON'
{
  "runs": [
    {
      "skill_name": "developer",
      "eval_id": "ambiguous-missing-design",
      "run_mode": "with_skill",
      "graded": true,
      "pass_rate": 1.0,
      "anchor_passed": 3,
      "anchor_total": 3
    },
    {
      "skill_name": "developer",
      "eval_id": "setup-failed",
      "run_mode": "with_skill",
      "graded": false,
      "pass_rate": null,
      "infra_failure": "executor exited 7",
      "anchor_passed": 0,
      "anchor_total": 0
    }
  ],
  "summary": {
    "infra_failures": 1
  }
}
JSON

python3 "$SCRIPT" \
  --skill product-manager \
  --with-summary "$PM_WITH" \
  --output-review "$OUT_DIR/product-manager-review.json" \
  --write-review

python3 "$SCRIPT" \
  --skill developer \
  --with-summary "$DEV_WITH" \
  --without-summary "$DEV_WITHOUT" \
  --output-review "$OUT_DIR/developer-review.json" \
  --write-review

python3 - <<'PY' "$OUT_DIR/product-manager-review.json" "$OUT_DIR/developer-review.json"
import json
import sys
from pathlib import Path

product_manager = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
developer = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

assert product_manager["decision"] == "optimize", product_manager
assert product_manager["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", product_manager
assert product_manager["encoded_preference"]["fidelity"] == 0.75, product_manager
assert product_manager["encoded_preference"]["sample_size"] == 2, product_manager
assert product_manager["pilot_empirical"]["with_skill"]["sample_size"] == 2, product_manager

assert developer["decision"] == "optimize", developer
assert developer["capability_uplift"]["measurement_status"] == "pilot_empirical_sample_recorded", developer
assert developer["capability_uplift"]["with_avg"] == 0.75, developer
assert developer["capability_uplift"]["without_avg"] == 0.5, developer
assert developer["capability_uplift"]["uplift"] == 0.25, developer
assert developer["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", developer
assert developer["encoded_preference"]["fidelity"] == 0.5, developer
assert developer["pilot_empirical"]["without_skill"]["sample_size"] == 1, developer
PY

python3 - <<'PY' "$ROOT/shared/skills/product-manager/evals/lifecycle-review.json" "$ROOT/shared/skills/developer/evals/lifecycle-review.json" "$ROOT"
import json
import sys
from pathlib import Path

product_manager = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
developer = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
root = Path(sys.argv[3])

for review in (product_manager, developer):
    assert review["decision"] == "optimize", review
    assert review["pilot_empirical"]["measurement_status"] == "pilot_empirical_sample_recorded", review
    with_skill = review["pilot_empirical"]["with_skill"]
    assert with_skill["sample_size"] >= 3, review
    assert with_skill["infra_failures"] == 0, review
    assert (root / with_skill["summary_ref"]).is_file(), review

assert product_manager["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", product_manager
assert product_manager["encoded_preference"]["sample_size"] >= 3, product_manager
assert product_manager["encoded_preference"]["anchor_total"] >= 1, product_manager

assert developer["capability_uplift"]["measurement_status"] == "pilot_empirical_sample_recorded", developer
assert developer["capability_uplift"]["with_sample_size"] >= 3, developer
assert developer["capability_uplift"]["without_sample_size"] >= 3, developer
without_skill = developer["pilot_empirical"]["without_skill"]
assert without_skill["sample_size"] >= 3, developer
assert without_skill["infra_failures"] == 0, developer
assert (root / without_skill["summary_ref"]).is_file(), developer
PY

if python3 "$SCRIPT" \
  --skill developer \
  --with-summary "$DEV_INFRA_FAILURE" \
  --output-review "$OUT_DIR/infra-failure-review.json" \
  --write-review 2>"$ERR_OUT"; then
  fail "updater accepted a summary with infrastructure failures"
fi
grep -Fq 'summary has infrastructure failures' "$ERR_OUT" || fail "infrastructure failure error was not actionable"

if python3 "$SCRIPT" \
  --skill developer \
  --with-summary "$OUT_DIR/missing-summary.json" \
  --output-review "$OUT_DIR/invalid-review.json" \
  --write-review 2>"$ERR_OUT"; then
  fail "updater accepted a missing summary file"
fi
grep -Fq 'missing summary file' "$ERR_OUT" || fail "missing summary error was not actionable"

if python3 "$SCRIPT" \
  --skill not-a-skill \
  --with-summary "$PM_WITH" \
  --output-review "$OUT_DIR/invalid-review.json" \
  --write-review 2>"$ERR_OUT"; then
  fail "updater accepted an unsupported skill"
fi
grep -Fq 'missing evals file' "$ERR_OUT" || fail "unsupported skill error was not actionable"

printf '[PASS] skill lifecycle empirical review\n'
