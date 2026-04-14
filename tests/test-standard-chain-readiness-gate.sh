#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-foundation/cutover"
PHASE_DIR="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
SCRIPT="$ROOT/tools/community/validate_standard_chain_readiness.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SCRIPT" ] || fail "missing readiness gate script"

python3 "$SCRIPT" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/dev/null \
  || fail "golden pilot should satisfy canonical readiness"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TMP_DIR/sample-feature"
rm -f "$TMP_DIR/sample-feature/brief.json"
if python3 "$SCRIPT" \
  --phase-dir "$TMP_DIR/sample-feature/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_missing_brief.out 2>&1; then
  cat /tmp/t6_missing_brief.out >&2
  fail "readiness gate should reject phase when feature brief.json is missing"
fi

cp "$ROOT/shared/runtime/standard-chain-catalog.json" "$TMP_DIR/bad-catalog.json"
python3 - "$TMP_DIR/bad-catalog.json" <<'PY'
import json
import sys
from pathlib import Path

catalog_path = Path(sys.argv[1])
payload = json.loads(catalog_path.read_text(encoding="utf-8"))
payload["artifacts"]["brief"]["default_path"] = "docs/{feature}/brief.md"
catalog_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$TMP_DIR/bad-catalog.json" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" >/tmp/t6_bad_catalog.out 2>&1; then
  cat /tmp/t6_bad_catalog.out >&2
  fail "readiness gate should reject catalog drift"
fi

python3 "$SCRIPT" \
  --fixture "$FIXTURE_ROOT/failed-cutover.json" \
  --expect-freeze-quarantine >/dev/null \
  || fail "failed cutover fixture should satisfy freeze + quarantine contract"

if python3 "$SCRIPT" --fixture "$FIXTURE_ROOT/illegal-rollback.json" >/tmp/t6_illegal_rollback.out 2>&1; then
  cat /tmp/t6_illegal_rollback.out >&2
  fail "readiness gate should reject illegal rollback"
fi

if python3 "$SCRIPT" --fixture "$FIXTURE_ROOT/mixed-mode.json" >/tmp/t6_mixed_mode.out 2>&1; then
  cat /tmp/t6_mixed_mode.out >&2
  fail "readiness gate should reject mixed mode fixture"
fi

if python3 "$SCRIPT" --fixture "$FIXTURE_ROOT/missing-green.json" >/tmp/t6_missing_green.out 2>&1; then
  cat /tmp/t6_missing_green.out >&2
  fail "readiness gate should reject missing validator green"
fi

echo "[PASS] standard chain readiness gate"
