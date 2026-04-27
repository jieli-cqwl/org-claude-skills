#!/usr/bin/env python3
"""Declare and replay bounded local overlays for the Superpowers upstream mirror."""
from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class OverlayRule:
    path: str
    name: str
    start: str
    end: str | None
    insert_before: str | None = None
    apply_start: str | None = None
    apply_end: str | None = None


SUPERPOWERS_FULL_FILE_OVERLAYS = [
    "skills/brainstorming/spec-document-reviewer-prompt.md",
    "skills/brainstorming/references/design-template.md",
    "skills/brainstorming/references/design-completeness-checklist.md",
    "skills/subagent-driven-development/implementer-prompt.md",
    "skills/subagent-driven-development/spec-reviewer-prompt.md",
    "skills/subagent-driven-development/code-quality-reviewer-prompt.md",
    "skills/using-superpowers/references/codex-tools.md",
    "skills/using-superpowers/references/gemini-tools.md",
]

SUPERPOWERS_LOCAL_ONLY_FILES = ["codex/skills/brainstorming/agents/openai.yaml", "skills/archive/SKILL.md", "skills/verify-change/SKILL.md", "skills/verify-change/scripts/check_task_plan_consistency.py"]

SUPERPOWERS_FRONTMATTER_LINES = {
    "skills/using-superpowers/SKILL.md": [
        "description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions",
        "disable-model-invocation: true",
    ],
    "skills/brainstorming/SKILL.md": ['description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."'],
    "skills/using-git-worktrees/SKILL.md": ["description: Use after small-chain-execution-router returns decision=serial and the small-chain needs an isolated workspace before implementation."],
    "skills/writing-plans/SKILL.md": ["description: Use after brainstorming produces design.md to generate tasks.md and plan.md for a small-chain implementation"],
    "skills/subagent-driven-development/SKILL.md": ["description: Use after small-chain-execution-router returns decision=serial to execute small-chain implementation via subagents."],
    "skills/requesting-code-review/SKILL.md": ["description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements"],
    "skills/verification-before-completion/SKILL.md": ["description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always"],
    "skills/finishing-a-development-branch/SKILL.md": ["description: Use after verify-change passes to integrate a small-chain branch — guides merge, PR, or cleanup options"],
    "skills/test-driven-development/SKILL.md": ["description: Use when implementing any feature or bugfix, before writing implementation code"],
}

SUPERPOWERS_OVERLAY_RULES = [
    OverlayRule(
        path="skills/using-superpowers/SKILL.md",
        name="small-chain",
        start="## Small Chain (End-to-End Workflow)",
        end="## 自动衔接",
    ),
    OverlayRule(path="skills/using-superpowers/SKILL.md", name="format-unification", start="## Instruction Priority", end="## Skill Types"),
    OverlayRule(
        path="skills/using-superpowers/SKILL.md",
        name="auto-handoff",
        start="## 自动衔接",
        end=None,
    ),
    OverlayRule(
        path="skills/brainstorming/SKILL.md",
        name="flow-navigation",
        start="## 流程导航",
        end=None,
    ),
    OverlayRule(path="skills/brainstorming/SKILL.md", name="checklist-expanded-steps", start="You MUST create a task for each of these items and complete them in order:", end="## Process Flow"),
    OverlayRule(path="skills/brainstorming/SKILL.md", name="process-format-and-spec-review", start="The terminal state is invoking writing-plans.", end="## Key Principles", apply_start="**The terminal state is invoking writing-plans.**", apply_end="## Key Principles"),
    OverlayRule(
        path="skills/using-git-worktrees/SKILL.md",
        name="called-by",
        start="**Called by:**",
        end="**Pairs with:**",
    ),
    OverlayRule(
        path="skills/using-git-worktrees/SKILL.md",
        name="flow-navigation",
        start="## 流程导航",
        end=None,
    ),
    OverlayRule(
        path="skills/writing-plans/SKILL.md",
        name="context-block",
        start="**Context:**",
        end="## Scope Check",
    ),
    OverlayRule(
        path="skills/writing-plans/SKILL.md",
        name="contract-grade-intake-gate",
        start="## Contract-Grade Intake Gate",
        end="## Process Flow",
        insert_before="## File Structure",
    ),
    OverlayRule(
        path="skills/writing-plans/SKILL.md",
        name="process-flow",
        start="## Process Flow",
        end="## File Structure",
        insert_before="## File Structure",
    ),
    OverlayRule(
        path="skills/writing-plans/SKILL.md",
        name="tasks-document",
        start="## Tasks Document (tasks.md)",
        end="## Bite-Sized Task Granularity",
        insert_before="## Bite-Sized Task Granularity",
    ),
    OverlayRule(
        path="skills/writing-plans/SKILL.md",
        name="plan-structure",
        start="## Bite-Sized Task Granularity",
        end="## No Placeholders",
    ),
    OverlayRule(
        path="skills/writing-plans/SKILL.md",
        name="contract-grade-self-review",
        start="For contract-grade designs, each C1-C8 preflight answer must map to at least one task, test, fixture, hook, validator, docs update, or explicit N/A reason.",
        end="**2. Placeholder scan:**",
        insert_before="**2. Placeholder scan:**",
    ),
    OverlayRule(
        path="skills/writing-plans/SKILL.md",
        name="handoff-tail",
        start="## **HARD-GATE: Task-Plan Consistency Audit**",
        end=None,
        apply_start="## Execution Handoff",
    ),
    OverlayRule(
        path="skills/subagent-driven-development/SKILL.md",
        name="workflow-core",
        start="## When to Use",
        end="## Model Selection",
    ),
    OverlayRule(
        path="skills/subagent-driven-development/SKILL.md",
        name="example-workflow",
        start="## Example Workflow",
        end="## Advantages",
    ),
    OverlayRule(path="skills/subagent-driven-development/SKILL.md", name="blocked-status-format", start="**BLOCKED:** The implementer cannot complete the task. Assess the blocker:", end="**Never** ignore"),
    OverlayRule(
        path="skills/subagent-driven-development/SKILL.md",
        name="integration-tail",
        start="## Integration",
        end=None,
    ),
    OverlayRule(
        path="skills/requesting-code-review/SKILL.md",
        name="example",
        start="## Example",
        end="## Integration with Workflows",
    ),
    OverlayRule(
        path="skills/requesting-code-review/SKILL.md",
        name="integration",
        start="## Integration with Workflows",
        end=None,
    ),
    OverlayRule(
        path="skills/verification-before-completion/SKILL.md",
        name="closeout-routing",
        start='Treat "可以交付了" / "ready to ship" as a closeout trigger, not delivery approval.',
        end="## The Bottom Line",
        insert_before="## The Bottom Line",
    ),
    OverlayRule(
        path="skills/verification-before-completion/SKILL.md",
        name="flow-navigation",
        start="## 流程导航",
        end=None,
    ),
    OverlayRule(
        path="skills/finishing-a-development-branch/SKILL.md",
        name="workflow-core",
        start="## The Process",
        end="## Red Flags",
    ),
    OverlayRule(
        path="skills/finishing-a-development-branch/SKILL.md",
        name="integration",
        start="## Integration",
        end=None,
    ),
]


def _superpowers_local_path(community: Path, relative_path: str) -> Path:
    return community / "superpowers" / relative_path


def _read_superpowers_head_text(
    community: Path,
    root: Path,
    relative_path: str,
    run_command: Callable[..., str],
) -> str | None:
    if community != root / "community":
        return None
    repo_relative = Path("community") / "superpowers" / relative_path
    try:
        return run_command(["git", "show", f"HEAD:{repo_relative.as_posix()}"], cwd=root)
    except Exception:
        return None


def _extract_block(text: str, start: str, end: str | None, *, label: str) -> str:
    start_idx = text.find(start)
    if start_idx == -1:
        raise RuntimeError(f"overlay start miss ({label}): {start!r}")
    if end is None:
        end_idx = len(text)
    else:
        end_idx = text.find(end, start_idx + len(start))
        if end_idx == -1:
            raise RuntimeError(f"overlay end miss ({label}): {end!r}")
    return text[start_idx:end_idx]


def _join_markdown_blocks(prefix: str, block: str, suffix: str) -> str:
    parts = [part for part in (prefix.rstrip("\n"), block.strip("\n"), suffix.strip("\n")) if part]
    if not parts:
        return ""
    return "\n\n".join(parts) + "\n"


def _replace_or_insert_block(text: str, block: str, rule: OverlayRule) -> str:
    apply_start = rule.apply_start or rule.start
    apply_end = rule.apply_end if rule.apply_end is not None else rule.end
    start_idx = text.find(apply_start)
    if start_idx != -1:
        end_idx = len(text) if apply_end is None else text.find(apply_end, start_idx + len(apply_start))
        if end_idx == -1:
            raise RuntimeError(f"overlay apply end miss ({rule.path}:{rule.name}): {apply_end!r}")
        return _join_markdown_blocks(text[:start_idx], block, text[end_idx:])

    if rule.insert_before:
        insert_idx = text.find(rule.insert_before)
        if insert_idx == -1:
            raise RuntimeError(
                f"overlay insert miss ({rule.path}:{rule.name}): before {rule.insert_before!r}"
            )
        return _join_markdown_blocks(text[:insert_idx], block, text[insert_idx:])

    return text.rstrip("\n") + "\n\n" + block.strip("\n") + "\n"


def _extract_frontmatter_lines(text: str, lines: list[str]) -> list[str]:
    raw_lines = text.splitlines()
    if len(raw_lines) < 3 or raw_lines[0].strip() != "---":
        return []
    end_idx = None
    for idx in range(1, len(raw_lines)):
        if raw_lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is None:
        return []
    frontmatter = raw_lines[1:end_idx]
    return [line for line in lines if line in frontmatter]


def _frontmatter_key(line: str) -> str | None:
    if ":" not in line or line.startswith((" ", "\t")):
        return None
    key = line.split(":", 1)[0].strip()
    return key or None


def _ensure_frontmatter_lines(text: str, lines: list[str], *, label: str) -> str:
    if not lines:
        return text
    raw_lines = text.splitlines(keepends=True)
    if len(raw_lines) < 3 or raw_lines[0].strip() != "---":
        raise RuntimeError(f"missing frontmatter when applying overlay: {label}")
    end_idx = None
    for idx in range(1, len(raw_lines)):
        if raw_lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is None:
        raise RuntimeError(f"missing frontmatter end fence when applying overlay: {label}")
    desired_by_key = {
        key: line for line in lines if (key := _frontmatter_key(line)) is not None
    }
    desired_literals = [line for line in lines if _frontmatter_key(line) is None]
    applied_keys: set[str] = set()
    rewritten: list[str] = []
    changed = False

    for raw_line in raw_lines[1:end_idx]:
        current = raw_line.rstrip("\n")
        key = _frontmatter_key(current)
        if key in desired_by_key:
            if key not in applied_keys:
                rewritten.append(f"{desired_by_key[key]}\n")
                applied_keys.add(key)
            changed = changed or current != desired_by_key[key]
            continue
        rewritten.append(raw_line)

    existing = {line.rstrip("\n") for line in rewritten}
    additions = [f"{line}\n" for line in desired_literals if line not in existing]
    additions.extend(f"{desired_by_key[key]}\n" for key in desired_by_key if key not in applied_keys)
    if additions:
        changed = True
    if not changed:
        return text
    return "".join(raw_lines[:1] + rewritten + additions + raw_lines[end_idx:])


def capture_superpowers_local_overlays(
    community: Path,
    root: Path,
    run_command: Callable[..., str],
    *,
    require_all: bool = True,
) -> dict[str, object]:
    full_files: dict[str, str] = {}
    for relative_path in SUPERPOWERS_FULL_FILE_OVERLAYS:
        path = _superpowers_local_path(community, relative_path)
        if path.exists():
            full_files[relative_path] = path.read_text(encoding="utf-8")
            continue
        head_text = _read_superpowers_head_text(community, root, relative_path, run_command)
        if head_text is not None:
            full_files[relative_path] = head_text

    frontmatter: dict[str, list[str]] = {}
    for relative_path, lines in SUPERPOWERS_FRONTMATTER_LINES.items():
        path = _superpowers_local_path(community, relative_path)
        candidate_texts: list[str] = []
        if path.exists():
            candidate_texts.append(path.read_text(encoding="utf-8"))
        head_text = _read_superpowers_head_text(community, root, relative_path, run_command)
        if head_text is not None:
            candidate_texts.append(head_text)
        for text in candidate_texts:
            extracted = _extract_frontmatter_lines(text, lines)
            if extracted:
                frontmatter[relative_path] = extracted
                break

    blocks: dict[str, str] = {}
    for rule in SUPERPOWERS_OVERLAY_RULES:
        path = _superpowers_local_path(community, rule.path)
        label = f"{rule.path}:{rule.name}"
        candidate_texts: list[str] = []
        if path.exists():
            candidate_texts.append(path.read_text(encoding="utf-8"))
        head_text = _read_superpowers_head_text(community, root, rule.path, run_command)
        if head_text is not None:
            candidate_texts.append(head_text)
        last_error: RuntimeError | None = None
        for text in candidate_texts:
            try:
                blocks[label] = _extract_block(text, rule.start, rule.end, label=label)
                break
            except RuntimeError as exc:
                last_error = exc
        else:
            if require_all and last_error is not None:
                raise last_error

    return {
        "full_files": full_files,
        "frontmatter": frontmatter,
        "blocks": blocks,
    }


def apply_superpowers_local_overlays(community: Path, overlays: dict[str, object]) -> None:
    frontmatter = overlays["frontmatter"]
    assert isinstance(frontmatter, dict)
    for relative_path, lines in frontmatter.items():
        assert isinstance(relative_path, str)
        assert isinstance(lines, list)
        path = _superpowers_local_path(community, relative_path)
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        updated = _ensure_frontmatter_lines(text, lines, label=relative_path)
        path.write_text(updated, encoding="utf-8")

    blocks = overlays["blocks"]
    assert isinstance(blocks, dict)
    rules_by_path: dict[str, list[OverlayRule]] = {}
    for rule in SUPERPOWERS_OVERLAY_RULES:
        rules_by_path.setdefault(rule.path, []).append(rule)
    for relative_path, rules in rules_by_path.items():
        path = _superpowers_local_path(community, relative_path)
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        changed = False
        for rule in rules:
            block = blocks.get(f"{rule.path}:{rule.name}")
            if not block:
                continue
            assert isinstance(block, str)
            text = _replace_or_insert_block(text, block, rule)
            changed = True
        if changed:
            path.write_text(text, encoding="utf-8")

    full_files = overlays["full_files"]
    assert isinstance(full_files, dict)
    for relative_path, content in full_files.items():
        assert isinstance(relative_path, str)
        assert isinstance(content, str)
        path = _superpowers_local_path(community, relative_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
