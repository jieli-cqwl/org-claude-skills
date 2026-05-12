#!/usr/bin/env python3
"""Sync selected Panniantong community skills into community/panniantong.

This script vendors only the repo slices declared in community/SOURCES.yaml.
It keeps upstream skill content unchanged and generates local Codex metadata.
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
PANNIANTONG_ROOT = ROOT / "community" / "panniantong"
DEST_SKILLS = PANNIANTONG_ROOT / "skills"
DEST_CODEX_SKILLS = PANNIANTONG_ROOT / "codex" / "skills"

SKILL_SOURCES = {
    "agent-reach": {
        "source_name": "panniantong_agent_reach",
        "repo_dir_name": "panniantong-agent-reach",
        "relative_path": Path("agent_reach") / "skill",
        "display_name": "Agent Reach",
        "short_description": "Multi-platform web, social, video, and code search guidance",
        "default_prompt": "Use $agent-reach to search, read, or interact with supported web platforms.",
    },
}


def fail(message: str) -> None:
    """Exit with a human-readable error message."""
    raise SystemExit(message)


def load_lock() -> dict[str, dict[str, str]]:
    """Load the source lock entries required by this sync."""
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
    """Replace the destination tree with the source tree, excluding git metadata."""
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".git"))


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
    """Copy one locked upstream skill into the community source tree."""
    meta = SKILL_SOURCES[skill_name]
    src = repo_root / meta["relative_path"]
    if not src.is_dir():
        fail(f"missing upstream skill directory: {src}")
    if not (src / "SKILL.md").is_file():
        fail(f"missing upstream SKILL.md: {src / 'SKILL.md'}")

    dest = DEST_SKILLS / skill_name
    sync_tree(src, dest)
    license_file = repo_root / "LICENSE"
    if license_file.is_file():
        shutil.copy2(license_file, dest / "LICENSE.txt")

    adapter_dir = DEST_CODEX_SKILLS / skill_name / "agents"
    adapter_dir.mkdir(parents=True, exist_ok=True)
    (adapter_dir / "openai.yaml").write_text(
        render_openai_yaml(skill_name),
        encoding="utf-8",
    )


def main() -> None:
    """Sync selected Panniantong skills from local checkout or locked upstream ref."""
    parser = argparse.ArgumentParser(
        description="Sync selected Panniantong skills into community/panniantong."
    )
    parser.add_argument(
        "--agent-reach-source-dir",
        help="Use an existing local panniantong/agent-reach checkout instead of cloning.",
    )
    args = parser.parse_args()

    locks = load_lock()
    DEST_SKILLS.mkdir(parents=True, exist_ok=True)
    if DEST_CODEX_SKILLS.exists():
        shutil.rmtree(DEST_CODEX_SKILLS)

    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp)
        source_name = SKILL_SOURCES["agent-reach"]["source_name"]

        if args.agent_reach_source_dir:
            repo_root = Path(args.agent_reach_source_dir).resolve()
        else:
            lock = locks[source_name]
            repo_root = clone_upstream(
                lock["repo"],
                lock["ref"],
                temp_root,
                SKILL_SOURCES["agent-reach"]["repo_dir_name"],
            )

        sync_skill(repo_root, "agent-reach")


if __name__ == "__main__":
    main()
