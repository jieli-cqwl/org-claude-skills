#!/usr/bin/env bash
# File role: prove skill-refiner uses ring rubrics and sub agents without adding a second reviewer layer.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-refiner/SKILL.md"
RUBRIC_DIR="$ROOT/shared/skills/skill-refiner/references/rubrics"
FLOW_RUBRIC="$RUBRIC_DIR/flow.md"
INPUT_RUBRIC="$RUBRIC_DIR/input.md"
RESOURCE_RUBRIC="$RUBRIC_DIR/resource.md"
DETERMINISM_RUBRIC="$RUBRIC_DIR/determinism.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#"$ROOT"/}: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in ${file#"$ROOT"/}: $needle"
  fi
}

test -f "$SKILL" || fail "missing skill-refiner SKILL.md"

assert_present '主 agent 负责调度、上下文控制和验收' "$SKILL"
assert_present 'sub agent 负责' "$SKILL"
assert_present '最小上下文' "$SKILL"
assert_present '候选问题只是输入' "$SKILL"
assert_present '不接受把候选问题信号或 sub agent 自证直接当最终语义裁决' "$SKILL"
assert_present '## 环节标准循环' "$SKILL"
assert_present '| Flow | `flow.md` | 是否还原真实办事流程，让 AI 按这个流程把事办成。 |' "$SKILL"
assert_present 'references/examples/developer-optimization-case.md' "$SKILL"
assert_absent 'skill-harness' "$SKILL"
assert_absent 'check_skill_package_quality.py' "$SKILL"
assert_absent '## Sub Agent 审查队列' "$SKILL"
assert_absent 'references/reviewers/' "$SKILL"
assert_absent 'discover_refinement_candidates.py' "$SKILL"
assert_absent 'Flow：流程是否是专业实践 SOP，且每步有可消费输出。' "$SKILL"
assert_absent '只读质量审计、迁移审计或 finding 输出时，交给 `skill-harness`。' "$SKILL"

rubrics=(
  trigger
  responsibility
  input
  flow
  output
  resource
  determinism
  eval
  cleanup
  runtime
)

for rubric in "${rubrics[@]}"; do
  file="$RUBRIC_DIR/$rubric.md"
  test -f "$file" || fail "missing rubric: $file"
  for heading in '## Why' '## 目标' '## 裁决标准' '## 证据' '## 问题信号' '## 验收'; do
    assert_present "$heading" "$file"
  done
done

assert_present 'Flow 是真实办事流程，不是工件流水线' "$FLOW_RUBRIC"
assert_present 'AI 按这个流程能像该职责的熟练从业者一样把事办成' "$FLOW_RUBRIC"
assert_present '工件、字段、脚本和验证只支撑流程' "$FLOW_RUBRIC"
assert_present '图示无歧义' "$FLOW_RUBRIC"
assert_absent '从目标输入推进到可验证产物' "$FLOW_RUBRIC"

assert_present '定位可执行' "$INPUT_RUBRIC"
assert_present '写“默认从 X 接手/读取”，但没有说明 X 在哪里' "$INPUT_RUBRIC"
assert_present 'reference 结构化' "$RESOURCE_RUBRIC"
assert_present '`目标`、`输入`、`方法/流程`、`裁决/成功标准`、`证据输出`' "$RESOURCE_RUBRIC"
assert_present '参数明确' "$DETERMINISM_RUBRIC"
assert_present '命令包含 `$PHASE_DIR`、`$TASK_ID` 等参数' "$DETERMINISM_RUBRIC"

printf '[PASS] skill-refiner agent loop\n'
