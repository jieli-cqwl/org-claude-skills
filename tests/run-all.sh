#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/31] bash syntax checks"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
bash -n "$ROOT/tests/test-install-smoke.sh"
bash -n "$ROOT/tests/test-install-systematic.sh"
bash -n "$ROOT/tests/test-install-runtime-audit.sh"
bash -n "$ROOT/tests/test-runtime-contract-catalog.sh"
bash -n "$ROOT/tests/test-runtime-integrity.sh"
bash -n "$ROOT/tests/test-runtime-reference-activation.sh"
bash -n "$ROOT/tests/test-platform-runtime-noise.sh"
bash -n "$ROOT/tests/test-single-source-layout.sh"
bash -n "$ROOT/tests/test-codex-skill-adapter.sh"
bash -n "$ROOT/tests/test-review-fix-redesign-contract.sh"
bash -n "$ROOT/tests/test-review-fix-redesign-scenarios.sh"
bash -n "$ROOT/tests/test-eval-fixtures-contract.sh"
bash -n "$ROOT/tests/test-constraint-closure-contract.sh"
bash -n "$ROOT/tests/test-phase-context-resolution.sh"
bash -n "$ROOT/tests/test-project-manager-phase3-contract.sh"
bash -n "$ROOT/tests/test-skill-output-and-gate-contract.sh"
bash -n "$ROOT/tests/test-doc-reference-integrity.sh"
bash -n "$ROOT/tests/test-reference-graph-hygiene.sh"
bash -n "$ROOT/tests/test-community-tools.sh"
bash -n "$ROOT/tests/test-superpowers-boundary.sh"
bash -n "$ROOT/tests/test-small-chain-boundary.sh"
bash -n "$ROOT/tests/test-no-cli-dependency.sh"
bash -n "$ROOT/tests/test-chain-completeness.sh"
bash -n "$ROOT/tests/test-skill-format-unification.sh"
bash -n "$ROOT/tests/test-skill-context-budget.sh"
bash -n "$ROOT/tests/test-skill-runtime-noise.sh"
bash -n "$ROOT/tests/test-release-metadata.sh"
bash -n "$ROOT/tests/test-product-restructure-residual.sh"
bash -n "$ROOT/tools/dev/probe-claude-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-hooks.sh"
bash -n "$ROOT/tools/dev/probe-runtime-capabilities.sh"
bash -n "$ROOT/tools/release/validate-release-metadata.sh"
python3 -m py_compile "$ROOT/tools/community/render_runtime_contract.py"

echo "[2/31] shellcheck"
shellcheck -x \
  "$ROOT/install.sh" \
  "$ROOT/uninstall.sh" \
  "$ROOT/tests/run-all.sh" \
  "$ROOT/tests/test-install-smoke.sh" \
  "$ROOT/tests/test-install-systematic.sh" \
  "$ROOT/tests/test-install-runtime-audit.sh" \
  "$ROOT/tests/test-runtime-contract-catalog.sh" \
  "$ROOT/tests/test-runtime-integrity.sh" \
  "$ROOT/tests/test-runtime-reference-activation.sh" \
  "$ROOT/tests/test-platform-runtime-noise.sh" \
  "$ROOT/tests/test-single-source-layout.sh" \
  "$ROOT/tests/test-codex-skill-adapter.sh" \
  "$ROOT/tests/test-review-fix-redesign-contract.sh" \
  "$ROOT/tests/test-review-fix-redesign-scenarios.sh" \
  "$ROOT/tests/test-eval-fixtures-contract.sh" \
  "$ROOT/tests/test-constraint-closure-contract.sh" \
  "$ROOT/tests/test-phase-context-resolution.sh" \
  "$ROOT/tests/test-project-manager-phase3-contract.sh" \
  "$ROOT/tests/test-skill-output-and-gate-contract.sh" \
  "$ROOT/tests/test-doc-reference-integrity.sh" \
  "$ROOT/tests/test-reference-graph-hygiene.sh" \
  "$ROOT/tests/test-community-tools.sh" \
  "$ROOT/tests/test-superpowers-boundary.sh" \
  "$ROOT/tests/test-small-chain-boundary.sh" \
  "$ROOT/tests/test-no-cli-dependency.sh" \
  "$ROOT/tests/test-chain-completeness.sh" \
  "$ROOT/tests/test-skill-format-unification.sh" \
  "$ROOT/tests/test-skill-context-budget.sh" \
  "$ROOT/tests/test-skill-runtime-noise.sh" \
  "$ROOT/tests/test-release-metadata.sh" \
  "$ROOT/tests/test-product-restructure-residual.sh" \
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

echo "[3/31] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"

echo "[4/31] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/31] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/31] install runtime audit test"
bash "$ROOT/tests/test-install-runtime-audit.sh"

echo "[7/31] runtime contract catalog test"
bash "$ROOT/tests/test-runtime-contract-catalog.sh"

echo "[8/31] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "[9/31] runtime reference activation test"
bash "$ROOT/tests/test-runtime-reference-activation.sh"

echo "[10/31] platform runtime noise test"
bash "$ROOT/tests/test-platform-runtime-noise.sh"

echo "[11/31] single-source layout test"
bash "$ROOT/tests/test-single-source-layout.sh"

echo "[12/31] codex skill adapter test"
bash "$ROOT/tests/test-codex-skill-adapter.sh"

echo "[13/31] review-fix redesign contract test"
bash "$ROOT/tests/test-review-fix-redesign-contract.sh"

echo "[14/31] review-fix redesign scenario test"
bash "$ROOT/tests/test-review-fix-redesign-scenarios.sh"

echo "[15/31] eval fixtures contract test"
bash "$ROOT/tests/test-eval-fixtures-contract.sh"

echo "[16/31] constraint closure contract test"
bash "$ROOT/tests/test-constraint-closure-contract.sh"

echo "[17/31] phase context resolution test"
bash "$ROOT/tests/test-phase-context-resolution.sh"

echo "[18/31] project-manager phase3 contract test"
bash "$ROOT/tests/test-project-manager-phase3-contract.sh"

echo "[19/31] skill output/gate contract test"
bash "$ROOT/tests/test-skill-output-and-gate-contract.sh"

echo "[20/31] doc reference integrity test"
bash "$ROOT/tests/test-doc-reference-integrity.sh"

echo "[21/31] reference graph hygiene test"
bash "$ROOT/tests/test-reference-graph-hygiene.sh"

echo "[22/31] community tools test"
bash "$ROOT/tests/test-community-tools.sh"

echo "[23/31] superpowers boundary test"
bash "$ROOT/tests/test-superpowers-boundary.sh"

echo "[24/31] small-chain boundary test"
bash "$ROOT/tests/test-small-chain-boundary.sh"

echo "[25/31] no CLI dependency test"
bash "$ROOT/tests/test-no-cli-dependency.sh"

echo "[26/31] chain completeness test"
bash "$ROOT/tests/test-chain-completeness.sh"

echo "[27/31] skill format unification test"
bash "$ROOT/tests/test-skill-format-unification.sh"

echo "[28/31] skill runtime noise test"
bash "$ROOT/tests/test-skill-runtime-noise.sh"

echo "[29/31] release metadata test"
bash "$ROOT/tests/test-release-metadata.sh"

echo "[30/31] skill context budget test"
bash "$ROOT/tests/test-skill-context-budget.sh"

echo "[31/31] product restructure residual scan"
bash "$ROOT/tests/test-product-restructure-residual.sh"

echo "All tests passed"
