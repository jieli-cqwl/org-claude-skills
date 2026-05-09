#!/usr/bin/env python3
"""Check M-S7 terminology consistency across all UNIT definitions.

Detects terminology drift by scanning all text fields in units/UNIT-*.json
for known synonym clusters. A synonym cluster is a set of terms that should
not coexist in the same Phase (e.g., {"token", "会话标识"} -> pick one).

The default cluster list is loaded from terminology_clusters.json in the
same directory; users may override via --clusters.

Exit codes:
  0 - all clusters have at most one preferred term in use
  1 - drift detected (multiple synonyms from the same cluster appear)
  2 - input errors (missing/malformed files)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


DEFAULT_CLUSTERS: list[dict[str, Any]] = [
    {
        "cluster_id": "session-identifier",
        "description": "会话/令牌标识的统一表达",
        "synonyms": ["token", "令牌", "会话标识", "session_id", "sessionId"],
        "preferred": "会话标识",
        "exclude_contexts": [],
    },
    {
        "cluster_id": "session-state",
        "description": "登录后状态的统一表达",
        "synonyms": ["会话", "登录状态", "认证状态", "登录态"],
        "preferred": "会话",
        "exclude_contexts": ["无认证状态", "未认证状态"],
    },
]


TEXT_FIELD_PATHS = (
    ("what",),
    ("why",),
    ("business_value",),
    ("input",),
    ("output",),
    ("integration_context", "protected_behaviors"),
    ("integration_context", "business_constraints"),
    ("acceptance_criteria",),
    ("verification_plan",),
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI args; phase-dir points at the phase directory containing units/."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument(
        "--clusters",
        type=Path,
        help="Optional path to a JSON file with cluster definitions (overrides defaults)",
    )
    return parser.parse_args(argv)


def load_json(path: Path) -> Any:
    """Read and parse a JSON file; raise SystemExit(2) on failure."""
    if not path.is_file():
        raise SystemExit((2, f"file not found: {path}"))
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit((2, f"malformed JSON: {path}: {exc}")) from exc


def load_units(phase_dir: Path) -> list[dict[str, Any]]:
    """Load every units/UNIT-*.json; empty list if directory missing."""
    units_dir = phase_dir / "units"
    if not units_dir.is_dir():
        return []
    return [load_json(p) for p in sorted(units_dir.glob("UNIT-*.json"))]


def walk_strings(node: Any) -> list[str]:
    """Recursively collect every string leaf from a nested structure."""
    out: list[str] = []
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, list):
        for item in node:
            out.extend(walk_strings(item))
    elif isinstance(node, dict):
        for value in node.values():
            out.extend(walk_strings(value))
    return out


def gather_unit_text(unit: dict[str, Any]) -> str:
    """Concatenate all free-text fields relevant to terminology drift."""
    chunks: list[str] = []
    for path in TEXT_FIELD_PATHS:
        node: Any = unit
        for key in path:
            if not isinstance(node, dict):
                node = None
                break
            node = node.get(key)
        if node is not None:
            chunks.extend(walk_strings(node))
    return "\n".join(chunks)


def find_hits(text: str, synonyms: list[str], exclude_contexts: list[str]) -> dict[str, int]:
    """Return {synonym: occurrence_count} for synonyms that appear in text.

    Occurrences swallowed by any exclude_context phrase are not counted
    (e.g., "认证状态" inside "无认证状态" is ignored when the latter is
    listed as an exclude_context).
    """
    # First mask out exclude_context phrases from the text so synonyms inside
    # them are invisible to the subsequent scan.
    masked = text
    for phrase in exclude_contexts:
        if phrase:
            masked = masked.replace(phrase, " " * len(phrase))
    hits: dict[str, int] = {}
    for term in synonyms:
        pattern = re.escape(term)
        count = len(re.findall(pattern, masked, flags=re.IGNORECASE))
        if count > 0:
            hits[term] = count
    return hits


def detect_drift(
    units: list[dict[str, Any]], clusters: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Return per-cluster drift reports; empty list means fully consistent."""
    findings: list[dict[str, Any]] = []
    for cluster in clusters:
        synonyms = cluster.get("synonyms", [])
        preferred = cluster.get("preferred")
        exclude_contexts = cluster.get("exclude_contexts", []) or []
        per_unit_hits: dict[str, dict[str, int]] = {}
        global_terms: set[str] = set()
        for unit in units:
            uid = unit.get("unit_id", "<unknown>")
            text = gather_unit_text(unit)
            hits = find_hits(text, synonyms, exclude_contexts)
            if hits:
                per_unit_hits[uid] = hits
                global_terms.update(hits.keys())
        if len(global_terms) > 1:
            findings.append(
                {
                    "cluster_id": cluster.get("cluster_id"),
                    "preferred": preferred,
                    "terms_in_use": sorted(global_terms),
                    "per_unit": per_unit_hits,
                }
            )
    return findings


def main(argv: list[str]) -> int:
    """CLI entry: print findings as JSON, exit 1 on drift."""
    args = parse_args(argv)
    if not args.phase_dir.is_dir():
        print(f"phase-dir not found: {args.phase_dir}", file=sys.stderr)
        return 2
    clusters = load_json(args.clusters) if args.clusters else DEFAULT_CLUSTERS
    if not isinstance(clusters, list):
        print("clusters must be a JSON array", file=sys.stderr)
        return 2
    units = load_units(args.phase_dir)
    findings = detect_drift(units, clusters)
    if not findings:
        print(
            json.dumps(
                {
                    "status": "PASS",
                    "checked_units": len(units),
                    "checked_clusters": len(clusters),
                },
                ensure_ascii=False,
            )
        )
        return 0
    for f in findings:
        print(json.dumps(f, ensure_ascii=False), file=sys.stderr)
    print(
        json.dumps(
            {"status": "FAIL", "drift_clusters": len(findings)}, ensure_ascii=False
        )
    )
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except SystemExit as exc:
        val = exc.code
        if isinstance(val, tuple):
            code, msg = val
            print(msg, file=sys.stderr)
            raise SystemExit(code) from None
        raise
