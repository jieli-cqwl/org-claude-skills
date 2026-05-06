#!/usr/bin/env bash
# File role: prove product/director/manager/design co-creation ledgers are first-class recovery artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$ROOT/contracts/co-creation-ledgers.yaml"
VALIDATOR="$ROOT/tools/community/validate_co_creation_ledger.py"
DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
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
    "product-director": ["D-S2", "D-S3", "D-S4", "D-S5", "D-S5.5", "D-S6", "D-G1"],
    "product-manager": [
        "M-S1",
        "M-S2",
        "M-S3",
        "M-S4",
        "M-S5",
        "M-S5.5",
        "M-S6",
        "M-S7",
        "M-S8",
        "M-G1",
        "M-S9",
    ],
    "design": ["S3", "S4", "S5", "S6", "S7", "S8", "S10"],
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
            "detected_at": "S2",
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

for file in "$CONTRACT" "$VALIDATOR" "$DIRECTOR_SKILL" "$MANAGER_SKILL" "$DESIGN_SKILL" "$STANDARD_CHAIN" "$RUN_ALL"; do
  assert_file "$file"
done

assert_present 'co_creation_ledgers:' "$CONTRACT"
assert_present 'product-director-ledger.json' "$CONTRACT"
assert_present 'product-manager-ledger.json' "$CONTRACT"
assert_present 'design-ledger.json' "$CONTRACT"
assert_present 'control_input: false' "$CONTRACT"

assert_present 'co_creation_ledgers:' "$STANDARD_CHAIN"
assert_present 'docs/{feature}/product-director-ledger.json' "$STANDARD_CHAIN"
assert_present 'docs/{feature}/phase-{N}/product-manager-ledger.json' "$STANDARD_CHAIN"
assert_present 'docs/{feature}/phase-{N}/design-ledger.json' "$STANDARD_CHAIN"

for skill in "$DIRECTOR_SKILL" "$MANAGER_SKILL" "$DESIGN_SKILL"; do
  assert_absent '## 共创台账' "$skill"
  assert_present '确认检查点未闭合' "$skill"
  assert_present 'validate_co_creation_ledger.py' "$skill"
  assert_present 'supersedes' "$skill"
done
assert_present 'product-director-ledger.json' "$DIRECTOR_SKILL"
assert_present 'producer product-director' "$DIRECTOR_SKILL"
assert_present 'D-S2~D-G1' "$DIRECTOR_SKILL"
assert_present 'product-manager-ledger.json' "$MANAGER_SKILL"
assert_present 'producer product-manager' "$MANAGER_SKILL"
assert_present 'M-S1~M-S9' "$MANAGER_SKILL"
assert_present 'design-ledger.json' "$DESIGN_SKILL"
assert_present 'producer design' "$DESIGN_SKILL"
assert_present 'S3~S10' "$DESIGN_SKILL"
assert_present 'co_creation_summary' "$DESIGN_SKILL"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

write_ledger "$tmpdir/director.json" "product-director" "co-creation-ledger" "CHK-2" "confirmed" "resolved"
write_ledger "$tmpdir/manager.json" "product-manager" "co-creation-ledger" "CHK-2" "confirmed" "resolved"
write_ledger "$tmpdir/design.json" "design" "co-creation-ledger" "CHK-2" "confirmed" "resolved"

python3 "$VALIDATOR" --artifact "$tmpdir/director.json" --producer product-director --require-finalized >/dev/null
python3 "$VALIDATOR" --artifact "$tmpdir/manager.json" --producer product-manager --require-finalized >/dev/null
python3 "$VALIDATOR" --artifact "$tmpdir/design.json" --producer design --require-finalized >/dev/null

write_ledger "$tmpdir/unresolved.json" "design" "co-creation-ledger" "CHK-2" "confirmed" "open"
python3 "$VALIDATOR" --artifact "$tmpdir/unresolved.json" --producer design >/dev/null
if python3 "$VALIDATOR" --artifact "$tmpdir/unresolved.json" --producer design --require-finalized >/dev/null 2>&1; then
  fail "validator must reject unresolved supersedes entries"
fi

write_ledger "$tmpdir/mismatch.json" "design" "co-creation-ledger" "CHK-404" "confirmed" "resolved"
python3 - "$tmpdir/mismatch.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["latest_checkpoint_id"] = "CHK-2"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
PY
if python3 "$VALIDATOR" --artifact "$tmpdir/mismatch.json" --producer design --require-finalized >/dev/null 2>&1; then
  fail "validator must reject latest_checkpoint_id drift"
fi

write_ledger "$tmpdir/not-final.json" "design" "co-creation-ledger" "CHK-2" "draft" "resolved"
if python3 "$VALIDATOR" --artifact "$tmpdir/not-final.json" --producer design --require-finalized >/dev/null 2>&1; then
  fail "validator must reject non-finalized ledgers when require-finalized is set"
fi

write_ledger "$tmpdir/missing-step.json" "design" "co-creation-ledger" "CHK-2" "confirmed" "resolved" "S7"
python3 "$VALIDATOR" --artifact "$tmpdir/missing-step.json" --producer design >/dev/null
if python3 "$VALIDATOR" --artifact "$tmpdir/missing-step.json" --producer design --require-finalized >/dev/null 2>&1; then
  fail "validator must reject ledgers missing required producer checkpoint steps"
fi

run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-standard-chain-co-creation-ledger-contract.sh' <<<"$run_all_list" \
  || fail "co-creation ledger contract test is not registered in tests/run-all.sh"

printf '[PASS] standard-chain co-creation ledger contract\n'
