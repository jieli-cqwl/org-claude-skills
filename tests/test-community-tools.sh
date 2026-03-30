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

python3 - <<'PY' >/dev/null || fail "community markdown 翻译应保护 skill id、术语缩写和嵌套代码块"
from tools.community.sync_canonical_from_upstream import translate_markdown


class FakeTranslator:
    def translate_batch(self, lines, timeout=8):
        out = []
        for src in lines:
            v = src
            v = v.replace("vs.", "与。")
            v = v.replace(
                "superpowers:finishing-a-development-branch",
                "超级大国：完成开发分支",
            )
            v = v.replace("DRY", "干燥")
            v = v.replace("YAGNI", "亚格尼")
            v = v.replace("TDD", "时分驱动")
            v = v.replace("test_specific_behavior", "测试特定行为")
            v = v.replace("git commit -m \"feat: add specific behavior\"", "git commit -m \"壮举：添加特定功能\"")
            out.append(v)
        return out


sample = """# Title

**vs. Manual execution:**
- Keep superpowers:finishing-a-development-branch
- DRY, YAGNI, TDD

````markdown
### Task N

```python
def test_specific_behavior():
    pass
```

```bash
git commit -m "feat: add specific behavior"
```
````
"""

translated = translate_markdown(sample, FakeTranslator())

assert "**vs. Manual execution:**" in translated
assert "superpowers:finishing-a-development-branch" in translated
assert "DRY, YAGNI, TDD" in translated
assert "def test_specific_behavior():" in translated
assert 'git commit -m "feat: add specific behavior"' in translated

assert "与。" not in translated
assert "超级大国：" not in translated
assert "干燥" not in translated
assert "亚格尼" not in translated
assert "时分驱动" not in translated
assert "测试特定行为" not in translated
assert "壮举：添加特定功能" not in translated
PY

python3 - <<'PY' >/dev/null || fail "sync helper 应为 selected superpowers skills 再生最简来源头"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

with tempfile.TemporaryDirectory() as td:
    root = Path(td) / "community" / "superpowers" / "skills"
    for skill in mod.SUPERPOWERS_SELECTED:
        skill_dir = root / skill
        skill_dir.mkdir(parents=True, exist_ok=True)
        (skill_dir / "SKILL.md").write_text(
            "---\n"
            f"name: {skill}\n"
            "description: test\n"
            "---\n\n"
            "# Title\n",
            encoding="utf-8",
        )

    original = mod.COMMUNITY
    try:
        mod.COMMUNITY = Path(td) / "community"
        mod.add_superpowers_source_headers()
    finally:
        mod.COMMUNITY = original

    for skill in mod.SUPERPOWERS_SELECTED:
        text = (root / skill / "SKILL.md").read_text(encoding="utf-8")
        expected = f"> Source: `obra/superpowers/skills/{skill}/SKILL.md` (pinned in `community/SOURCES.yaml`)"
        assert expected in text, skill

    translated_like = root / mod.SUPERPOWERS_SELECTED[0] / "SKILL.md"
    translated_like.write_text(
        "---\n"
        f"name: {mod.SUPERPOWERS_SELECTED[0]}\n"
        "description: test\n"
        "---\n\n"
        f"> 来源：`obra/superpowers/skills/{mod.SUPERPOWERS_SELECTED[0]}/SKILL.md`（固定在 `community/SOURCES.yaml`）\n\n"
        "# Title\n",
        encoding="utf-8",
    )

    original = mod.COMMUNITY
    try:
        mod.COMMUNITY = Path(td) / "community"
        mod.add_superpowers_source_headers()
    finally:
        mod.COMMUNITY = original

    text = translated_like.read_text(encoding="utf-8")
    expected = f"> Source: `obra/superpowers/skills/{mod.SUPERPOWERS_SELECTED[0]}/SKILL.md` (pinned in `community/SOURCES.yaml`)"
    assert text.count(expected) == 1
PY

python3 - <<'PY' >/dev/null || fail "sync_superpowers 应在再生成后保留 selected superpowers skills 的最简来源头"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

with tempfile.TemporaryDirectory() as td, tempfile.TemporaryDirectory() as comm:
    repo_dir = Path(td)
    src = repo_dir / "superpowers"
    for skill in mod.SUPERPOWERS_SELECTED:
        skill_dir = src / "skills" / skill
        skill_dir.mkdir(parents=True, exist_ok=True)
        (skill_dir / "SKILL.md").write_text(
            "---\n"
            f"name: {skill}\n"
            "description: test\n"
            "---\n\n"
            "# Title\n",
            encoding="utf-8",
        )
    (src / "agents").mkdir(parents=True, exist_ok=True)
    (src / "agents" / "code-reviewer.md").write_text("# Agent\n", encoding="utf-8")

    original_community = mod.COMMUNITY
    original_patch = mod.patch_superpowers_local_overrides
    try:
        mod.COMMUNITY = Path(comm)
        mod.patch_superpowers_local_overrides = lambda: None
        mod.sync_superpowers(repo_dir, translate=False)
    finally:
        mod.COMMUNITY = original_community
        mod.patch_superpowers_local_overrides = original_patch

    for skill in mod.SUPERPOWERS_SELECTED:
        text = (Path(comm) / "superpowers" / "skills" / skill / "SKILL.md").read_text(encoding="utf-8")
        expected = f"> Source: `obra/superpowers/skills/{skill}/SKILL.md` (pinned in `community/SOURCES.yaml`)"
        assert expected in text, skill
PY

python3 - <<'PY' >/dev/null || fail "selected superpowers skills 应带最简来源头且不应残留已知坏词"
from pathlib import Path

root = Path("community/superpowers/skills")
bad_terms = (
    "与。",
    "超级大国：",
    "超级能力：",
    "亚格尼",
    "时分驱动",
    "干燥。",
    "人类伴侣",
    "写作计划技能",
    "执行计划技能",
    "完成开发分支技能",
    "使用超能力：",
    "超能力技能",
)

for path in sorted(root.glob("*/SKILL.md")):
    text = path.read_text(encoding="utf-8")
    assert '> Source: `obra/superpowers/skills/' in text, path.as_posix()
    for term in bad_terms:
        assert term not in text, f"{path.as_posix()}: {term}"
PY

echo "[PASS] community tools"
