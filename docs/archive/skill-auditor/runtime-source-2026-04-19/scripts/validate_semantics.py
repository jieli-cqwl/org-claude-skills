#!/usr/bin/env python3
"""Validate semantic invariants for skill-auditor runtime artifacts."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


KNOWN_ANCHORS = {
    "SO-TRIGGER-01",
    "SO-LOAD-01",
    "SO-REFERENCE-01",
    "SO-PERMISSION-01",
    "SO-SCRIPT-01",
    "SO-SUBAGENT-01",
    "SO-RUNTIME-01",
    "SO-VALIDATION-01",
    "SO-MIGRATION-01",
    "SO-TRACKING-01",
}
KNOWN_SOURCE_MARKERS = {"C09", "C10", "C11", "C12", "C13", "C14", "C99", "L", "O", "S"}
KNOWN_DIMENSIONS = {"D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"}
LEGACY_DIMENSION_LABELS = {
    "D1 结构合规",
    "D2 闭环自治",
    "D3 I/O 契约",
    "D4 角色与对抗",
    "D5 验证即证据",
    "D6 Token 效率",
    "D7 跨模型适配",
}
MARKDOWN_SUFFIXES = (".md", ".markdown", ".html", ".htm")


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        fail(f"file not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"top-level JSON must be object: {path}")
    return data


def ensure_known_anchors(anchors: Any, field_name: str) -> None:
    if not isinstance(anchors, list) or not anchors:
        fail(f"{field_name} must be a non-empty array")
    unknown = [anchor for anchor in anchors if anchor not in KNOWN_ANCHORS]
    if unknown:
        fail(f"{field_name} contains unknown anchors: {', '.join(map(str, unknown))}")


def validate_inputs(inputs: Any) -> None:
    if not isinstance(inputs, list) or not inputs:
        fail("inputs must be a non-empty array")
    for item in inputs:
        if not isinstance(item, dict):
            fail("inputs entries must be objects")
        path = str(item.get("path", ""))
        role = item.get("role")
        if role == "fact_source" and path.endswith(MARKDOWN_SUFFIXES):
            fail("Markdown/HTML cannot be runtime fact source")


def evidence_ids(evidence_refs: Any) -> set[str]:
    ids: set[str] = set()
    if not isinstance(evidence_refs, list):
        fail("evidence_refs must be an array")
    for entry in evidence_refs:
        if isinstance(entry, dict) and "id" in entry:
            ids.add(str(entry["id"]))
    return ids


def validate_findings(findings: Any, top_evidence_ids: set[str]) -> None:
    if not isinstance(findings, list):
        fail("findings must be an array")
    for finding in findings:
        if not isinstance(finding, dict):
            fail("finding entries must be objects")
        severity = finding.get("severity")
        dimension = finding.get("dimension")
        source_marker = finding.get("source_marker")
        evidence_level = finding.get("evidence_level")
        if dimension in LEGACY_DIMENSION_LABELS or dimension not in KNOWN_DIMENSIONS:
            fail(f"finding {finding.get('id')} has invalid quality dimension: {dimension}")
        if source_marker not in KNOWN_SOURCE_MARKERS:
            fail(f"finding {finding.get('id')} has unknown source marker: {source_marker}")
        ensure_known_anchors(finding.get("design_anchors"), f"finding {finding.get('id')} design_anchors")
        for field in ("file_ref", "impact", "recommendation", "verification"):
            if not isinstance(finding.get(field), str) or not finding.get(field).strip():
                fail(f"finding {finding.get('id')} missing {field}")
        refs = finding.get("evidence_refs")
        if not isinstance(refs, list) or not refs:
            fail(f"finding {finding.get('id')} missing evidence_refs")
        missing_refs = [ref for ref in refs if str(ref) not in top_evidence_ids]
        if missing_refs:
            fail(f"finding {finding.get('id')} references missing evidence ids: {missing_refs}")
        if severity == "FAIL":
            if evidence_level == "E5":
                fail(f"E5 finding {finding.get('id')} cannot be FAIL hard gate")


def validate(artifact: dict[str, Any]) -> None:
    ensure_known_anchors(artifact.get("design_anchors"), "design_anchors")
    validate_inputs(artifact.get("inputs"))
    ids = evidence_ids(artifact.get("evidence_refs"))
    validate_findings(artifact.get("findings"), ids)


def main(argv: list[str]) -> None:
    if len(argv) != 2:
        fail("usage: validate_semantics.py <artifact.json>")
    validate(load_json(Path(argv[1])))


if __name__ == "__main__":
    main(sys.argv)
