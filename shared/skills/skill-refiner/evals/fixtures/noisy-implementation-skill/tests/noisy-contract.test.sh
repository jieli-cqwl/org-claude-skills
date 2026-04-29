#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
SKILL="$ROOT/SKILL.md"

grep -q '流程合规输出合同' "$SKILL"
grep -q '主动探索' "$SKILL"
grep -q '前置条件' "$SKILL"
