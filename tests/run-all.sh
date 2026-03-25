#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/5] bash syntax checks"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
bash -n "$ROOT/tests/test-install-smoke.sh"
bash -n "$ROOT/tests/test-install-systematic.sh"


echo "[2/5] shellcheck"
shellcheck \
  "$ROOT/install.sh" \
  "$ROOT/uninstall.sh" \
  "$ROOT/tests/run-all.sh" \
  "$ROOT/tests/test-install-smoke.sh" \
  "$ROOT/tests/test-install-systematic.sh" \
  "$ROOT/tools/validate-contracts.sh" \
  "$ROOT/tools/dev/validate-contracts.sh" \
  "$ROOT/tools/install/generate-all-openai-yaml.sh"


echo "[3/5] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"


echo "[4/5] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/5] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "All tests passed"
