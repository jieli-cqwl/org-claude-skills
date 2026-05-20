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

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

SMOKE_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/product-director-real-demand.XXXXXX")"
trap 'rm -rf "$SMOKE_TMP_ROOT"' EXIT

WORKSPACE="$SMOKE_TMP_ROOT/workspace"
FEATURE="feature--finance-aging-reminders"
FEATURE_DIR="$WORKSPACE/docs/$FEATURE"
PHASE_DIR="$FEATURE_DIR/phase-1"
mkdir -p "$PHASE_DIR"

python3 - "$ROOT" "$WORKSPACE" "$FEATURE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
workspace = Path(sys.argv[2])
feature = sys.argv[3]
feature_dir = workspace / "docs" / feature
phase_dir = feature_dir / "phase-1"
catalog = json.loads((root / "shared/runtime/standard-chain-catalog.json").read_text(encoding="utf-8"))
chain_digest = catalog["chain_registry_digest"]
produced_at = "2026-05-20T12:00:00Z"


def digest(snapshot: dict) -> str:
    raw = json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


brief_locked = {
    "root_problem": (
        "Finance operations specialists reviewing overdue lease invoices each morning miss "
        "follow-ups because aging status is tracked in spreadsheets and chat threads, causing "
        "delayed collections and repeated reconciliation work."
    ),
    "user_profile": [
        {
            "who": "finance operations specialist",
            "scenario": "reviewing overdue lease invoices each morning before customer follow-up",
            "current_workaround": "export aging data, update a spreadsheet, then ask account owners in chat for status",
            "workaround_cost": "3-5 missed overdue follow-ups per week, slow collections, and repeated reconciliation questions",
        }
    ],
    "business_goals": [
        "reduce missed overdue invoice follow-ups from 3-5 per week to zero reported misses during the first 30-day observation window",
        "make daily collection status visible from the billing export before finance operations starts manual outreach",
    ],
    "appetite": {
        "investment_scale": "single focused phase",
        "complexity_ceiling": "reuse the existing billing export and account owner directory",
        "trim_first": "automated payment recovery, customer messaging, and analytics dashboards",
    },
    "scope_boundaries": [
        "identify overdue lease invoices from the existing billing export",
        "show one daily follow-up queue for finance operations",
        "record whether an account owner has acknowledged the overdue item",
    ],
    "non_goals": [
        "do not change invoice calculation rules",
        "do not send customer-facing collection messages in this phase",
        "do not build cross-region collection analytics",
    ],
    "feasibility_constraints": [
        {
            "type": "data",
            "constraint": "billing export is available once per business day",
            "impact_scope": "phase-1 queue freshness",
            "handling": "limit the phase goal to daily follow-up visibility rather than real-time collection automation",
        }
    ],
    "risks_and_unknowns": [
        {
            "item": "billing export availability reviewed for daily queue generation",
            "impact": "confirmed daily export cadence supports the Phase 1 follow-up queue without changing scope or phase split",
            "mitigation": "keep Phase 1 on daily visibility; return to risk review if export cadence changes the Director baseline",
            "status": "RESOLVED",
        }
    ],
    "decision_rationale": [
        {
            "decision": "start with a daily overdue follow-up queue",
            "choice": "focus Phase 1 on finance operations visibility and owner acknowledgement",
            "rationale": "this closes the missed-follow-up loop before investing in automated collection workflows",
            "excluded_options": "customer-facing dunning automation, invoice rule changes, and analytics dashboards",
        }
    ],
    "delivery_plan": [
        {
            "phase_id": "phase-1",
            "goal": "deliver a daily overdue invoice follow-up baseline for finance operations",
            "iteration_timebox_days": 10,
        }
    ],
}

brief = {
    "artifact_type": "brief",
    "artifact_id": f"{feature}.brief",
    "schema_version": "1.0.0",
    "producer": "product",
    "produced_at": produced_at,
    "chain_version": "standard-chain/v1",
    "chain_registry_digest": chain_digest,
    "authority_scope": "artifact",
    "authoritative_fields": [
        "$.root_problem",
        "$.user_profile",
        "$.business_goals",
        "$.appetite",
        "$.scope_boundaries",
        "$.non_goals",
        "$.feasibility_constraints",
        "$.risks_and_unknowns",
        "$.decision_rationale",
        "$.delivery_plan",
        "$.director_confirmation",
    ],
    **brief_locked,
    "director_confirmation": {
        "status": "passed",
        "confirmed_at": produced_at,
        "locked_field_digest": digest(brief_locked),
        "locked_fields": brief_locked,
    },
}

phase_locked = {
    "phase_goal": "deliver a daily overdue invoice follow-up baseline for finance operations",
    "entry_conditions": [
        "finance operations owns the daily overdue lease invoice review before customer follow-up",
        "daily billing export remains available to finance operations",
        "account owner directory is available for owner acknowledgement",
    ],
    "exit_conditions": [
        "finance operations can review every overdue lease invoice from the daily billing export in one follow-up queue before manual outreach",
        "finance operations can see owner acknowledgement for each overdue item without checking spreadsheet or chat threads",
        "weekly reconciliation review can count missed overdue follow-ups from the daily queue evidence",
    ],
}

phase = {
    "artifact_type": "phase-prd",
    "artifact_id": f"{feature}.phase-1.prd",
    "schema_version": "1.0.0",
    "producer": "product",
    "produced_at": produced_at,
    "chain_version": "standard-chain/v1",
    "chain_registry_digest": chain_digest,
    "authority_scope": "phase",
    "authoritative_fields": [
        "$.phase_goal",
        "$.entry_conditions",
        "$.exit_conditions",
        "$.director_confirmation",
    ],
    **phase_locked,
    "unit_index": [],
    "director_confirmation": {
        "status": "passed",
        "confirmed_at": produced_at,
        "locked_field_digest": digest(phase_locked),
        "locked_fields": phase_locked,
    },
}

step_summaries = {
    "D-S2": "Root problem confirmed: finance operations misses overdue lease invoice follow-ups because status is split across spreadsheets and chat.",
    "D-S3": "Success signal confirmed: missed overdue follow-ups move from 3-5 per week to zero reported misses in a 30-day observation window.",
    "D-S4": "Business semantics confirmed: overdue lease invoice comes from the daily billing export; owner acknowledgement means accepted follow-up responsibility.",
    "D-S5": "Scope confirmed: daily overdue queue and owner acknowledgement are in; invoice rule changes, customer messages, and analytics are out.",
    "D-S5.5": "Risk confirmed: daily billing export cadence supports Phase 1; export cadence drift returns to risk review before finalization.",
    "D-S6": "Phase confirmed: one 10-day value slice closes finance operations follow-up visibility before automation expansion.",
    "D-G1": "Finalization confirmed: ledger, brief, phase-prd, locked fields, and digest are ready for Director handoff.",
}
confirmations = []
for index, (step, summary) in enumerate(step_summaries.items(), start=1):
    confirmations.append(
        {
            "checkpoint_id": f"PD-{index:02d}",
            "step": step,
            "subject_ref": f"{feature}:{step}",
            "confirmed_at": f"2026-05-20T12:{index:02d}:00Z",
            "decision_summary": summary,
            "source_refs": [f"docs/{feature}/brief.json"],
            "output_refs": [
                f"docs/{feature}/brief.json",
                f"docs/{feature}/phase-1/phase-prd.json",
            ],
        }
    )

ledger = {
    "artifact_type": "co-creation-ledger",
    "schema_version": "1.0.0",
    "producer": "product-director",
    "scope_ref": f"docs/{feature}",
    "current_state": {
        "summary": "Director baseline finalized for a finance operations overdue invoice follow-up queue",
        "source_refs": [f"docs/{feature}/brief.json"],
        "next_step": "handoff to product-manager and technical lead",
    },
    "latest_checkpoint_id": confirmations[-1]["checkpoint_id"],
    "confirmations": confirmations,
    "open_questions": [],
    "supersedes": [],
    "handoff_refs": [
        f"docs/{feature}/brief.json",
        f"docs/{feature}/phase-1/phase-prd.json",
    ],
    "finalization_basis": {
        "status": "confirmed",
        "confirmed_at": produced_at,
        "summary": "All Director checkpoints were accepted before artifact finalization",
        "accepted_checkpoint_ids": [item["checkpoint_id"] for item in confirmations],
    },
}

feature_dir.mkdir(parents=True, exist_ok=True)
phase_dir.mkdir(parents=True, exist_ok=True)
(feature_dir / "brief.json").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(phase_dir / "phase-prd.json").write_text(json.dumps(phase, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(feature_dir / "product-director-ledger.json").write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(workspace / "brief.fixture.json").write_text(json.dumps({"artifacts": [brief]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(workspace / "phase.fixture.json").write_text(json.dumps({"artifacts": [phase]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$ROOT/tools/community/validate_co_creation_ledger.py" \
  --artifact "$FEATURE_DIR/product-director-ledger.json" \
  --producer product-director \
  --require-finalized

python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$WORKSPACE/brief.fixture.json"
python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$WORKSPACE/phase.fixture.json"
python3 "$ROOT/tools/community/validate_product_closure.py" --artifact "$FEATURE_DIR/brief.json"
python3 "$ROOT/tools/community/validate_product_closure.py" --artifact "$PHASE_DIR/phase-prd.json"

jq -e '
  (has("acceptance_criteria") | not)
  and (has("design_decisions") | not)
  and (has("non_functional_requirements") | not)
  and (has("business_flows") | not)
  and (has("user_paths") | not)
  and (has("rule_mappings") | not)
' "$FEATURE_DIR/brief.json" >/dev/null

jq -e '
  (.unit_index == [])
  and (has("unit_priority_order") | not)
  and (has("business_flows") | not)
  and (has("user_paths") | not)
  and (has("rule_mappings") | not)
' "$PHASE_DIR/phase-prd.json" >/dev/null

QUALITY_OUT="$SMOKE_TMP_ROOT/content-quality.json"
python3 "$ROOT/shared/skills/product-director/scripts/evaluate_content_quality.py" \
  --brief "$FEATURE_DIR/brief.json" \
  --phase-prd "$PHASE_DIR/phase-prd.json" \
  --ledger "$FEATURE_DIR/product-director-ledger.json" \
  --min-score 12 >"$QUALITY_OUT"

assert_present '"verdict": "PASS"' "$QUALITY_OUT"
assert_present '"root_problem_quality"' "$QUALITY_OUT"
assert_present '"success_standard_quality"' "$QUALITY_OUT"
assert_present '"phase_value_slice_quality"' "$QUALITY_OUT"

WEAK_DIR="$SMOKE_TMP_ROOT/weak-content"
mkdir -p "$WEAK_DIR/phase-1"
cp "$FEATURE_DIR/brief.json" "$WEAK_DIR/brief.json"
cp "$PHASE_DIR/phase-prd.json" "$WEAK_DIR/phase-1/phase-prd.json"
cp "$FEATURE_DIR/product-director-ledger.json" "$WEAK_DIR/product-director-ledger.json"
python3 - "$WEAK_DIR/brief.json" "$WEAK_DIR/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
phase_path = Path(sys.argv[2])
brief = json.loads(brief_path.read_text(encoding="utf-8"))
phase = json.loads(phase_path.read_text(encoding="utf-8"))
brief["root_problem"] = "Improve billing reminder efficiency."
brief["business_goals"] = ["make the process better"]
phase["entry_conditions"] = ["director baseline confirmed"]
phase["exit_conditions"] = ["finish the 10-day timebox"]
brief_path.write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
phase_path.write_text(json.dumps(phase, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

WEAK_OUT="$SMOKE_TMP_ROOT/weak-content-quality.json"
if python3 "$ROOT/shared/skills/product-director/scripts/evaluate_content_quality.py" \
  --brief "$WEAK_DIR/brief.json" \
  --phase-prd "$WEAK_DIR/phase-1/phase-prd.json" \
  --ledger "$WEAK_DIR/product-director-ledger.json" \
  --min-score 12 >"$WEAK_OUT"; then
  fail "content quality evaluator should reject weak Director artifacts"
fi
assert_present '"verdict": "FAIL"' "$WEAK_OUT"
assert_present 'root_problem_quality' "$WEAK_OUT"
assert_present 'phase entry conditions must be business facts' "$WEAK_OUT"

HOOK_OUT="$SMOKE_TMP_ROOT/hook.out"
HOOK_ERR="$SMOKE_TMP_ROOT/hook.err"
printf '{"cwd":"%s","session_id":"real-demand-smoke","transcript_path":"/dev/null","tool_input":{"file_path":"docs/%s/brief.json"}}\n' \
  "$WORKSPACE" "$FEATURE" \
  | "$ROOT/shared/skills/product-director/scripts/completion_check.sh" >"$HOOK_OUT" 2>"$HOOK_ERR"

assert_present '"decision":"allow"' "$HOOK_OUT"
assert_present 'director canonical baseline validated' "$HOOK_OUT"

echo "[PASS] product-director real demand smoke"
