#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import tempfile
from datetime import date
from pathlib import Path

try:
    from superpowers_overlay_rules import (  # type: ignore
        apply_superpowers_local_overlays,
        capture_superpowers_local_overlays,
    )
except ModuleNotFoundError:
    from tools.community.superpowers_overlay_rules import (
        apply_superpowers_local_overlays,
        capture_superpowers_local_overlays,
    )


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

VERSION_RE = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.\-]+)?")


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


def extract_source_lock_field(source_name: str, field: str) -> str:
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
    m_field = re.search(rf"^    {re.escape(field)}:\s*(?P<value>\S.+?)\s*$", body, flags=re.MULTILINE)
    if not m_field:
        raise RuntimeError(f"SOURCES.yaml missing {field} for source: {source_name}")
    return m_field.group("value")


def extract_source_lock_ref(source_name: str) -> str:
    return extract_source_lock_field(source_name, "ref")


def clone_superpowers_from_lock(workdir: Path) -> tuple[Path, str]:
    """Clone Superpowers and checkout the ref locked in community/SOURCES.yaml."""
    repo = extract_source_lock_field("superpowers", "repo")
    ref = extract_source_lock_ref("superpowers")
    checkout = workdir / "superpowers"
    run(["git", "clone", "--depth", "1", repo, str(checkout)])
    run(["git", "-C", str(checkout), "fetch", "--depth", "1", "origin", ref])
    run(["git", "-C", str(checkout), "checkout", ref])
    commit = run(["git", "-C", str(checkout), "rev-parse", "HEAD"]).strip()
    return checkout, commit


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

def sync_superpowers(repo_dir: Path, *, overlays: dict[str, object] | None = None) -> None:
    src = repo_dir / "superpowers"
    dst = COMMUNITY / "superpowers"
    must_exist(src / "skills")
    must_exist(src / "agents" / "code-reviewer.md")
    active_overlays = overlays or capture_superpowers_local_overlays(COMMUNITY, ROOT, run)

    for skill in SUPERPOWERS_SELECTED:
        print(f"[sync] superpowers skill: {skill}")
        copy_tree(src / "skills" / skill, dst / "skills" / skill)

    (dst / "agents").mkdir(parents=True, exist_ok=True)
    generic_agent_path = dst / "agents" / "generic-code-reviewer.md"
    legacy_agent_path = dst / "agents" / "code-reviewer.md"
    if legacy_agent_path.exists():
        legacy_agent_path.unlink()
    shutil.copy2(src / "agents" / "code-reviewer.md", generic_agent_path)
    generic_text = generic_agent_path.read_text(encoding="utf-8")
    generic_text = replace_or_fail(
        generic_text,
        "name: code-reviewer",
        "name: generic-code-reviewer",
        label="generic code reviewer frontmatter",
    )
    generic_agent_path.write_text(generic_text, encoding="utf-8")

    patch_superpowers_local_overrides()
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

    path = generic_agent_path
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    if len(lines) < 3 or lines[0].strip() != "---":
        raise RuntimeError(f"superpowers agent missing frontmatter fence: {path}")
    end_idx = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is None:
        raise RuntimeError(f"superpowers agent missing closing frontmatter fence: {path}")
    header = "> Source: `obra/superpowers/agents/code-reviewer.md` (pinned in `community/SOURCES.yaml`)\n\n"
    body = "".join(lines[end_idx + 1 :])
    header_re = re.compile(
        r"^> [^\n]*`obra/superpowers/agents/code-reviewer\.md`[^\n]*`community/SOURCES\.yaml`[^\n]*\n\n"
    )
    body = header_re.sub("", body, count=1)
    if not body.startswith(header):
        text = "".join(lines[: end_idx + 1]) + "\n" + header + body
        path.write_text(text, encoding="utf-8")

    apply_superpowers_local_overlays(COMMUNITY, active_overlays)


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
    parser = argparse.ArgumentParser(description="Sync canonical community assets from locked upstream refs.")
    parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="community-sync-") as td:
        tmp = Path(td)
        _, sp_commit = clone_superpowers_from_lock(tmp)

        sync_superpowers(tmp)
        update_sources_yaml(sp_commit)

    print("[PASS] Synced community canonical assets from upstream.")


if __name__ == "__main__":
    main()
