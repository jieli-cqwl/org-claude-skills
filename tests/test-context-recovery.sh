#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECOVER="$ROOT/tools/community/recover_context.py"
FIX="$ROOT/tests/fixtures/context-contract/recovery"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_json_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  grep -Fq "$pattern" "$file" || {
    cat "$file" >&2
    fail "$label"
  }
}

python3 "$RECOVER" --root "$FIX" >/tmp/context_recovery_candidates.json
assert_json_contains /tmp/context_recovery_candidates.json '"decision": "candidates"' "candidate listing decision missing"
assert_json_contains /tmp/context_recovery_candidates.json '"feature_path": "docs/feature--context--small"' "small-chain candidate missing"
assert_json_contains /tmp/context_recovery_candidates.json '"feature_path": "docs/feature--context--standard"' "standard-chain candidate missing"

python3 "$RECOVER" --root "$FIX" --feature docs/feature--context--small >/tmp/context_recovery_exact.json
assert_json_contains /tmp/context_recovery_exact.json '"decision": "recovered"' "exact recovery failed"
assert_json_contains /tmp/context_recovery_exact.json '"next_ref": "2026-04-25-demo/plan.md#T1"' "exact next_ref missing"

python3 "$RECOVER" --root "$FIX" --feature feature--context--standard >/tmp/context_recovery_basename.json
assert_json_contains /tmp/context_recovery_basename.json '"decision": "recovered"' "basename recovery failed"
assert_json_contains /tmp/context_recovery_basename.json '"mode": "standard-chain"' "standard-chain mode missing"

if python3 "$RECOVER" --root "$FIX" --feature context >/tmp/context_recovery_fuzzy.json 2>&1; then
  cat /tmp/context_recovery_fuzzy.json >&2
  fail "fuzzy match should require a choice"
fi
assert_json_contains /tmp/context_recovery_fuzzy.json '"reason": "fuzzy_candidates"' "fuzzy reason missing"

python3 "$RECOVER" --root "$FIX" --feature feature--context--legacy --archived >/tmp/context_recovery_archived.json
assert_json_contains /tmp/context_recovery_archived.json '"decision": "recovered"' "archived recovery failed"
assert_json_contains /tmp/context_recovery_archived.json '"archive_ref": "docs/archive/feature--context--legacy"' "archive ref missing"

python3 "$RECOVER" --root "$FIX" --feature feature--context--legacy >/tmp/context_recovery_legacy_miss.json
assert_json_contains /tmp/context_recovery_legacy_miss.json '"decision": "recovered"' "active miss legacy basename recovery failed"

if python3 "$RECOVER" --root "$FIX" --feature feature--context--small >/tmp/context_recovery_ambiguous.json 2>&1; then
  cat /tmp/context_recovery_ambiguous.json >&2
  fail "active plus archived basename should require a choice"
fi
assert_json_contains /tmp/context_recovery_ambiguous.json '"reason": "active_and_archived_match"' "active archived ambiguity missing"

cp -R "$FIX" "$TMP_DIR/bad-ref"
python3 - "$TMP_DIR/bad-ref/docs/feature--context--small/worklog.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("2026-04-25-demo/tasks.md#T1", "2026-04-25-demo/missing.md#T1"), encoding="utf-8")
PY
if python3 "$RECOVER" --root "$TMP_DIR/bad-ref" --feature docs/feature--context--small >/tmp/context_recovery_bad_ref.json 2>&1; then
  cat /tmp/context_recovery_bad_ref.json >&2
  fail "bad state ref should block recovery"
fi
assert_json_contains /tmp/context_recovery_bad_ref.json '"reason": "state_ref_unreachable"' "bad state ref reason missing"

python3 "$RECOVER" --root "$ROOT" --feature docs/feature--doc-governance--context-recovery >/tmp/context_recovery_real_pilot.json
assert_json_contains /tmp/context_recovery_real_pilot.json '"feature_path": "docs/feature--doc-governance--context-recovery"' "real pilot feature missing"
assert_json_contains /tmp/context_recovery_real_pilot.json '"decision": "recovered"' "real pilot should recover"
assert_json_contains /tmp/context_recovery_real_pilot.json '"state_ref": "2026-04-25-active-context-handoff-phase-1/verify-change-report.md"' "real pilot state_ref missing"
assert_json_contains /tmp/context_recovery_real_pilot.json '"next_ref": "2026-04-25-active-context-handoff-phase-1/verify-change-report.md"' "real pilot next_ref missing"

printf '[PASS] context recovery\n'
