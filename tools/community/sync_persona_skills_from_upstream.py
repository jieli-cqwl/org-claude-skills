#!/usr/bin/env python3
"""Sync selected persona/distillation community skills into community/persona.

This script vendors only the repositories declared in community/SOURCES.yaml.
Persona skills are installed as manual-only runtime skills by install.sh.
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
PERSONA_ROOT = ROOT / "community" / "persona"
DEST_SKILLS = PERSONA_ROOT / "skills"

SKILL_SOURCES = {
    "colleague-skill": {
        "source_name": "persona_colleague_skill",
        "repo_dir_name": "titanwings-colleague-skill",
        "required_skills": ["SKILL.md"],
    },
    "nuwa-skill": {
        "source_name": "persona_nuwa_skill",
        "repo_dir_name": "alchaincyf-nuwa-skill",
        "required_skills": ["SKILL.md"],
    },
    "yourself-skill": {
        "source_name": "persona_yourself_skill",
        "repo_dir_name": "notdog1998-yourself-skill",
        "required_skills": ["SKILL.md"],
    },
    "midas-skill": {
        "source_name": "persona_midas_skill",
        "repo_dir_name": "hermesnest-midas-skill",
        "required_skills": ["SKILL.md"],
    },
}


def fail(message: str) -> None:
    """Exit with a human-readable error message."""
    raise SystemExit(message)


def load_lock() -> dict[str, dict[str, str]]:
    """Load source lock entries required for persona skill sync."""
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


def sync_tree(src: Path, dst: Path, ignore: list[str] | None = None) -> None:
    """Replace the destination tree with the source tree."""
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*(ignore or [".git"])))


def ensure_frontmatter_start(skill_file: Path) -> None:
    """Normalize upstream skills that have a closing marker but no opening marker."""
    text = skill_file.read_text(encoding="utf-8")
    if text.startswith("---\n"):
        return
    if "\n---\n" not in text:
        return
    skill_file.write_text("---\n" + text, encoding="utf-8")


def normalize_codex_skill_root(skill_root: Path) -> None:
    """Rewrite legacy Codex skill roots to the current runtime discovery root."""
    replacements = {
        "~/.codex/skills": "~/.agents/skills",
        "$HOME/.codex/skills": "$HOME/.agents/skills",
        'Path.home() / ".codex" / "skills"': 'Path.home() / ".agents" / "skills"',
    }
    for path in sorted(item for item in skill_root.rglob("*") if item.is_file()):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        updated = text
        for old, new in replacements.items():
            updated = updated.replace(old, new)
        if updated != text:
            path.write_text(updated, encoding="utf-8")


def validate_required_skills(repo_root: Path, skill_name: str) -> None:
    """Ensure the upstream checkout exposes every expected SKILL.md entry."""
    for required in SKILL_SOURCES[skill_name]["required_skills"]:
        skill_file = repo_root / required
        if not skill_file.is_file():
            fail(f"missing upstream SKILL.md: {skill_file}")


def normalize_synced_skills(skill_root: Path) -> None:
    """Apply source-shape normalization needed for runtime visibility injection."""
    for skill_file in sorted(skill_root.rglob("SKILL.md")):
        ensure_frontmatter_start(skill_file)
    normalize_codex_skill_root(skill_root)


def sync_skill(repo_root: Path, skill_name: str) -> None:
    """Copy one locked upstream skill into the community/persona source tree."""
    validate_required_skills(repo_root, skill_name)
    ignore = SKILL_SOURCES[skill_name].get("ignore", [".git"])
    dest = DEST_SKILLS / skill_name
    sync_tree(repo_root, dest, ignore=ignore)
    normalize_synced_skills(dest)


def prune_unselected_skill_roots() -> None:
    """Remove stale persona skill roots that are no longer selected."""
    selected = set(SKILL_SOURCES)
    if not DEST_SKILLS.is_dir():
        return

    for child in sorted(DEST_SKILLS.iterdir()):
        if child.is_dir() and child.name not in selected:
            shutil.rmtree(child)


def main() -> None:
    """Sync selected persona skills from locked upstream refs."""
    parser = argparse.ArgumentParser(
        description="Sync selected persona/distillation skills into community/persona."
    )
    parser.parse_args()

    locks = load_lock()
    DEST_SKILLS.mkdir(parents=True, exist_ok=True)
    prune_unselected_skill_roots()

    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp)
        for skill_name, meta in SKILL_SOURCES.items():
            source_name = meta["source_name"]
            lock = locks[source_name]
            repo_root = clone_upstream(
                lock["repo"],
                lock["ref"],
                temp_root,
                meta["repo_dir_name"],
            )
            sync_skill(repo_root, skill_name)


if __name__ == "__main__":
    main()
