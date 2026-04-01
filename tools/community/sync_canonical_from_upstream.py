#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import tempfile
from dataclasses import dataclass
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


def update_sources_yaml(superpowers_commit: str) -> None:
    path = COMMUNITY / "SOURCES.yaml"
    text = path.read_text(encoding="utf-8")
    text = re.sub(
        r"(superpowers:\n(?:.*\n)*?\s+ref:\s*)[^\n]+",
        rf"\1{superpowers_commit}",
        text,
    )
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
