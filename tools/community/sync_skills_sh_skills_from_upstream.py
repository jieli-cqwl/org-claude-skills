#!/usr/bin/env python3
"""Sync selected skills.sh community skills into community/skills-sh.

This script vendors only the repo slices declared in community/SOURCES.yaml.
It keeps upstream skill content unchanged and generates local Codex metadata
only for skills that should be auto-exposed.
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
SKILLS_SH_ROOT = ROOT / "community" / "skills-sh"
DEST_SKILLS = SKILLS_SH_ROOT / "skills"
DEST_CODEX_SKILLS = SKILLS_SH_ROOT / "codex" / "skills"

SKILL_SOURCES = {
    "bb-browser": {
        "source_name": "skills_sh_bb_browser",
        "repo_dir_name": "bb-browser",
        "relative_path": Path("skills") / "bb-browser",
        "display_name": "BBBrowser",
        "short_description": "Browser automation and authenticated web information extraction",
        "default_prompt": "Use $bb-browser to operate a logged-in browser or extract web information.",
        "local_arg": "bb_browser_source_dir",
        "codex_adapter": True,
        "copy_root_license": True,
    },
    "humanizer-zh": {
        "source_name": "skills_sh_humanizer_zh",
        "repo_dir_name": "humanizer-zh",
        "relative_path": Path("."),
        "display_name": "Humanizer zh",
        "short_description": "Chinese text editing guidance for reducing AI-writing traces",
        "default_prompt": "Use $humanizer-zh to edit Chinese text so it sounds more natural.",
        "local_arg": "humanizer_zh_source_dir",
        "codex_adapter": True,
        "copy_root_license": False,
    },
    "notebooklm": {
        "source_name": "skills_sh_notebooklm",
        "repo_dir_name": "notebooklm-skill",
        "relative_path": Path("."),
        "display_name": "NotebookLM",
        "short_description": "Query Google NotebookLM notebooks through browser automation",
        "default_prompt": "Use $notebooklm to query or manage Google NotebookLM notebooks.",
        "local_arg": "notebooklm_source_dir",
        "codex_adapter": True,
        "copy_root_license": False,
    },
    "self-improving-agent": {
        "source_name": "skills_sh_self_improving_agent",
        "repo_dir_name": "agent-playbook",
        "relative_path": Path("skills") / "self-improving-agent",
        "display_name": "Self-Improving Agent",
        "short_description": "Manual self-improvement workflow for extracting reusable lessons",
        "default_prompt": "Use $self-improving-agent to manually summarize lessons and improvement opportunities.",
        "local_arg": "self_improving_agent_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
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
    if meta.get("copy_root_license") and license_file.is_file():
        shutil.copy2(license_file, dest / "LICENSE.txt")

    if not meta.get("codex_adapter"):
        return

    adapter_dir = DEST_CODEX_SKILLS / skill_name / "agents"
    adapter_dir.mkdir(parents=True, exist_ok=True)
    (adapter_dir / "openai.yaml").write_text(
        render_openai_yaml(skill_name),
        encoding="utf-8",
    )


def main() -> None:
    """Sync selected skills from local checkouts or locked upstream refs."""
    parser = argparse.ArgumentParser(
        description="Sync selected skills.sh community skills into community/skills-sh."
    )
    for skill_name, meta in SKILL_SOURCES.items():
        parser.add_argument(
            f"--{skill_name}-source-dir",
            dest=meta["local_arg"],
            help=f"Use an existing {skill_name} checkout instead of cloning.",
        )
    args = parser.parse_args()

    locks = load_lock()
    DEST_SKILLS.mkdir(parents=True, exist_ok=True)
    if DEST_CODEX_SKILLS.exists():
        shutil.rmtree(DEST_CODEX_SKILLS)

    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp)
        for skill_name, meta in sorted(SKILL_SOURCES.items()):
            local_dir = getattr(args, meta["local_arg"])
            if local_dir:
                repo_root = Path(local_dir).resolve()
            else:
                lock = locks[meta["source_name"]]
                repo_root = clone_upstream(
                    lock["repo"],
                    lock["ref"],
                    temp_root,
                    meta["repo_dir_name"],
                )
            sync_skill(repo_root, skill_name)


if __name__ == "__main__":
    main()
