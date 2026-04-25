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
  vercel_skills:
    repo: https://github.com/vercel-labs/skills
    ref: abcdef123456
    captured_at: 2026-04-12
    scope:
      - community/vercel/skills/find-skills
    notes:
      - good
  vercel_agent_browser:
    repo: https://github.com/vercel-labs/agent-browser
    ref: abcdef123456
    captured_at: 2026-04-12
    scope:
      - community/vercel/skills/agent-browser
    notes:
      - good
  alchaincyf_darwin_skill:
    repo: https://github.com/alchaincyf/darwin-skill
    ref: abcdef123456
    captured_at: 2026-04-18
    scope:
      - community/alchaincyf/skills/darwin-skill
    notes:
      - good
  nextlevelbuilder_ui_ux_pro_max:
    repo: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
    ref: abcdef123456
    captured_at: 2026-04-20
    scope:
      - community/nextlevelbuilder/skills/ui-ux-pro-max
    notes:
      - good
  persona_colleague_skill:
    repo: https://github.com/titanwings/colleague-skill
    ref: abcdef123456
    captured_at: 2026-04-24
    scope:
      - community/persona/skills/colleague-skill
    notes:
      - good
  persona_nuwa_skill:
    repo: https://github.com/alchaincyf/nuwa-skill
    ref: abcdef123456
    captured_at: 2026-04-24
    scope:
      - community/persona/skills/nuwa-skill
    notes:
      - good
  persona_yourself_skill:
    repo: https://github.com/notdog1998/yourself-skill
    ref: abcdef123456
    captured_at: 2026-04-24
    scope:
      - community/persona/skills/yourself-skill
    notes:
      - good
  persona_midas_skill:
    repo: https://github.com/hermesnest/midas-skill
    ref: abcdef123456
    captured_at: 2026-04-24
    scope:
      - community/persona/skills/midas-skill
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
  vercel_skills:
    repo: https://github.com/vercel-labs/skills
    captured_at: 2026-04-12
    scope:
      - community/vercel/skills/find-skills
    notes:
      - missing-ref
  vercel_agent_browser:
    repo: https://github.com/vercel-labs/agent-browser
    ref: abcdef123456
    captured_at: 2026-04-12
    scope:
      - community/vercel/skills/agent-browser
    notes:
      - good
  alchaincyf_darwin_skill:
    repo: https://github.com/alchaincyf/darwin-skill
    ref: abcdef123456
    captured_at: 2026-04-18
    scope:
      - community/alchaincyf/skills/darwin-skill
    notes:
      - good
  nextlevelbuilder_ui_ux_pro_max:
    repo: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
    ref: abcdef123456
    captured_at: 2026-04-20
    scope:
      - community/nextlevelbuilder/skills/ui-ux-pro-max
    notes:
      - good
EOF

if python3 "$ROOT/tools/community/source_lock_check.py" \
  "$TMP_DIR/sources-bad.yaml" >/tmp/org_bad_source_lock.out 2>&1; then
  cat /tmp/org_bad_source_lock.out >&2
  fail "缺失 anthropic_skills.ref 的 SOURCES 锁文件应失败"
fi

python3 -c 'from tools.community.sync_canonical_from_upstream import parse_version; assert parse_version("v1.2.0") == "1.2.0"' \
  >/dev/null || fail "sync_canonical_from_upstream.py 模块导入/版本解析应可用"

python3 - <<'PY' >/dev/null || fail "community upstream sync 不应包含正文机器翻译入口"
from pathlib import Path

root = Path(".")
translation_dependency = "deep_" + "translator"
translation_class = "Google" + "Translator"
translation_flag = "--skip-" + "translate"
translation_target = "zh-" + "CN"
for rel in [
    "tools/community/check_superpowers_upstream_fidelity.py",
    "tools/community/sync_canonical_from_upstream.py",
    "tools/community/superpowers_overlay_rules.py",
    "shared/skills/community-skill-updater/scripts/run_update.py",
]:
    text = (root / rel).read_text(encoding="utf-8")
    for forbidden in (translation_dependency, translation_class, translation_flag, translation_target):
        assert forbidden not in text, f"{rel} contains forbidden translation marker: {forbidden}"

source_lock = (root / "community" / "SOURCES.yaml").read_text(encoding="utf-8")
obsolete_source_policies = [
    "\u4e2d\u6587 canonical",
    "\u8fd0\u884c\u6b63\u6587\u6539\u4e3a\u4e2d\u6587",
    "translated " + "to",
]
for forbidden in obsolete_source_policies:
    assert forbidden not in source_lock, f"SOURCES.yaml contains obsolete source policy: {forbidden}"
PY

python3 - <<'PY' >/dev/null || fail "superpowers sync 应 checkout SOURCES.yaml 锁定 ref"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

sample = """sources:
  superpowers:
    repo: https://example.invalid/locked-superpowers.git
    ref: locked-superpowers-ref
    captured_at: 2026-03-27
    scope:
      - skills/brainstorming
    notes:
      - good
"""

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    community = root / "community"
    community.mkdir(parents=True, exist_ok=True)
    (community / "SOURCES.yaml").write_text(sample, encoding="utf-8")

    calls = []

    def fake_run(cmd, cwd=None):
        calls.append((cmd, cwd))
        if cmd[:2] == ["git", "clone"]:
            Path(cmd[-1]).mkdir(parents=True, exist_ok=True)
            return ""
        if cmd[-2:] == ["rev-parse", "HEAD"]:
            return "resolved-locked-commit\n"
        return ""

    original_community = mod.COMMUNITY
    original_run = mod.run
    try:
        mod.COMMUNITY = community
        mod.run = fake_run
        checkout, commit = mod.clone_superpowers_from_lock(root / "tmp")
    finally:
        mod.COMMUNITY = original_community
        mod.run = original_run

    assert checkout == root / "tmp" / "superpowers"
    assert commit == "resolved-locked-commit"
    assert ["git", "clone", "--depth", "1", "https://example.invalid/locked-superpowers.git", str(checkout)] in [
        call[0] for call in calls
    ]
    assert ["git", "-C", str(checkout), "fetch", "--depth", "1", "origin", "locked-superpowers-ref"] in [
        call[0] for call in calls
    ]
    assert ["git", "-C", str(checkout), "checkout", "locked-superpowers-ref"] in [call[0] for call in calls]
PY

python3 - <<'PY' >/dev/null || fail "update_sources_yaml 应同时更新 superpowers.ref 和 captured_at"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

sample = """sources:
  anthropic_skills:
    repo: https://github.com/anthropics/skills
    ref: keep-anthropic
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
    ref: old-superpowers
    captured_at: 2026-03-27
    scope:
      - skills/brainstorming
    notes:
      - good
"""

with tempfile.TemporaryDirectory() as td:
    community = Path(td) / "community"
    community.mkdir(parents=True, exist_ok=True)
    (community / "SOURCES.yaml").write_text(sample, encoding="utf-8")

    original = mod.COMMUNITY
    try:
        mod.COMMUNITY = community
        mod.update_sources_yaml("new-superpowers", captured_at="2026-04-12")
    finally:
        mod.COMMUNITY = original

    updated = (community / "SOURCES.yaml").read_text(encoding="utf-8")
    assert "ref: new-superpowers" in updated
    assert "captured_at: 2026-04-12" in updated
    assert "ref: keep-anthropic" in updated
PY

python3 -c 'import tools.community.sync_vercel_skills_from_upstream as mod; assert callable(mod.main)' \
  >/dev/null || fail "sync_vercel_skills_from_upstream.py 模块导入应可用"

python3 -c 'import tools.community.sync_alchaincyf_skills_from_upstream as mod; assert callable(mod.main)' \
  >/dev/null || fail "sync_alchaincyf_skills_from_upstream.py 模块导入应可用"

python3 -c 'import tools.community.sync_nextlevelbuilder_skills_from_upstream as mod; assert callable(mod.main)' \
  >/dev/null || fail "sync_nextlevelbuilder_skills_from_upstream.py 模块导入应可用"

python3 -c 'import tools.community.sync_persona_skills_from_upstream as mod; assert callable(mod.main)' \
  >/dev/null || fail "sync_persona_skills_from_upstream.py 模块导入应可用"

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

python3 - <<'PY' >/dev/null || fail "sync_superpowers 应保留 superpowers 本地 overlay，并刷新其余官方正文"
import tempfile
from pathlib import Path

import tools.community.sync_canonical_from_upstream as mod

selected = [
    "using-superpowers",
    "brainstorming",
    "using-git-worktrees",
    "writing-plans",
    "subagent-driven-development",
    "requesting-code-review",
    "verification-before-completion",
    "finishing-a-development-branch",
    "test-driven-development",
]


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    upstream_root = root / "upstream"
    repo = upstream_root / "superpowers"
    community = root / "community"

    for skill in selected:
        write(
            repo / "skills" / skill / "SKILL.md",
            f"---\nname: {skill}\ndescription: upstream {skill}\n---\n\n# {skill}\n\nUpstream body for {skill}.\n",
        )

    write(
        repo / "skills" / "brainstorming" / "SKILL.md",
        """---
name: brainstorming
description: upstream brainstorming
---

# Brainstorming

Write the validated design (spec) to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
""",
    )

    write(
        repo / "skills" / "using-superpowers" / "SKILL.md",
        """---
name: using-superpowers
description: upstream using-superpowers
---

# Using Skills

## Instruction Priority

1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest priority
2. **Superpowers skills** — override default system behavior where they conflict

## Skill Types

Upstream skill types.

## User Instructions

Upstream ending.
""",
    )
    write(repo / "skills" / "using-superpowers" / "references" / "codex-tools.md", "# upstream codex tools\n")
    write(repo / "skills" / "using-superpowers" / "references" / "gemini-tools.md", "# upstream gemini tools\n")

    write(
        repo / "skills" / "writing-plans" / "SKILL.md",
        """---
name: writing-plans
description: upstream writing-plans
---

# Writing Plans

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** upstream context

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- upstream save path

## Scope Check

Upstream scope check.

## File Structure

Upstream file structure.

## Bite-Sized Task Granularity

Upstream bite sized steps.

## No Placeholders

Upstream no placeholders.

## Self-Review

Upstream self review.

## Execution Handoff

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - upstream recommended path

**2. Inline Execution** - Execute tasks in this session using executing-plans
""",
    )

    write(
        repo / "skills" / "subagent-driven-development" / "SKILL.md",
        """---
name: subagent-driven-development
description: upstream subagent-driven-development
---

# Subagent-Driven Development

## When to Use

Upstream when to use.

## Model Selection

Upstream model selection.

## Handling Implementer Status

**BLOCKED:** The implementer cannot complete the task. Assess the blocker:
1. If it's a context problem, provide more context and re-dispatch with the same model

**Never** ignore an escalation.

## Example Workflow

```
[Read plan file once: docs/superpowers/plans/feature-plan.md]
```

## Advantages

Upstream advantages.

## Integration

- **superpowers:executing-plans** - Use for parallel session instead of same-session execution
""",
    )

    write(
        repo / "agents" / "code-reviewer.md",
        """---
name: code-reviewer
description: |
  upstream description
model: inherit
---

You are a Senior Code Reviewer with expertise in software architecture, design patterns, and best practices. Your role is to review completed project steps against original plans and ensure code quality standards are met.

When reviewing completed work, you will:

1. Check the code.
""",
    )

    write(
        community / "superpowers" / "skills" / "using-superpowers" / "SKILL.md",
        """---
name: using-superpowers
description: local using-superpowers
disable-model-invocation: true
---

# Using Skills

## Instruction Priority

1. User's explicit instructions
   - Includes CLAUDE.md, GEMINI.md, AGENTS.md, and direct requests.
   - Highest priority.
2. Superpowers skills
   - Override default system behavior where they conflict.

## Skill Types

Local skill types.

## User Instructions

Upstream ending.

## Small Chain (End-to-End Workflow)

Local small chain block.

## 自动衔接

Local auto handoff block.
""",
    )
    write(
        community / "superpowers" / "skills" / "using-superpowers" / "references" / "codex-tools.md",
        "# local codex tools\n",
    )
    write(
        community / "superpowers" / "skills" / "using-superpowers" / "references" / "gemini-tools.md",
        "# local gemini tools\n",
    )
    write(
        community / "superpowers" / "skills" / "brainstorming" / "references" / "design-completeness-checklist.md",
        "# local design completeness checklist\n",
    )

    write(
        community / "superpowers" / "skills" / "writing-plans" / "SKILL.md",
        """---
name: writing-plans
description: local writing-plans
---

# Writing Plans

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** local context

**Input:** `docs/{feature}/YYYY-MM-DD-{change}/design.md`

## Scope Check

Upstream scope check.

## Process Flow

Local process flow.

## File Structure

Upstream file structure.

## Tasks Document (tasks.md)

Local tasks doc.

## Bite-Sized Task Granularity

Local bite sized steps.

## No Placeholders

Upstream no placeholders.

## **HARD-GATE: Task-Plan Consistency Audit**

Local task-plan audit.

## Execution Handoff

If the current workspace is not already isolated, invoke `using-git-worktrees` first. Once isolation is satisfied, invoke `subagent-driven-development` to execute the plan task-by-task.

## 流程导航

Local flow nav.
""",
    )

    write(
        community / "superpowers" / "skills" / "subagent-driven-development" / "SKILL.md",
        """---
name: subagent-driven-development
description: local subagent-driven-development
---

# Subagent-Driven Development

## When to Use

Local when to use.

## Model Selection

Local model selection.

## Handling Implementer Status

**BLOCKED:** The implementer cannot complete the task. Assess the blocker:
1. Context problem
   - Provide more context and re-dispatch with the same model.

**Never** ignore an escalation.

## Example Workflow

```
[Read plan.md + tasks.md]
[Build task-id mapping from tasks.md]
```

## Advantages

Local advantages.

## Integration

Terminal chain:
- verification-before-completion
- verify-change
- finishing-a-development-branch
- archive

## 流程导航

Local subagent flow nav.
""",
    )

    write(
        community / "superpowers" / "agents" / "generic-code-reviewer.md",
        """---
name: generic-code-reviewer
description: local generic code reviewer
model: inherit
---

You are a Senior Code Reviewer with expertise in software architecture, design patterns, and best practices. Your role is to review completed project steps against original plans and ensure code quality standards are met.

When reviewing completed work, you will:

1. Check the code.
""",
    )

    original = mod.COMMUNITY
    try:
        mod.COMMUNITY = community
        mod.sync_superpowers(upstream_root)
    finally:
        mod.COMMUNITY = original

    using_superpowers = (community / "superpowers" / "skills" / "using-superpowers" / "SKILL.md").read_text(encoding="utf-8")
    assert "disable-model-invocation: true" in using_superpowers
    assert "Local small chain block." in using_superpowers
    assert "Local auto handoff block." in using_superpowers
    assert "Upstream ending." in using_superpowers

    assert (community / "superpowers" / "skills" / "using-superpowers" / "references" / "codex-tools.md").read_text(encoding="utf-8") == "# local codex tools\n"
    assert (community / "superpowers" / "skills" / "using-superpowers" / "references" / "gemini-tools.md").read_text(encoding="utf-8") == "# local gemini tools\n"
    assert (community / "superpowers" / "skills" / "brainstorming" / "references" / "design-completeness-checklist.md").read_text(encoding="utf-8") == "# local design completeness checklist\n"

    writing_plans = (community / "superpowers" / "skills" / "writing-plans" / "SKILL.md").read_text(encoding="utf-8")
    assert "**Context:** local context" in writing_plans
    assert "## Tasks Document (tasks.md)" in writing_plans
    assert "Local tasks doc." in writing_plans
    assert "Local bite sized steps." in writing_plans
    assert "## **HARD-GATE: Task-Plan Consistency Audit**" in writing_plans
    assert "using-git-worktrees" in writing_plans
    assert "## 流程导航" in writing_plans
    assert "Upstream file structure." in writing_plans
    assert "docs/superpowers/plans/" not in writing_plans
    assert "executing-plans" not in writing_plans

    subagent = (community / "superpowers" / "skills" / "subagent-driven-development" / "SKILL.md").read_text(encoding="utf-8")
    assert "[Read plan.md + tasks.md]" in subagent
    assert "[Build task-id mapping from tasks.md]" in subagent
    assert "Terminal chain:" in subagent
    assert "verification-before-completion" in subagent
    assert "## 流程导航" in subagent
    assert "docs/superpowers/plans/" not in subagent
    assert "executing-plans" not in subagent

    code_reviewer = (community / "superpowers" / "agents" / "generic-code-reviewer.md").read_text(encoding="utf-8")
    assert "name: generic-code-reviewer" in code_reviewer
    assert "upstream description" in code_reviewer
    assert "When reviewing completed work, you will:" in code_reviewer
    assert "Local distrust principle." not in code_reviewer
    assert not (community / "superpowers" / "agents" / "code-reviewer.md").exists()
PY

echo "[PASS] community tools"
