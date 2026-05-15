#!/usr/bin/env python3
"""Validate Stage 2 product-director handoff materials without entering qft-pai."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

from render_stage2_product_director_handoff import ROOT, render
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json


def make_real_candidate(example_payload: dict[str, Any]) -> dict[str, Any]:
    candidate = copy.deepcopy(example_payload)
    candidate["intake_provenance"] = {
        "source_type": "human_business_owner_input",
        "filled_by": "产研负责人",
        "confirmed_by": "客服运营负责人",
        "confirmed_at": "2026-05-14",
        "confirmation_basis": "human/business owner 明确确认该文件用于 Stage 2 真实采证入口",
        "fact_source_refs": [
            "human://客服运营负责人/stage-2-intake-confirmation/2026-05-14",
            "doc://stage-2-intake-business-sample",
        ],
        "not_copied_from_example": True,
    }
    return candidate


def validate_materials(repo_root: Path) -> dict[str, Any]:
    example_path = repo_root / DEFAULT_INTAKE.relative_to(ROOT)
    example_payload = load_json(example_path)
    example_result, example_exit = render(example_payload, example_path)
    failures: list[str] = []
    if example_exit == 0:
        failures.append("example intake unexpectedly rendered product-director handoff")
    if example_result.get("reason") != "product_director_handoff_not_allowed":
        failures.append("example block reason must be product_director_handoff_not_allowed")

    real_candidate = make_real_candidate(example_payload)
    real_result, real_exit = render(real_candidate, Path("real-stage2-intake-facts.json"))
    if real_exit != 0:
        failures.append("real intake candidate did not render product-director handoff")
    if real_result.get("handoff_owner_role") != "product-director":
        failures.append("real handoff owner must be product-director")
    if real_result.get("next_required_action") != "start_product_director_confirmed_brief":
        failures.append("real handoff next action must start product-director confirmed brief")
    blocked_actions = real_result.get("discovery_boundary", {}).get("blocked_actions", [])
    if "code_changes" not in blocked_actions:
        failures.append("real handoff must keep code_changes blocked")

    return {
        "status": "fail" if failures else "pass",
        "failed_checks": failures,
        "example_block_reason": example_result.get("reason"),
        "real_handoff": real_result if real_exit == 0 else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root.")
    args = parser.parse_args()

    payload = validate_materials(args.repo_root.resolve())
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
