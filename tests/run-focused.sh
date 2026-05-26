#!/usr/bin/env bash
set -euo pipefail

# Run a focused validation slice for a changed skill or workflow area.
# Full release confidence still comes from tests/run-all.sh.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE=""
LIST_ONLY=0

PLAN_LABELS=()
PLAN_KINDS=()
PLAN_TARGETS=()
PLAN_DISPLAYS=()

usage() {
  cat <<'USAGE'
Usage:
  bash tests/run-focused.sh <profile> [--list]

Profiles:
  design    Design skill, design handoff, and standard-chain pilot checks.

Options:
  --list      Print the planned steps without executing them.
  -h, --help  Show this help text.
USAGE
}

fail() {
  printf '[run-focused][ERROR] %s\n' "$*" >&2
  exit 1
}

available_profiles() {
  printf 'design\n'
}

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

add_bash() {
  local target="$1"

  add_step "${target#tests/}" "bash" "$target" "bash $ROOT/$target"
}

add_python() {
  local target="$1"

  add_step "${target#tests/}" "python" "$target" "python3 $ROOT/$target"
}

build_design_plan() {
  add_bash "tests/test-skill-output-and-gate-contract.sh"
  add_bash "tests/test-design-skill-governance-redesign.sh"
  add_bash "tests/test-design-architect-capability-contract.sh"
  add_python "tests/test-design-architect-contract.py"
  add_bash "tests/test-design-dogfood-e2e.sh"
  add_bash "tests/test-stage2-design-package.sh"
  add_bash "tests/test-standard-chain-login-homepage-pilot.sh"
  add_bash "tests/test-standard-chain-feedback-thanks-pilot.sh"
}

build_plan() {
  case "$PROFILE" in
    design)
      build_design_plan
      ;;
    *)
      fail "unknown profile: $PROFILE. Available profiles: $(available_profiles | paste -sd ', ' -)"
      ;;
  esac
}

list_plan() {
  local total="${#PLAN_LABELS[@]}"
  local idx

  printf 'profile=%s\n' "$PROFILE"
  printf 'steps=%s\n' "$total"
  for idx in "${!PLAN_LABELS[@]}"; do
    printf '[%s/%s] %s\n' "$((idx + 1))" "$total" "${PLAN_LABELS[$idx]}"
    printf '%s\n' "${PLAN_DISPLAYS[$idx]}"
  done
}

run_step_target() {
  local kind="$1"
  local target="$2"

  case "$kind" in
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

run_plan() {
  local total="${#PLAN_LABELS[@]}"
  local idx label kind target

  for idx in "${!PLAN_LABELS[@]}"; do
    label="${PLAN_LABELS[$idx]}"
    kind="${PLAN_KINDS[$idx]}"
    target="${PLAN_TARGETS[$idx]}"
    printf '[%s/%s] %s\n' "$((idx + 1))" "$total" "$label"
    run_step_target "$kind" "$target"
  done
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --list)
      LIST_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      if [ -n "$PROFILE" ]; then
        fail "multiple profiles provided: $PROFILE and $1"
      fi
      PROFILE="$1"
      shift
      ;;
  esac
done

[ -n "$PROFILE" ] || fail "missing profile. Available profiles: $(available_profiles | paste -sd ', ' -)"

build_plan
if [ "$LIST_ONLY" -eq 1 ]; then
  list_plan
else
  run_plan
fi
