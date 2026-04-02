#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
LOCK_FILE = ROOT / "community" / "SOURCES.yaml"
ANTHROPIC_ROOT = ROOT / "community" / "anthropic"
DEST_SKILLS = ANTHROPIC_ROOT / "skills"
DEST_CODEX_SKILLS = ANTHROPIC_ROOT / "codex" / "skills"

DISPLAY_NAMES = {
    "algorithmic-art": "Algorithmic Art",
    "brand-guidelines": "Brand Guidelines",
    "canvas-design": "Canvas Design",
    "claude-api": "Claude API",
    "doc-coauthoring": "Doc Coauthoring",
    "docx": "DOCX",
    "frontend-design": "Frontend Design",
    "internal-comms": "Internal Comms",
    "mcp-builder": "MCP Builder",
    "pdf": "PDF",
    "pptx": "PPTX",
    "skill-creator": "Skill Creator",
    "slack-gif-creator": "Slack GIF Creator",
    "theme-factory": "Theme Factory",
    "web-artifacts-builder": "Web Artifacts Builder",
    "webapp-testing": "Webapp Testing",
    "xlsx": "XLSX",
}

SHORT_DESCRIPTIONS = {
    "algorithmic-art": "Generative art with p5.js and seeded randomness",
    "brand-guidelines": "Apply Anthropic brand colors and typography",
    "canvas-design": "Create visual art in PNG and PDF formats",
    "claude-api": "Build apps with Claude API and SDKs",
    "doc-coauthoring": "Structured workflow for co-authoring documents",
    "docx": "Create, inspect, and edit Word documents",
    "frontend-design": "Build distinctive production-grade frontend UIs",
    "internal-comms": "Write internal communications in company formats",
    "mcp-builder": "MCP Server development and tool definition",
    "pdf": "Create, edit, extract, and process PDF files",
    "pptx": "Create, inspect, and edit PowerPoint decks",
    "skill-creator": "Create, test, benchmark, and improve skills",
    "slack-gif-creator": "Create animated GIFs optimized for Slack",
    "theme-factory": "Apply or generate themes for visual artifacts",
    "web-artifacts-builder": "Build complex HTML artifacts with modern web UI",
    "webapp-testing": "Test local web apps with Playwright tooling",
    "xlsx": "Create, inspect, and edit spreadsheet files",
}

DEFAULT_PROMPTS = {
    "algorithmic-art": "Use $algorithmic-art to create original algorithmic art with code.",
    "brand-guidelines": "Use $brand-guidelines to apply Anthropic brand styling.",
    "canvas-design": "Use $canvas-design to create static visual designs.",
    "claude-api": "Use $claude-api to build with the Claude API or SDK.",
    "doc-coauthoring": "Use $doc-coauthoring to co-author structured documentation.",
    "docx": "Use $docx to create, inspect, or edit Word documents.",
    "frontend-design": "Use $frontend-design to build polished frontend interfaces.",
    "internal-comms": "Use $internal-comms to draft internal communications.",
    "mcp-builder": "Use $mcp-builder to build an MCP server for [service].",
    "pdf": "Use $pdf to create, inspect, or process PDF files.",
    "pptx": "Use $pptx to create, inspect, or edit presentation decks.",
    "skill-creator": "Use $skill-creator to create or improve a skill.",
    "slack-gif-creator": "Use $slack-gif-creator to create a Slack-ready GIF.",
    "theme-factory": "Use $theme-factory to apply or create a visual theme.",
    "web-artifacts-builder": "Use $web-artifacts-builder to build a complex web artifact.",
    "webapp-testing": "Use $webapp-testing to test a local web application.",
    "xlsx": "Use $xlsx to create, inspect, or edit spreadsheet files.",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def load_lock() -> dict:
    if not LOCK_FILE.is_file():
        fail(f"missing source lock: {LOCK_FILE}")
    data = yaml.safe_load(LOCK_FILE.read_text(encoding="utf-8"))
    try:
        return data["sources"]["anthropic_skills"]
    except KeyError:
        fail(f"missing anthropic_skills in {LOCK_FILE}")


def clone_upstream(repo: str, ref: str, workdir: Path) -> Path:
    checkout = workdir / "anthropic-skills"
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
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def render_openai_yaml(skill_name: str) -> str:
    return (
        "interface:\n"
        f'  display_name: "{DISPLAY_NAMES[skill_name]}"\n'
        f'  short_description: "{SHORT_DESCRIPTIONS[skill_name]}"\n'
        f'  default_prompt: "{DEFAULT_PROMPTS[skill_name]}"\n'
    )


def generate_codex_adapters(skill_names: list[str]) -> None:
    if DEST_CODEX_SKILLS.exists():
        shutil.rmtree(DEST_CODEX_SKILLS)
    for skill_name in skill_names:
        adapter_dir = DEST_CODEX_SKILLS / skill_name / "agents"
        adapter_dir.mkdir(parents=True, exist_ok=True)
        (adapter_dir / "openai.yaml").write_text(
            render_openai_yaml(skill_name),
            encoding="utf-8",
        )


def discover_skill_names(skills_root: Path) -> list[str]:
    skill_names = sorted(
        path.name
        for path in skills_root.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    )
    if sorted(DISPLAY_NAMES) != skill_names:
        fail(
            "official skill set changed; update adapter metadata map first. "
            f"expected={sorted(DISPLAY_NAMES)} actual={skill_names}"
        )
    return skill_names


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sync Anthropic official skills into community/anthropic and generate Codex adapters."
    )
    parser.add_argument(
        "--source-dir",
        help="Use an existing local anthropics/skills checkout instead of cloning from source lock.",
    )
    args = parser.parse_args()

    lock = load_lock()
    if args.source_dir:
        repo_root = Path(args.source_dir).resolve()
    else:
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = clone_upstream(lock["repo"], lock["ref"], Path(tmp))
            skills_root = repo_root / "skills"
            skill_names = discover_skill_names(skills_root)
            DEST_SKILLS.parent.mkdir(parents=True, exist_ok=True)
            sync_tree(skills_root, DEST_SKILLS)
            generate_codex_adapters(skill_names)
            return

    skills_root = repo_root / "skills"
    if not skills_root.is_dir():
        fail(f"missing skills directory in source: {skills_root}")

    skill_names = discover_skill_names(skills_root)
    DEST_SKILLS.parent.mkdir(parents=True, exist_ok=True)
    sync_tree(skills_root, DEST_SKILLS)
    generate_codex_adapters(skill_names)


if __name__ == "__main__":
    main()
