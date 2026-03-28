#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

cat >"$TMP_DIR/tasks.md" <<'EOF'
- [ ] T1 登录接口
- [ ] T2 登录页与本地会话
- [ ] T3 首页动画
EOF

cat >"$TMP_DIR/plan.md" <<'EOF'
# 示例计划

- [ ] [T1] 写失败测试
- [ ] [T1] 实现接口
- [ ] [T2] 实现登录页
- [ ] [T3] 实现首页动画
EOF

python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/plan.md" >/dev/null || fail "合法的 tasks/plan 映射不应失败"

cat >"$TMP_DIR/plan-missing-id.md" <<'EOF'
# 缺少 task id 的计划

- [ ] 写失败测试（无 task id）
EOF

if python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/plan-missing-id.md" >/tmp/org_plan_missing_id.out 2>&1; then
  cat /tmp/org_plan_missing_id.out >&2
  fail "缺少 task id 的 checklist 应失败"
fi

cat >"$TMP_DIR/bad-plan.md" <<'EOF'
# 错误计划

- [ ] [T1] 写失败测试
- [ ] [T9] 不存在的任务
EOF

if python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/bad-plan.md" >/tmp/org_bad_plan.out 2>&1; then
  cat /tmp/org_bad_plan.out >&2
  fail "非法 tasks/plan 映射应失败"
fi

cat >"$TMP_DIR/tasks-native.md" <<'EOF'
## 1. Setup
- [ ] 1.1 初始化模块
- [ ] 1.2 添加依赖
EOF

cat >"$TMP_DIR/plan-native.md" <<'EOF'
# OpenSpec 风格计划

- [ ] [1.1] 初始化模块
- [ ] [1.2] 添加依赖
EOF

python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks-native.md" \
  "$TMP_DIR/plan-native.md" >/dev/null || fail "OpenSpec 默认编号风格应通过一致性校验"

cat >"$TMP_DIR/bad-plan-native.md" <<'EOF'
# 错误计划

- [ ] [1.1] 初始化模块
- [ ] [9.9] 不存在的任务
EOF

if python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks-native.md" \
  "$TMP_DIR/bad-plan-native.md" >/tmp/org_bad_plan_native.out 2>&1; then
  cat /tmp/org_bad_plan_native.out >&2
  fail "非法 OpenSpec 编号映射应失败"
fi

cat >"$TMP_DIR/tasks-sync.md" <<'EOF'
- [x] 1.1 登录接口
EOF

cat >"$TMP_DIR/plan-sync-mismatch.md" <<'EOF'
# 状态不同步

- [x] [1.1] 编写测试
- [ ] [1.1] 实现接口
EOF

if python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks-sync.md" \
  "$TMP_DIR/plan-sync-mismatch.md" >/tmp/org_bad_sync.out 2>&1; then
  cat /tmp/org_bad_sync.out >&2
  fail "tasks/plan 状态不同步应失败"
fi

skill_checker="$ROOT/community/openspec/skills/openspec-verify-change/scripts/check_task_plan_consistency.py"
[ -f "$skill_checker" ] || fail "缺少 verify skill 内置一致性校验器"

python3 "$skill_checker" \
  "$TMP_DIR/tasks-native.md" \
  "$TMP_DIR/plan-native.md" >/dev/null || fail "skill 内置一致性校验器对合法输入不应失败"

cat >"$TMP_DIR/sources-good.yaml" <<'EOF'
sources:
  openspec:
    repo: https://github.com/Fission-AI/OpenSpec
    ref: v1.2.0
    captured_at: 2026-03-27
    scope:
      - docs/commands.md
    notes:
      - good
  superpowers:
    repo: https://github.com/obra/superpowers
    ref: abcdef123456
    captured_at: 2026-03-27
    scope:
      - skills/brainstorming
    notes:
      - good
EOF

python3 "$ROOT/tools/community/source_lock_check.py" \
  "$TMP_DIR/sources-good.yaml" >/dev/null || fail "合法 SOURCES 锁文件不应失败"

cat >"$TMP_DIR/sources-bad.yaml" <<'EOF'
sources:
  openspec:
    repo: https://github.com/Fission-AI/OpenSpec
    ref: v1.2.0
    captured_at: 2026-03-27
    scope:
      - docs/commands.md
    notes:
      - good
  superpowers:
    repo: https://github.com/obra/superpowers
    captured_at: 2026-03-27
    scope:
      - skills/brainstorming
    notes:
      - missing-ref
EOF

if python3 "$ROOT/tools/community/source_lock_check.py" \
  "$TMP_DIR/sources-bad.yaml" >/tmp/org_bad_source_lock.out 2>&1; then
  cat /tmp/org_bad_source_lock.out >&2
  fail "缺失 superpowers.ref 的 SOURCES 锁文件应失败"
fi

python3 -c 'from tools.community.sync_canonical_from_upstream import parse_version; assert parse_version("v1.2.0") == "1.2.0"' \
  >/dev/null || fail "sync_canonical_from_upstream.py 模块导入/版本解析应可用"

echo "[PASS] community tools"
