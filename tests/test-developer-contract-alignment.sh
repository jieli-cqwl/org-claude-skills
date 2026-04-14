#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

PASS=0
FAIL=0

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  FAIL=$((FAIL + 1))
}

pass() {
  printf '[PASS] %s\n' "$*"
  PASS=$((PASS + 1))
}

assert_present() {
  local desc="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc — missing pattern '$pattern' in $file"
  fi
}

assert_absent() {
  local desc="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "$desc — unexpected pattern '$pattern' found in $file"
  else
    pass "$desc"
  fi
}

assert_non_git_gate_blocks_fake_sha() {
  local tmp_root report transcript payload stdout_file stderr_file output_file rc

  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/developer-gate.XXXXXX")"
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/developer-gate.stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/developer-gate.stderr.XXXXXX")"
  output_file="$(mktemp "${TMPDIR:-/tmp}/developer-gate.output.XXXXXX")"

  cleanup_non_git_gate_fixture() {
    rm -rf "$tmp_root" "$stdout_file" "$stderr_file" "$output_file"
  }
  trap cleanup_non_git_gate_fixture RETURN

  mkdir -p "$tmp_root/docs/demo"
  report="$tmp_root/docs/demo/developer-report-Task-1.md"
  transcript="$tmp_root/transcript.log"

  cat > "$report" <<'EOF'
# developer-report-Task-1.md

### TDD 记录
| AC | 测试描述 | RED 证据 | GREEN 证据 |
|----|---------|---------|-----------|
| AC-001 | 示例 | red | green |

### TDD 证据索引
| 阶段 | Commit SHA | 测试文件 | 结果 |
|------|-----------|---------|------|
| RED | abc1111 | tests/demo.test.ts | FAIL (expected) |
| GREEN | abc2222 | tests/demo.test.ts | PASS |

### 自测结果

#### 测试完备性审视
| 驱动源 | AC/用例 | 对应测试 | 覆盖状态 |
|--------|---------|---------|---------|
| AC 推导 | AC-001 | tests/demo.test.ts | COVERED |

> 缺口处理：无缺口

#### 全量测试回归
- 命令: `bash tests/demo.sh`
- 结果: 通过 1 / 失败 0 / 跳过 0

#### 静态分析
| 工具 | 命令 | 结果 |
|------|------|------|
| Lint | `echo lint` | PASS |
| 类型检查 | `echo type` | PASS |
| 构建 | `echo build` | PASS |

#### 功能集成冒烟
不适用——纯 fixture 报告

#### E2E 端到端
不适用——无前端链路

### 文件变更
| 文件 | 操作 | 涉及 AC | 在范围内 |
|------|------|---------|---------|
| src/demo.ts | 修改 | AC-001 | YES |

### 自审发现
| 维度 | 结果 | 备注 |
|------|------|------|
| AC 完整性 | PASS | ok |
| TDD 完整性 | PASS | ok |
| 自测证据 | PASS | ok |
| 范围合规 | PASS | ok |
| 代码规范 | PASS | ok |
| 报告完整性 | PASS | ok |
| 执行拆解遵循度 | PASS | ok |
EOF

  cat > "$transcript" <<'EOF'
Write docs/demo/developer-report-Task-1.md
EOF

  payload="$(jq -nc \
    --arg cwd "$tmp_root" \
    --arg sid "session-developer-nongit" \
    --arg tp "$transcript" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}')"

  if bash "$ROOT/shared/skills/developer/scripts/completion_check.sh" >"$stdout_file" 2>"$stderr_file" <<<"$payload"; then
    rc=0
  else
    rc=$?
  fi
  cat "$stdout_file" "$stderr_file" >"$output_file"

  if [ "$rc" -eq 0 ]; then
    fail "developer gate 在非 Git 环境不应接受伪造 Commit SHA"
    return
  fi

  if ! grep -Fq '"decision":"block"' "$stdout_file"; then
    fail "developer gate 非 Git 阻断时必须输出 block decision"
    return
  fi

  if ! rg -n '非 Git 环境|Commit SHA.*无法验证|可追溯的 Commit SHA' "$output_file" >/dev/null 2>&1; then
    fail "developer gate 非 Git 阻断信息必须明确说明 Commit SHA 无法验证"
    return
  fi

  pass "developer gate 在非 Git 环境阻断伪造 Commit SHA"
}

DEV_SKILL="$ROOT/shared/skills/developer/SKILL.md"
DEV_AGENT="$ROOT/shared/agents/developer.md"
DEV_SELF_TEST="$ROOT/shared/skills/developer/references/self-testing-methodology.md"
DEV_SELF_REVIEW="$ROOT/shared/skills/developer/references/self-review-methodology.md"
DEV_TEMPLATE="$ROOT/shared/skills/developer/references/templates/developer-report-template.md"

assert_present \
  "developer SKILL 规定 design.md 必须显式入文件范围" \
  'design\.md.*显式列入.*文件范围' \
  "$DEV_SKILL"

assert_present \
  "developer agent 同步 design.md 显式入范围口径" \
  'design\.md.*显式列入.*文件范围' \
  "$DEV_AGENT"

assert_present \
  "developer SKILL 对既有失败给出 BLOCKED 口径" \
  '既有失败.*BLOCKED' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 对既有失败给出部分完成口径" \
  '既有失败.*部分完成' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 仍要求全量测试 PASS 才能完成" \
  '全量测试 PASS' \
  "$DEV_SKILL"

assert_present \
  "self-testing 方法论对既有失败给出 BLOCKED 口径" \
  '既有失败.*BLOCKED' \
  "$DEV_SELF_TEST"

assert_present \
  "self-testing 方法论对既有失败给出部分完成口径" \
  '既有失败.*部分完成' \
  "$DEV_SELF_TEST"

assert_absent \
  "developer SKILL 不再残留 PM" \
  '(^|[^A-Za-z])PM([^A-Za-z]|$)|项目经理' \
  "$DEV_SKILL"

assert_absent \
  "developer agent 不再残留 PM" \
  '(^|[^A-Za-z])PM([^A-Za-z]|$)|项目经理' \
  "$DEV_AGENT"

assert_absent \
  "developer 模板不再残留 PM" \
  '(^|[^A-Za-z])PM([^A-Za-z]|$)|项目经理' \
  "$DEV_TEMPLATE"

assert_present \
  "developer 模板改为 delivery-owner/verify 引用说明" \
  'delivery-owner/verify' \
  "$DEV_TEMPLATE"

assert_present \
  "self-review 标题修正为 7 维度" \
  '^## 7 维度结构化自审$' \
  "$DEV_SELF_REVIEW"

assert_present \
  "developer 模板仍固定 Commit SHA 字段" \
  '^\| 阶段 \| Commit SHA \| 测试文件 \| 结果 \|$' \
  "$DEV_TEMPLATE"

assert_non_git_gate_blocks_fake_sha

printf '\n── Summary ──\n'
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
