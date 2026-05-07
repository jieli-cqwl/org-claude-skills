#!/usr/bin/env bash
# File role: prove every skill-refiner dogfood transcript keeps SR-S2 as a minimum decision package.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOGFOOD_DIR="$ROOT/shared/skills/skill-refiner/evals/dogfood"
RUN_ALL="$ROOT/tests/run-all.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

extract_sr_s2() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
inside = False
for line in lines:
    if line.startswith("### SR-S2"):
        inside = True
        continue
    if inside and line.startswith("### "):
        break
    if inside:
        print(line)
PY
}

test -d "$DOGFOOD_DIR" || fail "missing dogfood dir: ${DOGFOOD_DIR#"$ROOT"/}"

found=0
while IFS= read -r transcript; do
  [ -n "$transcript" ] || continue
  found=$((found + 1))
  sr_s2_block="$(extract_sr_s2 "$transcript")"
  [ -n "$sr_s2_block" ] || fail "missing SR-S2 section in ${transcript#"$ROOT"/}"

  for label in \
    "已闭合事实：" \
    "推荐理解：" \
    "关键假设：" \
    "用户动作："; do
    grep -Fq "$label" <<<"$sr_s2_block" \
      || fail "SR-S2 missing user-facing label ${label} in ${transcript#"$ROOT"/}"
  done

  for forbidden in \
    "Current judgment:" \
    "Best-practice target:" \
    "入口基线确认卡" \
    "co_created_baseline" \
    "expected_outcome_signal:" \
    "real_scenario:" \
    "business_constraint:" \
    "observed_pain:" \
    "protected_capability_candidate:" \
    "entry_point_candidate:" \
    "located_carrier:" \
    "open_questions:" \
    "当前判断" \
    "最佳实践目标" \
    "候选策略" \
    "验证方式"; do
    if grep -Fq "$forbidden" <<<"$sr_s2_block"; then
      fail "SR-S2 contains forbidden label '$forbidden' in ${transcript#"$ROOT"/}"
    fi
  done

  if grep -Eq '因为|所以' <<<"$sr_s2_block"; then
    fail "SR-S2 should not infer cause with 因为/所以 in ${transcript#"$ROOT"/}"
  fi
done < <(find "$DOGFOOD_DIR" -name flow-transcript.md -print | sort)

[ "$found" -gt 0 ] || fail "no dogfood flow transcripts found"

run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-sr-s2-fielded-dogfood.sh' <<<"$run_all_list" \
  || fail "SR-S2 fielded dogfood test is not registered in tests/run-all.sh"

printf '[PASS] skill-refiner SR-S2 minimum decision package dogfood\n'
