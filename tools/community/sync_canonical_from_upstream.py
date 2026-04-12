#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import tempfile
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
COMMUNITY = ROOT / "community"

SUPERPOWERS_SELECTED = [
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

PROTECTED_SKILL_NAMES = sorted(
    {*(SUPERPOWERS_SELECTED), "code-reviewer"},
    key=len,
    reverse=True,
)

CODE_SPAN_RE = re.compile(r"`[^`]+`")
URL_RE = re.compile(r"https?://[^\s)]+")
ANGLE_RE = re.compile(r"<[^>\n]+>")
TABLE_DIVIDER_RE = re.compile(r"^[\s|:\-]+$")
VERSION_RE = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.\-]+)?")
FENCE_RE = re.compile(r"^([`~]{3,})(.*)$")
SKILL_REF_RE = re.compile(r"\b[a-z][a-z0-9-]*:[a-z0-9][a-z0-9-]*\b")
PLAIN_SKILL_NAME_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(name) for name in PROTECTED_SKILL_NAMES) + r")\b"
)
VS_RE = re.compile(r"(?<!\w)vs\.")
UPPER_TERM_RE = re.compile(r"\b(?:[A-Z]{2,}|[A-Z]{2,}(?:/[A-Z]{2,})+)\b")
MIXED_CASE_TOKEN_RE = re.compile(r"\b[A-Za-z]+[A-Z][A-Za-z]*\b")


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
    "skills/subagent-driven-development/implementer-prompt.md",
    "skills/subagent-driven-development/spec-reviewer-prompt.md",
    "skills/subagent-driven-development/code-quality-reviewer-prompt.md",
    "skills/using-superpowers/references/codex-tools.md",
    "skills/using-superpowers/references/gemini-tools.md",
]

SUPERPOWERS_FRONTMATTER_LINES = {
    "skills/using-superpowers/SKILL.md": ["disable-model-invocation: true"],
}

SUPERPOWERS_OVERLAY_RULES = [
    OverlayRule(
        path="skills/using-superpowers/SKILL.md",
        name="small-chain",
        start="## Small Chain (End-to-End Workflow)",
        end="## 自动衔接",
    ),
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
        start="## Process Flow",
        end="## Red Flags",
    ),
    OverlayRule(
        path="skills/finishing-a-development-branch/SKILL.md",
        name="integration",
        start="## Integration",
        end=None,
    ),
    OverlayRule(
        path="agents/code-reviewer.md",
        name="distrust-principle",
        start="## 不信任原则",
        end="When reviewing completed work, you will:",
        insert_before="When reviewing completed work, you will:",
    ),
]


def run(cmd: list[str], cwd: Path | None = None) -> str:
    import subprocess

    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=True,
        text=True,
        capture_output=True,
    ).stdout


def must_exist(path: Path) -> None:
    if not path.exists():
        raise RuntimeError(f"Missing expected path: {path}")


def copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def replace_or_fail(text: str, old: str, new: str, *, label: str, min_hits: int = 1) -> str:
    hits = text.count(old)
    if hits < min_hits:
        raise RuntimeError(f"override replace miss ({label}): expected >= {min_hits}, actual {hits}")
    return text.replace(old, new)


def extract_source_lock_ref(source_name: str) -> str:
    lock_path = COMMUNITY / "SOURCES.yaml"
    text = lock_path.read_text(encoding="utf-8")
    m = re.search(
        rf"^  {re.escape(source_name)}:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
        text,
        flags=re.MULTILINE,
    )
    if not m:
        raise RuntimeError(f"SOURCES.yaml missing source section: {source_name}")
    body = m.group("body")
    m_ref = re.search(r"^    ref:\s*(?P<ref>\S+)\s*$", body, flags=re.MULTILINE)
    if not m_ref:
        raise RuntimeError(f"SOURCES.yaml missing ref for source: {source_name}")
    return m_ref.group("ref")


def normalize_version(value: str) -> str:
    return value.strip().lstrip("vV")


def parse_version(value: str) -> str:
    m = VERSION_RE.search(value)
    if not m:
        raise RuntimeError(f"Cannot parse version from: {value!r}")
    return m.group(0)


def _superpowers_local_path(relative_path: str) -> Path:
    return COMMUNITY / "superpowers" / relative_path


def _read_superpowers_head_text(relative_path: str) -> str | None:
    if COMMUNITY != ROOT / "community":
        return None
    repo_relative = Path("community") / "superpowers" / relative_path
    try:
        return run(["git", "show", f"HEAD:{repo_relative.as_posix()}"], cwd=ROOT)
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
    parts = [part for part in (prefix.rstrip("\n"), block.strip("\n"), suffix.lstrip("\n")) if part]
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
    existing = {line.rstrip("\n") for line in raw_lines[1:end_idx]}
    additions = [f"{line}\n" for line in lines if line not in existing]
    if not additions:
        return text
    return "".join(raw_lines[:end_idx] + additions + raw_lines[end_idx:])


def capture_superpowers_local_overlays() -> dict[str, object]:
    full_files: dict[str, str] = {}
    for relative_path in SUPERPOWERS_FULL_FILE_OVERLAYS:
        path = _superpowers_local_path(relative_path)
        if path.exists():
            full_files[relative_path] = path.read_text(encoding="utf-8")
            continue
        head_text = _read_superpowers_head_text(relative_path)
        if head_text is not None:
            full_files[relative_path] = head_text

    frontmatter: dict[str, list[str]] = {}
    for relative_path, lines in SUPERPOWERS_FRONTMATTER_LINES.items():
        path = _superpowers_local_path(relative_path)
        candidate_texts: list[str] = []
        if path.exists():
            candidate_texts.append(path.read_text(encoding="utf-8"))
        head_text = _read_superpowers_head_text(relative_path)
        if head_text is not None:
            candidate_texts.append(head_text)
        for text in candidate_texts:
            extracted = _extract_frontmatter_lines(text, lines)
            if extracted:
                frontmatter[relative_path] = extracted
                break

    blocks: dict[str, str] = {}
    for rule in SUPERPOWERS_OVERLAY_RULES:
        path = _superpowers_local_path(rule.path)
        label = f"{rule.path}:{rule.name}"
        candidate_texts: list[str] = []
        if path.exists():
            candidate_texts.append(path.read_text(encoding="utf-8"))
        head_text = _read_superpowers_head_text(rule.path)
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
            if last_error is not None:
                raise last_error

    return {
        "full_files": full_files,
        "frontmatter": frontmatter,
        "blocks": blocks,
    }


def patch_superpowers_local_overrides() -> None:
    brainstorming = COMMUNITY / "superpowers" / "skills" / "brainstorming" / "SKILL.md"
    writing_plans = COMMUNITY / "superpowers" / "skills" / "writing-plans" / "SKILL.md"

    text = brainstorming.read_text(encoding="utf-8")
    text = replace_or_fail(
        text,
        "docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md",
        "docs/{feature}/YYYY-MM-DD-{change}/design.md",
        label="brainstorming design path",
    )
    brainstorming.write_text(text, encoding="utf-8")

    text = writing_plans.read_text(encoding="utf-8")
    text = replace_or_fail(
        text,
        "docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md",
        "docs/{feature}/YYYY-MM-DD-{change}/plan.md",
        label="writing-plans path",
    )
    writing_plans.write_text(text, encoding="utf-8")


def apply_superpowers_local_overlays(overlays: dict[str, object]) -> None:
    frontmatter = overlays["frontmatter"]
    assert isinstance(frontmatter, dict)
    for relative_path, lines in frontmatter.items():
        assert isinstance(relative_path, str)
        assert isinstance(lines, list)
        path = _superpowers_local_path(relative_path)
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
        path = _superpowers_local_path(relative_path)
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
        path = _superpowers_local_path(relative_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def protect_tokens(text: str) -> tuple[str, dict[str, str]]:
    token_map: dict[str, str] = {}
    counter = 0

    def repl(match: re.Match[str]) -> str:
        nonlocal counter
        key = f"@@{counter}@@"
        counter += 1
        token_map[key] = match.group(0)
        return key

    protected = text
    for pattern in (
        CODE_SPAN_RE,
        URL_RE,
        ANGLE_RE,
        SKILL_REF_RE,
        PLAIN_SKILL_NAME_RE,
        VS_RE,
        UPPER_TERM_RE,
        MIXED_CASE_TOKEN_RE,
    ):
        protected = pattern.sub(repl, protected)
    return protected, token_map


def restore_tokens(text: str, token_map: dict[str, str]) -> str:
    out = text
    for key, value in token_map.items():
        out = out.replace(key, value)
    return out


def should_translate_line(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return False
    if TABLE_DIVIDER_RE.fullmatch(stripped):
        return False
    if FENCE_RE.match(stripped):
        return False
    if stripped.startswith("<!--") and stripped.endswith("-->"):
        return False
    return bool(re.search(r"[A-Za-z]", stripped))


@dataclass
class PendingLine:
    idx: int
    prefix: str
    core: str
    suffix: str
    token_map: dict[str, str]


def build_translator() -> Any:
    try:
        from deep_translator import GoogleTranslator  # type: ignore
    except ModuleNotFoundError as exc:
        raise RuntimeError(
            "Missing dependency: deep_translator. "
            "Install with: python3 -m pip install deep-translator"
        ) from exc
    return GoogleTranslator(source="auto", target="zh-CN", timeout=8)


def translate_batch(translator: Any, lines: list[str]) -> list[str]:
    if not lines:
        return []
    try:
        translated = translator.translate_batch(lines, timeout=8)
        if isinstance(translated, list) and len(translated) == len(lines):
            return [item if isinstance(item, str) else src for item, src in zip(translated, lines)]
    except Exception:
        pass

    out: list[str] = []
    for src in lines:
        try:
            v = translator.translate(src, timeout=8)
            out.append(v if isinstance(v, str) else src)
        except Exception:
            out.append(src)
    return out


def translate_markdown(content: str, translator: Any) -> str:
    lines = content.splitlines(keepends=True)
    if not lines:
        return content

    out = list(lines)

    # Keep frontmatter keys stable; only translate description value.
    idx = 0
    if lines and lines[0].strip() == "---":
        idx = 1
        while idx < len(lines):
            if lines[idx].strip() == "---":
                idx += 1
                break
            if lines[idx].startswith("description:"):
                k, v = lines[idx].split(":", 1)
                text = v.strip()
                if text:
                    t = translate_batch(translator, [text])[0]
                    out[idx] = f"{k}: {t}\n"
            idx += 1

    in_code = False
    fence_char = ""
    fence_len = 0
    pending: list[PendingLine] = []

    def flush_pending() -> None:
        nonlocal pending
        if not pending:
            return
        translated = translate_batch(translator, [p.core for p in pending])
        for p, t in zip(pending, translated):
            restored = restore_tokens(t, p.token_map)
            out[p.idx] = f"{p.prefix}{restored}{p.suffix}"
        pending = []

    for i in range(idx, len(lines)):
        raw = lines[i]
        stripped = raw.strip()
        fence_match = FENCE_RE.match(stripped)
        if fence_match:
            flush_pending()
            fence = fence_match.group(1)
            if not in_code:
                in_code = True
                fence_char = fence[0]
                fence_len = len(fence)
            elif fence[0] == fence_char and len(fence) >= fence_len:
                in_code = False
                fence_char = ""
                fence_len = 0
            continue
        if in_code:
            continue

        if not should_translate_line(raw):
            flush_pending()
            continue

        m = re.match(r"^(\s*(?:[-*+]\s+|\d+\.\s+|#{1,6}\s+|>\s+|))", raw)
        prefix = m.group(1) if m else ""
        core = raw[len(prefix) :].rstrip("\n")
        suffix = "\n" if raw.endswith("\n") else ""

        protected, token_map = protect_tokens(core)
        pending.append(PendingLine(i, prefix, protected, suffix, token_map))

        if len(pending) >= 30:
            flush_pending()

    flush_pending()
    return "".join(out)


def translate_md_tree(root: Path) -> None:
    translator = build_translator()
    for path in sorted(root.rglob("*.md")):
        print(f"[translate] {path.relative_to(ROOT)}")
        content = path.read_text(encoding="utf-8")
        translated = translate_markdown(content, translator)
        path.write_text(translated, encoding="utf-8")


def sync_superpowers(repo_dir: Path, *, translate: bool) -> None:
    src = repo_dir / "superpowers"
    dst = COMMUNITY / "superpowers"
    must_exist(src / "skills")
    must_exist(src / "agents" / "code-reviewer.md")
    overlays = capture_superpowers_local_overlays()

    for skill in SUPERPOWERS_SELECTED:
        print(f"[sync] superpowers skill: {skill}")
        copy_tree(src / "skills" / skill, dst / "skills" / skill)

    (dst / "agents").mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "agents" / "code-reviewer.md", dst / "agents" / "code-reviewer.md")

    patch_superpowers_local_overrides()
    if translate:
        translate_md_tree(dst / "skills")
        translate_md_tree(dst / "agents")
    for skill in SUPERPOWERS_SELECTED:
        path = COMMUNITY / "superpowers" / "skills" / skill / "SKILL.md"
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines(keepends=True)
        if len(lines) < 3 or lines[0].strip() != "---":
            raise RuntimeError(f"superpowers skill missing frontmatter fence: {path}")

        end_idx = None
        for idx in range(1, len(lines)):
            if lines[idx].strip() == "---":
                end_idx = idx
                break
        if end_idx is None:
            raise RuntimeError(f"superpowers skill missing closing frontmatter fence: {path}")

        header = f"> Source: `obra/superpowers/skills/{skill}/SKILL.md` (pinned in `community/SOURCES.yaml`)\n\n"
        body = "".join(lines[end_idx + 1 :])
        header_re = re.compile(
            rf"^> [^\n]*`obra/superpowers/skills/{re.escape(skill)}/SKILL\.md`[^\n]*`community/SOURCES\.yaml`[^\n]*\n\n"
        )
        body = header_re.sub("", body, count=1)
        if body.startswith(header):
            continue
        text = "".join(lines[: end_idx + 1]) + "\n" + header + body
        path.write_text(text, encoding="utf-8")

    apply_superpowers_local_overlays(overlays)


def update_sources_yaml(superpowers_commit: str, *, captured_at: str | None = None) -> None:
    path = COMMUNITY / "SOURCES.yaml"
    text = path.read_text(encoding="utf-8")
    m = re.search(
        r"^  superpowers:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
        text,
        flags=re.MULTILINE,
    )
    if not m:
        raise RuntimeError("SOURCES.yaml missing source section: superpowers")
    body = m.group("body")
    body = re.sub(r"^    ref:\s*[^\n]+$", f"    ref: {superpowers_commit}", body, flags=re.MULTILINE)
    captured = captured_at or date.today().isoformat()
    body = re.sub(r"^    captured_at:\s*[^\n]+$", f"    captured_at: {captured}", body, flags=re.MULTILINE)
    text = text[: m.start("body")] + body + text[m.end("body") :]
    path.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync and translate canonical community assets from upstream.")
    parser.add_argument(
        "--skip-translate",
        action="store_true",
        help="Skip markdown translation step (sync upstream content only).",
    )
    args = parser.parse_args()
    do_translate = not args.skip_translate

    with tempfile.TemporaryDirectory(prefix="community-sync-") as td:
        tmp = Path(td)
        run(["git", "clone", "--depth=1", "https://github.com/obra/superpowers", str(tmp / "superpowers")])
        sp_commit = run(["git", "rev-parse", "HEAD"], cwd=tmp / "superpowers").strip()

        sync_superpowers(tmp, translate=do_translate)
        update_sources_yaml(sp_commit)

    if do_translate:
        print("[PASS] Synced community canonical assets from upstream and translated to zh-CN.")
    else:
        print("[PASS] Synced community canonical assets from upstream (translation skipped).")


if __name__ == "__main__":
    main()
