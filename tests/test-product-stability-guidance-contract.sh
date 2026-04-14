#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

SKILL="$ROOT/shared/skills/product/SKILL.md"
TEMPLATE="$ROOT/shared/skills/product/references/templates/brief-template.md"
CHECKLIST="$ROOT/shared/skills/product/references/completeness-checklist.md"

test -f "$SKILL" || fail "missing product skill: $SKILL"
test -f "$TEMPLATE" || fail "missing product brief template: $TEMPLATE"
test -f "$CHECKLIST" || fail "missing product checklist: $CHECKLIST"

assert_present "不要同时保留 \`无前置约束（经评估）\`" "$SKILL"
assert_present "Review Round\` 只写 issue 首次出现轮次" "$SKILL"
assert_present "审查问题台账\` 不能留空" "$SKILL"
assert_present "用户裁决记录\` 只在 \`ASK_USER\` 或 \`BLOCKED\` 时填写" "$SKILL"
assert_present "确认时间\` 必须写真实确认时刻" "$SKILL"
assert_present "不要追加 \`CST\`、\`UTC\\+8\` 等时区后缀" "$SKILL"
assert_present "交付计划\` 必须保留 \`UNIT / 定义文件 / 工作区 / 状态\` 这 4 列" "$SKILL"
assert_present "工作区\` 必须使用 \`phase-\\{N\\}/unit-\\{M\\}/\` 格式" "$SKILL"
assert_present "当前基线" "$SKILL"
assert_present "目标值或方向" "$SKILL"
assert_present "观测窗口" "$SKILL"
assert_present "数据来源" "$SKILL"

assert_present "若已填写结构化约束表，就不要再保留上面这句声明" "$TEMPLATE"
assert_present "已关闭但仍想保留修订痕迹的内容，改写为 \`HIS-\\*\`" "$TEMPLATE"
assert_present "审查问题台账\` 不能留空；即使首轮全 PASS" "$TEMPLATE"
assert_present "首轮全 PASS 也必须补一轮 \`R2 / CONFIRMATION\`" "$TEMPLATE"
assert_present "未触发用户裁决时，只保留表头，不要写.*占位行" "$TEMPLATE"
assert_present "不要追加 \`CST\`、\`UTC\\+8\` 等时区后缀" "$TEMPLATE"
assert_present "UNIT 表必须保留 \`UNIT / 定义文件 / 工作区 / 状态\` 这 4 列" "$TEMPLATE"
assert_present "工作区\` 必须使用 \`phase-\\{N\\}/unit-\\{M\\}/\` 格式" "$TEMPLATE"
assert_present "度量类型" "$TEMPLATE"
assert_present "当前基线" "$TEMPLATE"
assert_present "目标值/方向" "$TEMPLATE"
assert_present "观测窗口" "$TEMPLATE"
assert_present "数据来源" "$TEMPLATE"
assert_present "观察型说明" "$TEMPLATE"
assert_present "替代观测信号" "$TEMPLATE"

assert_present "成功信号是否包含基线、目标值/方向、观测窗口和数据来源" "$CHECKLIST"
assert_present "观察型成功信号" "$CHECKLIST"

echo "[PASS] product stability guidance contract"
