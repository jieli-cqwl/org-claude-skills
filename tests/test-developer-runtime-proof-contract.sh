#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALID="$ROOT/tests/fixtures/developer-runtime-layering/verified-report.json"
BLOCKED="$ROOT/tests/fixtures/developer-runtime-layering/blocked-report.json"

validate_report() {
  local report="$1"
  local tmp rc
  tmp="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-proof.XXXXXX")"
  jq -n --slurpfile artifact "$report" '{artifacts: [$artifact[0]]}' >"$tmp"
  if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$tmp" >/dev/null; then
    rc=0
  else
    rc=$?
  fi
  rm -f "$tmp"
  return "$rc"
}

validate_report "$VALID"
validate_report "$BLOCKED"

jq -e '.failure_contract.status == "BLOCKED" and .failure_contract.safe_to_continue == false' "$BLOCKED" >/dev/null
jq -e '.fresh_proof.current_evidence_refs | length > 0' "$VALID" >/dev/null
jq -e 'all(.fresh_proof.proving_commands[]; (.current_output_ref // "") | length > 0)' "$VALID" >/dev/null

while IFS= read -r report; do
  if jq -e '.runtime_status == "VERIFIED" and (has("fresh_proof") | not)' "$report" >/dev/null; then
    printf '[FAIL] VERIFIED developer report lacks fresh_proof: %s\n' "$report" >&2
    exit 1
  fi
done < <(find "$ROOT/tests/fixtures" -path '*/developer-report.json' -print | sort)

BROKEN="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-proof-broken.XXXXXX")"
jq 'del(.fresh_proof.current_evidence_refs) | .fresh_proof.proving_commands[0].current_output_ref = ""' "$VALID" >"$BROKEN"
if validate_report "$BROKEN" >/dev/null 2>&1; then
  printf '[FAIL] verified report without current fresh proof evidence passed\n' >&2
  exit 1
fi
rm -f "$BROKEN"

BROKEN_BLOCKED="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-blocked-broken.XXXXXX")"
jq 'del(.failure_contract.owner)' "$BLOCKED" >"$BROKEN_BLOCKED"
if validate_report "$BROKEN_BLOCKED" >/dev/null 2>&1; then
  printf '[FAIL] blocked report without failure_contract.owner passed\n' >&2
  exit 1
fi
rm -f "$BROKEN_BLOCKED"

printf '[PASS] developer runtime proof contract\n'
