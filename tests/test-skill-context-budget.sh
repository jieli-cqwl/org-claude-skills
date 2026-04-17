#!/usr/bin/env bash
# Skill context budget checker
# Hard gate: SKILL.md line count follows Skill quality standard v2 type budgets.
# Soft signal: SKILL.md + references/ total lines stay within the context health budget.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$ROOT/shared/skills"
BUDGET=800

# Core skills to audit (alphabetical)
CORE_SKILLS=(
  design
  developer
  fix
  delivery-owner
  product
  qa
  review
  skill-optimizer
  tech-lead
  test-design
)

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
    review|skill-optimizer) printf '200' ;;
    design|delivery-owner|product|qa|tech-lead|test-design) printf '250' ;;
    *) printf '150' ;;
  esac
}

for skill in "${CORE_SKILLS[@]}"; do
  idx=$((idx + 1))
  skill_dir="$SKILLS_DIR/$skill"

  if [ ! -d "$skill_dir" ]; then
    if [ "$skill" = "skill-optimizer" ]; then
      fail "$skill directory missing from context budget audit"
    fi
    printf '[%d/%d] %s ... INFO (directory not found)\n' "$idx" "$total" "$skill"
    continue
  fi

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
    printf '[%d/%d] %s ... WARN (%d total lines, soft budget %d; SKILL.md %d/%d)\n' "$idx" "$total" "$skill" "$lines" "$BUDGET" "$skill_lines" "$skill_budget"
    warn_count=$((warn_count + 1))
  else
    printf '[%d/%d] %s ... PASS (%d total lines, soft budget %d; SKILL.md %d/%d)\n' "$idx" "$total" "$skill" "$lines" "$BUDGET" "$skill_lines" "$skill_budget"
  fi
done

if [ "$warn_count" -gt 0 ]; then
  printf '\n[WARN] %d/%d skills exceed context budget of %d lines\n' "$warn_count" "$total" "$BUDGET"
else
  printf '\n[PASS] all %d skills within context budget of %d lines\n' "$total" "$BUDGET"
fi
