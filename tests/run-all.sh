#!/usr/bin/env bash
set -euo pipefail

# File responsibility: orchestrate repository validation suites for full release
# gates and faster local iteration without changing individual test semantics.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="full"
PROFILE=0
LIST_ONLY=0

usage() {
  cat <<'USAGE'
Usage:
  bash tests/run-all.sh [--full|--quick] [--profile] [--list]

Options:
  --full      Run the complete regression suite. This is the default.
  --quick     Skip full-only install safety/runtime/migration/cleanup scenarios for local iteration.
  --profile   Print elapsed seconds for each executed step.
  --list      Print the planned steps without executing them.
  -h, --help  Show this help text.
USAGE
}

fail() {
  printf '[run-all][ERROR] %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --full)
      MODE="full"
      shift
      ;;
    --quick)
      MODE="quick"
      shift
      ;;
    --profile)
      PROFILE=1
      shift
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

SYNTAX_SHELL_FILES=(
  "install.sh"
  "uninstall.sh"
  "tests/run-all.sh"
  "tests/lib/install-test-env.sh"
  "tests/test-install-core.sh"
  "tests/test-install-runtime-smoke.sh"
  "tests/test-install-safety.sh"
  "tests/test-install-runtime.sh"
  "tests/test-install-migration.sh"
  "tests/test-install-retired-skill-cleanup.sh"
  "tests/test-runtime-contract-catalog.sh"
  "tests/test-runtime-integrity.sh"
  "tests/test-runtime-reference-activation.sh"
  "tests/test-platform-runtime-noise.sh"
  "tests/test-single-source-layout.sh"
  "tests/test-codex-skill-adapter.sh"
  "tests/test-consistency-audit-canonical-agent.sh"
  "tests/test-run-all-runner-contract.sh"
  "tests/test-standard-chain-closure-contract.sh"
  "tests/test-standard-chain-co-creation-ledger-contract.sh"
  "tests/test-standard-chain-hard-gate-boundary-contract.sh"
  "tests/test-task-contract-consumer-alignment.sh"
  "tests/test-first-party-hard-gate-boundary-contract.sh"
  "tests/test-standard-chain-cutover.sh"
  "tests/test-standard-chain-feedback-thanks-pilot.sh"
  "tests/test-standard-chain-foundation-registry.sh"
  "tests/test-standard-chain-login-homepage-pilot.sh"
  "tests/test-standard-chain-pilot-audit.sh"
  "tests/test-standard-chain-local-eval-runner.sh"
  "tests/test-standard-chain-projection-replay.sh"
  "tests/test-standard-chain-readiness-gate.sh"
  "tests/test-standard-chain-runtime-state.sh"
  "tests/test-standard-chain-runtime-layering-contract.sh"
  "tests/test-standard-chain-skill-evals.sh"
  "tests/test-standard-chain-skill-structure.sh"
  "tests/test-standard-chain-user-decision.sh"
  "tests/test-standard-chain-validator-stack.sh"
  "tests/test-review-fix-redesign-contract.sh"
  "tests/test-review-fix-redesign-scenarios.sh"
  "tests/test-review-canonical-result-gate.sh"
  "tests/test-eval-fixtures-contract.sh"
  "tests/test-eval-summary-compat.sh"
  "tests/test-product-eval-contract.sh"
  "tests/test-product-stability-guidance-contract.sh"
  "tests/test-product-context-signal-quality.sh"
  "tests/test-product-manager-preflight-contract.sh"
  "tests/test-product-manager-dogfood-e2e.sh"
  "tests/test-constraint-closure-contract.sh"
  "tests/test-phase-context-resolution.sh"
  "tests/test-delivery-owner-sop-contract.sh"
  "tests/test-skill-output-and-gate-contract.sh"
  "tests/test-design-skill-governance-redesign.sh"
  "tests/test-test-design-clean-resource.sh"
  "tests/test-test-design-dogfood-flow.sh"
  "tests/test-design-dogfood-e2e.sh"
  "tests/test-verify-contract-alignment.sh"
  "tests/test-qa-browser-gate-contract.sh"
  "tests/test-review-convergence-gates.sh"
  "tests/test-doc-reference-integrity.sh"
  "tests/test-doc-management-rule-contract.sh"
  "tests/test-reference-graph-hygiene.sh"
  "tests/test-reference-decision-rules.sh"
  "tests/test-contract-grade-design-preflight.sh"
  "tests/test-community-tools.sh"
  "tests/test-superpowers-upstream-fidelity.sh"
  "tests/test-superpowers-boundary.sh"
  "tests/test-small-chain-boundary.sh"
  "tests/test-small-chain-closeout-automation.sh"
  "tests/test-active-doc-scope-lifecycle.sh"
  "tests/test-context-contract-validator.sh"
  "tests/test-context-contract-hook.sh"
  "tests/test-context-recovery.sh"
  "tests/test-context-contract-audit.sh"
  "tests/test-no-cli-dependency.sh"
  "tests/test-chain-completeness.sh"
  "tests/test-skill-format-unification.sh"
  "tests/test-skill-effectiveness-eval-framework.sh"
  "tests/test-skill-effectiveness-empirical-review.sh"
  "tests/test-developer-effectiveness-review-evals.sh"
  "tests/test-developer-runtime-proof-contract.sh"
  "tests/test-developer-runtime-failure-matrix.sh"
  "tests/test-developer-process-compliance-contract.sh"
  "tests/test-developer-real-flow-value-pilot.sh"
  "tests/test-skill-quality-standard.sh"
  "tests/test-shared-skill-package-quality-baseline.sh"
  "tests/test-skill-body-quality-static-audit.sh"
  "tests/test-skill-anti-noise-static-audit.sh"
  "tests/test-skill-quality-detection-fixtures.sh"
  "tests/test-skill-optimization-contracts.sh"
  "tests/test-skill-refiner-agent-loop.sh"
  "tests/test-skill-refiner-completion-gate.sh"
  "tests/test-skill-refiner-no-harness-dependency.sh"
  "tests/test-skill-refiner-effect-evidence.sh"
  "tests/test-skill-refiner-live-baseline-pilot.sh"
  "tests/test-skill-refiner-pre-f1-closure-gate.sh"
  "tests/test-skill-refiner-self-dogfood-flow.sh"
  "tests/test-skill-refiner-sr-s2-fielded-dogfood.sh"
  "tests/test-skill-refiner-tech-lead-shadow-flow.sh"
  "tests/test-skill-refiner-closure-audit.sh"
  "tests/test-skill-refiner-github-radar-external-practice.sh"
  "tests/test-skill-refiner-supersedes-drift-gate.sh"
  "tests/test-github-repo-radar-contract.sh"
  "tests/test-skill-context-budget.sh"
  "tests/test-skill-context-budget-expiry.sh"
  "tests/test-skill-runtime-noise.sh"
  "tests/test-release-metadata.sh"
  "tests/test-runtime-closeout-record.sh"
  "tests/test-product-restructure-residual.sh"
  "tests/test-community-skill-updater-contract.sh"
  "tests/test-research-skill-contract.sh"
  "tests/test-deep-research-skill-contract.sh"
  "tests/test-feishu-docs-skill-contract.sh"
  "tools/dev/probe-claude-capabilities.sh"
  "tools/dev/probe-codex-capabilities.sh"
  "tools/dev/probe-codex-hooks.sh"
  "tools/dev/probe-runtime-capabilities.sh"
  "tools/release/validate-release-metadata.sh"
  "shared/skills/research/scripts/completion_check.sh"
  "shared/skills/delivery-owner/scripts/completion_check.sh"
  "shared/skills/skill-refiner/scripts/completion_check.sh"
  "shared/skills/delivery-owner/scripts/intake_preflight_check.sh"
  "shared/skills/delivery-owner/scripts/task_packet_check.sh"
)

SHELLCHECK_FILES=(
  "${SYNTAX_SHELL_FILES[@]}"
  "tools/validate-contracts.sh"
  "tools/dev/validate-contracts.sh"
  "tools/install/generate-all-openai-yaml.sh"
  "tools/github/apply-branch-protection.sh"
  "tools/migration/retire-dot-claude.sh"
)

FULL_TESTS=(
  "tests/test-install-core.sh"
  "tests/test-install-runtime-smoke.sh"
  "tests/test-install-safety.sh"
  "tests/test-install-runtime.sh"
  "tests/test-install-migration.sh"
  "tests/test-install-retired-skill-cleanup.sh"
  "tests/test-runtime-contract-catalog.sh"
  "tests/test-runtime-integrity.sh"
  "tests/test-runtime-reference-activation.sh"
  "tests/test-platform-runtime-noise.sh"
  "tests/test-single-source-layout.sh"
  "tests/test-codex-skill-adapter.sh"
  "tests/test-consistency-audit-canonical-agent.sh"
  "tests/test-run-all-runner-contract.sh"
  "tests/test-review-fix-redesign-contract.sh"
  "tests/test-review-fix-redesign-scenarios.sh"
  "tests/test-review-canonical-result-gate.sh"
  "tests/test-eval-fixtures-contract.sh"
  "tests/test-eval-summary-compat.sh"
  "tests/test-product-eval-contract.sh"
  "tests/test-product-stability-guidance-contract.sh"
  "tests/test-product-context-signal-quality.sh"
  "tests/test-product-manager-preflight-contract.sh"
  "tests/test-product-manager-dogfood-e2e.sh"
  "tests/test-constraint-closure-contract.sh"
  "tests/test-phase-context-resolution.sh"
  "tests/test-delivery-owner-sop-contract.sh"
  "tests/test-skill-output-and-gate-contract.sh"
  "tests/test-design-skill-governance-redesign.sh"
  "tests/test-test-design-clean-resource.sh"
  "tests/test-test-design-dogfood-flow.sh"
  "tests/test-design-dogfood-e2e.sh"
  "tests/test-verify-contract-alignment.sh"
  "tests/test-qa-browser-gate-contract.sh"
  "tests/test-review-convergence-gates.sh"
  "tests/test-research-skill-contract.sh"
  "tests/test-deep-research-skill-contract.sh"
  "tests/test-deep-research-scripts.py"
  "tests/test-doc-reference-integrity.sh"
  "tests/test-doc-management-rule-contract.sh"
  "tests/test-reference-graph-hygiene.sh"
  "tests/test-reference-decision-rules.sh"
  "tests/test-contract-grade-design-preflight.sh"
  "tests/test-community-tools.sh"
  "tests/test-superpowers-upstream-fidelity.sh"
  "tests/test-superpowers-boundary.sh"
  "tests/test-small-chain-boundary.sh"
  "tests/test-small-chain-closeout-automation.sh"
  "tests/test-active-doc-scope-lifecycle.sh"
  "tests/test-context-contract-validator.sh"
  "tests/test-context-contract-hook.sh"
  "tests/test-context-recovery.sh"
  "tests/test-context-contract-audit.sh"
  "tests/test-no-cli-dependency.sh"
  "tests/test-chain-completeness.sh"
  "tests/test-skill-format-unification.sh"
  "tests/test-skill-effectiveness-eval-framework.sh"
  "tests/test-skill-effectiveness-empirical-review.sh"
  "tests/test-developer-effectiveness-review-evals.sh"
  "tests/test-developer-runtime-proof-contract.sh"
  "tests/test-developer-runtime-failure-matrix.sh"
  "tests/test-developer-process-compliance-contract.sh"
  "tests/test-developer-real-flow-value-pilot.sh"
  "tests/test-skill-quality-standard.sh"
  "tests/test-shared-skill-package-quality-baseline.sh"
  "tests/test-skill-body-quality-static-audit.sh"
  "tests/test-skill-anti-noise-static-audit.sh"
  "tests/test-skill-quality-detection-fixtures.sh"
  "tests/test-skill-optimization-contracts.sh"
  "tests/test-skill-refiner-agent-loop.sh"
  "tests/test-skill-refiner-completion-gate.sh"
  "tests/test-skill-refiner-no-harness-dependency.sh"
  "tests/test-skill-refiner-effect-evidence.sh"
  "tests/test-skill-refiner-live-baseline-pilot.sh"
  "tests/test-skill-refiner-pre-f1-closure-gate.sh"
  "tests/test-skill-refiner-self-dogfood-flow.sh"
  "tests/test-skill-refiner-sr-s2-fielded-dogfood.sh"
  "tests/test-skill-refiner-tech-lead-shadow-flow.sh"
  "tests/test-skill-refiner-closure-audit.sh"
  "tests/test-skill-refiner-github-radar-external-practice.sh"
  "tests/test-skill-refiner-supersedes-drift-gate.sh"
  "tests/test-github-repo-radar-contract.sh"
  "tests/test-skill-runtime-noise.sh"
  "tests/test-release-metadata.sh"
  "tests/test-runtime-closeout-record.sh"
  "tests/test-skill-context-budget.sh"
  "tests/test-skill-context-budget-expiry.sh"
  "tests/test-standard-chain-closure-contract.sh"
  "tests/test-standard-chain-co-creation-ledger-contract.sh"
  "tests/test-standard-chain-hard-gate-boundary-contract.sh"
  "tests/test-task-contract-consumer-alignment.sh"
  "tests/test-first-party-hard-gate-boundary-contract.sh"
  "tests/test-standard-chain-cutover.sh"
  "tests/test-standard-chain-feedback-thanks-pilot.sh"
  "tests/test-standard-chain-foundation-registry.sh"
  "tests/test-standard-chain-login-homepage-pilot.sh"
  "tests/test-standard-chain-pilot-audit.sh"
  "tests/test-standard-chain-local-eval-runner.sh"
  "tests/test-standard-chain-projection-replay.sh"
  "tests/test-standard-chain-readiness-gate.sh"
  "tests/test-standard-chain-runtime-state.sh"
  "tests/test-standard-chain-runtime-layering-contract.sh"
  "tests/test-standard-chain-skill-evals.sh"
  "tests/test-standard-chain-skill-structure.sh"
  "tests/test-standard-chain-user-decision.sh"
  "tests/test-standard-chain-validator-stack.sh"
  "tests/test-product-restructure-residual.sh"
  "tests/test-community-skill-updater-contract.sh"
  "tests/test-community-skill-updater-scripts.py"
  "tests/test-feishu-docs-skill-contract.sh"
)

PLAN_LABELS=()
PLAN_KINDS=()
PLAN_TARGETS=()
PLAN_DISPLAYS=()

add_step() {
  local label="$1"
  local kind="$2"
  local target="$3"
  local display="$4"

  PLAN_LABELS+=("$label")
  PLAN_KINDS+=("$kind")
  PLAN_TARGETS+=("$target")
  PLAN_DISPLAYS+=("$display")
}

is_full_only_test() {
  case "$1" in
    "tests/test-install-safety.sh"|"tests/test-install-runtime.sh"|"tests/test-install-migration.sh"|"tests/test-install-retired-skill-cleanup.sh")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_bash_syntax_checks() {
  local file

  for file in "${SYNTAX_SHELL_FILES[@]}"; do
    bash -n "$ROOT/$file"
  done
  python3 -m py_compile "$ROOT/tools/community/check_superpowers_upstream_fidelity.py"
  python3 -m py_compile "$ROOT/tools/community/validate_context_contract.py"
  python3 -m py_compile "$ROOT/tools/community/recover_context.py"
  python3 -m py_compile "$ROOT/tools/community/update_active_doc_scope.py"
  python3 -m py_compile "$ROOT/tools/community/small_chain_closeout.py"
  python3 -m py_compile "$ROOT/tools/community/validate_co_creation_ledger.py"
  python3 -m py_compile "$ROOT/shared/skills/product-manager/scripts/preflight_check.py"
  python3 -m py_compile "$ROOT/shared/skills/verify/scripts/preflight_check.py"
  python3 -m py_compile "$ROOT/shared/skills/skill-refiner/scripts/validate_refinement_result.py"
  python3 -m py_compile "$ROOT/shared/skills/skill-refiner/scripts/validate_effect_evidence.py"
}

run_shellcheck() {
  local files=()
  local file

  for file in "${SHELLCHECK_FILES[@]}"; do
    files+=("$ROOT/$file")
  done
  shellcheck -x "${files[@]}"
}

run_step_target() {
  local kind="$1"
  local target="$2"

  case "$kind" in
    function)
      "$target"
      ;;
    bash)
      bash "$ROOT/$target"
      ;;
    python)
      python3 "$ROOT/$target"
      ;;
    *)
      fail "unknown step kind: $kind"
      ;;
  esac
}

build_plan() {
  local test_file

  add_step "bash syntax checks" "function" "run_bash_syntax_checks" "bash -n selected shell files; python3 -m py_compile selected Python files"
  add_step "shellcheck" "function" "run_shellcheck" "shellcheck -x selected shell files"
  add_step "contracts validation" "bash" "tools/validate-contracts.sh" "bash $ROOT/tools/validate-contracts.sh"

  for test_file in "${FULL_TESTS[@]}"; do
    if [ "$MODE" = "quick" ] && is_full_only_test "$test_file"; then
      continue
    fi
    case "$test_file" in
      *.py)
        add_step "${test_file#tests/}" "python" "$test_file" "python3 $ROOT/$test_file"
        ;;
      *)
        add_step "${test_file#tests/}" "bash" "$test_file" "bash $ROOT/$test_file"
        ;;
    esac
  done
}

list_plan() {
  local total="${#PLAN_LABELS[@]}"
  local idx test_file excluded_count=0

  printf 'mode=%s\n' "$MODE"
  printf 'profile=%s\n' "$PROFILE"
  printf 'steps=%s\n' "$total"
  if [ "$MODE" = "quick" ]; then
    for test_file in "${FULL_TESTS[@]}"; do
      if is_full_only_test "$test_file"; then
        excluded_count=$((excluded_count + 1))
      fi
    done
    printf 'full_only_excluded=%s\n' "$excluded_count"
    for test_file in "${FULL_TESTS[@]}"; do
      if is_full_only_test "$test_file"; then
        printf 'excluded: %s\n' "$test_file"
      fi
    done
  fi
  for idx in "${!PLAN_LABELS[@]}"; do
    printf '[%s/%s] %s\n' "$((idx + 1))" "$total" "${PLAN_LABELS[$idx]}"
    printf '%s\n' "${PLAN_DISPLAYS[$idx]}"
  done
}

run_plan() {
  local total="${#PLAN_LABELS[@]}"
  local idx label kind target start end elapsed

  for idx in "${!PLAN_LABELS[@]}"; do
    label="${PLAN_LABELS[$idx]}"
    kind="${PLAN_KINDS[$idx]}"
    target="${PLAN_TARGETS[$idx]}"
    printf '[%s/%s] %s\n' "$((idx + 1))" "$total" "$label"

    if [ "$PROFILE" -eq 1 ]; then
      start="$(date +%s)"
      if run_step_target "$kind" "$target"; then
        end="$(date +%s)"
        elapsed="$((end - start))"
        printf '[profile] PASS %ss %s\n' "$elapsed" "$label"
      else
        end="$(date +%s)"
        elapsed="$((end - start))"
        printf '[profile] FAIL %ss %s\n' "$elapsed" "$label" >&2
        return 1
      fi
    else
      run_step_target "$kind" "$target"
    fi
  done
}

build_plan

if [ "$LIST_ONLY" -eq 1 ]; then
  list_plan
  exit 0
fi

run_plan
echo "All tests passed"
