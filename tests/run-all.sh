#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/32] bash syntax checks"
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
bash -n "$ROOT/tests/test-research-skill-contract.sh"
bash -n "$ROOT/tools/dev/probe-claude-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-capabilities.sh"
bash -n "$ROOT/tools/dev/probe-codex-hooks.sh"
bash -n "$ROOT/tools/dev/probe-runtime-capabilities.sh"
bash -n "$ROOT/tools/release/validate-release-metadata.sh"
bash -n "$ROOT/shared/skills/research/scripts/completion_check.sh"
python3 -m py_compile "$ROOT/tools/community/render_runtime_contract.py"

echo "[2/32] shellcheck"
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

echo "[3/32] contracts validation"
bash "$ROOT/tools/validate-contracts.sh"

echo "[4/32] install smoke test"
bash "$ROOT/tests/test-install-smoke.sh"

echo "[5/32] install systematic test"
bash "$ROOT/tests/test-install-systematic.sh"

echo "[6/32] install runtime audit test"
bash "$ROOT/tests/test-install-runtime-audit.sh"

echo "[7/32] runtime contract catalog test"
bash "$ROOT/tests/test-runtime-contract-catalog.sh"

echo "[8/32] runtime integrity test"
bash "$ROOT/tests/test-runtime-integrity.sh"

echo "[9/32] runtime reference activation test"
bash "$ROOT/tests/test-runtime-reference-activation.sh"

echo "[10/32] platform runtime noise test"
bash "$ROOT/tests/test-platform-runtime-noise.sh"

echo "[11/32] single-source layout test"
bash "$ROOT/tests/test-single-source-layout.sh"

echo "[12/32] codex skill adapter test"
bash "$ROOT/tests/test-codex-skill-adapter.sh"

echo "[13/32] review-fix redesign contract test"
bash "$ROOT/tests/test-review-fix-redesign-contract.sh"

echo "[14/32] review-fix redesign scenario test"
bash "$ROOT/tests/test-review-fix-redesign-scenarios.sh"

echo "[15/32] eval fixtures contract test"
bash "$ROOT/tests/test-eval-fixtures-contract.sh"

echo "[16/32] constraint closure contract test"
bash "$ROOT/tests/test-constraint-closure-contract.sh"

echo "[17/32] phase context resolution test"
bash "$ROOT/tests/test-phase-context-resolution.sh"

echo "[18/32] project-manager phase3 contract test"
bash "$ROOT/tests/test-project-manager-phase3-contract.sh"

echo "[19/32] skill output/gate contract test"
bash "$ROOT/tests/test-skill-output-and-gate-contract.sh"

echo "[20/32] research skill contract test"
bash "$ROOT/tests/test-research-skill-contract.sh"

echo "[21/32] doc reference integrity test"
bash "$ROOT/tests/test-doc-reference-integrity.sh"

echo "[22/32] reference graph hygiene test"
bash "$ROOT/tests/test-reference-graph-hygiene.sh"

echo "[23/32] community tools test"
bash "$ROOT/tests/test-community-tools.sh"

echo "[24/32] superpowers boundary test"
bash "$ROOT/tests/test-superpowers-boundary.sh"

echo "[25/32] small-chain boundary test"
bash "$ROOT/tests/test-small-chain-boundary.sh"

echo "[26/32] no CLI dependency test"
bash "$ROOT/tests/test-no-cli-dependency.sh"

echo "[27/32] chain completeness test"
bash "$ROOT/tests/test-chain-completeness.sh"

echo "[28/32] skill format unification test"
bash "$ROOT/tests/test-skill-format-unification.sh"

echo "[29/32] skill runtime noise test"
bash "$ROOT/tests/test-skill-runtime-noise.sh"

echo "[30/32] release metadata test"
bash "$ROOT/tests/test-release-metadata.sh"

echo "[31/32] skill context budget test"
bash "$ROOT/tests/test-skill-context-budget.sh"

echo "[32/32] product restructure residual scan"
bash "$ROOT/tests/test-product-restructure-residual.sh"

echo "All tests passed"
