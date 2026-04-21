#!/usr/bin/env bash
# Skill context budget checker
# Hard gate: SKILL.md line count follows Skill quality standard type budgets.
# Soft signal: SKILL.md + references/ total lines stay within the context health budget.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$ROOT/shared/skills"
CHAIN="$ROOT/contracts/skill-chain.yaml"
BUDGET=800

# Main standard-chain skills are the gate target; extra quality skills stay under the same budget signal.
STANDARD_CHAIN_SKILLS=()
while IFS= read -r skill; do
  STANDARD_CHAIN_SKILLS+=("$skill")
done < <(
  awk '
    /^  - name: / { name=$3 }
    /position: main/ { print name }
  ' "$CHAIN"
)

QUALITY_GATE_EXTRA_SKILLS=(
  fix
  skill-harness
)

CORE_SKILLS=("${STANDARD_CHAIN_SKILLS[@]}" "${QUALITY_GATE_EXTRA_SKILLS[@]}")

total=${#CORE_SKILLS[@]}
idx=0
warn_count=0

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

skill_line_budget() {
  case "$1" in
    developer|fix) printf '150' ;;
    review|verify|skill-harness) printf '200' ;;
    design|delivery-owner|product-director|product-manager|qa|tech-lead|test-design) printf '250' ;;
    *) printf '150' ;;
  esac
}

is_standard_chain_skill() {
  local candidate="$1" skill
  for skill in "${STANDARD_CHAIN_SKILLS[@]}"; do
    [ "$skill" = "$candidate" ] && return 0
  done
  return 1
}

context_budget_exception() {
  case "$1" in
    design)
      printf 'owner=standard-chain-structure-cleanup; expires=2026-05-15; reason=existing design references exceed soft budget pending extraction'
      ;;
    delivery-owner)
      printf 'owner=standard-chain-structure-cleanup; expires=2026-05-15; reason=delivery orchestration references exceed soft budget pending extraction'
      ;;
    tech-lead)
      printf 'owner=standard-chain-structure-cleanup; expires=2026-05-15; reason=planning references exceed soft budget pending extraction'
      ;;
    *)
      return 1
      ;;
  esac
}

[ "${#STANDARD_CHAIN_SKILLS[@]}" -eq 10 ] || fail "expected 10 standard-chain skills from $CHAIN, got ${#STANDARD_CHAIN_SKILLS[@]}"

for skill in "${CORE_SKILLS[@]}"; do
  idx=$((idx + 1))
  skill_dir="$SKILLS_DIR/$skill"

  [ -d "$skill_dir" ] || fail "$skill directory missing from context budget audit"

  lines=0
  skill_lines=0

  # Count SKILL.md
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill_lines="$(wc -l < "$skill_dir/SKILL.md" | tr -d ' ')"
    lines=$((lines + skill_lines))
  fi

  skill_budget="$(skill_line_budget "$skill")"
  if [ "$skill_lines" -gt "$skill_budget" ]; then
    fail "$skill SKILL.md line budget exceeded: $skill_lines > $skill_budget"
  fi

  # Count all files under references/
  if [ -d "$skill_dir/references" ]; then
    while IFS= read -r -d '' ref_file; do
      ref_lines="$(wc -l < "$ref_file" | tr -d ' ')"
      lines=$((lines + ref_lines))
    done < <(find "$skill_dir/references" -type f -print0)
  fi

  if [ "$lines" -gt "$BUDGET" ]; then
    if is_standard_chain_skill "$skill" && exception="$(context_budget_exception "$skill")"; then
      printf '[%d/%d] %s ... WARN_ALLOWED (%d total lines, soft budget %d; SKILL.md %d/%d; %s)\n' "$idx" "$total" "$skill" "$lines" "$BUDGET" "$skill_lines" "$skill_budget" "$exception"
      warn_count=$((warn_count + 1))
    elif is_standard_chain_skill "$skill"; then
      fail "$skill context budget exceeded without allowlist: $lines > $BUDGET"
    else
      printf '[%d/%d] %s ... WARN (%d total lines, soft budget %d; SKILL.md %d/%d)\n' "$idx" "$total" "$skill" "$lines" "$BUDGET" "$skill_lines" "$skill_budget"
      warn_count=$((warn_count + 1))
    fi
  else
    printf '[%d/%d] %s ... PASS (%d total lines, soft budget %d; SKILL.md %d/%d)\n' "$idx" "$total" "$skill" "$lines" "$BUDGET" "$skill_lines" "$skill_budget"
  fi
done

if [ "$warn_count" -gt 0 ]; then
  printf '\n[WARN] %d/%d skills exceed context budget of %d lines\n' "$warn_count" "$total" "$BUDGET"
else
  printf '\n[PASS] all %d skills within context budget of %d lines\n' "$total" "$BUDGET"
fi
