#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
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
    "executing-plans",
    "requesting-code-review",
    "verification-before-completion",
    "finishing-a-development-branch",
    "test-driven-development",
]

OPENSPEC_CORE_SKILLS = [
    "openspec-propose",
    "openspec-apply-change",
    "openspec-archive-change",
    "openspec-explore",
]

CODE_SPAN_RE = re.compile(r"`[^`]+`")
URL_RE = re.compile(r"https?://[^\s)]+")
ANGLE_RE = re.compile(r"<[^>\n]+>")
TABLE_DIVIDER_RE = re.compile(r"^[\s|:\-]+$")
VERSION_RE = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.\-]+)?")

LOCAL_WORKFLOW_NOTE = (
    "\n\n## Local Workflow Note\n\n"
    "In this repository's fused workflow, after `/opsx:propose` completes "
    "you should run `writing-plans` before `/opsx:apply`.\n"
    "If `/opsx:propose` is explicitly invoked, do not jump back to brainstorming.\n"
)


def run(cmd: list[str], cwd: Path | None = None) -> str:
    p = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=True,
        text=True,
        capture_output=True,
    )
    return p.stdout


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


def assert_openspec_cli_matches_lock() -> None:
    expected_ref = extract_source_lock_ref("openspec")
    expected_version = parse_version(expected_ref)
    actual_output = run(["openspec", "--version"]).strip()
    actual_version = parse_version(actual_output)
    if normalize_version(actual_version) != normalize_version(expected_version):
        raise RuntimeError(
            "openspec CLI version mismatch with source lock: "
            f"expected {expected_ref}, actual {actual_output}"
        )


def patch_superpowers_local_overrides() -> None:
    brainstorming = COMMUNITY / "superpowers" / "skills" / "brainstorming" / "SKILL.md"
    writing_plans = COMMUNITY / "superpowers" / "skills" / "writing-plans" / "SKILL.md"

    text = brainstorming.read_text(encoding="utf-8")
    text = replace_or_fail(
        text,
        "docs/superpowers/specs/",
        "openspec/designs/",
        label="brainstorming specs path",
    )
    text = replace_or_fail(
        text,
        "YYYY-MM-DD-<topic>-design.md",
        "YYYY-MM-DD-<topic>-draft.md",
        label="brainstorming design filename",
    )
    text = replace_or_fail(
        text,
        "The ONLY skill you invoke after brainstorming is writing-plans.",
        "The ONLY skill you invoke after brainstorming is opsx:propose.",
        label="brainstorming skill handoff",
    )
    text = replace_or_fail(
        text,
        "Invoke writing-plans skill",
        "Invoke opsx:propose skill",
        label="brainstorming flow diagram handoff",
    )
    text = replace_or_fail(
        text,
        "invoke the writing-plans skill",
        "invoke the opsx:propose skill",
        label="brainstorming post-design handoff",
    )
    brainstorming.write_text(text, encoding="utf-8")

    text = writing_plans.read_text(encoding="utf-8")
    text = replace_or_fail(
        text,
        "docs/superpowers/plans/",
        "openspec/plans/",
        label="writing-plans path",
    )
    text = replace_or_fail(
        text,
        "<feature-name>",
        "<change-name>",
        label="writing-plans placeholder",
    )
    writing_plans.write_text(text, encoding="utf-8")


def patch_openspec_local_overrides() -> None:
    propose_skill = COMMUNITY / "openspec" / "skills" / "openspec-propose" / "SKILL.md"
    propose_cmd = COMMUNITY / "openspec" / "claude" / "commands" / "opsx" / "propose.md"

    for path in [propose_skill, propose_cmd]:
        text = path.read_text(encoding="utf-8")
        if LOCAL_WORKFLOW_NOTE not in text:
            text += LOCAL_WORKFLOW_NOTE
        path.write_text(text, encoding="utf-8")



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
    for pattern in (CODE_SPAN_RE, URL_RE, ANGLE_RE):
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
    if stripped.startswith("```"):
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
        if stripped.startswith("```"):
            flush_pending()
            in_code = not in_code
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


def sync_openspec(repo_dir: Path, *, translate: bool) -> None:
    gen = repo_dir / "openspec-generated"
    gen.mkdir(parents=True, exist_ok=True)
    print("[sync] openspec init")
    run(["openspec", "init", "--tools", "claude,codex"], cwd=gen)

    claude_skills = gen / ".claude" / "skills"
    claude_commands = gen / ".claude" / "commands" / "opsx"
    must_exist(claude_skills)
    must_exist(claude_commands)

    dst = COMMUNITY / "openspec"
    verify_skill_path = dst / "skills" / "openspec-verify-change" / "SKILL.md"
    verify_cmd_path = dst / "claude" / "commands" / "opsx" / "verify.md"
    verify_skill_backup = verify_skill_path.read_text(encoding="utf-8") if verify_skill_path.exists() else None
    verify_cmd_backup = verify_cmd_path.read_text(encoding="utf-8") if verify_cmd_path.exists() else None

    for name in OPENSPEC_CORE_SKILLS:
        print(f"[sync] openspec skill: {name}")
        copy_tree(claude_skills / name, dst / "skills" / name)

    print("[sync] openspec commands: opsx/*")
    copy_tree(claude_commands, dst / "claude" / "commands" / "opsx")

    # Preserve local verify extension (OpenSpec core profile does not emit verify).
    if verify_skill_backup is not None:
        verify_skill_path.parent.mkdir(parents=True, exist_ok=True)
        verify_skill_path.write_text(verify_skill_backup, encoding="utf-8")
    if verify_cmd_backup is not None:
        verify_cmd_path.parent.mkdir(parents=True, exist_ok=True)
        verify_cmd_path.write_text(verify_cmd_backup, encoding="utf-8")

    patch_openspec_local_overrides()
    if translate:
        translate_md_tree(dst / "skills")
        translate_md_tree(dst / "claude" / "commands")


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

    assert_openspec_cli_matches_lock()

    with tempfile.TemporaryDirectory(prefix="community-sync-") as td:
        tmp = Path(td)
        run(["git", "clone", "--depth=1", "https://github.com/obra/superpowers", str(tmp / "superpowers")])
        sp_commit = run(["git", "rev-parse", "HEAD"], cwd=tmp / "superpowers").strip()

        sync_superpowers(tmp, translate=do_translate)
        sync_openspec(tmp, translate=do_translate)
        update_sources_yaml(sp_commit)

    if do_translate:
        print("[PASS] Synced community canonical assets from upstream and translated to zh-CN.")
    else:
        print("[PASS] Synced community canonical assets from upstream (translation skipped).")


if __name__ == "__main__":
    main()
