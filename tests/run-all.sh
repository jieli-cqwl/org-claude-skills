#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/39] bash syntax checks"
bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"
bash -n "$ROOT/tests/test-install-smoke.sh"
bash -n "$ROOT/tests/test-install-retired-skill-cleanup.sh"
bash -n "$ROOT/tests/test-install-systematic.sh"
bash -n "$ROOT/tests/test-install-runtime-audit.sh"
bash -n "$ROOT/tests/test-runtime-contract-catalog.sh"
bash -n "$ROOT/tests/test-runtime-integrity.sh"
bash -n "$ROOT/tests/test-runtime-reference-activation.sh"
bash -n "$ROOT/tests/test-platform-runtime-noise.sh"
bash -n "$ROOT/tests/test-single-source-layout.sh"
bash -n "$ROOT/tests/test-codex-skill-adapter.sh"
bash -n "$ROOT/tests/test-consistency-audit-canonical-agent.sh"
bash -n "$ROOT/tests/test-review-fix-redesign-contract.sh"
bash -n "$ROOT/tests/test-review-fix-redesign-scenarios.sh"
bash -n "$ROOT/tests/test-eval-fixtures-contract.sh"
bash -n "$ROOT/tests/test-eval-summary-compat.sh"
bash -n "$ROOT/tests/test-product-eval-contract.sh"
bash -n "$ROOT/tests/test-product-stability-guidance-contract.sh"
bash -n "$ROOT/tests/test-product-context-signal-quality.sh"
bash -n "$ROOT/tests/test-constraint-closure-contract.sh"
bash -n "$ROOT/tests/test-phase-context-resolution.sh"
bash -n "$ROOT/tests/test-delivery-owner-gate-contract.sh"
bash -n "$ROOT/tests/test-skill-output-and-gate-contract.sh"
bash -n "$ROOT/tests/test-qa-browser-gate-contract.sh"
bash -n "$ROOT/tests/test-review-convergence-gates.sh"
bash -n "$ROOT/tests/test-doc-reference-integrity.sh"
bash -n "$ROOT/tests/test-reference-graph-hygiene.sh"
bash -n "$ROOT/tests/test-community-tools.sh"
bash -n "$ROOT/tests/test-superpowers-boundary.sh"
bash -n "$ROOT/tests/test-small-chain-boundary.sh"
bash -n "$ROOT/tests/test-no-cli-dependency.sh"
bash -n "$ROOT/tests/test-chain-completeness.sh"
bash -n "$ROOT/tests/test-skill-format-unification.sh"
bash -n "$ROOT/tests/test-skill-harness-contract.sh"
bash -n "$ROOT/tests/test-skill-harness-gates.sh"
bash -n "$ROOT/tests/test-skill-harness-migration.sh"
bash -n "$ROOT/tests/test-skill-context-budget.sh"
bash -n "$ROOT/tests/test-skill-runtime-noise.sh"
bash -n "$ROOT/tests/test-release-metadata.sh"
bash -n "$ROOT/tests/test-product-restructure-residual.sh"
bash -n "$ROOT/tests/test-research-skill-contract.sh"
bash -n "$ROOT/tests/test-deep-research-skill-contract.sh"
bash -n "$ROOT/tools/dev/probe-claude-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-hooks.sh"
bash -n "$ROOT/tools/dev/probe-runtime-capabilities.sh"
bash -n "$ROOT/tools/release/validate-release-metadata.sh"
bash -n "$ROOT/shared/skills/research/scripts/completion_check.sh"
python3 -m py_compile "$ROOT/tools/community/render_runtime_contract.py"

echo "[2/39] shellcheck"
shellcheck -x \
  "$ROOT/install.sh" \
  "$ROOT/uninstall.sh" \
  "$ROOT/tests/run-all.sh" \
  "$ROOT/tests/test-install-smoke.sh" \
  "$ROOT/tests/test-install-retired-skill-cleanup.sh" \
  "$ROOT/tests/test-install-systematic.sh" \
  "$ROOT/tests/test-install-runtime-audit.sh" \
  "$ROOT/tests/test-runtime-contract-catalog.sh" \
  "$ROOT/tests/test-runtime-integrity.sh" \
  "$ROOT/tests/test-runtime-reference-activation.sh" \
  "$ROOT/tests/test-platform-runtime-noise.sh" \
  "$ROOT/tests/test-single-source-layout.sh" \
  "$ROOT/tests/test-codex-skill-adapter.sh" \
  "$ROOT/tests/test-consistency-audit-canonical-agent.sh" \
  "$ROOT/tests/test-review-fix-redesign-contract.sh" \
  "$ROOT/tests/test-review-fix-redesign-scenarios.sh" \
  "$ROOT/tests/test-eval-fixtures-contract.sh" \
  "$ROOT/tests/test-eval-summary-compat.sh" \
  "$ROOT/tests/test-product-eval-contract.sh" \
  "$ROOT/tests/test-product-stability-guidance-contract.sh" \
  "$ROOT/tests/test-product-context-signal-quality.sh" \
  "$ROOT/tests/test-constraint-closure-contract.sh" \
  "$ROOT/tests/test-phase-context-resolution.sh" \
  "$ROOT/tests/test-delivery-owner-gate-contract.sh" \
  "$ROOT/tests/test-skill-output-and-gate-contract.sh" \
  "$ROOT/tests/test-qa-browser-gate-contract.sh" \
  "$ROOT/tests/test-review-convergence-gates.sh" \
  "$ROOT/tests/test-doc-reference-integrity.sh" \
  "$ROOT/tests/test-reference-graph-hygiene.sh" \
  "$ROOT/tests/test-community-tools.sh" \
  "$ROOT/tests/test-superpowers-boundary.sh" \
  "$ROOT/tests/test-small-chain-boundary.sh" \
  "$ROOT/tests/test-no-cli-dependency.sh" \
  "$ROOT/tests/test-chain-completeness.sh" \
  "$ROOT/tests/test-skill-format-unification.sh" \
  "$ROOT/tests/test-skill-harness-contract.sh" \
  "$ROOT/tests/test-skill-harness-gates.sh" \
  "$ROOT/tests/test-skill-harness-migration.sh" \
  "$ROOT/tests/test-skill-context-budget.sh" \
  "$ROOT/tests/test-skill-runtime-noise.sh" \
  "$ROOT/tests/test-release-metadata.sh" \
  "$ROOT/tests/test-product-restructure-residual.sh" \
  "$ROOT/tests/test-research-skill-contract.sh" \
  "$ROOT/tests/test-deep-research-skill-contract.sh" \
  "$ROOT/shared/skills/delivery-owner/scripts/delivery-gate-stages.sh" \
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

echo "[3/39] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"

echo "[4/39] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[4a/39] install retired skill cleanup test"
bash "$ROOT/tests/test-install-retired-skill-cleanup.sh"

echo "[5/39] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/39] install runtime audit test"
bash "$ROOT/tests/test-install-runtime-audit.sh"

echo "[7/39] runtime contract catalog test"
bash "$ROOT/tests/test-runtime-contract-catalog.sh"

echo "[8/39] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "[9/39] runtime reference activation test"
bash "$ROOT/tests/test-runtime-reference-activation.sh"

echo "[10/39] platform runtime noise test"
bash "$ROOT/tests/test-platform-runtime-noise.sh"

echo "[11/39] single-source layout test"
bash "$ROOT/tests/test-single-source-layout.sh"

echo "[12/39] codex skill adapter test"
bash "$ROOT/tests/test-codex-skill-adapter.sh"

echo "[12a/39] consistency-audit canonical agent contract test"
bash "$ROOT/tests/test-consistency-audit-canonical-agent.sh"

echo "[13/39] review-fix redesign contract test"
bash "$ROOT/tests/test-review-fix-redesign-contract.sh"

echo "[14/39] review-fix redesign scenario test"
bash "$ROOT/tests/test-review-fix-redesign-scenarios.sh"

echo "[15/39] eval fixtures contract test"
bash "$ROOT/tests/test-eval-fixtures-contract.sh"

echo "[16/39] eval summary compatibility test"
bash "$ROOT/tests/test-eval-summary-compat.sh"

echo "[17/39] product eval contract test"
bash "$ROOT/tests/test-product-eval-contract.sh"

echo "[18/39] product stability guidance contract test"
bash "$ROOT/tests/test-product-stability-guidance-contract.sh"

echo "[18a/39] product context signal quality contract test"
bash "$ROOT/tests/test-product-context-signal-quality.sh"

echo "[19/39] constraint closure contract test"
bash "$ROOT/tests/test-constraint-closure-contract.sh"

echo "[20/39] phase context resolution test"
bash "$ROOT/tests/test-phase-context-resolution.sh"

echo "[21/39] delivery-owner gate contract test"
bash "$ROOT/tests/test-delivery-owner-gate-contract.sh"

echo "[22/39] skill output/gate contract test"
bash "$ROOT/tests/test-skill-output-and-gate-contract.sh"

echo "[22a/39] qa browser gate contract test"
bash "$ROOT/tests/test-qa-browser-gate-contract.sh"

echo "[23/39] review convergence gate test"
bash "$ROOT/tests/test-review-convergence-gates.sh"

echo "[24/39] research skill contract test"
bash "$ROOT/tests/test-research-skill-contract.sh"

echo "[24a/39] deep research skill contract test"
bash "$ROOT/tests/test-deep-research-skill-contract.sh"

echo "[24b/39] deep research scripts test"
python3 "$ROOT/tests/test-deep-research-scripts.py"

echo "[25/39] doc reference integrity test"
bash "$ROOT/tests/test-doc-reference-integrity.sh"

echo "[26/39] reference graph hygiene test"
bash "$ROOT/tests/test-reference-graph-hygiene.sh"

echo "[27/39] community tools test"
bash "$ROOT/tests/test-community-tools.sh"

echo "[28/39] superpowers boundary test"
bash "$ROOT/tests/test-superpowers-boundary.sh"

echo "[29/39] small-chain boundary test"
bash "$ROOT/tests/test-small-chain-boundary.sh"

echo "[30/39] no CLI dependency test"
bash "$ROOT/tests/test-no-cli-dependency.sh"

echo "[31/39] chain completeness test"
bash "$ROOT/tests/test-chain-completeness.sh"

echo "[32/39] skill format unification test"
bash "$ROOT/tests/test-skill-format-unification.sh"

echo "[33/39] skill-harness contract test"
bash "$ROOT/tests/test-skill-harness-contract.sh"

echo "[34/39] skill-harness gates test"
bash "$ROOT/tests/test-skill-harness-gates.sh"

echo "[35/39] skill-harness migration test"
bash "$ROOT/tests/test-skill-harness-migration.sh"

echo "[36/39] skill runtime noise test"
bash "$ROOT/tests/test-skill-runtime-noise.sh"

echo "[37/39] release metadata test"
bash "$ROOT/tests/test-release-metadata.sh"

echo "[38/39] skill context budget test"
bash "$ROOT/tests/test-skill-context-budget.sh"

echo "[39/39] product restructure residual scan"
bash "$ROOT/tests/test-product-restructure-residual.sh"

echo "All tests passed"
