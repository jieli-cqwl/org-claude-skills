#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/7] bash syntax checks"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
bash -n "$ROOT/tests/test-install-smoke.sh"
bash -n "$ROOT/tests/test-install-systematic.sh"
bash -n "$ROOT/tests/test-runtime-integrity.sh"
bash -n "$ROOT/tests/test-single-source-layout.sh"


echo "[2/7] shellcheck"
shellcheck \
  "$ROOT/install.sh" \
  "$ROOT/uninstall.sh" \
  "$ROOT/tests/run-all.sh" \
  "$ROOT/tests/test-install-smoke.sh" \
  "$ROOT/tests/test-install-systematic.sh" \
  "$ROOT/tests/test-runtime-integrity.sh" \
  "$ROOT/tests/test-single-source-layout.sh" \
  "$ROOT/tools/validate-contracts.sh" \
  "$ROOT/tools/dev/validate-contracts.sh" \
  "$ROOT/tools/dev/probe-codex-hooks.sh" \
  "$ROOT/tools/install/generate-all-openai-yaml.sh" \
  "$ROOT/tools/github/apply-branch-protection.sh" \
  "$ROOT/tools/migration/retire-dot-claude.sh"


echo "[3/7] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"


echo "[4/7] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/7] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/7] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "[7/7] single-source layout test"
bash "$ROOT/tests/test-single-source-layout.sh"

echo "All tests passed"
