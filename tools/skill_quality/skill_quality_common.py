"""Shared helpers for deterministic Skill quality audit scripts."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
NAME_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$")
HISTORICAL_SKILL_DIRS = {"test-design-h"}
ACTIVE_DOC_SUBDIRS = ("references", "projections")


def repo_ref(path: Path, line: int) -> str:
    return f"{path.relative_to(REPO_ROOT).as_posix()}:{line}"


def resolve_skill_path(raw: str) -> Path:
    path = Path(raw)
    if not path.is_absolute():
        path = (REPO_ROOT / path).resolve()
    else:
        path = path.resolve()
    try:
        path.relative_to(REPO_ROOT)
    except ValueError:
        raise SystemExit(f"[FAIL] path must be repo-local: {raw}")
    if path.is_dir():
        path = path / "SKILL.md"
    if path.name != "SKILL.md" or not path.is_file():
        raise SystemExit(f"[FAIL] missing SKILL.md: {raw}")
    return path


def contains_xml_tag(text: str) -> bool:
    return bool(re.search(r"<[A-Za-z][^>\n]{0,80}>", text))


def priority_for(severity: str, dimension: str) -> str:
    if severity == "FAIL" and dimension in {"G0", "G1", "G2", "S5", "S7"}:
        return "P0"
    if severity == "FAIL":
        return "P1"
    if severity == "WARN":
        return "P2"
    return "P3"


def scope_for(dimension: str) -> str:
    return {
        "G0": "frontmatter",
        "G1": "adapter",
        "G2": "resource",
        "S1": "frontmatter",
        "S2": "body",
        "S3": "body",
        "S4": "resource",
        "S5": "script",
        "S6": "artifact",
        "S7": "eval",
        "S8": "adapter",
    }.get(dimension, "body")


def skill_id_for(path: Path) -> str:
    try:
        parts = path.resolve().relative_to(REPO_ROOT).parts
    except ValueError:
        parts = ()
    if len(parts) >= 3 and parts[0] == "shared" and parts[1] == "skills":
        return parts[2]
    return path.parent.name if path.name == "SKILL.md" else path.parent.parent.name


def iter_active_skill_docs(root: Path = REPO_ROOT) -> list[Path]:
    docs: list[Path] = []
    skills_dir = root / "shared" / "skills"
    if not skills_dir.is_dir():
        return docs
    for skill_dir in sorted(path for path in skills_dir.iterdir() if path.is_dir()):
        if skill_dir.name in HISTORICAL_SKILL_DIRS:
            continue
        docs.extend(iter_skill_runtime_docs(skill_dir))
    return docs


def iter_skill_runtime_docs(path: Path) -> list[Path]:
    target = path.resolve()
    if target.is_file():
        return [target]
    docs: list[Path] = []
    skill_file = target / "SKILL.md"
    if skill_file.is_file():
        docs.append(skill_file)
    for subdir_name in ACTIVE_DOC_SUBDIRS:
        subdir = target / subdir_name
        if subdir.is_dir():
            docs.extend(sorted(subdir.rglob("*.md")))
    return docs


def base_finding(
    *,
    code: str,
    severity: str,
    dimension: str,
    path: Path,
    line: int,
    evidence: str,
    impact: str,
    recommendation: str,
    verification: str,
    false_positive_guard: str | None = None,
) -> dict[str, Any]:
    file_ref = repo_ref(path, line)
    finding: dict[str, Any] = {
        "code": code,
        "severity": severity,
        "dimension": dimension,
        "priority": priority_for(severity, dimension),
        "skill_id": skill_id_for(path),
        "runtime_target": "repo-static",
        "scope": scope_for(dimension),
        "owner": "skill-author",
        "file_ref": file_ref,
        "evidence_refs": [file_ref],
        "impact": impact,
        "recommendation": recommendation,
        "verification": verification,
        "evidence": evidence,
    }
    if false_positive_guard:
        finding["false_positive_guard"] = false_positive_guard
    return finding
