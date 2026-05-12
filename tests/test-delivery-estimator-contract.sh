#!/usr/bin/env bash
# File role: prove delivery-estimator exposes a consumable PM scheduling skill contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

SKILL_DIR="$ROOT/shared/skills/delivery-estimator"
SKILL="$SKILL_DIR/SKILL.md"
CONTRACT="$ROOT/contracts/skill-runtime-surface.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  local file="$1"
  test -f "$file" || fail "missing file: $file"
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_file "$SKILL"
assert_file "$SKILL_DIR/agents/openai.yaml"
assert_file "$SKILL_DIR/scripts/estimate_schedule.py"
assert_file "$SKILL_DIR/scripts/schedule_common.py"
assert_file "$SKILL_DIR/scripts/schedule_core.py"
assert_file "$SKILL_DIR/scripts/schedule_markdown.py"
assert_file "$SKILL_DIR/scripts/schedule_model.py"
assert_file "$SKILL_DIR/templates/estimate-input.template.json"
assert_file "$SKILL_DIR/projections/delivery-estimate-template.md"
assert_file "$SKILL_DIR/evals/evals.json"

assert_present '^name: delivery-estimator$' "$SKILL"
assert_present 'disable-model-invocation: true' "$SKILL"
assert_present 'Use when.*排期|Use when.*交付时间|Use when.*工期|Use when.*投入' "$SKILL"
assert_present '1 人 \+ AI agents|1人 \+ AI agents|1 人 \+ Codex|Claude Code' "$SKILL"
assert_present '业务.*交付|老板.*投入' "$SKILL"
assert_present 'WBS' "$SKILL"
assert_present '甘特图|Gantt' "$SKILL"
assert_present '里程碑|milestone' "$SKILL"
assert_present 'baseline|data date' "$SKILL"
assert_present 'float/slack|slack' "$SKILL"
assert_present 'rebaseline|重估' "$SKILL"
assert_present '关键路径' "$SKILL"
assert_present '并行批次|parallel' "$SKILL"
assert_present 'P50.*P80.*P95|P80.*P95' "$SKILL"
assert_present 'PERT|三点估算' "$SKILL"
assert_present '风险缓冲|重估触发' "$SKILL"
assert_present 'scripts/estimate_schedule.py' "$SKILL"
assert_present ' --markdown ' "$SKILL"
assert_present 'templates/estimate-input.template.json' "$SKILL"
assert_present 'projections/delivery-estimate-template.md' "$SKILL"
assert_present '输出' "$SKILL"
assert_present '完成校验' "$SKILL"
assert_present '"project_start_date"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '"baseline"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '"milestones"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '"owner"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '"resource"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '"status"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '"percent_complete"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '"rebaseline_rules"' "$SKILL_DIR/templates/estimate-input.template.json"
assert_present '```mermaid' "$SKILL_DIR/projections/delivery-estimate-template.md"
assert_present '## WBS 字典' "$SKILL_DIR/projections/delivery-estimate-template.md"
assert_present '## 里程碑计划' "$SKILL_DIR/projections/delivery-estimate-template.md"
assert_present '## 资源与 AI-Agent 计划' "$SKILL_DIR/projections/delivery-estimate-template.md"

python3 - "$CONTRACT" <<'PY'
import json
import sys
from pathlib import Path

contract = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
entry = contract["skills"].get("delivery-estimator")
if not entry:
    raise SystemExit("delivery-estimator missing from runtime surface contract")
if entry.get("mode") != "manual":
    raise SystemExit(f"delivery-estimator should be manual, got {entry}")
if entry.get("owner") != "first-party":
    raise SystemExit(f"delivery-estimator should be first-party, got {entry}")
if "排期" not in entry.get("reason", "") and "estimate" not in entry.get("reason", ""):
    raise SystemExit(f"delivery-estimator reason should explain scheduling intent: {entry}")
PY

python3 - "$SKILL_DIR/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if data.get("skill_name") != "delivery-estimator":
    raise SystemExit("evals skill_name mismatch")
evals = data.get("evals", [])
if len(evals) < 3:
    raise SystemExit("delivery-estimator needs at least three pressure evals")
for item in evals:
    expected = " ".join(item.get("expectations", []))
    if "交付" not in expected or "风险" not in expected:
        raise SystemExit(f"eval lacks delivery/risk expectations: {item.get('id')}")
PY

printf '[PASS] delivery-estimator skill contract\n'
