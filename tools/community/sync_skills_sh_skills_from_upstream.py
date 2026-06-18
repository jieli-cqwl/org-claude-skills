#!/usr/bin/env python3
"""Sync selected skills.sh community skills into community/skills-sh.

This script vendors only the repo slices declared in community/SOURCES.yaml.
It keeps upstream skill content unchanged and generates local Codex metadata
only for skills that should be auto-exposed.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import NoReturn


ROOT = Path(__file__).resolve().parents[2]
LOCK_FILE = ROOT / "community" / "SOURCES.yaml"
SKILLS_SH_ROOT = ROOT / "community" / "skills-sh"
DEST_SKILLS = SKILLS_SH_ROOT / "skills"
DEST_CODEX_SKILLS = SKILLS_SH_ROOT / "codex" / "skills"

SKILL_SOURCES = {
    "architecture": {
        "source_name": "skills_sh_markdown_viewer_architecture",
        "repo_dir_name": "markdown-viewer-skills",
        "relative_path": Path("architecture"),
        "display_name": "Architecture",
        "short_description": "Manual layered system architecture diagrams using HTML and CSS templates",
        "default_prompt": "Use $architecture to manually create layered system architecture diagrams.",
        "local_arg": "architecture_source_dir",
        "codex_adapter": False,
        "copy_root_license": False,
    },
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
    "code-to-prd": {
        "source_name": "skills_sh_alirezarezvani_code_to_prd",
        "repo_dir_name": "alirezarezvani-claude-skills",
        "relative_path": Path("product-team")
        / "code-to-prd"
        / "skills"
        / "code-to-prd",
        "display_name": "Code To PRD",
        "short_description": "Manual reverse engineering of an existing codebase into a PRD",
        "default_prompt": "Use $code-to-prd to manually reverse-engineer a PRD from an existing codebase.",
        "local_arg": "code_to_prd_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
    },
    "to-prd": {
        "source_name": "skills_sh_mattpocock_to_prd",
        "repo_dir_name": "mattpocock-skills",
        "relative_path": Path("skills") / "engineering" / "to-prd",
        "display_name": "To PRD",
        "short_description": "Manual conversion of current context and codebase understanding into a PRD",
        "default_prompt": "Use $to-prd to manually turn current context into a PRD.",
        "local_arg": "to_prd_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
    },
    "prd": {
        "source_name": "skills_sh_github_prd",
        "repo_dir_name": "awesome-copilot",
        "relative_path": Path("skills") / "prd",
        "display_name": "PRD",
        "short_description": "Manual Product Requirements Document drafting guidance",
        "default_prompt": "Use $prd to manually draft or review a product requirements document.",
        "local_arg": "prd_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
    },
    "graphify": {
        "source_name": "skills_sh_graphify",
        "repo_dir_name": "graphify",
        "relative_path": Path("graphify"),
        "source_skill_file": "skill-codex.md",
        "display_name": "Graphify",
        "short_description": "Manual knowledge-graph generation from code, docs, papers, images, and videos",
        "default_prompt": "Use $graphify to manually build or query a knowledge graph for local project content.",
        "local_arg": "graphify_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
    },
    "mermaid-diagrams": {
        "source_name": "skills_sh_softaworks_mermaid_diagrams",
        "repo_dir_name": "softaworks-agent-toolkit",
        "relative_path": Path("skills") / "mermaid-diagrams",
        "display_name": "Mermaid Diagrams",
        "short_description": "Manual Mermaid diagram generation for architecture and technical documentation",
        "default_prompt": "Use $mermaid-diagrams to manually create Mermaid diagrams for technical documentation.",
        "local_arg": "mermaid_diagrams_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
    },
    "baoyu-markdown-to-html": {
        "source_name": "skills_sh_baoyu_markdown_to_html",
        "repo_dir_name": "baoyu-skills",
        "relative_path": Path("skills") / "baoyu-markdown-to-html",
        "display_name": "Baoyu Markdown To HTML",
        "short_description": "Manual conversion of Markdown to styled HTML",
        "default_prompt": "Use $baoyu-markdown-to-html to manually convert Markdown to styled HTML.",
        "local_arg": "baoyu_markdown_to_html_source_dir",
        "codex_adapter": False,
        "copy_root_license": False,
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
    "obsidian-cli": {
        "source_name": "skills_sh_kepano_obsidian_skills",
        "repo_dir_name": "kepano-obsidian-skills",
        "relative_path": Path("skills") / "obsidian-cli",
        "display_name": "Obsidian CLI",
        "short_description": "Manual Obsidian vault operations through the Obsidian CLI",
        "default_prompt": "Use $obsidian-cli to manually read, create, search, or manage Obsidian vault notes.",
        "local_arg": "obsidian_cli_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
    },
    "obsidian-markdown": {
        "source_name": "skills_sh_kepano_obsidian_skills",
        "repo_dir_name": "kepano-obsidian-skills",
        "relative_path": Path("skills") / "obsidian-markdown",
        "display_name": "Obsidian Markdown",
        "short_description": "Manual Obsidian-flavored Markdown authoring",
        "default_prompt": "Use $obsidian-markdown to manually write Obsidian notes with wikilinks, callouts, embeds, and properties.",
        "local_arg": "obsidian_markdown_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
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
    "planning-with-files": {
        "source_name": "skills_sh_othmanadi_planning_with_files",
        "repo_dir_name": "planning-with-files",
        "relative_path": Path("skills") / "planning-with-files",
        "display_name": "Planning with Files",
        "short_description": "Manual file-based scratchpad planning for complex multi-step tasks",
        "default_prompt": "Use $planning-with-files to manually track a complex task with local planning files.",
        "local_arg": "planning_with_files_source_dir",
        "codex_adapter": False,
        "copy_root_license": True,
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


def fail(message: str) -> NoReturn:
    """Exit with a human-readable error message."""
    raise SystemExit(message)


def load_lock() -> dict[str, dict[str, str]]:
    """Load the source lock entries required by this sync."""
    if not LOCK_FILE.is_file():
        fail(f"missing source lock: {LOCK_FILE}")

    text = LOCK_FILE.read_text(encoding="utf-8")
    loaded: dict[str, dict[str, str]] = {}
    for config in SKILL_SOURCES.values():
        source_name = config["source_name"]
        block_match = re.search(
            rf"^  {re.escape(source_name)}:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
            text,
            flags=re.MULTILINE,
        )
        if not block_match:
            fail(f"missing {source_name} in {LOCK_FILE}")
        body = block_match.group("body")
        fields: dict[str, str] = {}
        for key in ("repo", "ref", "captured_at"):
            field_match = re.search(
                rf"^    {key}:\s*(?P<value>\S.+?)\s*$", body, flags=re.MULTILINE
            )
            if not field_match:
                fail(f"missing {source_name}.{key} in {LOCK_FILE}")
            fields[key] = field_match.group("value")
        loaded[source_name] = fields
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
    dest = DEST_SKILLS / skill_name

    source_skill_file = meta.get("source_skill_file")
    if source_skill_file:
        skill_file = src / str(source_skill_file)
        if not skill_file.is_file():
            fail(f"missing upstream skill file: {skill_file}")
        if dest.exists():
            shutil.rmtree(dest)
        dest.mkdir(parents=True)
        shutil.copy2(skill_file, dest / "SKILL.md")
    else:
        if not src.is_dir():
            fail(f"missing upstream skill directory: {src}")
        if not (src / "SKILL.md").is_file():
            fail(f"missing upstream SKILL.md: {src / 'SKILL.md'}")
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
        cloned_repos: dict[tuple[str, str, str], Path] = {}
        for skill_name, meta in sorted(SKILL_SOURCES.items()):
            local_dir = getattr(args, meta["local_arg"])
            if local_dir:
                repo_root = Path(local_dir).resolve()
            else:
                lock = locks[meta["source_name"]]
                checkout_key = (lock["repo"], lock["ref"], meta["repo_dir_name"])
                if checkout_key not in cloned_repos:
                    cloned_repos[checkout_key] = clone_upstream(
                        lock["repo"],
                        lock["ref"],
                        temp_root,
                        meta["repo_dir_name"],
                    )
                repo_root = cloned_repos[checkout_key]
            sync_skill(repo_root, skill_name)


if __name__ == "__main__":
    main()
