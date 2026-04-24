#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - <<'PY' >/dev/null || fail "superpowers upstream fidelity 应允许声明 overlay 并阻断未声明正文差异"
from pathlib import Path
import tempfile

from tools.community import check_superpowers_upstream_fidelity as fidelity
from tools.community import superpowers_overlay_rules as overlay_rules

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

overlay_rules_subset = [
    overlay_rules.OverlayRule(
        path="skills/using-superpowers/SKILL.md",
        name="small-chain",
        start="## Small Chain (End-to-End Workflow)",
        end="## 自动衔接",
    ),
    overlay_rules.OverlayRule(
        path="skills/using-superpowers/SKILL.md",
        name="auto-handoff",
        start="## 自动衔接",
        end=None,
    ),
]
frontmatter_subset = {
    "skills/using-superpowers/SKILL.md": ["disable-model-invocation: true"],
}
local_only_subset = [
    "skills/archive/SKILL.md",
    "skills/verify-change/SKILL.md",
]
for module in (overlay_rules, fidelity):
    module.SUPERPOWERS_FULL_FILE_OVERLAYS = []
    module.SUPERPOWERS_LOCAL_ONLY_FILES = local_only_subset
    module.SUPERPOWERS_FRONTMATTER_LINES = frontmatter_subset
    module.SUPERPOWERS_OVERLAY_RULES = overlay_rules_subset


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def seed_upstream(upstream_root: Path) -> None:
    repo = upstream_root / "superpowers"
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

## User Instructions

Upstream ending.
""",
    )
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

## Execution Handoff

Upstream handoff.
""",
    )
    write(
        repo / "agents" / "code-reviewer.md",
        """---
name: code-reviewer
description: upstream reviewer
model: inherit
---

Upstream reviewer body.
""",
    )


def seed_local(local_root: Path) -> None:
    for skill in selected:
        write(
            local_root / "community" / "superpowers" / "skills" / skill / "SKILL.md",
            f"---\nname: {skill}\ndescription: upstream {skill}\n---\n\n"
            f"> Source: `obra/superpowers/skills/{skill}/SKILL.md` (pinned in `community/SOURCES.yaml`)\n\n\n"
            f"# {skill}\n\nUpstream body for {skill}.\n",
        )

    write(
        local_root / "community" / "superpowers" / "skills" / "using-superpowers" / "SKILL.md",
        """---
name: using-superpowers
description: upstream using-superpowers
disable-model-invocation: true
---

> Source: `obra/superpowers/skills/using-superpowers/SKILL.md` (pinned in `community/SOURCES.yaml`)


# Using Skills

## User Instructions

Upstream ending.

## Small Chain (End-to-End Workflow)

Declared local overlay.

## 自动衔接

Declared auto handoff.
""",
    )
    write(
        local_root / "community" / "superpowers" / "skills" / "using-git-worktrees" / "SKILL.md",
        """---
name: using-git-worktrees
description: upstream using-git-worktrees
---

> Source: `obra/superpowers/skills/using-git-worktrees/SKILL.md` (pinned in `community/SOURCES.yaml`)


# using-git-worktrees

Upstream body for using-git-worktrees.
""",
    )
    write(
        local_root / "community" / "superpowers" / "skills" / "brainstorming" / "SKILL.md",
        """---
name: brainstorming
description: upstream brainstorming
---

> Source: `obra/superpowers/skills/brainstorming/SKILL.md` (pinned in `community/SOURCES.yaml`)


# Brainstorming

Write the validated design (spec) to `docs/{feature}/YYYY-MM-DD-{change}/design.md`
""",
    )
    write(
        local_root / "community" / "superpowers" / "skills" / "writing-plans" / "SKILL.md",
        """---
name: writing-plans
description: upstream writing-plans
---

> Source: `obra/superpowers/skills/writing-plans/SKILL.md` (pinned in `community/SOURCES.yaml`)


# Writing Plans

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** upstream context

**Save plans to:** `docs/{feature}/YYYY-MM-DD-{change}/plan.md`
- upstream save path

## Scope Check

Upstream scope check.

## File Structure

Upstream file structure.

## Bite-Sized Task Granularity

Upstream bite sized steps.

## No Placeholders

Upstream no placeholders.

## Execution Handoff

Upstream handoff.
""",
    )
    write(
        local_root / "community" / "superpowers" / "agents" / "generic-code-reviewer.md",
        """---
name: generic-code-reviewer
description: upstream reviewer
model: inherit
---

> Source: `obra/superpowers/agents/code-reviewer.md` (pinned in `community/SOURCES.yaml`)


Upstream reviewer body.
""",
    )
    write(
        local_root / "community" / "superpowers" / "skills" / "archive" / "SKILL.md",
        "local archive skill\n",
    )
    write(
        local_root / "community" / "superpowers" / "skills" / "verify-change" / "SKILL.md",
        "local verify-change skill\n",
    )


with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    upstream_root = root / "upstream"
    local_root = root / "local"
    seed_upstream(upstream_root)
    seed_local(local_root)

    clean = fidelity.check_superpowers_fidelity(local_root, upstream_root)
    assert clean.ok, clean.message

    using_superpowers = local_root / "community" / "superpowers" / "skills" / "using-superpowers" / "SKILL.md"
    using_text = using_superpowers.read_text(encoding="utf-8")
    using_superpowers.write_text(
        using_text.replace(
            "\n## Small Chain (End-to-End Workflow)\n\nDeclared local overlay.\n",
            "\n",
        ),
        encoding="utf-8",
    )
    missing_overlay = fidelity.check_superpowers_fidelity(local_root, upstream_root)
    assert not missing_overlay.ok, "missing declared overlay block should fail"
    assert "skills/using-superpowers/SKILL.md:small-chain" in missing_overlay.message

    seed_local(local_root)
    using_text = using_superpowers.read_text(encoding="utf-8")
    using_superpowers.write_text(
        using_text.replace("disable-model-invocation: true\n", ""),
        encoding="utf-8",
    )
    missing_frontmatter = fidelity.check_superpowers_fidelity(local_root, upstream_root)
    assert not missing_frontmatter.ok, "missing declared frontmatter overlay should fail"
    assert "disable-model-invocation: true" in missing_frontmatter.message

    seed_local(local_root)
    missing_local_only_path = (
        local_root / "community" / "superpowers" / "skills" / "verify-change" / "SKILL.md"
    )
    missing_local_only_path.unlink()
    missing_local_only = fidelity.check_superpowers_fidelity(local_root, upstream_root)
    assert not missing_local_only.ok, "missing declared local-only file should fail"
    assert "skills/verify-change/SKILL.md" in missing_local_only.message

    seed_local(local_root)
    undeclared = local_root / "community" / "superpowers" / "skills" / "undeclared" / "SKILL.md"
    write(undeclared, "undeclared local file\n")
    dirty_file = fidelity.check_superpowers_fidelity(local_root, upstream_root)
    assert not dirty_file.ok, "undeclared local file should fail"
    assert "skills/undeclared/SKILL.md" in dirty_file.message
    undeclared.unlink()
    undeclared.parent.rmdir()

    seed_local(local_root)
    target = local_root / "community" / "superpowers" / "skills" / "test-driven-development" / "SKILL.md"
    target.write_text(target.read_text(encoding="utf-8") + "\nUndeclared local rewrite.\n", encoding="utf-8")

    dirty = fidelity.check_superpowers_fidelity(local_root, upstream_root)
    assert not dirty.ok, "undeclared upstream body difference should fail"
    assert "test-driven-development/SKILL.md" in dirty.message
PY

echo "[PASS] superpowers upstream fidelity"
