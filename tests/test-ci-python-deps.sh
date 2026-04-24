#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQUIREMENTS_FILE="$ROOT/.github/requirements-ci.txt"
TEST_WORKFLOW="$ROOT/.github/workflows/test.yml"
RELEASE_WORKFLOW="$ROOT/.github/workflows/release.yml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$REQUIREMENTS_FILE" || fail "missing CI Python requirements file"
test -s "$REQUIREMENTS_FILE" || fail "CI Python requirements file must not be empty"

for dep in pyyaml jsonschema referencing; do
  grep -Fxq "$dep" "$REQUIREMENTS_FILE" || fail "missing CI Python dependency: $dep"
done

for workflow in "$TEST_WORKFLOW" "$RELEASE_WORKFLOW"; do
  grep -Fq 'python -m pip install -r .github/requirements-ci.txt' "$workflow" \
    || fail "${workflow#"$ROOT"/} must install CI Python requirements from the shared file"
  if rg -n 'pip install .*pyyaml|pip install .*jsonschema|pip install .*referencing' "$workflow" >/dev/null; then
    fail "${workflow#"$ROOT"/} must not inline CI Python package names"
  fi
done

printf '[PASS] ci python dependencies single source\n'
