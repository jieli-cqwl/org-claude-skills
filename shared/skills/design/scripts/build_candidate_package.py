#!/usr/bin/env python3
"""Build an S8 design candidate package from a design JSON artifact."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from review_digest import candidate_digest


FINAL_ONLY_FIELDS = {"review_closure", "final_confirmation"}


def load_json_object(path: Path, label: str) -> dict:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"{label} not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{label} must be JSON: {exc}") from exc

    if not isinstance(payload, dict):
        raise SystemExit(f"{label} must contain a JSON object")
    return payload


def strip_final_fields(payload: dict) -> dict:
    candidate = dict(payload)
    for field in FINAL_ONLY_FIELDS:
        candidate.pop(field, None)
    return candidate


def build_source_refs(design_path: Path, candidate: dict) -> list[dict]:
    phase_dir = design_path.absolute().parent
    feature_dir = phase_dir.parent
    refs = [
        {"kind": "design_source", "path": str(design_path.absolute())},
        {"kind": "brief", "path": str(feature_dir / "brief.json")},
        {"kind": "phase_prd", "path": str(phase_dir / "phase-prd.json")},
    ]
    for unit_path in sorted((phase_dir / "units").glob("UNIT-*.json")):
        refs.append({"kind": "unit", "path": str(unit_path)})

    product_handoff = candidate.get("product_handoff")
    if isinstance(product_handoff, dict):
        for ref in product_handoff.get("accepted_refs", []):
            if isinstance(ref, str) and ref:
                refs.append({"kind": "handoff_ref", "path": ref})
    return refs


def build_co_creation_confirmations(candidate: dict) -> list[dict]:
    confirmations = []
    for row in candidate.get("co_creation_summary", []):
        if not isinstance(row, dict):
            continue
        confirmations.append(
            {
                "stage_id": row.get("stage_id", ""),
                "stage_name": row.get("stage_name", ""),
                "summary": row.get("user_response_summary", ""),
                "decision_refs": row.get("decision_refs", []),
            }
        )
    return confirmations


def build_open_warns(payload: dict, candidate: dict) -> list[dict]:
    warns = []
    product_handoff = candidate.get("product_handoff")
    if isinstance(product_handoff, dict):
        for index, warning in enumerate(product_handoff.get("warn_followups", []), start=1):
            if isinstance(warning, str) and warning:
                warns.append(
                    {
                        "finding_id": f"S8-WARN-{index:03d}",
                        "summary": warning,
                        "target": "design.json#product_handoff",
                    }
                )

    review_closure = payload.get("review_closure")
    if isinstance(review_closure, dict):
        for row in review_closure.get("warn_followups", []):
            if isinstance(row, dict):
                warns.append(row)
    return warns


def build_handoff_summary(candidate: dict) -> dict:
    product_handoff = candidate.get("product_handoff")
    if not isinstance(product_handoff, dict):
        product_handoff = {}
    return {
        "status": product_handoff.get("status", ""),
        "accepted_refs": product_handoff.get("accepted_refs", []),
        "open_failures": product_handoff.get("open_failures", []),
        "planning_constraint_count": len(candidate.get("planning_constraints", [])),
        "risk_response_count": len(candidate.get("risk_response", [])),
        "verification_mapping_count": len(candidate.get("verification_mapping", [])),
    }


def build_package(design_path: Path) -> dict:
    payload = load_json_object(design_path, "design file")
    if payload.get("artifact_type") != "design":
        raise SystemExit("design file must have artifact_type=design")

    candidate = strip_final_fields(payload)
    return {
        "candidate_design_json": candidate,
        "candidate_digest": candidate_digest(candidate),
        "source_refs": build_source_refs(design_path, candidate),
        "co_creation_confirmations": build_co_creation_confirmations(candidate),
        "open_warns": build_open_warns(payload, candidate),
        "handoff_summary": build_handoff_summary(candidate),
    }


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--design", type=Path, required=True)
    parser.add_argument("--package-output", type=Path, required=True)
    parser.add_argument("--candidate-output", type=Path, required=True)
    args = parser.parse_args(argv)

    package = build_package(args.design)
    write_json(args.candidate_output, package["candidate_design_json"])
    write_json(args.package_output, package)
    print(
        json.dumps(
            {
                "status": "PASS",
                "package_output": str(args.package_output.absolute()),
                "candidate_output": str(args.candidate_output.absolute()),
                "candidate_digest": package["candidate_digest"],
                "source_ref_count": len(package["source_refs"]),
                "open_warn_count": len(package["open_warns"]),
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
