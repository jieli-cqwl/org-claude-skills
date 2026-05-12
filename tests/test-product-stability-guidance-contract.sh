#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

SKILL="$ROOT/shared/skills/product-director/SKILL.md"
CHECK_SCRIPT="$ROOT/shared/skills/product-director/scripts/completion_check.sh"
SCRIPT_MANIFEST="$ROOT/shared/skills/product-director/scripts/manifest.json"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
DIRECTOR_BRIEF_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"

for path in \
  "$SKILL" \
  "$CHECK_SCRIPT" \
  "$SCRIPT_MANIFEST" \
  "$HOOK_REGISTRY" \
  "$DIRECTOR_BRIEF_JSON_TEMPLATE" \
  "$DIRECTOR_PHASE_JSON_TEMPLATE"
do
  test -f "$path" || fail "missing product-director contract file: $path"
done

if [ -d "$ROOT/shared/skills/product-director/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi
if find "$ROOT/shared/skills/product-director/references" -maxdepth 1 -type f -name 'd-s*.md' | rg . >/dev/null 2>&1; then
  fail "product-director reference filenames must use semantic names, not D-S step prefixes"
fi

assert_present '^name: product-director$' "$SKILL"
assert_present '^allowed-tools: .*Bash' "$SKILL"
assert_present 'validate_director_confirmation' "$CHECK_SCRIPT"
assert_present 'validate_director_lock' "$CHECK_SCRIPT"
assert_present 'validate_director_boundary' "$CHECK_SCRIPT"
assert_present 'validate_canonical_schema\.py' "$CHECK_SCRIPT"
assert_present 'validate_product_closure\.py' "$CHECK_SCRIPT"

jq -e '
  .schema_version == "1.0.0"
  and (.scripts | length == 1)
  and .scripts[0].id == "completion-check"
  and .scripts[0].path == "scripts/completion_check.sh"
  and .scripts[0].owner == "product-director"
  and (.scripts[0].allowed_args | index("hook payload via stdin only"))
  and .scripts[0].timeout_seconds == 15
  and .scripts[0].output_root == "."
  and (.scripts[0].allowed_output_roots | index("$TMPDIR"))
  and (.scripts[0].allowed_input_roots | index("docs"))
  and (.scripts[0].failure_state | test("blocks handoff"))
' "$SCRIPT_MANIFEST" >/dev/null || fail "product-director manifest completion-check contract drift"

jq -e '
  .skill_completion_gates[]
  | select(.skill == "product-director")
  | .owner == "product-director"
    and .handler_rel == "skills/product-director/scripts/completion_check.sh"
    and (.allowed_args | index("hook payload via stdin only"))
    and (.allowed_args | index("--help"))
    and (.allowed_args | index("-h"))
    and .timeout_sec == 15
    and .output_root == "."
    and (.failure_state | test("blocks handoff"))
    and .claude.supported == true
    and .codex.supported == true
' "$HOOK_REGISTRY" >/dev/null || fail "product-director hook registry contract drift"

jq -e '
  .artifact_type == "brief"
  and .schema_version == "1.0.0"
  and .director_confirmation.locked_fields
  and .director_confirmation.locked_field_digest
  and .user_profile
  and .appetite
  and .non_goals
  and .feasibility_constraints
  and .risks_and_unknowns
  and .decision_rationale
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
  and (.delivery_confirmation? | not)
' "$DIRECTOR_BRIEF_JSON_TEMPLATE" >/dev/null || fail "director brief template must encode Director-only lock fields"

jq -e '
  .artifact_type == "phase-prd"
  and .schema_version == "1.0.0"
  and .phase_goal
  and .entry_conditions
  and .exit_conditions
  and ((.unit_index // []) | type == "array" and length == 0)
  and .director_confirmation.locked_fields
  and .director_confirmation.locked_field_digest
  and (.review_conclusion? | not)
  and (.business_flows? | not)
  and (.user_paths? | not)
  and (.rule_mappings? | not)
  and (.design_decision_candidates? | not)
' "$DIRECTOR_PHASE_JSON_TEMPLATE" >/dev/null || fail "director phase template must encode Director-only phase skeleton"

python3 - "$ROOT" "$CHECK_SCRIPT" <<'PY'
import json
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
check_script = Path(sys.argv[2])
feature = Path(tempfile.mkdtemp(prefix="director-gate-", dir=tempfile.gettempdir()))
try:
    docs_feature = root / "docs" / feature.name
    phase_dir = docs_feature / "phase-1"
    phase_dir.mkdir(parents=True, exist_ok=True)
    (docs_feature / "brief.json").write_text(
        (root / "shared/skills/product-director/templates/brief.template.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (phase_dir / "phase-prd.json").write_text(
        (root / "shared/skills/product-director/templates/phase-prd.template.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    payload = {
        "cwd": str(root),
        "session_id": "product-director-test",
        "tool_input": {"file_path": f"docs/{feature.name}/brief.json"},
    }
    completed = subprocess.run(
        ["bash", str(check_script)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        cwd=root,
        check=False,
    )
    if completed.returncode != 0:
        raise SystemExit(completed.stderr or completed.stdout)
    decision = json.loads(completed.stdout)
    if decision.get("decision") != "allow":
        raise SystemExit(f"expected allow decision, got {decision}")
finally:
    if docs_feature.exists():
        for path in sorted(docs_feature.rglob("*"), reverse=True):
            if path.is_file():
                path.unlink()
            elif path.is_dir():
                path.rmdir()
        docs_feature.rmdir()
PY

echo "[PASS] product stability guidance contract"
