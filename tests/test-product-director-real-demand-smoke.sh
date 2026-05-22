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

python3 - "$WORKSPACE" "$FEATURE" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1])
feature = sys.argv[2]
feature_dir = workspace / "docs" / feature
phase_dir = feature_dir / "phase-1"
produced_at = "2026-05-20T12:00:00Z"

brief = {
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

phase = {
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

step_summaries = {
    "问题澄清": "Root problem confirmed: finance operations misses overdue lease invoice follow-ups because status is split across spreadsheets and chat.",
    "目标、成功标准与投入边界": "Success signal confirmed: missed overdue follow-ups move from 3-5 per week to zero in a 30-day observation window.",
    "业务语义收口": "Business semantics confirmed: overdue lease invoice comes from the daily billing export; owner acknowledgement means accepted follow-up responsibility.",
    "范围、本期不做、可行性约束与决策理由": "Scope confirmed: daily overdue queue and owner acknowledgement are in; invoice rule changes, customer messages, and analytics are out.",
    "风险与未知项": "Risk confirmed: daily billing export cadence supports Phase 1; export cadence drift returns to risk review before finalization.",
    "Phase 规划": "Phase confirmed: one 10-day value slice closes finance operations follow-up visibility before automation expansion.",
    "Director Finalization": "Finalization confirmed: ledger, brief, and phase-prd result payloads are ready for Director completion.",
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
        "next_step": "ready for product and technical detail work",
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
PY

python3 "$ROOT/tools/community/validate_co_creation_ledger.py" \
  --artifact "$FEATURE_DIR/product-director-ledger.json" \
  --producer product-director \
  --require-finalized

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
' "$FEATURE_DIR/brief.json" >/dev/null

jq -e '
  (keys_unsorted | sort) == ([
    "entry_conditions",
    "exit_conditions",
    "phase_goal"
  ] | sort)
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

SEMANTIC_LEDGER_DIR="$SMOKE_TMP_ROOT/semantic-ledger"
mkdir -p "$SEMANTIC_LEDGER_DIR/phase-1"
cp "$FEATURE_DIR/brief.json" "$SEMANTIC_LEDGER_DIR/brief.json"
cp "$PHASE_DIR/phase-prd.json" "$SEMANTIC_LEDGER_DIR/phase-1/phase-prd.json"
cp "$FEATURE_DIR/product-director-ledger.json" "$SEMANTIC_LEDGER_DIR/product-director-ledger.json"
python3 - "$SEMANTIC_LEDGER_DIR/product-director-ledger.json" <<'PY'
import json
import sys
from pathlib import Path

ledger_path = Path(sys.argv[1])
ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
steps = [
    ("pd-problem", "问题澄清"),
    ("pd-success", "目标、成功标准与投入边界"),
    ("pd-semantics", "业务语义收口"),
    ("pd-scope", "范围、本期不做、可行性约束与决策理由"),
    ("pd-risk", "风险与未知项"),
    ("pd-phase", "Phase 规划"),
    ("pd-final", "Director Finalization"),
]
for item, (checkpoint_id, step) in zip(ledger["confirmations"], steps):
    item["checkpoint_id"] = checkpoint_id
    item["step"] = step
ledger["latest_checkpoint_id"] = ledger["confirmations"][-1]["checkpoint_id"]
ledger["finalization_basis"]["accepted_checkpoint_ids"] = [
    item["checkpoint_id"] for item in ledger["confirmations"]
]
ledger_path.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

SEMANTIC_QUALITY_OUT="$SMOKE_TMP_ROOT/semantic-ledger-quality.json"
python3 "$ROOT/shared/skills/product-director/scripts/evaluate_content_quality.py" \
  --brief "$SEMANTIC_LEDGER_DIR/brief.json" \
  --phase-prd "$SEMANTIC_LEDGER_DIR/phase-1/phase-prd.json" \
  --ledger "$SEMANTIC_LEDGER_DIR/product-director-ledger.json" \
  --min-score 12 >"$SEMANTIC_QUALITY_OUT"
assert_present '"verdict": "PASS"' "$SEMANTIC_QUALITY_OUT"

PROJECTION_OUT="$SMOKE_TMP_ROOT/projection-render.json"
python3 "$ROOT/shared/skills/product-director/scripts/render_projection.py" \
  --feature-dir "$FEATURE_DIR" >"$PROJECTION_OUT"

PROJECTION_FILE="$FEATURE_DIR/views/product-director.projection.md"
PROJECTION_MANIFEST="$FEATURE_DIR/views/product-director.projection-manifest.json"
test -f "$PROJECTION_FILE" || fail "product-director projection markdown should be generated"
test -f "$PROJECTION_MANIFEST" || fail "product-director projection manifest should be generated"

assert_present '"status": "PASS"' "$PROJECTION_OUT"
assert_present '产品总监基线说明书' "$PROJECTION_FILE"
assert_present '一句话结论' "$PROJECTION_FILE"
assert_present '为什么现在要做' "$PROJECTION_FILE"
assert_present '本期成功标准' "$PROJECTION_FILE"
assert_present '本期范围' "$PROJECTION_FILE"
assert_present '风险与未决项' "$PROJECTION_FILE"
assert_present 'Phase 规划' "$PROJECTION_FILE"
assert_present '决策理由' "$PROJECTION_FILE"
assert_present 'JSON 是唯一真源' "$PROJECTION_FILE"
assert_present 'finance operations specialist' "$PROJECTION_FILE"
assert_present '3-5 per week' "$PROJECTION_FILE"
assert_present 'zero reported misses' "$PROJECTION_FILE"
assert_present 'daily overdue invoice follow-up baseline' "$PROJECTION_FILE"
if rg -n '\$\.|JSON Pointer|Source: `' "$PROJECTION_FILE" >/dev/null 2>&1; then
  fail "product-director projection markdown should be human-facing and keep JSON pointers in manifest"
fi
jq -e '
  .source_artifact_refs == [
    "brief.json",
    "phase-1/phase-prd.json"
  ]
  and (.sections[] | select(.section_id == "one_line_conclusion") | .json_pointers | index("$.root_problem") != null)
  and (.sections[] | select(.section_id == "phase_plan") | .json_pointers | index("$.delivery_plan") != null)
  and (.sections[] | select(.section_id == "phase_plan") | .json_pointers | index("phase-1/phase-prd.json:$.entry_conditions") != null)
' "$PROJECTION_MANIFEST" >/dev/null || fail "product-director projection manifest should point back to Director JSON"

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

MISSING_WINDOW_DIR="$SMOKE_TMP_ROOT/missing-window"
mkdir -p "$MISSING_WINDOW_DIR/phase-1"
cp "$FEATURE_DIR/brief.json" "$MISSING_WINDOW_DIR/brief.json"
cp "$PHASE_DIR/phase-prd.json" "$MISSING_WINDOW_DIR/phase-1/phase-prd.json"
cp "$FEATURE_DIR/product-director-ledger.json" "$MISSING_WINDOW_DIR/product-director-ledger.json"
python3 - "$MISSING_WINDOW_DIR/brief.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
brief = json.loads(brief_path.read_text(encoding="utf-8"))
brief["business_goals"] = ["reduce missed overdue invoice follow-ups from 5 misses to zero reported misses"]
brief_path.write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

MISSING_WINDOW_OUT="$SMOKE_TMP_ROOT/missing-window-quality.json"
if python3 "$ROOT/shared/skills/product-director/scripts/evaluate_content_quality.py" \
  --brief "$MISSING_WINDOW_DIR/brief.json" \
  --phase-prd "$MISSING_WINDOW_DIR/phase-1/phase-prd.json" \
  --ledger "$MISSING_WINDOW_DIR/product-director-ledger.json" \
  --min-score 12 >"$MISSING_WINDOW_OUT"; then
  fail "content quality evaluator should reject missing success observation window"
fi
assert_present 'business goals must include an observation window' "$MISSING_WINDOW_OUT"

LEDGER_GAP_DIR="$SMOKE_TMP_ROOT/ledger-gap"
mkdir -p "$LEDGER_GAP_DIR/phase-1"
cp "$FEATURE_DIR/brief.json" "$LEDGER_GAP_DIR/brief.json"
cp "$PHASE_DIR/phase-prd.json" "$LEDGER_GAP_DIR/phase-1/phase-prd.json"
cp "$FEATURE_DIR/product-director-ledger.json" "$LEDGER_GAP_DIR/product-director-ledger.json"
python3 - "$LEDGER_GAP_DIR/product-director-ledger.json" <<'PY'
import json
import sys
from pathlib import Path

ledger_path = Path(sys.argv[1])
ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
for item in ledger["confirmations"]:
    if item.get("step") == "目标、成功标准与投入边界":
        item["decision_summary"] = "Success standard reviewed without preserving its measurable checkpoint."
ledger_path.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

LEDGER_GAP_OUT="$SMOKE_TMP_ROOT/ledger-gap-quality.json"
if python3 "$ROOT/shared/skills/product-director/scripts/evaluate_content_quality.py" \
  --brief "$LEDGER_GAP_DIR/brief.json" \
  --phase-prd "$LEDGER_GAP_DIR/phase-1/phase-prd.json" \
  --ledger "$LEDGER_GAP_DIR/product-director-ledger.json" \
  --min-score 12 >"$LEDGER_GAP_OUT"; then
  fail "content quality evaluator should reject missing ledger success checkpoint"
fi
assert_present 'ledger must preserve the success-standard checkpoint' "$LEDGER_GAP_OUT"

HOOK_OUT="$SMOKE_TMP_ROOT/hook.out"
HOOK_ERR="$SMOKE_TMP_ROOT/hook.err"
if ! printf '{"cwd":"%s","session_id":"real-demand-smoke","transcript_path":"/dev/null","tool_input":{"file_path":"docs/%s/brief.json"}}\n' \
  "$WORKSPACE" "$FEATURE" \
  | "$ROOT/shared/skills/product-director/scripts/completion_check.sh" >"$HOOK_OUT" 2>"$HOOK_ERR"; then
  cat "$HOOK_OUT" >&2
  cat "$HOOK_ERR" >&2
  fail "completion hook should accept valid Director result payloads"
fi

assert_present '"decision":"allow"' "$HOOK_OUT"
assert_present 'director result baseline validated' "$HOOK_OUT"

REL_HOOK_OUT="$SMOKE_TMP_ROOT/relative-hook.out"
REL_HOOK_ERR="$SMOKE_TMP_ROOT/relative-hook.err"
(
  cd "$ROOT"
  if ! printf '{"cwd":"%s","session_id":"relative-real-demand-smoke","transcript_path":"/dev/null","tool_input":{"file_path":"docs/%s/brief.json"}}\n' \
    "$WORKSPACE" "$FEATURE" \
    | shared/skills/product-director/scripts/completion_check.sh >"$REL_HOOK_OUT" 2>"$REL_HOOK_ERR"; then
    cat "$REL_HOOK_OUT" >&2
    cat "$REL_HOOK_ERR" >&2
    fail "relative completion hook should accept valid Director result payloads"
  fi
)
assert_present '"decision":"allow"' "$REL_HOOK_OUT"

RUNTIME_NOISE_WORKSPACE="$SMOKE_TMP_ROOT/runtime-noise-workspace"
cp -R "$WORKSPACE" "$RUNTIME_NOISE_WORKSPACE"
python3 - "$RUNTIME_NOISE_WORKSPACE/docs/$FEATURE/brief.json" "$RUNTIME_NOISE_WORKSPACE/docs/$FEATURE/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
phase_path = Path(sys.argv[2])
brief = json.loads(brief_path.read_text(encoding="utf-8"))
phase = json.loads(phase_path.read_text(encoding="utf-8"))
brief["artifact_type"] = "brief"
brief["director_confirmation"] = {"status": "passed"}
phase["unit_index"] = []
brief_path.write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
phase_path.write_text(json.dumps(phase, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

RUNTIME_NOISE_HOOK_OUT="$SMOKE_TMP_ROOT/runtime-noise-hook.out"
RUNTIME_NOISE_HOOK_ERR="$SMOKE_TMP_ROOT/runtime-noise-hook.err"
if printf '{"cwd":"%s","session_id":"runtime-noise-real-demand-smoke","transcript_path":"/dev/null","tool_input":{"file_path":"docs/%s/brief.json"}}\n' \
  "$RUNTIME_NOISE_WORKSPACE" "$FEATURE" \
  | "$ROOT/shared/skills/product-director/scripts/completion_check.sh" >"$RUNTIME_NOISE_HOOK_OUT" 2>"$RUNTIME_NOISE_HOOK_ERR"; then
  fail "completion hook should reject runtime envelope fields"
fi
assert_present '"decision":"block"' "$RUNTIME_NOISE_HOOK_OUT"
assert_present 'contains runtime or downstream fields' "$RUNTIME_NOISE_HOOK_ERR"

STUFFED_WORKSPACE="$SMOKE_TMP_ROOT/stuffed-workspace"
cp -R "$WORKSPACE" "$STUFFED_WORKSPACE"
python3 - "$STUFFED_WORKSPACE/docs/$FEATURE/brief.json" <<'PY'
import json
import sys
from pathlib import Path

brief_path = Path(sys.argv[1])
brief = json.loads(brief_path.read_text(encoding="utf-8"))
brief["root_problem"] = "finance operations specialist because because causing cost 999 day"
brief["user_profile"][0]["current_workaround"] = "anything vague"
brief["business_goals"] = ["reduce missed overdue invoice follow-ups from 999 per day to 1 in a 30-day window"]
brief_path.write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

STUFFED_HOOK_OUT="$SMOKE_TMP_ROOT/stuffed-hook.out"
STUFFED_HOOK_ERR="$SMOKE_TMP_ROOT/stuffed-hook.err"
if printf '{"cwd":"%s","session_id":"stuffed-real-demand-smoke","transcript_path":"/dev/null","tool_input":{"file_path":"docs/%s/brief.json"}}\n' \
  "$STUFFED_WORKSPACE" "$FEATURE" \
  | "$ROOT/shared/skills/product-director/scripts/completion_check.sh" >"$STUFFED_HOOK_OUT" 2>"$STUFFED_HOOK_ERR"; then
  fail "completion hook should reject keyword-stuffed Director artifacts"
fi
assert_present '"decision":"block"' "$STUFFED_HOOK_OUT"
assert_present 'product-director content quality validation failed' "$STUFFED_HOOK_ERR"

echo "[PASS] product-director real demand smoke"
