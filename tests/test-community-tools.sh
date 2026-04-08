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

### Task 1: 登录接口 [T1]
1. [T1] 写失败测试
2. [T1] 实现接口

### Task 2: 登录页 [T2]
1. [T2] 实现登录页

### Task 3: 首页动画 [T3]
1. [T3] 实现首页动画
EOF

python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/plan.md" >/dev/null || fail "合法的 tasks/plan 映射不应失败"

cat >"$TMP_DIR/plan-missing-id.md" <<'EOF'
# 缺少 task id 的计划

### Task 1: 登录接口 [T1]
1. 写失败测试（无 task id）
EOF

if python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/plan-missing-id.md" >/tmp/org_plan_missing_id.out 2>&1; then
  cat /tmp/org_plan_missing_id.out >&2
  fail "缺少 task id 的编号步骤应失败"
fi

cat >"$TMP_DIR/plan-with-checkbox.md" <<'EOF'
# 非法计划

### Task 1: 登录接口 [T1]
- [ ] [T1] 写失败测试
EOF

if python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/plan-with-checkbox.md" >/tmp/org_plan_checkbox.out 2>&1; then
  cat /tmp/org_plan_checkbox.out >&2
  fail "plan.md 持有 checkbox 状态应失败"
fi

cat >"$TMP_DIR/bad-plan.md" <<'EOF'
# 错误计划

### Task 1: 登录接口 [T1]
1. [T1] 写失败测试
2. [T9] 不存在的任务
EOF

if python3 "$ROOT/tools/community/check_task_plan_consistency.py" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/bad-plan.md" >/tmp/org_bad_plan.out 2>&1; then
  cat /tmp/org_bad_plan.out >&2
  fail "非法 tasks/plan 映射应失败"
fi

skill_checker="$ROOT/community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py"
[ -f "$skill_checker" ] || fail "缺少 verify-change skill 内置一致性校验器"

python3 "$skill_checker" \
  "$TMP_DIR/tasks.md" \
  "$TMP_DIR/plan.md" >/dev/null || fail "skill 内置一致性校验器对合法输入不应失败"

cat >"$TMP_DIR/sources-good.yaml" <<'EOF'
sources:
  anthropic_skills:
    repo: https://github.com/anthropics/skills
    ref: abcdef123456
    captured_at: 2026-04-02
    scope:
      - community/anthropic/skills
    notes:
      - good
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
  anthropic_skills:
    repo: https://github.com/anthropics/skills
    captured_at: 2026-04-02
    scope:
      - community/anthropic/skills
    notes:
      - missing-ref
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
  fail "缺失 anthropic_skills.ref 的 SOURCES 锁文件应失败"
fi

python3 -c 'from tools.community.sync_canonical_from_upstream import parse_version; assert parse_version("v1.2.0") == "1.2.0"' \
  >/dev/null || fail "sync_canonical_from_upstream.py 模块导入/版本解析应可用"

python3 - <<'PY' >/dev/null || fail "superpowers 本地 patch 应收口到 small-chain canonical 工件路径"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

with tempfile.TemporaryDirectory() as td:
    community = Path(td) / "community" / "superpowers" / "skills"
    brainstorming_dir = community / "brainstorming"
    writing_plans_dir = community / "writing-plans"
    brainstorming_dir.mkdir(parents=True, exist_ok=True)
    writing_plans_dir.mkdir(parents=True, exist_ok=True)

    (brainstorming_dir / "SKILL.md").write_text(
        "---\n"
        "name: brainstorming\n"
        "description: test\n"
        "---\n\n"
        "save to docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md\n"
        "Invoke writing-plans skill\n",
        encoding="utf-8",
    )
    (writing_plans_dir / "SKILL.md").write_text(
        "---\n"
        "name: writing-plans\n"
        "description: test\n"
        "---\n\n"
        "save to docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md\n",
        encoding="utf-8",
    )

    original = mod.COMMUNITY
    try:
        mod.COMMUNITY = Path(td) / "community"
        mod.patch_superpowers_local_overrides()
    finally:
        mod.COMMUNITY = original

    brainstorming = (brainstorming_dir / "SKILL.md").read_text(encoding="utf-8")
    writing_plans = (writing_plans_dir / "SKILL.md").read_text(encoding="utf-8")

    assert "docs/superpowers/specs/" not in brainstorming
    assert "docs/{feature}/YYYY-MM-DD-{change}/design.md" in brainstorming
    assert "docs/superpowers/plans/" not in writing_plans
    assert "docs/{feature}/YYYY-MM-DD-{change}/plan.md" in writing_plans
PY

echo "[PASS] community tools"
