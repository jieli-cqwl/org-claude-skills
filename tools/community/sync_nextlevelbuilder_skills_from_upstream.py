#!/usr/bin/env python3
"""Sync selected NextLevelBuilder community skills into community/nextlevelbuilder.

This script vendors only the repo slices declared in community/SOURCES.yaml.
It assembles the upstream UI/UX Pro Max skill from its generated SKILL.md plus
the resource tree used by the generated skill, then adds local Codex metadata.
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
NEXTLEVELBUILDER_ROOT = ROOT / "community" / "nextlevelbuilder"
DEST_SKILLS = NEXTLEVELBUILDER_ROOT / "skills"
DEST_CODEX_SKILLS = NEXTLEVELBUILDER_ROOT / "codex" / "skills"

SKILL_SOURCES = {
    "ui-ux-pro-max": {
        "source_name": "nextlevelbuilder_ui_ux_pro_max",
        "repo_dir_name": "nextlevelbuilder-ui-ux-pro-max-skill",
        "resource_path": Path("src") / "ui-ux-pro-max",
        "skill_file_path": Path(".claude") / "skills" / "ui-ux-pro-max" / "SKILL.md",
        "display_name": "UI/UX Pro Max",
        "short_description": "Searchable UI/UX design intelligence and design-system recommendations",
        "default_prompt": "Use $ui-ux-pro-max to plan, review, or improve a UI/UX design.",
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
    """Replace the destination tree with the source tree."""
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".git"))


def normalize_text_files(root: Path) -> None:
    """Remove trailing spaces from text resources so staged diffs pass checks."""
    text_suffixes = {".csv", ".json", ".md", ".py", ".txt"}
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in text_suffixes:
            continue
        text = path.read_text(encoding="utf-8")
        normalized = "\n".join(line.rstrip(" \t") for line in text.splitlines())
        if text.endswith(("\n", "\r\n")):
            normalized += "\n"
        if normalized != text:
            path.write_text(normalized, encoding="utf-8")


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
    resource_root = repo_root / meta["resource_path"]
    skill_file = repo_root / meta["skill_file_path"]
    license_file = repo_root / "LICENSE"

    if not resource_root.is_dir():
        fail(f"missing upstream resource directory: {resource_root}")
    if not skill_file.is_file():
        fail(f"missing upstream SKILL.md: {skill_file}")
    if not license_file.is_file():
        fail(f"missing upstream LICENSE: {license_file}")

    dest = DEST_SKILLS / skill_name
    sync_tree(resource_root, dest)
    shutil.copy2(skill_file, dest / "SKILL.md")
    shutil.copy2(license_file, dest / "LICENSE.txt")
    normalize_text_files(dest)

    adapter_dir = DEST_CODEX_SKILLS / skill_name / "agents"
    adapter_dir.mkdir(parents=True, exist_ok=True)
    (adapter_dir / "openai.yaml").write_text(
        render_openai_yaml(skill_name),
        encoding="utf-8",
    )


def main() -> None:
    """Sync selected NextLevelBuilder skills from local checkout or locked upstream ref."""
    parser = argparse.ArgumentParser(
        description="Sync selected NextLevelBuilder skills into community/nextlevelbuilder and generate Codex adapters."
    )
    parser.add_argument(
        "--ui-ux-pro-max-source-dir",
        help="Use an existing local nextlevelbuilder/ui-ux-pro-max-skill checkout instead of cloning from source lock.",
    )
    args = parser.parse_args()

    locks = load_lock()
    DEST_SKILLS.mkdir(parents=True, exist_ok=True)
    if DEST_CODEX_SKILLS.exists():
        shutil.rmtree(DEST_CODEX_SKILLS)

    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp)
        source_name = SKILL_SOURCES["ui-ux-pro-max"]["source_name"]

        if args.ui_ux_pro_max_source_dir:
            repo_root = Path(args.ui_ux_pro_max_source_dir).resolve()
        else:
            lock = locks[source_name]
            repo_root = clone_upstream(
                lock["repo"],
                lock["ref"],
                temp_root,
                SKILL_SOURCES["ui-ux-pro-max"]["repo_dir_name"],
            )

        sync_skill(repo_root, "ui-ux-pro-max")


if __name__ == "__main__":
    main()
