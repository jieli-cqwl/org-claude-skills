#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import tempfile
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMUNITY = ROOT / "community"

OFFICIAL_SUPERPOWERS_SKILLS = [
    "brainstorming",
    "dispatching-parallel-agents",
    "executing-plans",
    "finishing-a-development-branch",
    "receiving-code-review",
    "requesting-code-review",
    "subagent-driven-development",
    "systematic-debugging",
    "test-driven-development",
    "using-git-worktrees",
    "using-superpowers",
    "verification-before-completion",
    "writing-plans",
    "writing-skills",
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


def _extract_source_section(text: str, source_name: str) -> re.Match[str]:
    pattern = re.compile(
        rf"^  {re.escape(source_name)}:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
        flags=re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        raise RuntimeError(f"SOURCES.yaml missing source section: {source_name}")
    return m


def extract_source_lock_field(source_name: str, field: str) -> str:
    lock_path = COMMUNITY / "SOURCES.yaml"
    text = lock_path.read_text(encoding="utf-8")
    m = _extract_source_section(text, source_name)
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
    run(["git", "clone", "--no-checkout", repo, str(checkout)])
    run(["git", "-C", str(checkout), "fetch", "--depth", "1", "origin", ref])
    run(["git", "-C", str(checkout), "checkout", "--detach", "FETCH_HEAD"])
    commit = run(["git", "-C", str(checkout), "rev-parse", "HEAD"]).strip()
    return checkout, commit


def _validate_official_skill_set(skills_root: Path) -> list[str]:
    skills = sorted(path.name for path in skills_root.iterdir() if path.is_dir())
    expected = sorted(OFFICIAL_SUPERPOWERS_SKILLS)
    if skills != expected:
        missing = sorted(set(expected) - set(skills))
        extra = sorted(set(skills) - set(expected))
        raise RuntimeError(
            "Superpowers locked ref does not match expected official skill set "
            f"(missing={missing}, extra={extra})"
        )
    return skills


def sync_superpowers(upstream_checkout: Path) -> None:
    src = upstream_checkout / "skills"
    dst = COMMUNITY / "superpowers"
    must_exist(src)
    skills = _validate_official_skill_set(src)

    if dst.exists():
        shutil.rmtree(dst)
    (dst / "skills").mkdir(parents=True, exist_ok=True)

    for skill in skills:
        print(f"[sync] superpowers skill: {skill}")
        shutil.copytree(src / skill, dst / "skills" / skill)


def update_sources_yaml(superpowers_commit: str, *, captured_at: str | None = None) -> None:
    path = COMMUNITY / "SOURCES.yaml"
    text = path.read_text(encoding="utf-8")
    m = _extract_source_section(text, "superpowers")
    repo = extract_source_lock_field("superpowers", "repo")
    captured = captured_at or date.today().isoformat()
    new_section = (
        "  superpowers:\n"
        f"    repo: {repo}\n"
        f"    ref: {superpowers_commit}\n"
        f"    captured_at: {captured}\n"
        "    scope:\n"
        "      - community/superpowers/skills\n"
        "    notes:\n"
        "      - Vendor official Superpowers skills/ full set; files remain byte-for-byte upstream originals from locked ref.\n"
        "      - No local overlays, Codex adapters, runtime metadata rewrites, source headers, or local-only skills are allowed under community/superpowers.\n"
    )
    text = text[: m.start()] + new_section + text[m.end() :]
    path.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync canonical community assets from locked upstream refs.")
    parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="community-sync-") as td:
        tmp = Path(td)
        checkout, sp_commit = clone_superpowers_from_lock(tmp)
        sync_superpowers(checkout)
        update_sources_yaml(sp_commit)

    print(f"[PASS] synced superpowers at {sp_commit}")


if __name__ == "__main__":
    main()
