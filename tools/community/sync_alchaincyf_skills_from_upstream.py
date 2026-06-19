#!/usr/bin/env python3
"""Sync selected Alchaincyf community skills into community/alchaincyf.

This script vendors only the repo slices declared in community/SOURCES.yaml.
It keeps upstream skill content unchanged and generates local Codex metadata.
"""

from __future__ import annotations

import argparse
import shutil
import tempfile
from pathlib import Path

import yaml

try:
    from git_upstream import clone_locked_ref  # type: ignore
except ModuleNotFoundError:
    from tools.community.git_upstream import clone_locked_ref


ROOT = Path(__file__).resolve().parents[2]
LOCK_FILE = ROOT / "community" / "SOURCES.yaml"
ALCHAINCYF_ROOT = ROOT / "community" / "alchaincyf"
DEST_SKILLS = ALCHAINCYF_ROOT / "skills"
DEST_CODEX_SKILLS = ALCHAINCYF_ROOT / "codex" / "skills"

SKILL_SOURCES = {
    "darwin-skill": {
        "source_name": "alchaincyf_darwin_skill",
        "repo_dir_name": "alchaincyf-darwin-skill",
        "display_name": "Darwin Skill",
        "short_description": "Autonomous optimizer for SKILL.md quality",
        "default_prompt": "Use $darwin-skill to evaluate or optimize selected SKILL.md files.",
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
    return clone_locked_ref(repo, ref, workdir, checkout_name)


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
    if not (repo_root / "SKILL.md").is_file():
        fail(f"missing upstream SKILL.md: {repo_root / 'SKILL.md'}")

    sync_tree(repo_root, DEST_SKILLS / skill_name)

    adapter_dir = DEST_CODEX_SKILLS / skill_name / "agents"
    adapter_dir.mkdir(parents=True, exist_ok=True)
    (adapter_dir / "openai.yaml").write_text(
        render_openai_yaml(skill_name),
        encoding="utf-8",
    )


def main() -> None:
    """Sync selected Alchaincyf skills from local checkout or locked upstream ref."""
    parser = argparse.ArgumentParser(
        description="Sync selected Alchaincyf skills into community/alchaincyf and generate Codex adapters."
    )
    parser.add_argument(
        "--darwin-skill-source-dir",
        help="Use an existing local alchaincyf/darwin-skill checkout instead of cloning from source lock.",
    )
    args = parser.parse_args()

    locks = load_lock()
    DEST_SKILLS.mkdir(parents=True, exist_ok=True)
    if DEST_CODEX_SKILLS.exists():
        shutil.rmtree(DEST_CODEX_SKILLS)

    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp)
        source_name = SKILL_SOURCES["darwin-skill"]["source_name"]

        if args.darwin_skill_source_dir:
            repo_root = Path(args.darwin_skill_source_dir).resolve()
        else:
            lock = locks[source_name]
            repo_root = clone_upstream(
                lock["repo"],
                lock["ref"],
                temp_root,
                SKILL_SOURCES["darwin-skill"]["repo_dir_name"],
            )

        sync_skill(repo_root, "darwin-skill")


if __name__ == "__main__":
    main()
