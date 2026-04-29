#!/usr/bin/env bash
# 文件职责：守住 reference 决策规则的高风险语义，防止旧坏味道回流。
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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

assert_regex() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing required pattern in $file: $pattern"
}

MCP="$ROOT/shared/reference/mcp-server开发.md"
COMPLETION="$ROOT/shared/reference/完成前验证.md"
DESIGN="$ROOT/shared/reference/设计原则.md"
TESTING="$ROOT/shared/reference/测试规范.md"
IMPACT="$ROOT/shared/reference/影响范围分析.md"
IMPACT_FORMAT="$ROOT/shared/reference/影响文件格式.md"
PERFORMANCE="$ROOT/shared/reference/性能效率.md"
TECH="$ROOT/shared/reference/技术选型.md"
SKILL_STANDARD="$ROOT/shared/reference/Skill质量标准.md"
SKILL_EFFECTIVENESS="$ROOT/shared/reference/Skill能力有效性标准.md"

assert_present 'readOnlyHint' "$MCP"
assert_present 'destructiveHint' "$MCP"
assert_present 'idempotentHint' "$MCP"
assert_present 'openWorldHint' "$MCP"
assert_absent 'readOnly/destructive/idempotent/openWorld' "$MCP"

assert_present '重新执行原复现步骤或回归测试，记录预期结果出现且原错误不再出现；日志仅作为辅助证据' "$COMPLETION"
assert_present '完成汇报前，列出本次适用的验证项；每项记录命令与通过证据，或记录不适用原因和替代验证。' "$COMPLETION"
assert_absent '日志/输出确认错误消失' "$COMPLETION"
assert_absent '任何一项没做' "$COMPLETION"

assert_present '用最小必要结构承载真实约束，并允许后续增删回退' "$DESIGN"
assert_present '删除自检：去掉该结构后，正常行为、异常/并发/回滚/恢复、安全/审计/合规/数据不变量仍可被验证证据证明 -> 优先削减；否则保留。' "$DESIGN"
assert_absent '业务需求仍能满足 -> Accidental' "$DESIGN"

assert_present '每个新增可观察行为都有先失败的测试；新增内部函数由对应行为、边界或错误路径测试覆盖，并在必要时说明覆盖关系' "$TESTING"
assert_absent '每个新函数都有测试' "$TESTING"

assert_present '代码符号、配置键、文档/规则条目、契约字段、脚本入口、数据表或 API 端点' "$IMPACT"
assert_present '仅表示文件范围无交集；确认接口、数据、配置和运行时依赖无共享写入后，可并行' "$IMPACT"
assert_present '写 `[]` 前必须已按影响范围分析检查代码符号、配置/数据流、运行时依赖、用户路径/业务不变量和搜索盲区' "$IMPACT_FORMAT"
assert_present '`[]` 只表示无额外文件或回归项，不表示跳过影响分析。' "$IMPACT_FORMAT"

assert_present '先用 profiling、日志或基准测试记录瓶颈与基线指标' "$PERFORMANCE"
assert_present '用同一场景对比命中率、延迟、内存、正确性回归和失效行为' "$PERFORMANCE"

assert_present '普通决策至少列 2 个候选；高影响低可逆决策列 3 个候选，少于 3 个时记录不可行原因' "$TECH"
assert_present '全局影响、低可逆或引入新技术栈时先向用户确认；仅在用户明确授权或当前流程无法等待人工输入时执行 AUTO_DECISION' "$TECH"

assert_present '好的 Skill 让 AI 按真实职责流程办成事' "$SKILL_STANDARD"
assert_present '无消费者即噪音' "$SKILL_STANDARD"
assert_present '确定性、可枚举、可复验的事项交给脚本、schema、hook、gate 或测试' "$SKILL_STANDARD"
assert_present '触发者、执行入口、执行时机、失败结果' "$SKILL_STANDARD"
assert_present 'bash shared/skills/developer/scripts/preflight_check.sh --phase-dir "$PHASE_DIR" --task-id "$TASK_ID"' "$SKILL_STANDARD"
assert_present 'shared/hooks/registry.json` 的 developer entry 调用 `shared/skills/developer/scripts/completion_check.sh' "$SKILL_STANDARD"
assert_present '机器消费的形状由 schema 或模板承载，正文不重复定义大段合同' "$SKILL_STANDARD"
assert_present '缺少效果信号时，质量等级停在 L2/L3' "$SKILL_STANDARD"
assert_absent '硬失败' "$SKILL_STANDARD"
assert_absent '## Finding 规则' "$SKILL_STANDARD"
assert_absent '## 职责边界' "$SKILL_STANDARD"
assert_absent '本标准不负责' "$SKILL_STANDARD"
assert_absent '本文定义判断 Skill 质量的标准' "$SKILL_STANDARD"
assert_absent '标准是衡量“哪里有问题、为什么是问题、会怎样影响办事质量”的依据' "$SKILL_STANDARD"
assert_absent '不是审计流程、finding 格式、生命周期治理、hook 方案或脚本实现说明' "$SKILL_STANDARD"
assert_absent 'Skill生命周期管理.md' "$SKILL_STANDARD"

assert_present 'Skill 会占用触发入口、上下文预算和维护成本' "$SKILL_EFFECTIVENESS"
assert_present '只有持续带来专业流程收益或稳定偏好收益的 Skill，才值得保留' "$SKILL_EFFECTIVENESS"
assert_present '一个 Skill 值得存在，看七项' "$SKILL_EFFECTIVENESS"
assert_present '价值来源明确' "$SKILL_EFFECTIVENESS"
assert_present '职责真实' "$SKILL_EFFECTIVENESS"
assert_present '偏好稳定' "$SKILL_EFFECTIVENESS"
assert_present '## 价值来源' "$SKILL_EFFECTIVENESS"
assert_present '专业流程' "$SKILL_EFFECTIVENESS"
assert_present '稳定偏好' "$SKILL_EFFECTIVENESS"
assert_present '## 证据路径' "$SKILL_EFFECTIVENESS"
assert_present '`eval-type` 是评测字段，不是 Skill 本体类型' "$SKILL_EFFECTIVENESS"
assert_present '价值方向成立但证据不足时，信号为 `optimize`；价值来源缺失或反证成立时，信号为 `retire`' "$SKILL_EFFECTIVENESS"
assert_present '价值独立' "$SKILL_EFFECTIVENESS"
assert_present '成本可接受' "$SKILL_EFFECTIVENESS"
assert_present '反证清楚' "$SKILL_EFFECTIVENESS"
assert_present '经验证据' "$SKILL_EFFECTIVENESS"
assert_present '反证证据' "$SKILL_EFFECTIVENESS"
assert_present '关键失败模式改善、上下文成本可接受' "$SKILL_EFFECTIVENESS"
assert_present '`retire` | 价值不足，进入移除讨论。' "$SKILL_EFFECTIVENESS"
assert_absent '一个 Skill 值得存在，至少应满足以下判断' "$SKILL_EFFECTIVENESS"
assert_absent '缺少这些证据时，结论为 `optimize`' "$SKILL_EFFECTIVENESS"
assert_absent '## Skill 类型' "$SKILL_EFFECTIVENESS"
assert_absent '## 职责边界' "$SKILL_EFFECTIVENESS"
assert_absent '本标准不负责' "$SKILL_EFFECTIVENESS"
assert_absent 'Skill生命周期管理.md' "$SKILL_EFFECTIVENESS"
assert_absent 'lifecycle_state":' "$SKILL_EFFECTIVENESS"
assert_absent 'Skill 质量标准的 D9' "$SKILL_EFFECTIVENESS"
assert_absent 'D9 存在合理性' "$SKILL_EFFECTIVENESS"

printf '[PASS] reference decision rules\n'
