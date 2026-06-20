#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/shared/skills/product-director/evals/dogfood/real-transcript-review"
VALIDATOR="$ROOT/shared/skills/product-director/scripts/validate_real_transcript_dogfood.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$BASE/plan.template.json" || fail "missing plan template"
test -f "$BASE/review.template.json" || fail "missing review template"
test -f "$BASE/summary.template.json" || fail "missing summary template"
test -f "$BASE/README.md" || fail "missing README"
test -f "$VALIDATOR" || fail "missing validator"

python3 "$VALIDATOR" --check-template "$BASE/plan.template.json"
python3 "$VALIDATOR" --check-template "$BASE/review.template.json"
python3 "$VALIDATOR" --check-template "$BASE/summary.template.json"

VALID_FIXTURE="$BASE/fixtures/valid-stage1-smoke"
INVALID_PROMOTION="$BASE/fixtures/invalid-promotion-with-four-transcripts"
INVALID_ROUTE_STATE="$BASE/fixtures/invalid-persistent-route-state"
INVALID_EVIDENCE_ANCHOR="$BASE/fixtures/invalid-evidence-anchor"
INVALID_DIGEST="$BASE/fixtures/invalid-digest"
INVALID_ROUTE_SIGNAL="$BASE/fixtures/invalid-route-signal"

python3 "$VALIDATOR" --check-package "$VALID_FIXTURE"

if python3 "$VALIDATOR" --check-package "$INVALID_PROMOTION" >/tmp/product-director-invalid-promotion.out 2>&1; then
  fail "invalid promotion fixture unexpectedly passed"
fi
rg -n "promotion requires 5 complete reviews" /tmp/product-director-invalid-promotion.out >/dev/null \
  || fail "invalid promotion fixture failed for the wrong reason"

if python3 "$VALIDATOR" --check-package "$INVALID_ROUTE_STATE" >/tmp/product-director-invalid-route.out 2>&1; then
  fail "invalid persistent route fixture unexpectedly passed"
fi
rg -n "route decisions must remain inline and non-persistent" /tmp/product-director-invalid-route.out >/dev/null \
  || fail "invalid persistent route fixture failed for the wrong reason"

if python3 "$VALIDATOR" --check-package "$INVALID_EVIDENCE_ANCHOR" >/tmp/product-director-invalid-anchor.out 2>&1; then
  fail "invalid evidence anchor fixture unexpectedly passed"
fi
rg -n "evidence anchor missing" /tmp/product-director-invalid-anchor.out >/dev/null \
  || fail "invalid evidence anchor fixture failed for the wrong reason"

if python3 "$VALIDATOR" --check-package "$INVALID_DIGEST" >/tmp/product-director-invalid-digest.out 2>&1; then
  fail "invalid digest fixture unexpectedly passed"
fi
rg -n "digest must match sha256 hex format" /tmp/product-director-invalid-digest.out >/dev/null \
  || fail "invalid digest fixture failed for the wrong reason"

if python3 "$VALIDATOR" --check-package "$INVALID_ROUTE_SIGNAL" >/tmp/product-director-invalid-signal.out 2>&1; then
  fail "invalid route signal fixture unexpectedly passed"
fi
rg -n "matched_signal is not declared in route policy" /tmp/product-director-invalid-signal.out >/dev/null \
  || fail "invalid route signal fixture failed for the wrong reason"

printf '[PASS] product-director real transcript dogfood\n'
