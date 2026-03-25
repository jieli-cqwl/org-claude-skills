#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/6] bash syntax checks"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
bash -n "$ROOT/tests/test-install-smoke.sh"
bash -n "$ROOT/tests/test-install-systematic.sh"
bash -n "$ROOT/tests/test-runtime-integrity.sh"


echo "[2/6] shellcheck"
shellcheck \
  "$ROOT/install.sh" \
  "$ROOT/uninstall.sh" \
  "$ROOT/tests/run-all.sh" \
  "$ROOT/tests/test-install-smoke.sh" \
  "$ROOT/tests/test-install-systematic.sh" \
  "$ROOT/tests/test-runtime-integrity.sh" \
  "$ROOT/tools/validate-contracts.sh" \
  "$ROOT/tools/dev/validate-contracts.sh" \
  "$ROOT/tools/install/generate-all-openai-yaml.sh" \
  "$ROOT/tools/github/apply-branch-protection.sh" \
  "$ROOT/tools/migration/retire-dot-claude.sh"


echo "[3/6] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"


echo "[4/6] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/6] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/6] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "All tests passed"
