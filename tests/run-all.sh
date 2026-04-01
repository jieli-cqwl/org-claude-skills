#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/23] bash syntax checks"
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
bash -n "$ROOT/tests/test-superpowers-boundary.sh"
bash -n "$ROOT/tests/test-small-chain-boundary.sh"
bash -n "$ROOT/tests/test-no-cli-dependency.sh"
bash -n "$ROOT/tests/test-chain-completeness.sh"
bash -n "$ROOT/tests/test-release-metadata.sh"
bash -n "$ROOT/tools/dev/probe-claude-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-hooks.sh"
bash -n "$ROOT/tools/dev/probe-runtime-capabilities.sh"
bash -n "$ROOT/tools/release/validate-release-metadata.sh"

echo "[2/23] shellcheck"
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
  "$ROOT/tests/test-superpowers-boundary.sh" \
  "$ROOT/tests/test-small-chain-boundary.sh" \
  "$ROOT/tests/test-no-cli-dependency.sh" \
  "$ROOT/tests/test-chain-completeness.sh" \
  "$ROOT/tests/test-release-metadata.sh" \
  "$ROOT/shared/skills/project-manager/scripts/phase3-grade-matrix.sh" \
  "$ROOT/tools/validate-contracts.sh" \
  "$ROOT/tools/dev/validate-contracts.sh" \
  "$ROOT/tools/dev/probe-claude-capabilities.sh" \
  "$ROOT/tools/dev/probe-codex-capabilities.sh" \
  "$ROOT/tools/dev/probe-codex-hooks.sh" \
  "$ROOT/tools/dev/probe-runtime-capabilities.sh" \
  "$ROOT/tools/install/generate-all-openai-yaml.sh" \
  "$ROOT/tools/github/apply-branch-protection.sh" \
  "$ROOT/tools/migration/retire-dot-claude.sh" \
  "$ROOT/tools/release/validate-release-metadata.sh"

echo "[3/23] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"

echo "[4/23] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/23] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/23] install runtime audit test"
bash "$ROOT/tests/test-install-runtime-audit.sh"

echo "[7/23] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "[8/23] platform runtime noise test"
bash "$ROOT/tests/test-platform-runtime-noise.sh"

echo "[9/23] single-source layout test"
bash "$ROOT/tests/test-single-source-layout.sh"

echo "[10/23] codex skill adapter test"
bash "$ROOT/tests/test-codex-skill-adapter.sh"

echo "[11/23] codex doc review repair test"
bash "$ROOT/tests/test-codex-doc-review-repair.sh"

echo "[12/23] codex doc review routing test"
bash "$ROOT/tests/test-codex-doc-review-routing.sh"

echo "[13/23] constraint closure contract test"
bash "$ROOT/tests/test-constraint-closure-contract.sh"

echo "[14/23] phase context resolution test"
bash "$ROOT/tests/test-phase-context-resolution.sh"

echo "[15/23] project-manager phase3 contract test"
bash "$ROOT/tests/test-project-manager-phase3-contract.sh"

echo "[16/23] skill output/gate contract test"
bash "$ROOT/tests/test-skill-output-and-gate-contract.sh"

echo "[17/23] doc reference integrity test"
bash "$ROOT/tests/test-doc-reference-integrity.sh"

echo "[18/23] community tools test"
bash "$ROOT/tests/test-community-tools.sh"

echo "[19/23] superpowers boundary test"
bash "$ROOT/tests/test-superpowers-boundary.sh"

echo "[20/23] small-chain boundary test"
bash "$ROOT/tests/test-small-chain-boundary.sh"

echo "[21/23] no CLI dependency test"
bash "$ROOT/tests/test-no-cli-dependency.sh"

echo "[22/23] chain completeness test"
bash "$ROOT/tests/test-chain-completeness.sh"

echo "[23/23] release metadata test"
bash "$ROOT/tests/test-release-metadata.sh"

echo "All tests passed"
