#!/usr/bin/env bash
# 文件职责：验证 Skill 质量标准保持“标准尺子”职责，不回流成审计 SOP 或生命周期文件。
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/reference/Skill质量标准.md"
REFINER="$ROOT/shared/skills/skill-refiner/SKILL.md"
FLOW_RUBRIC="$ROOT/shared/skills/skill-refiner/references/rubrics/flow.md"
OUTPUT_RUBRIC="$ROOT/shared/skills/skill-refiner/references/rubrics/output.md"
SCAN_RULES="$ROOT/shared/skills/scan/references/skills-scan-rules.md"
SCAN_SKILL="$ROOT/shared/skills/scan/SKILL.md"

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

assert_count() {
  local expected="$1"
  local pattern="$2"
  local file="$3"
  local label="$4"
  local count
  count="$(grep -Ec "$pattern" "$file")"
  [ "$count" = "$expected" ] || fail "$label must be $expected, got $count"
}

test -f "$STANDARD" || fail "missing standard: $STANDARD"
test -f "$REFINER" || fail "missing skill-refiner: $REFINER"
test -f "$FLOW_RUBRIC" || fail "missing flow rubric: $FLOW_RUBRIC"
test -f "$OUTPUT_RUBRIC" || fail "missing output rubric: $OUTPUT_RUBRIC"
test -f "$SCAN_RULES" || fail "missing scan rules: $SCAN_RULES"
test -f "$SCAN_SKILL" || fail "missing scan skill: $SCAN_SKILL"
[ ! -f "$ROOT/shared/reference/Skill生命周期管理.md" ] || fail "lifecycle management standard must be removed"
[ ! -d "$ROOT/docs/skill-quality-standard-v2" ] || fail "obsolete skill quality standard design must be archived"
[ ! -d "$ROOT/docs/deep-research/2026-04-28-skill-quality-standard" ] \
  || fail "obsolete skill quality standard research must be archived"

assert_present '好的 Skill 让 AI 按真实职责流程办成事' "$STANDARD"
assert_present '真实职责优先' "$STANDARD"
assert_present '单一职责' "$STANDARD"
assert_present '渐进式披露' "$STANDARD"
assert_present '工程化分工' "$STANDARD"
assert_present '无消费者即噪音' "$STANDARD"
assert_present '旧资料只是证据' "$STANDARD"
assert_present '## 确定性校验' "$STANDARD"
assert_present '可枚举、可复验的判断必须落到脚本、schema、hook、gate 或测试' "$STANDARD"
assert_present '触发者、执行入口、执行时机、失败结果' "$STANDARD"
assert_present '| Skill 主流程 | 进入关键步骤前的输入、范围或依赖校验 |' "$STANDARD"
assert_present '| hooks 运行面 | 写入产物或会话收口后的自动 gate |' "$STANDARD"
assert_present 'bash shared/skills/developer/scripts/preflight_check.sh --phase-dir "$PHASE_DIR" --task-id "$TASK_ID"' "$STANDARD"
assert_present 'shared/hooks/registry.json` 的 developer entry 调用 `shared/skills/developer/scripts/completion_check.sh' "$STANDARD"
assert_present '确定性检查靠文字约束' "$STANDARD"
assert_present '输出字段不必要' "$STANDARD"

assert_count 3 '^\| G[0-9] \|' "$STANDARD" "gate count"
assert_count 8 '^\| S[0-9] \|' "$STANDARD" "runtime dimension count"
assert_count 5 '^\| E[0-9] \|' "$STANDARD" "evidence dimension count"

for item in \
  'G0 | Skill 本体存在' \
  'G1 | 运行入口可达' \
  'G2 | 关键材料可读' \
  'S1 | Discovery & Trigger' \
  'S2 | Task Contract' \
  'S3 | Professional Workflow' \
  'S4 | Resource Architecture' \
  'S5 | Runtime Fit & Safety' \
  'S6 | Artifact Contract' \
  'S7 | Verification Loop' \
  'S8 | Evolution & Integration' \
  'E1 | Baseline 对比' \
  'E5 | 反证样本' \
  'L0 | 不可审计' \
  'L4 | 可证明有效'; do
  assert_present "$item" "$STANDARD"
done

for forbidden in \
  '## Finding 规则' \
  '"priority": "P0|P1|P2|P3"' \
  '"runtime_target": "claude-code|codex|copilot|api|multi|repo-static"' \
  'WARN 累积规则' \
  '## 职责边界' \
  '本标准负责' \
  '本标准不负责' \
  '本文定义判断 Skill 质量的标准' \
  '标准是衡量“哪里有问题、为什么是问题、会怎样影响办事质量”的依据' \
  '不是审计流程、finding 格式、生命周期治理、hook 方案或脚本实现说明' \
  'Required Evidence' \
  'FAIL Conditions' \
  'PASS Conditions' \
  'False Positive Guard' \
  'retire_runbook' \
  'data flow disclosure' \
  'Trigger | 何时读取' \
  'Read | 读取哪个路径' \
  'Expect | 从中获得' \
  'Consume | 谁消费' \
  'Sync | 资源变化' \
  'lifecycle_state' \
  'Skill生命周期管理.md' \
  '| D1 |' \
  'D1-D8' \
  'D9 存在合理性' \
  'v2'; do
  assert_absent "$forbidden" "$STANDARD"
done

assert_present '先读取当前 `{{RUNTIME_HOME}}/reference/Skill质量标准.md`' "$REFINER"
assert_present '问题卡必须映射到 G0-G2、S1-S8 或 E1-E5' "$REFINER"
assert_present 'Flow 是真实办事流程，不是工件流水线' "$FLOW_RUBRIC"
assert_present 'AI 按这个流程能像该职责的熟练从业者一样把事办成' "$FLOW_RUBRIC"
assert_present '消费者明确' "$OUTPUT_RUBRIC"
assert_present '形状有真源' "$OUTPUT_RUBRIC"
assert_present '机器消费字段由 schema、template 或脚本承载' "$OUTPUT_RUBRIC"

for scan_rule in \
  'R0: 准入门禁（G0-G2）' \
  'R1: Discovery & Trigger（S1）' \
  'R2: Task Contract（S2）' \
  'R3: Professional Workflow（S3）' \
  'R4: Resource Architecture（S4）' \
  'R5: Runtime Fit & Safety（S5）' \
  'R6: Artifact Contract（S6）' \
  'R7: Verification Loop（S7）' \
  'R8: Evolution & Integration（S8）' \
  'R9: Behavioral Evidence（E1-E5）'; do
  assert_present "$scan_rule" "$SCAN_RULES"
done

assert_present 'static_pass' "$SCAN_RULES"
assert_present 'static_warn' "$SCAN_RULES"
assert_present 'static_fail' "$SCAN_RULES"
assert_present '不直接输出最终 L1/L2/L3/L4' "$SCAN_RULES"
assert_present 'runtime 可达性缺证据' "$SCAN_RULES"
assert_present '`allowed-tools` 语义误用' "$SCAN_RULES"
assert_present '外部内容信任策略缺失' "$SCAN_RULES"
assert_present '步骤产物缺消费者' "$SCAN_RULES"
assert_present 'proof command 表演' "$SCAN_RULES"
assert_present '最佳实践声明无 baseline' "$SCAN_RULES"
assert_present 'R0-R9 检测规则' "$SCAN_SKILL"
assert_absent 'R1-R8 检测规则' "$SCAN_SKILL"
assert_absent 'R1-R8' "$SCAN_RULES"
assert_absent '表达可审计与口径一致性（D8）' "$SCAN_RULES"

assert_present 'context budget is a warning-level health signal' "$ROOT/tests/test-skill-context-budget.sh"
assert_absent 'quality standard v2 type budgets' "$ROOT/tests/test-skill-context-budget.sh"

printf '[PASS] skill quality standard\n'
