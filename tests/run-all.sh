#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/36] bash syntax checks"
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
bash -n "$ROOT/tests/test-eval-summary-compat.sh"
bash -n "$ROOT/tests/test-product-eval-contract.sh"
bash -n "$ROOT/tests/test-product-stability-guidance-contract.sh"
bash -n "$ROOT/tests/test-constraint-closure-contract.sh"
bash -n "$ROOT/tests/test-phase-context-resolution.sh"
bash -n "$ROOT/tests/test-project-manager-phase3-contract.sh"
bash -n "$ROOT/tests/test-skill-output-and-gate-contract.sh"
bash -n "$ROOT/tests/test-review-convergence-gates.sh"
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
bash -n "$ROOT/tests/test-research-skill-contract.sh"
bash -n "$ROOT/tools/dev/probe-claude-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-hooks.sh"
bash -n "$ROOT/tools/dev/probe-runtime-capabilities.sh"
bash -n "$ROOT/tools/release/validate-release-metadata.sh"
bash -n "$ROOT/shared/skills/research/scripts/completion_check.sh"
python3 -m py_compile "$ROOT/tools/community/render_runtime_contract.py"

echo "[2/36] shellcheck"
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
  "$ROOT/tests/test-eval-summary-compat.sh" \
  "$ROOT/tests/test-product-eval-contract.sh" \
  "$ROOT/tests/test-product-stability-guidance-contract.sh" \
  "$ROOT/tests/test-constraint-closure-contract.sh" \
  "$ROOT/tests/test-phase-context-resolution.sh" \
  "$ROOT/tests/test-project-manager-phase3-contract.sh" \
  "$ROOT/tests/test-skill-output-and-gate-contract.sh" \
  "$ROOT/tests/test-review-convergence-gates.sh" \
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
  "$ROOT/tests/test-research-skill-contract.sh" \
  "$ROOT/shared/skills/project-manager/scripts/phase3-grade-matrix.sh" \
  "$ROOT/shared/skills/research/scripts/completion_check.sh" \
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

echo "[3/36] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"

echo "[4/35] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/35] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/35] install runtime audit test"
bash "$ROOT/tests/test-install-runtime-audit.sh"

echo "[7/35] runtime contract catalog test"
bash "$ROOT/tests/test-runtime-contract-catalog.sh"

echo "[8/35] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "[9/35] runtime reference activation test"
bash "$ROOT/tests/test-runtime-reference-activation.sh"

echo "[10/35] platform runtime noise test"
bash "$ROOT/tests/test-platform-runtime-noise.sh"

echo "[11/35] single-source layout test"
bash "$ROOT/tests/test-single-source-layout.sh"

echo "[12/35] codex skill adapter test"
bash "$ROOT/tests/test-codex-skill-adapter.sh"

echo "[13/35] review-fix redesign contract test"
bash "$ROOT/tests/test-review-fix-redesign-contract.sh"

echo "[14/35] review-fix redesign scenario test"
bash "$ROOT/tests/test-review-fix-redesign-scenarios.sh"

echo "[15/35] eval fixtures contract test"
bash "$ROOT/tests/test-eval-fixtures-contract.sh"

echo "[16/35] eval summary compatibility test"
bash "$ROOT/tests/test-eval-summary-compat.sh"

echo "[17/36] product eval contract test"
bash "$ROOT/tests/test-product-eval-contract.sh"

echo "[18/36] product stability guidance contract test"
bash "$ROOT/tests/test-product-stability-guidance-contract.sh"

echo "[19/36] constraint closure contract test"
bash "$ROOT/tests/test-constraint-closure-contract.sh"

echo "[20/36] phase context resolution test"
bash "$ROOT/tests/test-phase-context-resolution.sh"

echo "[21/36] project-manager phase3 contract test"
bash "$ROOT/tests/test-project-manager-phase3-contract.sh"

echo "[22/36] skill output/gate contract test"
bash "$ROOT/tests/test-skill-output-and-gate-contract.sh"

echo "[23/36] review convergence gate test"
bash "$ROOT/tests/test-review-convergence-gates.sh"

echo "[24/36] research skill contract test"
bash "$ROOT/tests/test-research-skill-contract.sh"

echo "[25/36] doc reference integrity test"
bash "$ROOT/tests/test-doc-reference-integrity.sh"

echo "[26/36] reference graph hygiene test"
bash "$ROOT/tests/test-reference-graph-hygiene.sh"

echo "[27/36] community tools test"
bash "$ROOT/tests/test-community-tools.sh"

echo "[28/36] superpowers boundary test"
bash "$ROOT/tests/test-superpowers-boundary.sh"

echo "[29/36] small-chain boundary test"
bash "$ROOT/tests/test-small-chain-boundary.sh"

echo "[30/36] no CLI dependency test"
bash "$ROOT/tests/test-no-cli-dependency.sh"

echo "[31/36] chain completeness test"
bash "$ROOT/tests/test-chain-completeness.sh"

echo "[32/36] skill format unification test"
bash "$ROOT/tests/test-skill-format-unification.sh"

echo "[33/36] skill runtime noise test"
bash "$ROOT/tests/test-skill-runtime-noise.sh"

echo "[34/36] release metadata test"
bash "$ROOT/tests/test-release-metadata.sh"

echo "[35/36] skill context budget test"
bash "$ROOT/tests/test-skill-context-budget.sh"

echo "[36/36] product restructure residual scan"
bash "$ROOT/tests/test-product-restructure-residual.sh"

echo "All tests passed"
