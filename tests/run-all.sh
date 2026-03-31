#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/18] bash syntax checks"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
bash -n "$ROOT/tests/test-install-smoke.sh"
bash -n "$ROOT/tests/test-install-systematic.sh"
bash -n "$ROOT/tests/test-install-runtime-audit.sh"
bash -n "$ROOT/tests/test-runtime-integrity.sh"
bash -n "$ROOT/tests/test-platform-runtime-noise.sh"
bash -n "$ROOT/tests/test-single-source-layout.sh"
bash -n "$ROOT/tests/test-codex-skill-adapter.sh"
bash -n "$ROOT/tests/test-codex-doc-review-repair.sh"
bash -n "$ROOT/tests/test-codex-doc-review-routing.sh"
bash -n "$ROOT/tests/test-constraint-closure-contract.sh"
bash -n "$ROOT/tests/test-phase-context-resolution.sh"
bash -n "$ROOT/tests/test-project-manager-phase3-contract.sh"
bash -n "$ROOT/tests/test-skill-output-and-gate-contract.sh"
bash -n "$ROOT/tests/test-doc-reference-integrity.sh"
bash -n "$ROOT/tests/test-community-tools.sh"
bash -n "$ROOT/tools/dev/probe-claude-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-hooks.sh"
bash -n "$ROOT/tools/dev/probe-runtime-capabilities.sh"


echo "[2/18] shellcheck"
shellcheck -x \
  "$ROOT/install.sh" \
  "$ROOT/uninstall.sh" \
  "$ROOT/tests/run-all.sh" \
  "$ROOT/tests/test-install-smoke.sh" \
  "$ROOT/tests/test-install-systematic.sh" \
  "$ROOT/tests/test-install-runtime-audit.sh" \
  "$ROOT/tests/test-runtime-integrity.sh" \
  "$ROOT/tests/test-platform-runtime-noise.sh" \
  "$ROOT/tests/test-single-source-layout.sh" \
  "$ROOT/tests/test-codex-skill-adapter.sh" \
  "$ROOT/tests/test-codex-doc-review-repair.sh" \
  "$ROOT/tests/test-codex-doc-review-routing.sh" \
  "$ROOT/tests/test-constraint-closure-contract.sh" \
  "$ROOT/tests/test-phase-context-resolution.sh" \
  "$ROOT/tests/test-project-manager-phase3-contract.sh" \
  "$ROOT/tests/test-skill-output-and-gate-contract.sh" \
  "$ROOT/tests/test-doc-reference-integrity.sh" \
  "$ROOT/tests/test-community-tools.sh" \
  "$ROOT/shared/skills/project-manager/scripts/phase3-grade-matrix.sh" \
  "$ROOT/tools/validate-contracts.sh" \
  "$ROOT/tools/dev/validate-contracts.sh" \
  "$ROOT/tools/dev/probe-claude-capabilities.sh" \
  "$ROOT/tools/dev/probe-codex-capabilities.sh" \
  "$ROOT/tools/dev/probe-codex-hooks.sh" \
  "$ROOT/tools/dev/probe-runtime-capabilities.sh" \
  "$ROOT/tools/install/generate-all-openai-yaml.sh" \
  "$ROOT/tools/github/apply-branch-protection.sh" \
  "$ROOT/tools/migration/retire-dot-claude.sh"


echo "[3/18] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"


echo "[4/18] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/18] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/18] install runtime audit test"
bash "$ROOT/tests/test-install-runtime-audit.sh"

echo "[7/18] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "[8/18] platform runtime noise test"
bash "$ROOT/tests/test-platform-runtime-noise.sh"

echo "[9/18] single-source layout test"
bash "$ROOT/tests/test-single-source-layout.sh"

echo "[10/18] codex skill adapter test"
bash "$ROOT/tests/test-codex-skill-adapter.sh"

echo "[11/18] codex doc review repair test"
bash "$ROOT/tests/test-codex-doc-review-repair.sh"

echo "[12/18] codex doc review routing test"
bash "$ROOT/tests/test-codex-doc-review-routing.sh"

echo "[13/18] constraint closure contract test"
bash "$ROOT/tests/test-constraint-closure-contract.sh"

echo "[14/18] phase context resolution test"
bash "$ROOT/tests/test-phase-context-resolution.sh"

echo "[15/18] project-manager phase3 contract test"
bash "$ROOT/tests/test-project-manager-phase3-contract.sh"

echo "[16/18] skill output/gate contract test"
bash "$ROOT/tests/test-skill-output-and-gate-contract.sh"

echo "[17/18] doc reference integrity test"
bash "$ROOT/tests/test-doc-reference-integrity.sh"

echo "[18/18] community tools test"
bash "$ROOT/tests/test-community-tools.sh"

echo "All tests passed"
