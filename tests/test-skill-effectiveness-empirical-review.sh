#!/usr/bin/env bash
# 文件职责：验证 effectiveness empirical review 聚合器能从本地 eval summary 生成保守有效性证据。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/tools/eval/scripts/update_lifecycle_review.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$SCRIPT" || fail "missing effectiveness review updater: $SCRIPT"

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-effectiveness-empirical-review.XXXXXX")"
ERR_OUT="$(mktemp "${TMPDIR:-/tmp}/skill-effectiveness-empirical-review.XXXXXX.err")"
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

python3 - <<'PY' "$ROOT" "$SCRIPT" "$DEV_WITH" "$DEV_WITHOUT" "$OUT_DIR"
import importlib.util
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
script = Path(sys.argv[2])
with_summary = Path(sys.argv[3])
without_summary = Path(sys.argv[4])
out_dir = Path(sys.argv[5])
temp_root = out_dir / "root-with-old-review"
skill_dir = temp_root / "shared" / "skills" / "developer" / "evals"
skill_dir.mkdir(parents=True)
shutil.copyfile(root / "shared" / "skills" / "developer" / "evals" / "evals.json", skill_dir / "evals.json")
old_review = json.loads((root / "shared" / "skills" / "developer" / "evals" / "lifecycle-review.json").read_text(encoding="utf-8"))
old_review.pop("lifecycle_state", None)
(skill_dir / "lifecycle-review.json").write_text(json.dumps(old_review, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

spec = importlib.util.spec_from_file_location("update_lifecycle_review", script)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
module.ROOT = temp_root
updated = module.update_review("developer", with_summary, without_summary)
assert updated["decision"] == "optimize", updated
assert "lifecycle_state" not in updated, updated
assert isinstance(updated.get("next_action"), str) and updated["next_action"].strip(), updated

pm_skill_dir = temp_root / "shared" / "skills" / "product-manager" / "evals"
pm_skill_dir.mkdir(parents=True)
shutil.copyfile(root / "shared" / "skills" / "product-manager" / "evals" / "evals.json", pm_skill_dir / "evals.json")
pm_review = json.loads((root / "shared" / "skills" / "product-manager" / "evals" / "lifecycle-review.json").read_text(encoding="utf-8"))
pm_review["encoded_preference"]["anchor_count"] = 1
pm_review["encoded_preference"]["eval_count"] = 1
(pm_skill_dir / "lifecycle-review.json").write_text(json.dumps(pm_review, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
updated = module.update_review("product-manager", out_dir / "product-manager-with-summary.json", None)
assert updated["encoded_preference"]["anchor_count"] == 7, updated
assert updated["encoded_preference"]["eval_count"] == 5, updated
assert updated["encoded_preference"]["sample_size"] == 2, updated

old_review["decision"] = "retain"
old_review["lifecycle_state"] = "optimize"
(skill_dir / "lifecycle-review.json").write_text(json.dumps(old_review, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
updated = module.update_review("developer", with_summary, without_summary)
assert updated["decision"] == "optimize", updated
assert "lifecycle_state" not in updated, updated
PY

python3 - <<'PY' "$OUT_DIR/product-manager-review.json" "$OUT_DIR/developer-review.json"
import json
import sys
from pathlib import Path

product_manager = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
developer = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

assert product_manager["decision"] == "optimize", product_manager
assert "lifecycle_state" not in product_manager, product_manager
assert isinstance(product_manager.get("next_action"), str) and product_manager["next_action"].strip(), product_manager
assert product_manager["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", product_manager
assert product_manager["encoded_preference"]["fidelity"] == 0.75, product_manager
assert product_manager["encoded_preference"]["sample_size"] == 2, product_manager
assert product_manager["pilot_empirical"]["with_skill"]["sample_size"] == 2, product_manager

assert developer["decision"] == "optimize", developer
assert "lifecycle_state" not in developer, developer
assert isinstance(developer.get("next_action"), str) and developer["next_action"].strip(), developer
assert developer["capability_uplift"]["measurement_status"] == "pilot_empirical_sample_recorded", developer
assert developer["capability_uplift"]["with_avg"] == 0.75, developer
assert developer["capability_uplift"]["without_avg"] == 0.5, developer
assert developer["capability_uplift"]["uplift"] == 0.25, developer
assert developer["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", developer
assert developer["encoded_preference"]["fidelity"] == 0.5, developer
assert developer["pilot_empirical"]["without_skill"]["sample_size"] == 1, developer
PY

python3 - <<'PY' \
  "$ROOT/shared/skills/product-manager/evals/lifecycle-review.json" \
  "$ROOT/shared/skills/developer/evals/lifecycle-review.json" \
  "$ROOT/shared/skills/product-director/evals/lifecycle-review.json" \
  "$ROOT/shared/skills/design/evals/lifecycle-review.json" \
  "$ROOT"
import json
import sys
from pathlib import Path

product_manager = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
developer = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
product_director = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
design = json.loads(Path(sys.argv[4]).read_text(encoding="utf-8"))
root = Path(sys.argv[5])
design_evals = json.loads((root / "shared/skills/design/evals/evals.json").read_text(encoding="utf-8"))
design_anchor_total = len(design_evals.get("preference_anchors", []))

for review in (developer, product_director, design):
    assert review["decision"] == "optimize", review
    assert review["pilot_empirical"]["measurement_status"] == "pilot_empirical_sample_recorded", review
    with_skill = review["pilot_empirical"]["with_skill"]
    assert with_skill["sample_size"] >= 3, review
    assert with_skill["infra_failures"] == 0, review
    assert (root / with_skill["summary_ref"]).is_file(), review

assert product_manager["decision"] == "retain", product_manager
assert product_manager["pilot_empirical"]["measurement_status"] == "pilot_empirical_sample_recorded", product_manager
pm_with_skill = product_manager["pilot_empirical"]["with_skill"]
assert pm_with_skill["sample_size"] >= 3, product_manager
assert pm_with_skill["infra_failures"] == 0, product_manager
assert (root / pm_with_skill["summary_ref"]).is_file(), product_manager
pm_without_skill = product_manager["pilot_empirical"]["without_skill"]
assert pm_without_skill["sample_size"] >= 3, product_manager
assert pm_without_skill["infra_failures"] == 0, product_manager
assert (root / pm_without_skill["summary_ref"]).is_file(), product_manager
human_review = product_manager["human_read_delta_review"]
assert human_review["measurement_status"] == "completed_human_delta_review", product_manager
assert human_review["conclusion"] == "retain", product_manager
assert len(human_review["reviewed_cases"]) >= 3, product_manager
retain_gate = human_review["retain_gate"]
assert retain_gate["encoded_preference_fidelity"] >= 0.8, product_manager
assert retain_gate["with_skill_anchor_passed"] == retain_gate["with_skill_anchor_total"], product_manager
assert retain_gate["without_skill_anchor_passed"] < retain_gate["without_skill_anchor_total"], product_manager
assert retain_gate["infra_failures"] == 0, product_manager
assert retain_gate["dogfood_downstream_design_preflight"] == "PASS", product_manager

assert product_manager["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", product_manager
assert product_manager["encoded_preference"]["sample_size"] >= 3, product_manager
assert product_manager["encoded_preference"]["anchor_total"] >= 1, product_manager
assert product_manager["encoded_preference"]["fidelity"] >= 0.8, product_manager

assert product_director["encoded_preference"]["measurement_status"] == "pilot_empirical_sample_recorded", product_director
assert product_director["encoded_preference"]["sample_size"] >= 3, product_director
assert product_director["encoded_preference"]["anchor_total"] >= 1, product_director

assert developer["capability_uplift"]["measurement_status"] == "pilot_empirical_sample_recorded", developer
assert developer["capability_uplift"]["with_sample_size"] >= 3, developer
assert developer["capability_uplift"]["without_sample_size"] >= 3, developer
without_skill = developer["pilot_empirical"]["without_skill"]
assert without_skill["sample_size"] >= 3, developer
assert without_skill["infra_failures"] == 0, developer
assert (root / without_skill["summary_ref"]).is_file(), developer

assert design["capability_uplift"]["measurement_status"] == "evals_updated_needs_empirical_rerun", design
assert design["capability_uplift"]["with_sample_size"] is None, design
assert design["capability_uplift"]["without_sample_size"] is None, design
assert design["encoded_preference"]["measurement_status"] == "anchors_updated_needs_fidelity_run", design
assert design["encoded_preference"]["sample_size"] is None, design
assert design["encoded_preference"]["anchor_total"] == design_anchor_total, design
assert design["encoded_preference"]["current_anchor_total"] == design_anchor_total, design
design_without_skill = design["pilot_empirical"]["without_skill"]
assert design_without_skill["sample_size"] >= 3, design
assert design_without_skill["infra_failures"] == 0, design
assert (root / design_without_skill["summary_ref"]).is_file(), design
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

printf '[PASS] skill effectiveness empirical review\n'
