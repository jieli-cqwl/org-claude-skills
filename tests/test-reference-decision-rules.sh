#!/usr/bin/env bash
# 文件职责：验证 shared reference 的稳定资源边界，避免旧拆分文档和孤儿文档回流。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REFERENCE_DIR="$ROOT/shared/reference"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

required_references=(
  "协作判断.md"
  "code-comments.md"
  "code-structure-reuse.md"
  "error-handling.md"
  "全栈开发.md"
  "impact-analysis.md"
  "performance-and-efficiency.md"
  "测试规范.md"
  "constants-and-configuration.md"
  "系统调试.md"
  "技术方案设计.md"
)

retired_references=(
  "完成前验证.md"
  "completion-claims.md"
  "性能效率.md"
  "硬编码治理规范.md"
  "代码复用.md"
  "Skill生命周期管理.md"
  "Skill质量标准.md"
  "Skill能力有效性标准.md"
  "Skill标准.md"
  "技术选型.md"
  "agent-team-patterns.md"
  "mcp-server开发.md"
  "影响文件格式.md"
)

for reference in "${required_references[@]}"; do
  test -f "$REFERENCE_DIR/$reference" || fail "missing required reference: $reference"
done

for reference in "${retired_references[@]}"; do
  test ! -e "$REFERENCE_DIR/$reference" || fail "retired reference should not be active: $reference"
done

printf '[PASS] reference decision rules\n'
