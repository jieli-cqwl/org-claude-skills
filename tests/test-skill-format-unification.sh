#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

target_files=(
  "$ROOT/shared/skills/design/SKILL.md"
  "$ROOT/shared/skills/test-design/SKILL.md"
  "$ROOT/shared/skills/delivery-owner/SKILL.md"
)

for file in "${target_files[@]}"; do
  test -f "$file" || fail "missing file: ${file#"$ROOT"/}"

  if rg -n '```mermaid|graph TD|graph LR|flowchart' "$file" >/tmp/org_skill_format_mermaid.out 2>&1; then
    cat /tmp/org_skill_format_mermaid.out >&2
    fail "Mermaid syntax must be retired in: ${file#"$ROOT"/}"
  fi

  if awk '
      BEGIN { in_fence = 0; bad = 0 }
      /^```/ { in_fence = !in_fence; next }
      in_fence { next }
      /^[0-9]+\.[[:space:]]/ {
        if (length($0) >= 80) {
          bad = 1
          print NR ":" $0
        }
      }
      END {
        if (bad) {
          exit 0
        }
        exit 1
      }
    ' "$file" >/tmp/org_skill_format_numbered_long.out 2>&1; then
    cat /tmp/org_skill_format_numbered_long.out >&2
    fail "numbered step must use title + bullets, not one-line long sentence: ${file#"$ROOT"/}"
  fi

  total_lines="$(wc -l < "$file" | tr -d ' ')"
  bold_lines="$( { rg -n '\*\*' "$file" || true; } | wc -l | tr -d ' ' )"
  if ! awk -v total="$total_lines" -v bold="$bold_lines" 'BEGIN { if (total == 0) exit 1; exit !(bold / total <= 0.10) }'; then
    fail "bold line ratio exceeds 10% in: ${file#"$ROOT"/} (bold=$bold_lines, total=$total_lines)"
  fi
done

echo "[PASS] skill format unification"
