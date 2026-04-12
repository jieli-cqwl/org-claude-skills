#!/usr/bin/env python3
"""Sync selected Vercel community skills into community/vercel and generate Codex adapters.

This script vendors only the repo slices declared in community/SOURCES.yaml.
It does not modify non-Vercel community sources.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
LOCK_FILE = ROOT / "community" / "SOURCES.yaml"
VERCEL_ROOT = ROOT / "community" / "vercel"
DEST_SKILLS = VERCEL_ROOT / "skills"
DEST_CODEX_SKILLS = VERCEL_ROOT / "codex" / "skills"

SKILL_SOURCES = {
    "find-skills": {
        "source_name": "vercel_skills",
        "repo_dir_name": "vercel-skills",
        "relative_path": Path("skills") / "find-skills",
        "display_name": "Find Skills",
        "short_description": "Discover installable skills from the open agent ecosystem",
        "default_prompt": "Use $find-skills to discover and install skills for a user task.",
    },
    "agent-browser": {
        "source_name": "vercel_agent_browser",
        "repo_dir_name": "vercel-agent-browser",
        "relative_path": Path("skills") / "agent-browser",
        "display_name": "Agent Browser",
        "short_description": "Browser automation CLI guidance for web interaction tasks",
        "default_prompt": "Use $agent-browser to automate a browser workflow or inspect a website.",
    },
}


def fail(message: str) -> None:
    """Exit with a human-readable error message."""
    raise SystemExit(message)


def load_lock() -> dict[str, dict[str, str]]:
    """Load the Vercel source lock entries required by this sync."""
    if not LOCK_FILE.is_file():
        fail(f"missing source lock: {LOCK_FILE}")

    data = yaml.safe_load(LOCK_FILE.read_text(encoding="utf-8"))
    sources = data.get("sources", {})

    loaded: dict[str, dict[str, str]] = {}
    for config in SKILL_SOURCES.values():
        source_name = config["source_name"]
        try:
            loaded[source_name] = sources[source_name]
        except KeyError:
            fail(f"missing {source_name} in {LOCK_FILE}")
    return loaded


def clone_upstream(repo: str, ref: str, workdir: Path, checkout_name: str) -> Path:
    """Clone and checkout a locked upstream ref into a temporary workdir."""
    checkout = workdir / checkout_name
    subprocess.run(
        ["git", "clone", "--depth", "1", repo, str(checkout)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        ["git", "-C", str(checkout), "fetch", "--depth", "1", "origin", ref],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        ["git", "-C", str(checkout), "checkout", ref],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return checkout


def sync_tree(src: Path, dst: Path) -> None:
    """Replace the destination tree with the source tree."""
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def render_openai_yaml(skill_name: str) -> str:
    """Render minimal Codex auto-exposure metadata for a vendored skill."""
    meta = SKILL_SOURCES[skill_name]
    return (
        "interface:\n"
        f'  display_name: "{meta["display_name"]}"\n'
        f'  short_description: "{meta["short_description"]}"\n'
        f'  default_prompt: "{meta["default_prompt"]}"\n'
    )


def sync_skill(repo_root: Path, skill_name: str) -> None:
    """Copy one locked upstream skill into the community/vercel source tree."""
    meta = SKILL_SOURCES[skill_name]
    src = repo_root / meta["relative_path"]
    if not src.is_dir():
        fail(f"missing upstream skill directory: {src}")
    if not (src / "SKILL.md").is_file():
        fail(f"missing upstream SKILL.md: {src / 'SKILL.md'}")

    sync_tree(src, DEST_SKILLS / skill_name)

    adapter_dir = DEST_CODEX_SKILLS / skill_name / "agents"
    adapter_dir.mkdir(parents=True, exist_ok=True)
    (adapter_dir / "openai.yaml").write_text(
        render_openai_yaml(skill_name),
        encoding="utf-8",
    )


def main() -> None:
    """Sync both selected Vercel skills from local checkouts or locked upstream refs."""
    parser = argparse.ArgumentParser(
        description="Sync selected Vercel skills into community/vercel and generate Codex adapters."
    )
    parser.add_argument(
        "--vercel-skills-source-dir",
        help="Use an existing local vercel-labs/skills checkout instead of cloning from source lock.",
    )
    parser.add_argument(
        "--agent-browser-source-dir",
        help="Use an existing local vercel-labs/agent-browser checkout instead of cloning from source lock.",
    )
    args = parser.parse_args()

    locks = load_lock()
    DEST_SKILLS.mkdir(parents=True, exist_ok=True)
    if DEST_CODEX_SKILLS.exists():
        shutil.rmtree(DEST_CODEX_SKILLS)

    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp)

        repo_roots: dict[str, Path] = {}
        for skill_name, meta in SKILL_SOURCES.items():
            source_name = meta["source_name"]
            if skill_name == "find-skills" and args.vercel_skills_source_dir:
                repo_roots[skill_name] = Path(args.vercel_skills_source_dir).resolve()
                continue
            if skill_name == "agent-browser" and args.agent_browser_source_dir:
                repo_roots[skill_name] = Path(args.agent_browser_source_dir).resolve()
                continue

            lock = locks[source_name]
            repo_roots[skill_name] = clone_upstream(
                lock["repo"],
                lock["ref"],
                temp_root,
                meta["repo_dir_name"],
            )

        for skill_name in sorted(SKILL_SOURCES):
            sync_skill(repo_roots[skill_name], skill_name)


if __name__ == "__main__":
    main()
