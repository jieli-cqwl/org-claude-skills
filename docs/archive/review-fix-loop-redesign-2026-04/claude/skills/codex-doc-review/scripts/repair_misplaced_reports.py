#!/usr/bin/env python3
"""Repair misplaced codex-doc-review reports inside a target repo."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import zlib
from datetime import datetime
from pathlib import Path


DOC_RE = re.compile(r"docs/[^`\"\s]+\.md")
SCOPE_RE = re.compile(r"(?:scope|stage|审查阶段(?:\s*\(stage\))?)\s*[:=]\s*([^\s,]+)")
STATUS_RE = re.compile(r"(?:status_code|状态码)\s*[:：]\s*`?([A-Z_]+)`?")


def scope_family(scope: str) -> str:
    value = scope.strip().strip("`\"").lower()
    if value.startswith("product"):
        return "product"
    if value.startswith("design"):
        return "design"
    if value.startswith("test-design") or value.startswith("test_design") or value.startswith("test-cases"):
        return "test-design"
    if value.startswith("tech-lead") or value.startswith("tech_lead") or value.startswith("techlead"):
        return "tech-lead"
    return ""


def parse_report(report: Path) -> tuple[list[str], str]:
    text = report.read_text(encoding="utf-8")
    docs = sorted({m.group(0) for m in DOC_RE.finditer(text) if not m.group(0).endswith("codex-doc-review-report.md")})
    scope_match = SCOPE_RE.search(text)
    scope = scope_match.group(1).strip("`\"") if scope_match else ""
    return docs, scope


def normalize_block(text: str) -> str:
    lines = [line.rstrip() for line in text.strip().splitlines()]
    return "\n".join(lines)


def semantic_signature(report: Path) -> tuple:
    text = report.read_text(encoding="utf-8")
    docs = tuple(sorted({m.group(0) for m in DOC_RE.finditer(text) if not m.group(0).endswith("codex-doc-review-report.md")}))
    scope_match = SCOPE_RE.search(text)
    status_match = STATUS_RE.search(text)

    sections: dict[str, list[str]] = {}
    current = None
    for line in text.splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            sections.setdefault(current, [])
            continue
        if current is not None:
            sections[current].append(line)

    return (
        docs,
        (scope_match.group(1).strip("`\"") if scope_match else ""),
        (status_match.group(1).strip("`\"") if status_match else ""),
        normalize_block("\n".join(sections.get("Findings", []))),
        normalize_block("\n".join(sections.get("DECEPTION", []))),
        normalize_block("\n".join(sections.get("Dimensions", []))),
        normalize_block("\n".join(sections.get("Summary", []))),
    )


def canonical_dir(repo_root: Path, docs: list[str], scope: str) -> Path | None:
    if not docs:
        return None

    features = sorted({doc.split("/", 2)[1] for doc in docs if doc.startswith("docs/")})
    if len(features) != 1:
        return None

    family = scope_family(scope)
    if not family:
        return None

    feature_root = repo_root / "docs" / features[0]
    if family == "product":
        if any("/phase-" in doc for doc in docs):
            return None
        return feature_root

    if family in {"design", "tech-lead"}:
        phases = sorted({"/".join(doc.split("/")[:3]) for doc in docs if re.match(r"docs/[^/]+/phase-\d+/", doc)})
        return (repo_root / phases[0]) if len(phases) == 1 else None

    if family == "test-design":
        units = sorted(
            {
                "/".join(doc.split("/")[:4])
                for doc in docs
                if re.match(r"docs/[^/]+/phase-\d+/unit-\d+/", doc)
            }
        )
        return (repo_root / units[0]) if len(units) == 1 else None

    return None


def short_digest(text: str) -> str:
    encoded = text.encode("utf-8")
    try:
        return hashlib.sha1(encoded).hexdigest()[:8]
    except (AttributeError, ValueError):
        return f"{zlib.crc32(encoded) & 0xFFFFFFFF:08x}"


def archive_path(report: Path, archive_root: Path, repo_root: Path) -> Path:
    rel = report.relative_to(repo_root)
    digest = short_digest(str(rel))
    return archive_root / f"{digest}" / rel


def repair_repo(repo_root: Path, dry_run: bool) -> int:
    reports = sorted(repo_root.rglob("codex-doc-review-report.md"))
    state_root = Path(os.environ.get("ORG_STATE_ROOT", str(Path.home() / ".org-skills-state"))).expanduser()
    archive_root = state_root / "archive" / "codex-doc-review-misplaced"
    stamp = os.environ.get("ORG_REPAIR_STAMP") or datetime.now().strftime("%Y%m%d%H%M%S")
    timestamp_root = archive_root / stamp

    changes = 0
    for report in reports:
        docs, scope = parse_report(report)
        canonical = canonical_dir(repo_root, docs, scope)
        if canonical is None:
            print(f"[skip] unresolved canonical dir: {report}")
            continue

        target = canonical / "codex-doc-review-report.md"
        if report == target:
            continue

        same_signature = target.exists() and semantic_signature(report) == semantic_signature(target)

        if dry_run:
            action = "delete-duplicate" if same_signature else (
                "archive-conflict" if target.exists() else "move"
            )
            print(f"[dry-run] {action}: {report} -> {target}")
            changes += 1
            continue

        canonical.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.move(str(report), str(target))
            print(f"[move] {report} -> {target}")
            changes += 1
            continue

        if same_signature:
            report.unlink()
            print(f"[delete-duplicate] {report}")
            changes += 1
            continue

        archived = archive_path(report, timestamp_root, repo_root)
        archived.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(report), str(archived))
        print(f"[archive-conflict] {report} -> {archived}")
        changes += 1

    return changes


def main() -> int:
    parser = argparse.ArgumentParser(description="Repair misplaced codex-doc-review reports")
    parser.add_argument("repo_root", nargs="?", default=".", help="target repo root")
    parser.add_argument("--dry-run", action="store_true", help="show actions without mutating files")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    if not repo_root.is_dir():
        print(f"[error] target root does not exist: {repo_root}")
        return 2

    changes = repair_repo(repo_root, dry_run=args.dry_run)
    print(f"[done] changes={changes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
