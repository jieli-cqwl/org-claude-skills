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

assert_present '机器消费者需要阻断、比较、状态转移、发布判定或派生报告时，必须输出 JSON artifact，并以该 JSON 作为机器事实源。' "$SKILL_STANDARD"
assert_present '仅供人工阅读且无机器消费者时，输出结构化 Markdown；Markdown 和 HTML 必须声明派生来源，不反向成为机器事实源。' "$SKILL_STANDARD"
assert_present 'S5 或 S7 存在影响权限、安全、验证证据、数据流或完成门禁的 FAIL 时，评级最高只能为 L1' "$SKILL_STANDARD"
assert_present '缺少 E1-E5 经验数据时，最高只能评为 L2，不能宣称 L3/L4 或 retain' "$SKILL_STANDARD"
assert_absent '硬失败' "$SKILL_STANDARD"

assert_regex 'review_date.*不超过 90 天' "$SKILL_EFFECTIVENESS"
assert_present '记录必须包含 `retain`、`optimize` 或 `retire` 结论与证据引用' "$SKILL_EFFECTIVENESS"
assert_present '指标是裁决信号，不是有效性结论。' "$SKILL_EFFECTIVENESS"
assert_present '结论必须同时参考样本代表性、失败模式覆盖、上下文成本、评分理由和反证样本。' "$SKILL_EFFECTIVENESS"
assert_present '保真度是裁决信号，不是有效性结论。' "$SKILL_EFFECTIVENESS"
assert_present '结论还需参考样本代表性、用户意图冲突、误触发、上下文成本和反证样本。' "$SKILL_EFFECTIVENESS"
assert_present '关键失败模式改善、上下文成本可接受' "$SKILL_EFFECTIVENESS"
assert_present '本标准不是 `Skill质量标准.md` 的运行质量维度' "$SKILL_EFFECTIVENESS"
assert_present '有效性评估不替代运行质量审计' "$SKILL_EFFECTIVENESS"
assert_absent '最近一次 lifecycle-review.json' "$SKILL_EFFECTIVENESS"
assert_absent 'Skill 质量标准的 D9' "$SKILL_EFFECTIVENESS"
assert_absent 'D9 存在合理性' "$SKILL_EFFECTIVENESS"

printf '[PASS] reference decision rules\n'
