#!/usr/bin/env python3
"""Check UNIT split priority consistency: detect high-priority UNITs depending on low-priority UNITs.

Reads phase-prd.json's unit_priority_order and scans units/UNIT-*.json's
integration_context.cross_unit_dependencies. Reports any UNIT whose priority
is strictly higher than a UNIT it depends on (e.g., P0 depends on P1).

Exit codes:
  0 - no violations
  1 - violations found (printed to stderr as JSON lines)
  2 - input errors (missing/malformed files)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


PRIORITY_RANK = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI args; requires --phase-dir pointing at a phase directory."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--phase-dir",
        type=Path,
        required=True,
        help="Path to phase directory containing phase-prd.json and units/",
    )
    return parser.parse_args(argv)


def load_json(path: Path) -> dict[str, Any]:
    """Read and parse a JSON file; raise SystemExit with code 2 on failure."""
    if not path.is_file():
        raise SystemExit((2, f"file not found: {path}"))
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit((2, f"malformed JSON: {path}: {exc}")) from exc


def load_priority_map(phase_prd: dict[str, Any]) -> dict[str, str]:
    """Extract a {unit_id: priority} map from phase-prd.unit_priority_order."""
    entries = phase_prd.get("unit_priority_order", [])
    if not isinstance(entries, list):
        raise SystemExit((2, "phase-prd.unit_priority_order must be an array"))
    result: dict[str, str] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        uid = entry.get("unit_id")
        prio = entry.get("priority")
        if isinstance(uid, str) and isinstance(prio, str):
            result[uid] = prio
    return result


def load_units(phase_dir: Path) -> list[dict[str, Any]]:
    """Load all UNIT-*.json files in phase_dir/units/ (empty if dir absent)."""
    units_dir = phase_dir / "units"
    if not units_dir.is_dir():
        return []
    return [load_json(p) for p in sorted(units_dir.glob("UNIT-*.json"))]


def extract_dependencies(unit: dict[str, Any]) -> list[str]:
    """Return the list of unit_ids this UNIT depends on via integration_context.

    Accepts either the canonical schema shape (list of strings, e.g.
    ``["UNIT-2"]``) or the richer dict shape (``[{"depends_on": "UNIT-2",
    "reason": "..."}]``) some earlier drafts used. Non-matching items are
    skipped silently.
    """
    ctx = unit.get("integration_context", {})
    if not isinstance(ctx, dict):
        return []
    deps = ctx.get("cross_unit_dependencies", [])
    if not isinstance(deps, list):
        return []
    result: list[str] = []
    for dep in deps:
        if isinstance(dep, str):
            result.append(dep)
        elif isinstance(dep, dict) and isinstance(dep.get("depends_on"), str):
            result.append(dep["depends_on"])
    return result


def check_violations(
    priority_map: dict[str, str], units: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Return a list of {unit_id, unit_priority, depends_on, dep_priority} violations."""
    violations: list[dict[str, Any]] = []
    for unit in units:
        uid = unit.get("unit_id")
        if not isinstance(uid, str):
            continue
        my_prio = priority_map.get(uid)
        if my_prio is None:
            violations.append(
                {
                    "type": "unit_missing_in_priority_order",
                    "unit_id": uid,
                }
            )
            continue
        my_rank = PRIORITY_RANK.get(my_prio, 99)
        for dep_id in extract_dependencies(unit):
            dep_prio = priority_map.get(dep_id)
            if dep_prio is None:
                violations.append(
                    {
                        "type": "dependency_not_in_priority_order",
                        "unit_id": uid,
                        "depends_on": dep_id,
                    }
                )
                continue
            dep_rank = PRIORITY_RANK.get(dep_prio, 99)
            if my_rank < dep_rank:
                violations.append(
                    {
                        "type": "high_priority_depends_on_low_priority",
                        "unit_id": uid,
                        "unit_priority": my_prio,
                        "depends_on": dep_id,
                        "dep_priority": dep_prio,
                    }
                )
    return violations


def main(argv: list[str]) -> int:
    """CLI entry: print violations as JSON lines, exit 1 if any found."""
    args = parse_args(argv)
    phase_dir = args.phase_dir
    if not phase_dir.is_dir():
        print(f"phase-dir not found: {phase_dir}", file=sys.stderr)
        return 2
    phase_prd = load_json(phase_dir / "phase-prd.json")
    priority_map = load_priority_map(phase_prd)
    units = load_units(phase_dir)
    violations = check_violations(priority_map, units)
    if not violations:
        print(
            json.dumps(
                {"status": "PASS", "checked_units": len(units)}, ensure_ascii=False
            )
        )
        return 0
    for v in violations:
        print(json.dumps(v, ensure_ascii=False), file=sys.stderr)
    print(
        json.dumps(
            {"status": "FAIL", "violation_count": len(violations)},
            ensure_ascii=False,
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
