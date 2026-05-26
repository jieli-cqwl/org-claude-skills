#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/design/SKILL.md"
OPENAI="$ROOT/shared/skills/design/agents/openai.yaml"
SCHEMA="$ROOT/shared/skills/design/contracts/design.schema.json"
TEMPLATE="$ROOT/shared/skills/design/templates/design.template.json"
MANIFEST="$ROOT/shared/skills/design/scripts/manifest.json"
EVALS="$ROOT/shared/skills/design/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/design/evals/lifecycle-review.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2" label="${3:-$2}"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${label#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2" label="${3:-$2}"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in ${label#"$ROOT"/}: $pattern"
  fi
}

assert_present '高级交付型架构师|senior delivery architect' "$SKILL"
python3 - "$SKILL" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = ["用户确认", "业务语义", "外部现实约束"]
missing = [term for term in required if term not in text]
if "LLM 主导" not in text and "你负责主导" not in text:
    missing.append("LLM 主导|你负责主导")
if missing:
    raise SystemExit(f"missing role boundary terms: {missing}")
PY
assert_present '脚本.*确定性|schema.*确定性|hook.*确定性' "$SKILL"
assert_present '下游.*把活干对|downstream.*correctly execute' "$SKILL"
assert_absent "boundary_behaviors\` 字段|只使用 \`input_params / output_params / error_codes / boundary_behaviors\` 字段" "$SKILL"
assert_present 'boundary_behaviors' "$SCHEMA"
assert_present 'boundary_behaviors' "$TEMPLATE"

assert_present 'senior delivery architect|executable architecture decisions|downstream delivery' "$OPENAI"

python3 - "$TEMPLATE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))

bad = []
if payload.get("final_confirmation", {}).get("status") == "confirmed":
    bad.append("final_confirmation.status defaults to confirmed")
if payload.get("constraint_inheritance_confirmation", {}).get("status") == "confirmed":
    bad.append("constraint_inheritance_confirmation.status defaults to confirmed")
for index, reviewer in enumerate(payload.get("review_closure", {}).get("reviewers", [])):
    if reviewer.get("verdict") in {"PASS", "WARN"}:
        bad.append(f"reviewers[{index}].verdict defaults to {reviewer.get('verdict')}")
if payload.get("product_handoff", {}).get("status") == "READY":
    bad.append("product_handoff.status defaults to READY")
if bad:
    raise SystemExit("; ".join(bad))
PY

python3 - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
ids = {entry.get("id") for entry in payload.get("scripts", [])}
if "architect-contract" not in ids:
    raise SystemExit("manifest missing architect-contract script entry")
PY

python3 - "$EVALS" "$LIFECYCLE" <<'PY'
import json
import sys
from pathlib import Path

evals = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
lifecycle = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

required_eval_ids = {
    "weak-runtime-facts-rejected",
    "planted-contract-drift-blocks-handoff",
    "user-script-llm-boundary",
    "downstream-consumer-smoke",
    "overdesign-pressure-case",
    "reviewer-finds-architecture-fail",
}
actual_eval_ids = {case.get("id") for case in evals.get("evals", [])}
missing = sorted(required_eval_ids - actual_eval_ids)
if missing:
    raise SystemExit(f"missing design architect eval ids: {missing}")

required_dimensions = {
    "architect_role_boundary",
    "weak_evidence_rejection",
    "semantic_conflict_detection",
    "downstream_consumability",
    "user_script_llm_boundary",
    "overdesign_detection",
}
dimensions = set(evals.get("grader_dimensions", []))
missing_dimensions = sorted(required_dimensions - dimensions)
if missing_dimensions:
    raise SystemExit(f"missing design grader dimensions: {missing_dimensions}")

status = lifecycle.get("capability_uplift", {}).get("measurement_status")
allowed_statuses = {"architect_eval_matrix_updated_needs_empirical_rerun", "pilot_empirical_sample_recorded"}
if status not in allowed_statuses:
    raise SystemExit(f"unexpected capability_uplift.measurement_status: {status!r}")
PY

printf '[PASS] design architect capability contract\n'
