#!/usr/bin/env bash
# File role: prove Product Director co-creation ledger remains a recovery artifact while PM/Design ledgers are unsupported.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$ROOT/contracts/co-creation-ledgers.yaml"
VALIDATOR="$ROOT/tools/community/validate_co_creation_ledger.py"
DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
STANDARD_CHAIN="$ROOT/contracts/standard-chain.yaml"
RUN_ALL="$ROOT/tests/run-all.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  test -f "$1" || fail "missing file: ${1#"$ROOT"/}"
}

assert_present() {
  local needle="$1" file="$2"
  grep -Fq "$needle" "$file" || fail "missing content in ${file#"$ROOT"/}: $needle"
}

assert_absent() {
  local needle="$1" file="$2"
  ! grep -Fq "$needle" "$file" || fail "unexpected content in ${file#"$ROOT"/}: $needle"
}

write_ledger() {
  local path="$1" producer="$2" artifact_type="$3" latest="$4" final_status="$5" supersedes_status="$6" omit_step="${7:-}"
  python3 - "$path" "$producer" "$artifact_type" "$latest" "$final_status" "$supersedes_status" "$omit_step" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
producer = sys.argv[2]
artifact_type = sys.argv[3]
latest = sys.argv[4]
final_status = sys.argv[5]
supersedes_status = sys.argv[6]
omit_step = sys.argv[7]

steps_by_producer = {
    "product-director": [
        "问题澄清",
        "目标、成功标准与投入边界",
        "业务语义收口",
        "范围、本期不做、可行性约束与决策理由",
        "风险与未知项",
        "Phase 规划",
        "Director Finalization",
    ],
}
steps = [step for step in steps_by_producer[producer] if step != omit_step]
confirmations = []
for index, step in enumerate(steps, start=1):
    checkpoint_id = latest if index == len(steps) else f"CHK-{index:02d}"
    confirmations.append(
        {
            "checkpoint_id": checkpoint_id,
            "step": step,
            "subject_ref": f"{producer}.{step}",
            "confirmed_at": f"2026-05-06T00:{index:02d}:00Z",
            "decision_summary": f"confirmed {step}",
            "source_refs": [f"conversation#{step}"],
            "output_refs": ["brief.json#director_confirmation"],
        }
    )

payload = {
    "artifact_type": artifact_type,
    "schema_version": "1.0.0",
    "producer": producer,
    "scope_ref": "docs/sample/phase-1",
    "current_state": {
        "summary": "confirmed recovery state",
        "source_refs": ["brief.json#director_confirmation"],
        "next_step": "handoff",
    },
    "latest_checkpoint_id": latest,
    "confirmations": confirmations,
    "open_questions": [],
    "supersedes": [
        {
            "supersedes_id": "SUP-1",
            "detected_at": confirmations[0]["step"],
            "drifted_from_checkpoint_id": confirmations[0]["checkpoint_id"],
            "proposed_change": "change earlier scope",
            "resolution": "keep latest confirmed decision",
            "status": supersedes_status,
        }
    ],
    "handoff_refs": ["brief.json#director_confirmation"],
    "finalization_basis": {
        "status": final_status,
        "confirmed_at": "2026-05-06T00:20:00Z",
        "summary": "final handoff confirmed",
        "accepted_checkpoint_ids": [item["checkpoint_id"] for item in confirmations],
    },
}
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

for file in "$CONTRACT" "$VALIDATOR" "$DIRECTOR_SKILL" "$MANAGER_SKILL" "$STANDARD_CHAIN" "$RUN_ALL"; do
  assert_file "$file"
done

assert_present 'co_creation_ledgers:' "$CONTRACT"
assert_present 'product-director-ledger.json' "$CONTRACT"
# negative assertion only: Product Manager and Design ledgers must stay unsupported.
assert_absent 'product-manager-ledger.json' "$CONTRACT"
assert_absent 'design-ledger.json' "$CONTRACT"
assert_present 'control_input: false' "$CONTRACT"

assert_present 'co_creation_ledgers:' "$STANDARD_CHAIN"
assert_present 'docs/{feature}/product-director-ledger.json' "$STANDARD_CHAIN"
# negative assertion only: active standard-chain must not publish PM/Design ledger paths.
assert_absent 'docs/{feature}/phase-{N}/product-manager-ledger.json' "$STANDARD_CHAIN"
assert_absent 'docs/{feature}/phase-{N}/design-ledger.json' "$STANDARD_CHAIN"

python3 - "$CONTRACT" "$DIRECTOR_SKILL" "$STANDARD_CHAIN" <<'PY'
import sys
from pathlib import Path

import yaml

contract = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8"))["co_creation_ledgers"]
if set(contract["ledgers"]) != {"product-director"}:
    raise SystemExit("only product-director may declare a co-creation ledger")
skill_path = Path(sys.argv[2])
standard_chain = yaml.safe_load(Path(sys.argv[3]).read_text(encoding="utf-8"))
spec = contract["ledgers"]["product-director"]
if spec.get("purpose") != "pre_finalization_recovery_and_confirmation":
    raise SystemExit("Director ledger purpose must be pre_finalization_recovery_and_confirmation")
if spec.get("downstream_canonical_source") is not False:
    raise SystemExit("Director ledger must not be a downstream canonical source")
expected_allowed = {
    "checkpoint",
    "subject_ref",
    "user_confirmed_decision_summary",
    "source_refs",
    "output_refs",
    "open_questions",
    "supersedes",
    "handoff_refs",
    "finalization_basis",
}
if set(spec.get("allowed_content", [])) != expected_allowed:
    raise SystemExit("Director ledger allowed_content must stay recovery/confirmation-only")
expected_forbidden = {
    "full_baseline_copy",
    "pm_product_model",
    "acceptance_criteria",
    "design_decisions",
    "implementation_details",
    "downstream_requirements",
}
if not expected_forbidden <= set(spec.get("forbidden_content", [])):
    raise SystemExit("Director ledger forbidden_content must exclude downstream requirements")
chain_ledgers = standard_chain.get("co_creation_ledgers", {})
if chain_ledgers.get("downstream_canonical_source") is not False:
    raise SystemExit("standard-chain must mark co-creation ledgers as non-canonical downstream sources")
product_manager = next(
    item for item in standard_chain["chain"] if item.get("name") == "product-manager"
)
required_inputs = product_manager.get("inputs", {}).get("required", [])
if any("ledger" in str(item) for item in required_inputs):
    raise SystemExit("Product Manager required inputs must consume canonical JSON, not ledger")
text = skill_path.read_text(encoding="utf-8")
required_terms = [
    spec["path"].split("/")[-1],
    "--producer product-director",
    "validate_co_creation_ledger.py",
    "supersedes",
    *spec["checkpoint_steps"],
]
missing = [term for term in required_terms if term not in text]
if missing:
    raise SystemExit(f"{skill_path}: missing ledger contract terms: {missing}")
print("[PASS] skill ledger contract declarations")
PY

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

write_ledger "$tmpdir/director.json" "product-director" "co-creation-ledger" "CHK-2" "confirmed" "resolved"
python3 "$VALIDATOR" --artifact "$tmpdir/director.json" --producer product-director --require-finalized >/dev/null

pm_error="$tmpdir/pm-ledger-error.txt"
# negative assertion only: unsupported Product Manager producer must fail before artifact IO.
if python3 "$VALIDATOR" --artifact "$tmpdir/nonexistent-manager.json" --producer product-manager --require-finalized >"$pm_error" 2>&1; then
  fail "validator must reject product-manager co-creation ledger producer"
fi
grep -Fq 'unsupported co-creation ledger producer: product-manager' "$pm_error" \
  || fail "validator must explain unsupported product-manager producer"
! grep -Fq 'ledger not found' "$pm_error" \
  || fail "validator must reject product-manager before reading artifact"

write_ledger "$tmpdir/unresolved.json" "product-director" "co-creation-ledger" "CHK-2" "confirmed" "open"
python3 "$VALIDATOR" --artifact "$tmpdir/unresolved.json" --producer product-director >/dev/null
if python3 "$VALIDATOR" --artifact "$tmpdir/unresolved.json" --producer product-director --require-finalized >/dev/null 2>&1; then
  fail "validator must reject unresolved supersedes entries"
fi

write_ledger "$tmpdir/mismatch.json" "product-director" "co-creation-ledger" "CHK-404" "confirmed" "resolved"
python3 - "$tmpdir/mismatch.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["latest_checkpoint_id"] = "CHK-2"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
PY
if python3 "$VALIDATOR" --artifact "$tmpdir/mismatch.json" --producer product-director --require-finalized >/dev/null 2>&1; then
  fail "validator must reject latest_checkpoint_id drift"
fi

write_ledger "$tmpdir/not-final.json" "product-director" "co-creation-ledger" "CHK-2" "draft" "resolved"
if python3 "$VALIDATOR" --artifact "$tmpdir/not-final.json" --producer product-director --require-finalized >/dev/null 2>&1; then
  fail "validator must reject non-finalized ledgers when require-finalized is set"
fi

write_ledger "$tmpdir/missing-step.json" "product-director" "co-creation-ledger" "CHK-2" "confirmed" "resolved" "Phase 规划"
python3 "$VALIDATOR" --artifact "$tmpdir/missing-step.json" --producer product-director >/dev/null
if python3 "$VALIDATOR" --artifact "$tmpdir/missing-step.json" --producer product-director --require-finalized >/dev/null 2>&1; then
  fail "validator must reject ledgers missing required producer checkpoint steps"
fi

run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-standard-chain-co-creation-ledger-contract.sh' <<<"$run_all_list" \
  || fail "co-creation ledger contract test is not registered in tests/run-all.sh"

printf '[PASS] standard-chain co-creation ledger contract\n'
