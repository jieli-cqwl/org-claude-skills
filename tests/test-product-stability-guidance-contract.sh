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
assert_present 'validate_director_result_payload' "$CHECK_SCRIPT"
assert_present 'evaluate_content_quality\.py' "$CHECK_SCRIPT"
assert_absent 'validate_director_confirmation|validate_director_lock|validate_canonical_schema\.py|validate_product_closure\.py' "$CHECK_SCRIPT"

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
  and (.scripts[0].failure_state | test("blocks completion"))
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
    and (.failure_state | test("blocks completion"))
    and .claude.supported == true
    and .codex.supported == true
' "$HOOK_REGISTRY" >/dev/null || fail "product-director hook registry contract drift"

jq -e '
  (keys_unsorted | sort) == ([
    "appetite",
    "business_goals",
    "decision_rationale",
    "delivery_plan",
    "feasibility_constraints",
    "non_goals",
    "risks_and_unknowns",
    "root_problem",
    "scope_boundaries",
    "user_profile"
  ] | sort)
  and .user_profile
  and .appetite
  and .non_goals
  and .feasibility_constraints
  and .risks_and_unknowns
  and .decision_rationale
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
  and (.delivery_confirmation? | not)
' "$DIRECTOR_BRIEF_JSON_TEMPLATE" >/dev/null || fail "director brief template must encode Director result payload only"

jq -e '
  (keys_unsorted | sort) == ([
    "entry_conditions",
    "exit_conditions",
    "phase_goal"
  ] | sort)
  and .phase_goal
  and .entry_conditions
  and .exit_conditions
' "$DIRECTOR_PHASE_JSON_TEMPLATE" >/dev/null || fail "director phase template must encode Director phase result payload only"

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
    step_summaries = {
        "D-S2": "Root problem confirmed: operations specialists miss merchant onboarding handoffs because checklist status is split across spreadsheets and tools.",
        "D-S3": "Success signal confirmed: missed onboarding handoffs move from 4 per month to zero in a 30-day observation window.",
        "D-S4": "Business semantics confirmed: onboarding record comes from the existing approval system; configuration handoff means accepted setup responsibility.",
        "D-S5": "Scope confirmed: intake review, configuration handoff, and status visibility are in; CRM replacement, rule builders, and analytics are out.",
        "D-S5.5": "Risk confirmed: existing approval status supports Phase 1; status model drift returns to risk review before finalization.",
        "D-S6": "Phase confirmed: one 14-day value slice closes operations handoff visibility before automation expansion.",
        "D-G1": "Finalization confirmed: ledger, brief, and phase-prd result payloads are ready for Director completion.",
    }
    confirmations = [
        {
            "checkpoint_id": f"PD-{index:02d}",
            "step": step,
            "subject_ref": f"{feature.name}:{step}",
            "confirmed_at": f"2026-04-14T02:{index:02d}:00Z",
            "decision_summary": summary,
            "source_refs": [f"docs/{feature.name}/brief.json"],
            "output_refs": [
                f"docs/{feature.name}/brief.json",
                f"docs/{feature.name}/phase-1/phase-prd.json",
            ],
        }
        for index, (step, summary) in enumerate(step_summaries.items(), start=1)
    ]
    (docs_feature / "product-director-ledger.json").write_text(
        json.dumps(
            {
                "artifact_type": "co-creation-ledger",
                "schema_version": "1.0.0",
                "producer": "product-director",
                "scope_ref": f"docs/{feature.name}",
                "current_state": {
                    "summary": "Director baseline finalized for merchant onboarding handoff quality check",
                    "source_refs": [f"docs/{feature.name}/brief.json"],
                    "next_step": "ready for product and technical detail work",
                },
                "latest_checkpoint_id": confirmations[-1]["checkpoint_id"],
                "confirmations": confirmations,
                "open_questions": [],
                "supersedes": [],
                "handoff_refs": [
                    f"docs/{feature.name}/brief.json",
                    f"docs/{feature.name}/phase-1/phase-prd.json",
                ],
                "finalization_basis": {
                    "status": "confirmed",
                    "confirmed_at": "2026-04-14T02:30:00Z",
                    "summary": "Director ledger finalized after all required checkpoints",
                    "accepted_checkpoint_ids": [item["checkpoint_id"] for item in confirmations],
                },
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
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
