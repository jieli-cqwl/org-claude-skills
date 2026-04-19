#!/usr/bin/env bash
# 文件职责：验证 Skill 质量标准、skill-harness 映射与 scan 静态规则保持一致。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/reference/Skill质量标准.md"
MAPPING="$ROOT/shared/skills/skill-harness/references/audit-method.md"
JSON_GATE="$ROOT/shared/skills/skill-harness/references/json-upgrade-gate.md"
SCAN_RULES="$ROOT/shared/skills/scan/references/skills-scan-rules.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in $file: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden legacy content in $file: $needle"
  fi
}

assert_dimension_count() {
  local count
  count="$(grep -Ec '^\| D[1-8] \|' "$STANDARD")"
  [ "$count" = "8" ] || fail "standard must define exactly 8 dimensions, got $count"
}

[ -f "$STANDARD" ] || fail "missing standard: $STANDARD"
[ -f "$MAPPING" ] || fail "missing skill-harness audit method: $MAPPING"
[ -f "$JSON_GATE" ] || fail "missing skill-harness JSON gate: $JSON_GATE"
[ -f "$SCAN_RULES" ] || fail "missing scan rules: $SCAN_RULES"
[ ! -d "$ROOT/docs/skill-quality-standard-v2" ] || fail "obsolete skill quality standard design must be archived"

assert_present 'Skill 质量标准' "$STANDARD"
assert_present 'Harness Engineering' "$STANDARD"
assert_present 'JSON artifact' "$STANDARD"
assert_present 'Markdown 和 HTML 是派生视图' "$STANDARD"
assert_dimension_count

for dimension in \
  'D1 | 触发与路由合同' \
  'D2 | 渐进加载与上下文预算' \
  'D3 | 输入输出与 artifact 合同' \
  'D4 | 执行安全与权限边界' \
  'D5 | 流程自治与异常控制' \
  'D6 | 验证与证据' \
  'D7 | 演化与兼容性' \
  'D8 | 人类可读与组织复用'; do
  assert_present "$dimension" "$STANDARD"
done

for resource in \
  "\`references/\`" \
  "\`examples/\`" \
  "\`rules/\`" \
  "\`schemas/\`" \
  "\`evals/\`" \
  "\`scripts/\`" \
  "\`templates/\`" \
  "\`hooks/\`" \
  "\`assets/\`"; do
  assert_present "$resource" "$STANDARD"
done

for contract_field in Trigger Read Expect Consume Evidence Sync; do
  assert_present "$contract_field" "$STANDARD"
done

assert_present 'manual-only 需要同时处理 Claude frontmatter 与 Codex adapter 移除' "$STANDARD"

assert_absent '| D6 Token 效率 | SKILL.md 精简，详情在 references/ |' "$STANDARD"
assert_absent '| D7 跨模型适配 | Skill 在不同模型下均可正确执行 |' "$STANDARD"

assert_present 'Trigger:' "$MAPPING"
assert_present 'Read:' "$MAPPING"
assert_present 'Expect:' "$MAPPING"
assert_present 'Consume:' "$MAPPING"
assert_present 'Evidence:' "$MAPPING"
assert_present 'Sync:' "$MAPPING"
assert_present 'Correctness' "$MAPPING"
assert_present 'Practice' "$MAPPING"
assert_present 'Proof Chain' "$MAPPING"
assert_absent 'Migration compatibility | D7 maintainability' "$MAPPING"
assert_absent 'Legacy Mapping' "$MAPPING"
assert_absent '旧 D1-D7' "$MAPPING"
assert_absent '迁移对照' "$MAPPING"
assert_absent '本表可删除' "$MAPPING"

for json_gate_field in consumer 'read purpose' validation 'drop condition'; do
  assert_present "$json_gate_field" "$JSON_GATE"
done

for scan_rule in \
  'R1: 触发与路由合同（D1）' \
  'R2: 渐进加载与上下文预算（D2）' \
  'R3: 输入输出与 artifact 合同（D3）' \
  'R4: 执行安全与权限边界（D4）' \
  'R5: 流程自治与异常控制（D5）' \
  'R6: 验证与证据（D6）' \
  'R7: 人类可读与组织复用（D8）' \
  'R8: 演化与兼容性（D7）'; do
  assert_present "$scan_rule" "$SCAN_RULES"
done
assert_present 'static_pass' "$SCAN_RULES"
assert_present 'static_warn' "$SCAN_RULES"
assert_present 'static_fail' "$SCAN_RULES"
assert_present '不直接输出最终 L1/L2/L3' "$SCAN_RULES"
assert_present 'external write API' "$SCAN_RULES"
assert_present '裸 Bash 写入风险' "$SCAN_RULES"
assert_present 'R1-R8 检测规则' "$ROOT/shared/skills/scan/SKILL.md"
assert_absent 'R1: 结构合规（D1）' "$SCAN_RULES"
assert_absent 'R1-R5 检测规则' "$ROOT/shared/skills/scan/SKILL.md"
assert_absent '结构合规/闭环自治/IO契约/角色/验证' "$ROOT/shared/skills/scan/SKILL.md"
assert_absent 'quality standard v2 type budgets' "$ROOT/tests/test-skill-context-budget.sh"

printf '[PASS] skill quality standard\n'
