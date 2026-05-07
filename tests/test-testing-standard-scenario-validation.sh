#!/usr/bin/env bash
# 文件职责：用代表性场景守住测试执行规范的有效性判断，防止规范退回知识清单。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/docs/2026-05-06-testing-standard-research/scenario-validation.md"
SPEC="$ROOT/shared/reference/测试规范.md"

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
    fail "forbidden content in $file: $needle"
  fi
}

test -f "$DOC" || fail "scenario validation doc missing: $DOC"

assert_present '验收结论：PASS' "$DOC"
assert_present '每个样本都能输出测试依据、测试义务、测试层级、交付证据和交付结论' "$DOC"

assert_present '## 样本 1：纯业务规则变更' "$DOC"
assert_present '纯业务规则、分支判断、边界计算和错误处理用单元测试证明' "$DOC"
assert_present '行覆盖率与分支覆盖率目标为 90% 以上' "$DOC"
assert_present '边界路径、失败路径、覆盖率和回归对象全部闭合后才能交付' "$DOC"

assert_present '## 样本 2：API + DB 变更' "$DOC"
assert_present '请求方法、路径、参数、鉴权、幂等、响应字段、状态码、错误结构和副作用结果' "$DOC"
assert_present '真实依赖、测试环境、本地容器或已验证集成路径证明' "$DOC"
assert_present 'Mock 不替代真实依赖验收' "$DOC"

assert_present '## 样本 3：UI 功能变更' "$DOC"
assert_present '键盘可操作、焦点可见、语义可识别、对比度合格和错误提示可感知' "$DOC"
assert_present '目标用户完成优惠码应用的主路径用最短真实流程或 E2E 证明' "$DOC"
assert_present '人工验收只在当前工具无法稳定复现时使用，并记录不自动化原因' "$DOC"

assert_present '## 样本 4：缺陷修复' "$DOC"
assert_present '原复现步骤或对应回归用例证明原错误结果不再出现' "$DOC"
assert_present '严重程度为 `S0 阻断` 或 `S1 严重`' "$DOC"
assert_present '优先级为 `P0 立即处理`' "$DOC"
assert_present '触发条件、实际结果、预期结果、影响范围、严重程度、优先级和复验方式' "$DOC"

assert_present '## 样本 5：性能 / 安全相关变更' "$DOC"
assert_present '记录变更前后指标或明确目标阈值' "$DOC"
assert_present '授权路径、拒绝路径、非法输入和敏感输出处理' "$DOC"
assert_present '性能基准、查询计划检查、安全用例、接口测试、覆盖率报告和真实依赖验证' "$DOC"

assert_present '每个样本都能从规范中推导出测试依据、测试义务、测试层级、交付证据和交付结论' "$DOC"
assert_absent '待补充' "$DOC"
assert_absent 'TODO' "$DOC"

assert_present '接到代码变更后，按顺序执行' "$SPEC"
assert_present '明确测试依据，生成测试义务，选择测试层级' "$SPEC"
assert_present '只有以下条件全部成立，才能汇报完成、上线或客户交付' "$SPEC"

printf '[PASS] testing standard scenario validation\n'
