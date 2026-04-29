#!/usr/bin/env bash
# 文件职责：验证 Skill 质量标准、skill-harness 映射与 scan 静态规则保持一致。
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/reference/Skill质量标准.md"
MAPPING="$ROOT/shared/skills/skill-harness/references/audit-method.md"
JSON_GATE="$ROOT/shared/skills/skill-harness/references/json-upgrade-gate.md"
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
test -f "$MAPPING" || fail "missing skill-harness audit method: $MAPPING"
test -f "$JSON_GATE" || fail "missing skill-harness JSON gate: $JSON_GATE"
test -f "$SCAN_RULES" || fail "missing scan rules: $SCAN_RULES"
test -f "$SCAN_SKILL" || fail "missing scan skill: $SCAN_SKILL"
[ ! -d "$ROOT/docs/skill-quality-standard-v2" ] || fail "obsolete skill quality standard design must be archived"
[ ! -d "$ROOT/docs/deep-research/2026-04-28-skill-quality-standard" ] \
  || fail "obsolete skill quality standard research must be archived"

assert_present 'Skill 质量标准' "$STANDARD"
assert_present 'first-party Skill 运行质量审计标准真源' "$STANDARD"
assert_present '不是指导作者写出“看起来完整”的 `SKILL.md`' "$STANDARD"
assert_present '能否在目标 runtime 中被发现、触发、执行、产出、验证' "$STANDARD"
assert_present 'Portable core' "$STANDARD"
assert_present 'First-party hardening' "$STANDARD"
assert_present 'Production evidence' "$STANDARD"
assert_present '禁止把 first-party hardening 冒充为跨生态官方最低标准' "$STANDARD"
assert_present '不保留旧维度对照表' "$STANDARD"
assert_present '机器消费者需要阻断、比较、状态转移、发布判定或派生报告时，必须输出 JSON artifact' "$STANDARD"
assert_present '仅供人工阅读且无机器消费者时，输出结构化 Markdown' "$STANDARD"
assert_present 'Markdown 和 HTML 必须声明派生来源，不反向成为机器事实源' "$STANDARD"
assert_present '"priority": "P0|P1|P2|P3"' "$STANDARD"
assert_present '"runtime_target": "claude-code|codex|copilot|api|multi|repo-static"' "$STANDARD"
assert_present 'JSON artifact 使用 `file_ref`；skill-harness Markdown/人工投影视图使用 `file:line`；field-consumers 使用 `file_line` 作为机器字段名' "$STANDARD"
assert_present '三者语义等同，均必须是单一 repo-local `path:line`' "$STANDARD"
assert_present 'WARN 累积规则' "$STANDARD"

assert_count 3 '^\| G[0-9] \|' "$STANDARD" "gate count"
assert_count 8 '^\| S[0-9] \|' "$STANDARD" "runtime dimension count"
assert_count 5 '^\| E[0-9] \|' "$STANDARD" "evidence dimension count"
assert_absent '| D1 |' "$STANDARD"
assert_absent 'D1-D8' "$STANDARD"
assert_absent 'D9 存在合理性' "$STANDARD"
assert_absent '过渡' "$STANDARD"
assert_absent 'v2' "$STANDARD"

for item in \
  'G0 | Skill 本体存在' \
  'G1 | 运行可达' \
  'G2 | 审计证据包完整' \
  'S1 | Discovery & Trigger' \
  'S2 | Task Contract' \
  'S3 | Execution Protocol' \
  'S4 | Resource Architecture' \
  'S5 | Runtime & Safety Boundary' \
  'S6 | Artifact Contract' \
  'S7 | Verification Loop' \
  'S8 | Evolution & Integration' \
  'E1 | Baseline 对比' \
  'E5 | 反证样本'; do
  assert_present "$item" "$STANDARD"
done

for step_field in step_id purpose input action output consumer acceptance failure_state next_step proof; do
  assert_present "$step_field" "$STANDARD"
done
assert_present 'freedom_level' "$STANDARD"

for resource in \
  "\`references/\`" \
  "\`resources/\`" \
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

assert_present 'S5 或 S7 存在影响权限、安全、验证证据、数据流或完成门禁的 FAIL 时，评级最高只能为 L1' "$STANDARD"
assert_present '缺少 E1-E5 经验数据时，最高只能评为 L2，不能宣称 L3/L4 或 retain' "$STANDARD"
assert_present '`allowed-tools` 只表示预授权/放行，不表示完整安全沙箱或 deny list' "$STANDARD"
assert_present '外部 URL、动态 fetch 或远程资源直接进入指令路径' "$STANDARD"
assert_present 'data flow disclosure' "$STANDARD"
assert_present 'retire_runbook' "$STANDARD"
assert_present 'L0 不可审计' "$STANDARD"
assert_present 'L4 生产级维护' "$STANDARD"

assert_present 'G0-G2 gate' "$MAPPING"
assert_present 'S1-S8 operating-quality item' "$MAPPING"
assert_present 'E1-E5 evidence item' "$MAPPING"
assert_present 'Gate readiness' "$MAPPING"
assert_present 'Discovery and trigger' "$MAPPING"
assert_present 'Execution protocol' "$MAPPING"
assert_present 'Runtime and safety boundary' "$MAPPING"
assert_present 'Multi-skill arbitration' "$MAPPING"
assert_present 'WARN accumulation' "$MAPPING"
assert_present 'Artifact contract' "$MAPPING"
assert_present 'Behavioral evidence' "$MAPPING"
assert_absent 'D1-D8' "$MAPPING"
assert_absent '旧 D1-D7' "$MAPPING"
assert_absent '迁移对照' "$MAPPING"

for json_gate_field in consumer 'read purpose' validation 'drop condition'; do
  assert_present "$json_gate_field" "$JSON_GATE"
done

for scan_rule in \
  'R0: 准入门禁（G0-G2）' \
  'R1: Discovery & Trigger（S1）' \
  'R2: Task Contract（S2）' \
  'R3: Execution Protocol（S3）' \
  'R4: Resource Architecture（S4）' \
  'R5: Runtime & Safety Boundary（S5）' \
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
assert_present '数据流声明缺失' "$SCAN_RULES"
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
