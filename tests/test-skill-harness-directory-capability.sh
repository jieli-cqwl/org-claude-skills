#!/usr/bin/env bash
# File role: prove retained skill-audit assets have machine-checkable ownership.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
DATA="$ROOT/tests/fixtures/skill-harness/legacy-assets/asset-ownership.json"
FIXTURES="$ROOT/tests/fixtures/skill-harness/legacy-assets"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-harness-directory-capability.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local label="$1"
  local expected="$2"
  shift 2
  local stdout_file
  local stderr_file
  stdout_file="$(mktemp "$TMP_DIR/stdout.XXXXXX")"
  stderr_file="$(mktemp "$TMP_DIR/stderr.XXXXXX")"
  set +e
  "$@" >"$stdout_file" 2>"$stderr_file"
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label unexpectedly passed"
  fi
  if ! grep -Fq "$expected" "$stdout_file" "$stderr_file"; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label did not report $expected"
  fi
}

[ -f "$DATA" ] || fail "missing asset-ownership.json"

python3 - "$DATA" <<'PY'
import json
import sys

required = {
    "audit-method",
    "runtime-noise-contract",
    "reference-contract",
    "permission-script-contract",
    "hook-adapter-contract",
    "subagent-handoff-contract",
    "field-consumers",
    "schemas",
    "evals",
    "examples",
    "templates-renderer",
    "optimization-plan",
    "verification-result",
    "old-runtime-entry",
    "old-agent-exposure",
    "permission-profiles",
    "source-map",
    "quality-dimension-mapping",
    "old-scripts-manifest",
    "old-audit-runner-scripts",
    "old-artifact-builders",
    "archive-readme-docs",
}

data = json.load(open(sys.argv[1], encoding="utf-8"))
actual = {row.get("asset_id") for row in data.get("assets", [])}
missing = sorted(required - actual)
if missing:
    raise SystemExit(f"missing asset ownership rows: {missing}")
print("[PASS] required legacy asset ids")
PY

python3 "$CHECKER" "$DATA"
expect_fail "missing target" "ASSET_OWNERSHIP_MISSING_TARGET" \
  python3 "$CHECKER" "$FIXTURES/invalid-missing-target.json"
expect_fail "duplicate source" "ASSET_OWNERSHIP_DUPLICATE_SOURCE" \
  python3 "$CHECKER" "$FIXTURES/invalid-duplicate-source.json"
expect_fail "duplicate asset id" "ASSET_OWNERSHIP_DUPLICATE_ASSET_ID" \
  python3 "$CHECKER" "$FIXTURES/invalid-duplicate-asset-id.json"
expect_fail "extra asset id" "ASSET_OWNERSHIP_UNKNOWN_ASSET_ID" \
  python3 "$CHECKER" "$FIXTURES/invalid-extra-asset-id.json"
expect_fail "immediate and triggered" "ASSET_OWNERSHIP_TARGET_MODE_CONFLICT" \
  python3 "$CHECKER" "$FIXTURES/invalid-immediate-and-triggered.json"

printf '[PASS] skill-harness directory capability\n'
