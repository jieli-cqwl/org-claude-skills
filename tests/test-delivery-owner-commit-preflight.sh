#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$ROOT/shared/skills/delivery-owner/scripts/commit_preflight_check.sh"
VALIDATOR="$ROOT/tools/community/validate_delivery_owner_commit_preflight.py"
SOURCE_FEATURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

init_repo() {
  local repo="$1"
  mkdir -p "$repo/docs"
  cp -R "$SOURCE_FEATURE" "$repo/docs/sample-feature"
  mkdir -p "$repo/src"
  printf 'baseline\n' >"$repo/src/allowed.txt"
  (
    cd "$repo"
    git init -q -b codex/test
    git config user.email "test@example.com"
    git config user.name "Test User"
    git add .
    git commit -q -m "baseline"
  )
}

run_preflight() {
  local repo="$1"
  shift
  bash "$WRAPPER" \
    --phase-dir "$repo/docs/sample-feature/phase-1" \
    --repo-root "$repo" \
    "$@"
}

test -f "$WRAPPER" || fail "missing delivery-owner commit preflight wrapper"
test -f "$VALIDATOR" || fail "missing delivery-owner commit preflight validator"
bash -n "$WRAPPER" || fail "commit preflight wrapper must pass bash syntax"
python3 -m py_compile "$VALIDATOR" || fail "commit preflight validator must compile"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/do-commit-preflight.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_REPO="$TMP_ROOT/pass"
init_repo "$PASS_REPO"
PASS_HEAD="$(git -C "$PASS_REPO" rev-parse HEAD)"
printf 'allowed change\n' >>"$PASS_REPO/src/allowed.txt"
run_preflight "$PASS_REPO" \
  --allowed-path src/allowed.txt \
  --expected-head "$PASS_HEAD" \
  --message "feat: delivery owner preflight" \
  --output "$PASS_REPO/docs/sample-feature/phase-1/commit-preflight.json" \
  >/tmp/do-commit-preflight-pass.out 2>&1 \
  || { cat /tmp/do-commit-preflight-pass.out >&2; fail "expected commit preflight to pass"; }
assert_present '"decision": "allow"' /tmp/do-commit-preflight-pass.out
assert_present '"src/allowed.txt"' "$PASS_REPO/docs/sample-feature/phase-1/commit-preflight.json"
assert_present '"signoff_ref"' "$PASS_REPO/docs/sample-feature/phase-1/commit-preflight.json"
assert_present '"user_decision_ref"' "$PASS_REPO/docs/sample-feature/phase-1/commit-preflight.json"

DRIFT_REPO="$TMP_ROOT/drift"
init_repo "$DRIFT_REPO"
DRIFT_HEAD="$(git -C "$DRIFT_REPO" rev-parse HEAD)"
printf 'allowed change\n' >>"$DRIFT_REPO/src/allowed.txt"
printf 'not signed off\n' >"$DRIFT_REPO/src/extra.txt"
if run_preflight "$DRIFT_REPO" \
  --allowed-path src/allowed.txt \
  --expected-head "$DRIFT_HEAD" \
  --message "feat: delivery owner preflight" \
  >/tmp/do-commit-preflight-drift.out 2>&1; then
  cat /tmp/do-commit-preflight-drift.out >&2
  fail "expected unauthorized worktree drift to fail"
fi
assert_present 'unauthorized changed path' /tmp/do-commit-preflight-drift.out
assert_present 'src/extra.txt' /tmp/do-commit-preflight-drift.out

HEAD_REPO="$TMP_ROOT/head"
init_repo "$HEAD_REPO"
OLD_HEAD="$(git -C "$HEAD_REPO" rev-parse HEAD)"
(
  cd "$HEAD_REPO"
  printf 'new baseline\n' >src/new-head.txt
  git add src/new-head.txt
  git commit -q -m "advance head"
)
printf 'allowed change\n' >>"$HEAD_REPO/src/allowed.txt"
if run_preflight "$HEAD_REPO" \
  --allowed-path src/allowed.txt \
  --expected-head "$OLD_HEAD" \
  --message "feat: delivery owner preflight" \
  >/tmp/do-commit-preflight-head.out 2>&1; then
  cat /tmp/do-commit-preflight-head.out >&2
  fail "expected HEAD drift to fail"
fi
assert_present 'HEAD drift' /tmp/do-commit-preflight-head.out

printf '[PASS] delivery-owner commit preflight\n'
