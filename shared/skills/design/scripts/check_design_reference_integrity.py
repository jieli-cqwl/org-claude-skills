#!/usr/bin/env python3
"""Check design.json semantic reference integrity that schema/rules don't cover.

Schema (`validate_canonical_schema`) enforces shapes and `canonical_design_rules`
enforces option_ref resolution within the same decision group, but NEITHER
enforces these cross-artifact / cross-section invariants:

  1. unit_coverage must enumerate every UNIT listed in
     phase-prd.unit_priority_order (no silently-dropped UNIT).
  2. unit_coverage[*].unit_id must exist in phase-prd.unit_priority_order
     (no phantom coverage entries).
  3. modules[*].unit_refs[*] must exist in phase-prd.unit_priority_order
     (no ghost UNIT references from design modules).
  4. quality_attributes[*].verification_refs, cross_cutting_concerns[*].
     verification_refs, impact_scope[*].verification_refs and
     risk_response[*].verification_refs must each resolve to a
     verification_mapping[*].evidence_ref.

A clean design.json passes silently (exit 0, JSON summary on stdout). Any
violation is reported as one JSONL line per issue on stderr with exit code 1.

Exit codes:
  0 - no violations
  1 - violations found
  2 - input errors (missing/malformed files, missing phase-prd or design.json)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI args; requires --phase-dir pointing at a phase directory."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--phase-dir",
        type=Path,
        required=True,
        help="Path to phase directory containing phase-prd.json and design.json",
    )
    return parser.parse_args(argv)


def load_json(path: Path) -> dict[str, Any]:
    """Read and parse a JSON file; exit 2 with message on failure."""
    if not path.is_file():
        raise SystemExit((2, f"file not found: {path}"))
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit((2, f"malformed JSON: {path}: {exc}")) from exc


def phase_unit_ids(phase_prd: dict[str, Any]) -> list[str]:
    """Return ordered list of unit_ids declared in phase-prd.unit_priority_order."""
    entries = phase_prd.get("unit_priority_order", [])
    if not isinstance(entries, list):
        return []
    return [
        e["unit_id"]
        for e in entries
        if isinstance(e, dict) and isinstance(e.get("unit_id"), str)
    ]


def check_unit_coverage(
    design: dict[str, Any], phase_unit_set: set[str]
) -> list[dict[str, Any]]:
    """Verify unit_coverage covers and only covers phase-prd UNITs."""
    violations: list[dict[str, Any]] = []
    coverage = design.get("unit_coverage", [])
    if not isinstance(coverage, list):
        return [{"type": "unit_coverage_not_array"}]

    covered = {
        e["unit_id"]
        for e in coverage
        if isinstance(e, dict) and isinstance(e.get("unit_id"), str)
    }
    missing = phase_unit_set - covered
    extra = covered - phase_unit_set

    for uid in sorted(missing):
        violations.append(
            {
                "type": "unit_not_covered_by_design",
                "unit_id": uid,
                "location": "design.json#unit_coverage",
            }
        )
    for uid in sorted(extra):
        violations.append(
            {
                "type": "unit_coverage_references_unknown_unit",
                "unit_id": uid,
                "location": "design.json#unit_coverage",
            }
        )
    return violations


def check_module_unit_refs(
    design: dict[str, Any], phase_unit_set: set[str]
) -> list[dict[str, Any]]:
    """Verify modules[*].unit_refs point to real UNITs."""
    violations: list[dict[str, Any]] = []
    modules = design.get("modules", [])
    if not isinstance(modules, list):
        return violations
    for idx, mod in enumerate(modules):
        if not isinstance(mod, dict):
            continue
        refs = mod.get("unit_refs", [])
        if not isinstance(refs, list):
            continue
        for ref in refs:
            if isinstance(ref, str) and ref not in phase_unit_set:
                violations.append(
                    {
                        "type": "module_references_unknown_unit",
                        "module_id": mod.get("module_id", f"modules[{idx}]"),
                        "unit_ref": ref,
                        "location": f"design.json#modules[{idx}].unit_refs",
                    }
                )
    return violations


def _collect_evidence_refs(design: dict[str, Any]) -> set[str]:
    """Gather all evidence_ref ids declared in verification_mapping."""
    mapping = design.get("verification_mapping", [])
    if not isinstance(mapping, list):
        return set()
    return {
        m["evidence_ref"]
        for m in mapping
        if isinstance(m, dict) and isinstance(m.get("evidence_ref"), str)
    }


def check_verification_refs(design: dict[str, Any]) -> list[dict[str, Any]]:
    """Verify verification_refs across several sections resolve to evidence_refs."""
    violations: list[dict[str, Any]] = []
    evidence = _collect_evidence_refs(design)
    sections = (
        ("quality_attributes", "verification_refs"),
        ("cross_cutting_concerns", "verification_refs"),
        ("impact_scope", "verification_refs"),
        ("risk_response", "verification_refs"),
    )
    for section, field in sections:
        items = design.get(section, [])
        if not isinstance(items, list):
            continue
        for idx, item in enumerate(items):
            if not isinstance(item, dict):
                continue
            refs = item.get(field, [])
            if not isinstance(refs, list):
                continue
            for ref in refs:
                if isinstance(ref, str) and ref not in evidence:
                    violations.append(
                        {
                            "type": "verification_ref_not_in_mapping",
                            "section": section,
                            "index": idx,
                            "verification_ref": ref,
                            "location": f"design.json#{section}[{idx}].{field}",
                        }
                    )
    return violations


def main(argv: list[str]) -> int:
    """CLI entry: report all violations; exit 1 if any found."""
    args = parse_args(argv)
    phase_dir = args.phase_dir
    if not phase_dir.is_dir():
        print(f"phase-dir not found: {phase_dir}", file=sys.stderr)
        return 2
    phase_prd_path = phase_dir / "phase-prd.json"
    design_path = phase_dir / "design.json"
    if not design_path.is_file():
        print(f"design.json not found: {design_path}", file=sys.stderr)
        return 2
    phase_prd = load_json(phase_prd_path)
    design = load_json(design_path)
    phase_units = set(phase_unit_ids(phase_prd))

    violations: list[dict[str, Any]] = []
    violations.extend(check_unit_coverage(design, phase_units))
    violations.extend(check_module_unit_refs(design, phase_units))
    violations.extend(check_verification_refs(design))

    if not violations:
        print(
            json.dumps(
                {
                    "status": "PASS",
                    "checked_units": len(phase_units),
                    "checks": [
                        "unit_coverage_completeness",
                        "module_unit_refs",
                        "verification_ref_resolution",
                    ],
                },
                ensure_ascii=False,
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
