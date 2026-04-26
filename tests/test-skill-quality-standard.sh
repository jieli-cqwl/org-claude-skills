#!/usr/bin/env bash
# 文件职责：验证 Skill 质量标准、skill-harness 映射与 scan 静态规则保持一致。
# shellcheck disable=SC2016
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
  count="$(grep -Ec '^\| D[1-9] \|' "$STANDARD")"
  [ "$count" = "8" ] || fail "standard must define exactly 8 dimensions, got $count"
}

[ -f "$STANDARD" ] || fail "missing standard: $STANDARD"
[ -f "$MAPPING" ] || fail "missing skill-harness audit method: $MAPPING"
[ -f "$JSON_GATE" ] || fail "missing skill-harness JSON gate: $JSON_GATE"
[ -f "$SCAN_RULES" ] || fail "missing scan rules: $SCAN_RULES"
[ ! -d "$ROOT/docs/skill-quality-standard-v2" ] || fail "obsolete skill quality standard design must be archived"

assert_present 'Skill 质量标准' "$STANDARD"
assert_present 'first-party Skill 质量裁决标准真源' "$STANDARD"
assert_present '本标准裁决 first-party Skill 的运行面质量' "$STANDARD"
assert_present 'PASS / FAIL / COMMENT' "$STANDARD"
assert_present '行数预算只能作为 COMMENT 或 warning-level signal' "$STANDARD"
assert_present 'JSON artifact' "$STANDARD"
assert_present '机器消费者需要阻断、比较、状态转移、发布判定或派生报告时，必须输出 JSON artifact' "$STANDARD"
assert_present '仅供人工阅读且无机器消费者时，输出结构化 Markdown' "$STANDARD"
assert_present 'Markdown 和 HTML 必须声明派生来源，不反向成为机器事实源' "$STANDARD"
assert_present '本体质量裁决模型' "$STANDARD"
assert_present 'Skill 本体质量裁决目标是判断 `SKILL.md` 能否稳定改变 agent 的执行行为' "$STANDARD"
assert_present '目标合同' "$STANDARD"
assert_present 'SOP 可执行性' "$STANDARD"
assert_present '指令精准度' "$STANDARD"
assert_present 'SMART 不是必写章节' "$STANDARD"
assert_absent '对审计、优化、验证、流转类 Skill，JSON artifact 是机器事实源' "$STANDARD"
assert_absent '行数基线：' "$STANDARD"
assert_absent 'Phase 1' "$STANDARD"
assert_absent 'MVP' "$STANDARD"
assert_absent 'readiness' "$STANDARD"
assert_absent 'proven-effectiveness' "$STANDARD"
assert_absent '本标准不裁决' "$STANDARD"
assert_absent '不裁决 retain' "$STANDARD"
assert_absent '不能被解释为有效性' "$STANDARD"
assert_absent '人类可读与组织复用' "$STANDARD"
assert_absent '人类如何理解、审查、复用和维护' "$STANDARD"
assert_absent '5/10/30' "$STANDARD"
assert_absent '学习成本' "$STANDARD"
assert_absent 'skill-harness 消费本标准' "$STANDARD"
assert_absent 'MVP quality concern' "$STANDARD"
assert_absent 'D9 readiness metadata' "$STANDARD"
assert_dimension_count

for dimension in \
  'D1 | 触发与路由合同' \
  'D2 | 渐进加载与上下文预算' \
  'D3 | 输入输出与 artifact 合同' \
  'D4 | 工具权限与执行边界' \
  'D5 | 流程自治与异常控制' \
  'D6 | 验证与证据' \
  'D7 | 演化与兼容性' \
  'D8 | 表达可审计与口径一致性'; do
  assert_present "$dimension" "$STANDARD"
done

assert_absent 'D9 | 存在合理性' "$STANDARD"
assert_absent '## D9 存在合理性' "$STANDARD"

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
assert_present 'D4 裁决 agent 在该 Skill 下可使用的工具权限' "$STANDARD"
assert_present '权限边界优先看 runtime 暴露给 agent 的工具能力' "$STANDARD"
assert_present '`allowed-tools` 与实际职责一致，且能解释每个非只读工具的必要性' "$STANDARD"
assert_present '`Edit`、`Write`、`MultiEdit`、外部写 API、commit、delete、migrate、deploy' "$STANDARD"
assert_present '`Bash` 默认按命令意图裁决' "$STANDARD"
assert_present '`Agent` 或 SubAgent 工具需要明确输入、输出、可写范围和接受标准' "$STANDARD"
assert_present '主体内容保留目标合同、主 SOP、关键分支、完成边界和必须先读的安全约束' "$STANDARD"
assert_present 'SOP 步骤使用可执行动词表达' "$STANDARD"
assert_present '多阶段、强分支、状态流转、handoff 或失败回退流程需要流程图、流程表或状态表' "$STANDARD"
assert_present '模糊指令必须绑定可观察判据、证据字段或终止条件' "$STANDARD"
assert_present '本体质量结论必须能回放到目标合同、SOP 步骤、资源加载证据、输出 artifact 或 eval 结果' "$STANDARD"
assert_present 'D8 裁决 Skill 文本、examples、报告模板和评审术语是否能被定位、复核和一致消费' "$STANDARD"
assert_present '主体表达优先服务执行路径：短句、命令式、少背景、少口号' "$STANDARD"
assert_present '术语、维度、评级、严重度和 finding 字段在标准、scan、optimizer、review 报告中一致' "$STANDARD"
assert_present '表达类 finding 只有在影响触发、加载、权限、输出、证据或裁决一致性时才升为 FAIL' "$STANDARD"

assert_absent '| D6 Token 效率 | SKILL.md 精简，详情在 references/ |' "$STANDARD"
assert_absent '| D7 跨模型适配 | Skill 在不同模型下均可正确执行 |' "$STANDARD"

assert_present 'Trigger:' "$MAPPING"
assert_present 'Read:' "$MAPPING"
assert_present 'Expect:' "$MAPPING"
assert_present 'Consume:' "$MAPPING"
assert_present 'Evidence:' "$MAPPING"
assert_present 'Sync:' "$MAPPING"
assert_present '质量裁决项' "$MAPPING"
assert_present 'Skill Body Quality Review' "$MAPPING"
assert_present 'Goal contract' "$MAPPING"
assert_present 'SOP executability' "$MAPPING"
assert_present 'Instruction precision' "$MAPPING"
assert_present 'Progressive loading' "$MAPPING"
assert_present 'Structured flow expression' "$MAPPING"
assert_present 'Correctness' "$MAPPING"
assert_present 'Practice' "$MAPPING"
assert_present 'Proof Chain' "$MAPPING"
assert_absent 'Migration compatibility | D7 maintainability' "$MAPPING"
assert_absent 'Legacy Mapping' "$MAPPING"
assert_absent '旧 D1-D7' "$MAPPING"
assert_absent '迁移对照' "$MAPPING"
assert_absent '本表可删除' "$MAPPING"
assert_absent 'Phase 1' "$MAPPING"
assert_absent 'MVP' "$MAPPING"
assert_absent 'D9 readiness' "$MAPPING"
assert_absent 'proven-effectiveness' "$MAPPING"

for json_gate_field in consumer 'read purpose' validation 'drop condition'; do
  assert_present "$json_gate_field" "$JSON_GATE"
done

for scan_rule in \
  'R1: 触发与路由合同（D1）' \
  'R2: 渐进加载与上下文预算（D2）' \
  'R3: 输入输出与 artifact 合同（D3）' \
  'R4: 工具权限与执行边界（D4）' \
  'R5: 流程自治与异常控制（D5）' \
  'R6: 验证与证据（D6）' \
  'R7: 演化与兼容性（D7）' \
  'R8: 表达可审计与口径一致性（D8）'; do
  assert_present "$scan_rule" "$SCAN_RULES"
done
assert_present 'static_pass' "$SCAN_RULES"
assert_present 'static_warn' "$SCAN_RULES"
assert_present 'static_fail' "$SCAN_RULES"
assert_present '不直接输出最终 L1/L2/L3' "$SCAN_RULES"
assert_present 'external write API' "$SCAN_RULES"
assert_present '裸 Bash 写入风险' "$SCAN_RULES"
assert_present '主体职责混杂' "$SCAN_RULES"
assert_present '渐进加载合同不完整' "$SCAN_RULES"
assert_present '目标合同缺失' "$SCAN_RULES"
assert_present 'SOP 动作不可定位' "$SCAN_RULES"
assert_present '复杂流程无结构化表达' "$SCAN_RULES"
assert_present '成功证据不可回放' "$SCAN_RULES"
assert_present '表达替代合同' "$SCAN_RULES"
assert_present '模糊指令无判据' "$SCAN_RULES"
assert_present 'R1-R8 检测规则' "$ROOT/shared/skills/scan/SKILL.md"
assert_present '表达口径' "$ROOT/shared/skills/scan/SKILL.md"
assert_present '行数预算超出 | 固定行数预算只产生 warning-level signal' "$SCAN_RULES"
assert_present 'context budget is a warning-level health signal' "$ROOT/tests/test-skill-context-budget.sh"
assert_absent '人类可读与组织复用' "$SCAN_RULES"
assert_absent '可读复用' "$ROOT/shared/skills/scan/SKILL.md"
assert_absent "按 \`Skill质量标准.md\` 的类型分档检查 \`SKILL.md\` 行数 | 严重" "$SCAN_RULES"
assert_absent 'R1: 结构合规（D1）' "$SCAN_RULES"
assert_absent 'R1-R5 检测规则' "$ROOT/shared/skills/scan/SKILL.md"
assert_absent '结构合规/闭环自治/IO契约/角色/验证' "$ROOT/shared/skills/scan/SKILL.md"
assert_absent 'quality standard v2 type budgets' "$ROOT/tests/test-skill-context-budget.sh"

printf '[PASS] skill quality standard\n'
