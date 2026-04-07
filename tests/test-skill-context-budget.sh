#!/usr/bin/env bash
# Skill context budget checker
# Counts total lines of SKILL.md + references/ per skill.
# Soft budget: 800 lines. Exceeding emits [WARN] but does not fail the run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$ROOT/shared/skills"
BUDGET=800

# Core skills to audit (alphabetical)
CORE_SKILLS=(
  design
  developer
  fix
  new-skills
  product
  project-manager
  qa
  review
  tech-lead
  test-design
)

total=${#CORE_SKILLS[@]}
idx=0
warn_count=0

for skill in "${CORE_SKILLS[@]}"; do
  idx=$((idx + 1))
  skill_dir="$SKILLS_DIR/$skill"

  if [ ! -d "$skill_dir" ]; then
    printf '[%d/%d] %s ... SKIP (directory not found)\n' "$idx" "$total" "$skill"
    continue
  fi

  lines=0

  # Count SKILL.md
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill_lines="$(wc -l < "$skill_dir/SKILL.md" | tr -d ' ')"
    lines=$((lines + skill_lines))
  fi

  # Count all files under references/
  if [ -d "$skill_dir/references" ]; then
    while IFS= read -r -d '' ref_file; do
      ref_lines="$(wc -l < "$ref_file" | tr -d ' ')"
      lines=$((lines + ref_lines))
    done < <(find "$skill_dir/references" -type f -print0)
  fi

  if [ "$lines" -gt "$BUDGET" ]; then
    printf '[%d/%d] %s ... WARN (%d lines, budget %d)\n' "$idx" "$total" "$skill" "$lines" "$BUDGET"
    warn_count=$((warn_count + 1))
  else
    printf '[%d/%d] %s ... PASS (%d lines, budget %d)\n' "$idx" "$total" "$skill" "$lines" "$BUDGET"
  fi
done

if [ "$warn_count" -gt 0 ]; then
  printf '\n[WARN] %d/%d skills exceed context budget of %d lines\n' "$warn_count" "$total" "$BUDGET"
else
  printf '\n[PASS] all %d skills within context budget of %d lines\n' "$total" "$BUDGET"
fi
