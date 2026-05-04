#!/usr/bin/env bash
# File role: prove skill-refiner has fixture-backed comparative effect evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE="$ROOT/shared/skills/skill-refiner/evals/dogfood/effect-evidence/effect-evidence.json"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_effect_evidence.py"
RUN_ALL="$ROOT/tests/run-all.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$EVIDENCE" || fail "missing effect evidence fixture: ${EVIDENCE#"$ROOT"/}"
test -f "$VALIDATOR" || fail "missing effect evidence validator: ${VALIDATOR#"$ROOT"/}"

jq empty "$EVIDENCE" >/dev/null || fail "invalid effect evidence JSON"
python3 "$VALIDATOR" "$EVIDENCE" >/dev/null

run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-effect-evidence.sh' <<<"$run_all_list" \
  || fail "effect evidence test is not registered in tests/run-all.sh"

tmp_bad_winner="$(mktemp)"
tmp_bad_anchor="$(mktemp)"
tmp_bad_baseline="$(mktemp)"
trap 'rm -f "$tmp_bad_winner" "$tmp_bad_anchor" "$tmp_bad_baseline"' EXIT

jq '.scenarios[0].winner = "baseline"' "$EVIDENCE" >"$tmp_bad_winner"
if python3 "$VALIDATOR" "$tmp_bad_winner" >/dev/null 2>&1; then
  fail "validator accepted baseline winner"
fi

jq 'del(.scenarios[1].current.passed_anchors[0])' "$EVIDENCE" >"$tmp_bad_anchor"
if python3 "$VALIDATOR" "$tmp_bad_anchor" >/dev/null 2>&1; then
  fail "validator accepted missing current anchor"
fi

jq '.scenarios[2].baseline.missing_anchors = []' "$EVIDENCE" >"$tmp_bad_baseline"
if python3 "$VALIDATOR" "$tmp_bad_baseline" >/dev/null 2>&1; then
  fail "validator accepted baseline without missing anchors"
fi

printf '[PASS] skill-refiner effect evidence\n'
