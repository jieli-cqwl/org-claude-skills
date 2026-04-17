#!/usr/bin/env bash
# 文件职责：验证 skill-optimizer 入口合同、触发边界和安装期引用边界。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/skill-optimizer"
SKILL_FILE="$SKILL_DIR/SKILL.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content present: $needle"
  fi
}

[ -f "$SKILL_FILE" ] || fail "missing skill-optimizer SKILL.md"

frontmatter="$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE")"

printf '%s\n' "$frontmatter" | grep -Fq 'name: skill-optimizer' || fail "frontmatter name must be skill-optimizer"
printf '%s\n' "$frontmatter" | grep -Fq 'Use when' || fail "description must include Use when trigger pattern"
printf '%s\n' "$frontmatter" | grep -Eq 'optimi[sz]e|audit|improv' || fail "description must mention optimize/audit/improve capability"
printf '%s\n' "$frontmatter" | grep -Fq 'allowed-tools:' || fail "allowed-tools must be explicit"
if printf '%s\n' "$frontmatter" | grep -Eq 'Write|Edit|MultiEdit'; then
  fail "audit entry must not grant write tools"
fi

assert_present '## HARD-GATE' "$SKILL_FILE"
assert_present '触发 → 加载 → 决策 → 执行 → 验证 → 演化' "$SKILL_FILE"
assert_present 'skill-creator' "$SKILL_FILE"
assert_present 'references/audit-method.md' "$SKILL_FILE"
assert_present 'references/reference-contract.md' "$SKILL_FILE"
assert_present 'references/permission-script-contract.md' "$SKILL_FILE"
assert_present 'references/subagent-handoff-contract.md' "$SKILL_FILE"
assert_present 'references/quality-dimension-mapping.md' "$SKILL_FILE"
assert_absent 'references/d1-d7-mapping.md' "$SKILL_FILE"
assert_present 'references/source-map.md' "$SKILL_FILE"
assert_present 'references/runtime-noise-contract.md' "$SKILL_FILE"
assert_present 'rules/permission-profiles.md' "$SKILL_FILE"
assert_present 'references/hook-adapter-contract.md' "$SKILL_FILE"
assert_present 'exact file scope' "$SKILL_FILE"
assert_present 'skill-audit.json' "$SKILL_FILE"
assert_present 'optimization-plan.json' "$SKILL_FILE"
assert_present 'verification-result.json' "$SKILL_FILE"
assert_absent 'docs/skill-optimizer/' "$SKILL_FILE"

required_references=(
  "$SKILL_DIR/references/audit-method.md"
  "$SKILL_DIR/references/reference-contract.md"
  "$SKILL_DIR/references/permission-script-contract.md"
  "$SKILL_DIR/references/subagent-handoff-contract.md"
  "$SKILL_DIR/references/quality-dimension-mapping.md"
  "$SKILL_DIR/references/runtime-noise-contract.md"
  "$SKILL_DIR/references/source-map.md"
)

for ref_file in "${required_references[@]}"; do
  [ -f "$ref_file" ] || fail "missing reference file: $ref_file"
  assert_present 'Trigger:' "$ref_file"
  assert_present 'Read:' "$ref_file"
  assert_present 'Expect:' "$ref_file"
  assert_present 'Consume:' "$ref_file"
  assert_present 'Evidence:' "$ref_file"
  assert_present 'Sync:' "$ref_file"
done

MAPPING_FILE="$SKILL_DIR/references/quality-dimension-mapping.md"
assert_present '{{RUNTIME_HOME}}/reference/Skill质量标准.md' "$MAPPING_FILE"
assert_absent 'shared/reference/Skill质量标准.md' "$MAPPING_FILE"
assert_absent 'Legacy Mapping' "$MAPPING_FILE"
assert_absent '旧 D1-D7' "$MAPPING_FILE"
assert_absent '迁移对照' "$MAPPING_FILE"
assert_absent '本表可删除' "$MAPPING_FILE"

NOISE_CONTRACT="$SKILL_DIR/references/runtime-noise-contract.md"
assert_present 'CURRENT_CONTRACT' "$NOISE_CONTRACT"
assert_present 'TEST_FIXTURE' "$NOISE_CONTRACT"
assert_present 'ARCHIVE_ONLY' "$NOISE_CONTRACT"
assert_present 'Who consumes it now?' "$NOISE_CONTRACT"
assert_present 'What runtime behavior changes?' "$NOISE_CONTRACT"
assert_present 'Which command proves it?' "$NOISE_CONTRACT"
assert_present 'Where is owner/exit condition?' "$NOISE_CONTRACT"
assert_present 'noise_class' "$NOISE_CONTRACT"
assert_present 'archive/delete' "$NOISE_CONTRACT"

for marker in C09 C10 C11 C12 C13 C14 C99 L O S; do
  assert_present "$marker" "$SKILL_DIR/references/source-map.md"
done

for keyword in "\$ARGUMENTS" '!command' 'Quick Reference' 'QUICKREF' 'INDEX' 'Push/Pull' 'skills marketplace' 'SLASH_COMMAND_TOOL_CHAR_BUDGET' 'full preload' 'pipeline' 'cross-platform' 'self-contained' 'namespace' 'monorepo' 'reuse'; do
  assert_present "$keyword" "$SKILL_DIR/references/source-map.md"
done

required_examples=(
  "$SKILL_DIR/examples/trigger-cases.md"
  "$SKILL_DIR/examples/reference-contract-cases.md"
  "$SKILL_DIR/examples/permission-cases.md"
  "$SKILL_DIR/examples/subagent-eval-cases.md"
)

for example_file in "${required_examples[@]}"; do
  [ -f "$example_file" ] || fail "missing example file: $example_file"
  assert_present 'Positive:' "$example_file"
  assert_present 'Negative:' "$example_file"
  assert_present 'Boundary:' "$example_file"
  assert_present 'Consumer:' "$example_file"
done

assert_present "\$ARGUMENTS" "$SKILL_DIR/examples/trigger-cases.md"
assert_present '!command' "$SKILL_DIR/examples/trigger-cases.md"
assert_present 'QUICKREF' "$SKILL_DIR/examples/reference-contract-cases.md"
assert_present 'INDEX' "$SKILL_DIR/examples/reference-contract-cases.md"
assert_present 'fork isolation' "$SKILL_DIR/examples/subagent-eval-cases.md"
assert_present 'pipeline handoff' "$SKILL_DIR/examples/subagent-eval-cases.md"

[ -f "$SKILL_DIR/rules/permission-profiles.md" ] || fail "missing permission profiles"
assert_present 'Consumer:' "$SKILL_DIR/rules/permission-profiles.md"
assert_present 'Global rules delta:' "$SKILL_DIR/rules/permission-profiles.md"
assert_present 'FORBIDDEN weaken global rules' "$SKILL_DIR/rules/permission-profiles.md"
assert_present 'edit/refactor/fix' "$SKILL_DIR/rules/permission-profiles.md"
assert_present 'current-session authorization' "$SKILL_DIR/rules/permission-profiles.md"

# Lock: both permission files must define the same five profiles
PERM_REF="$SKILL_DIR/references/permission-script-contract.md"
PERM_RULES="$SKILL_DIR/rules/permission-profiles.md"
for profile in 'audit/read' 'edit/refactor/fix' 'script/run' 'dangerous-action' 'hook/adapter'; do
  assert_present "$profile" "$PERM_REF"
  assert_present "$profile" "$PERM_RULES"
done
# Cross-reference: speed-ref must point to detailed rules
assert_present 'rules/permission-profiles.md' "$PERM_REF"

printf '[PASS] skill-optimizer contract\n'
