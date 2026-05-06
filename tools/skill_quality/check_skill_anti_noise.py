#!/usr/bin/env python3
"""Detect active Skill runtime docs that duplicate machine contracts as prose."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from skill_quality_common import (
    REPO_ROOT,
    base_finding,
    iter_active_skill_docs,
    iter_skill_runtime_docs,
)

RESOURCE_FIELDS = ("Trigger", "Read", "Expect", "Consume", "Evidence", "Sync")
RESOURCE_HEADER_RE = re.compile(r"^(Trigger|Read|Expect|Consume|Evidence|Sync):")
SOP_SELF_EXPLANATION_RE = re.compile(
    r"顶层 sections 包含|本\s*(?:SOP|文件|文档|正文)\s*不(?:重复|展开)|字段全集"
)
FIELD_SECTION_INVENTORY_RE = re.compile(
    r"(?:顶层\s*)?sections?\s*包含|字段清单|字段全集"
)
PROJECTION_CONTROL_RE = re.compile(
    r"all columns required|<!--\s*(?:conditional:\s*)?required(?:[,\s][^>]*)?-->|required,\s*enum|引用锚点合同"
)
CANONICAL_FIELD_PROSE_RE = re.compile(r"canonical 字段：")


SPEC: dict[str, tuple[str, str, str, str, str]] = {
    "SOP_SELF_EXPLANATION_NOISE": (
        "FAIL",
        "S4",
        "Skill prose explains why it does not repeat a machine contract instead of giving an execution instruction.",
        "Self-explanatory SOP text consumes context without changing execution behavior.",
        "Keep the schema/template/validator route and remove the self-explanation.",
    ),
    "FIELD_SECTION_INVENTORY_NOISE": (
        "FAIL",
        "S6",
        "Skill body repeats top-level artifact sections that belong to schema/template/validator.",
        "The Skill body becomes a second, drifting source of artifact shape truth.",
        "Replace the section inventory with a template/schema/validator route.",
    ),
    "RESOURCE_HEADER_NOISE": (
        "FAIL",
        "S4",
        "Runtime reference uses Trigger/Read/Expect/Consume/Evidence/Sync header prose.",
        "Resource contract headers make references self-describe instead of being loaded from a specific workflow step.",
        "Route references from the workflow with concise wording such as read X and extract Y.",
    ),
    "PROJECTION_CONTROL_NOISE": (
        "FAIL",
        "S6",
        "Projection contains required/type/enum or anchor-control machine contract prose.",
        "Human projections can drift into runtime control inputs and compete with canonical JSON contracts.",
        "Keep human-readable labels/examples and move required/type/enum/anchor rules to schema/template/validator.",
    ),
    "CANONICAL_FIELD_PROSE_NOISE": (
        "FAIL",
        "S6",
        "Projection repeats canonical field rules as prose.",
        "Canonical field rules in projections duplicate schema/template/validator contracts.",
        "Use JSON pointers for readability, but keep field rules in machine contracts.",
    ),
}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument(
        "--path", help="Skill directory, SKILL.md, reference, or projection to audit"
    )
    scope.add_argument(
        "--scope",
        choices=("active", "standard-chain"),
        help="Repository scope to audit",
    )
    return parser.parse_args(argv)


def docs_for(args: argparse.Namespace) -> list[Path]:
    if args.path:
        raw = Path(args.path)
        target = raw if raw.is_absolute() else REPO_ROOT / raw
        target = target.resolve()
        try:
            target.relative_to(REPO_ROOT)
        except ValueError:
            raise SystemExit(f"[FAIL] path must be repo-local: {args.path}")
        if not target.exists():
            raise SystemExit(f"[FAIL] path not found: {args.path}")
        if target.is_file():
            return [target]
        return iter_skill_runtime_docs(target)
    docs = iter_active_skill_docs(REPO_ROOT)
    if args.scope == "standard-chain":
        standard = {
            "product-director",
            "product-manager",
            "design",
            "test-design",
            "tech-lead",
            "delivery-owner",
            "developer",
            "review",
            "verify",
            "qa",
            "fix",
            "consistency-audit",
        }
        docs = [path for path in docs if skill_name_for(path) in standard]
    return docs


def skill_name_for(path: Path) -> str:
    parts = path.relative_to(REPO_ROOT).parts
    if len(parts) >= 3 and parts[0] == "shared" and parts[1] == "skills":
        return parts[2]
    if path.name == "SKILL.md":
        return path.parent.name
    return path.parent.name


def line_for(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def emit(findings: list[dict[str, Any]], path: Path, line: int, code: str) -> None:
    severity, dimension, evidence, impact, recommendation = SPEC[code]
    findings.append(
        base_finding(
            code=code,
            severity=severity,
            dimension=dimension,
            path=path,
            line=line,
            evidence=evidence,
            impact=impact,
            recommendation=recommendation,
            verification="python3 tools/skill_quality/check_skill_anti_noise.py --scope active",
            false_positive_guard="Applies only to active runtime docs, not archives, fixtures, or eval outputs.",
        )
    )


def has_all_resource_headers(lines: list[str], start_index: int) -> bool:
    seen: set[str] = set()
    for line in lines[start_index : start_index + 8]:
        stripped = line.strip()
        for field in RESOURCE_FIELDS:
            if re.search(rf"(?:^|\s){field}:", stripped):
                seen.add(field)
    return set(RESOURCE_FIELDS).issubset(seen)


def check_doc(path: Path) -> list[dict[str, Any]]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    findings: list[dict[str, Any]] = []
    is_projection = "/projections/" in path.as_posix()
    is_skill = path.name == "SKILL.md"

    for index, line in enumerate(lines):
        if RESOURCE_HEADER_RE.match(line.strip()) and has_all_resource_headers(
            lines, index
        ):
            emit(findings, path, index + 1, "RESOURCE_HEADER_NOISE")
            break

    for match in SOP_SELF_EXPLANATION_RE.finditer(text):
        emit(
            findings, path, line_for(text, match.start()), "SOP_SELF_EXPLANATION_NOISE"
        )
        break

    if is_skill:
        for match in FIELD_SECTION_INVENTORY_RE.finditer(text):
            emit(
                findings,
                path,
                line_for(text, match.start()),
                "FIELD_SECTION_INVENTORY_NOISE",
            )
            break

    if is_projection:
        for match in PROJECTION_CONTROL_RE.finditer(text):
            emit(
                findings,
                path,
                line_for(text, match.start()),
                "PROJECTION_CONTROL_NOISE",
            )
            break
        for match in CANONICAL_FIELD_PROSE_RE.finditer(text):
            emit(
                findings,
                path,
                line_for(text, match.start()),
                "CANONICAL_FIELD_PROSE_NOISE",
            )
            break

    return findings


def status_for(findings: list[dict[str, Any]]) -> str:
    return "static_fail" if findings else "static_pass"


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    docs = docs_for(args)
    findings: list[dict[str, Any]] = []
    for path in docs:
        findings.extend(check_doc(path))
    result = {
        "artifact_type": "skill-anti-noise-audit",
        "target": args.path or args.scope,
        "status": status_for(findings),
        "finding_count": len(findings),
        "findings": findings,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
