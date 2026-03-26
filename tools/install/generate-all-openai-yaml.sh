#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_CODEX_SKILLS="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
DST_SKILLS="$ROOT/shared/skills"

success=0
fail=0
skip=0

for skill_dir in "$DST_SKILLS"/*; do
  [ -d "$skill_dir" ] || continue
  base="$(basename "$skill_dir")"
  [ "$base" = "lib" ] && continue
  skill="$base"

  if [ ! -f "$skill_dir/SKILL.md" ]; then
    echo "[SKIP] $skill: missing SKILL.md"
    skip=$((skip + 1))
    continue
  fi

  mkdir -p "$skill_dir/agents"

  if [ -f "$SRC_CODEX_SKILLS/$skill/agents/openai.yaml" ]; then
    cp "$SRC_CODEX_SKILLS/$skill/agents/openai.yaml" "$skill_dir/agents/openai.yaml"
    echo "[OK]   $skill -> agents/openai.yaml"
    success=$((success + 1))
  else
    echo "[FAIL] $skill: source missing $SRC_CODEX_SKILLS/$skill/agents/openai.yaml"
    fail=$((fail + 1))
  fi

done

printf '\n=== Summary ===\n'
echo "Success: $success"
echo "Failed:  $fail"
echo "Skipped: $skip"

[ "$fail" -eq 0 ]
