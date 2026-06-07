"""Cross-check formal reports against confirmed skill audit alignments."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from skill_audit_alignment_contract import load_alignment
from skill_audit_report_contract import require


def validate_capability_baseline(report: dict[str, Any]) -> None:
    baseline_ref = Path(report["capability_baseline_ref"])
    require(
        ".." not in baseline_ref.parts,
        f"capability_baseline_ref must stay inside a safe location: {baseline_ref}",
    )
    require(
        baseline_ref.is_file(),
        f"capability_baseline_ref does not exist: {baseline_ref}",
    )
    alignment = load_alignment(baseline_ref)
    require(
        report["target_skill"] == alignment["target_skill"],
        "capability_baseline_ref target_skill must match report target_skill",
    )
    confirmation = alignment["user_confirmation"]
    require(
        alignment["stage"] == "confirmed"
        and confirmation.get("status") == "confirmed",
        "capability_baseline_ref must point to a confirmed alignment",
    )
    require(
        confirmation.get("level") != "G3",
        "capability_baseline_ref cannot point to a G3 alignment for formal audit",
    )
    confirmed_in_alignment = set(confirmation["confirmed_target_capability_ids"])
    report_confirmed = set(report["confirmed_target_capability_ids"])
    missing_confirmed = sorted(report_confirmed - confirmed_in_alignment)
    require(
        not missing_confirmed,
        "confirmed_target_capability_ids not confirmed by alignment: "
        + ", ".join(missing_confirmed),
    )
    omitted_confirmed = sorted(confirmed_in_alignment - report_confirmed)
    require(
        not omitted_confirmed,
        "confirmed_target_capability_ids must include all alignment-confirmed target capabilities: "
        + ", ".join(omitted_confirmed),
    )
    gaps = {
        gap["gap_id"]: gap
        for gap in alignment["capability_match_draft"]["gaps"]
        if isinstance(gap, dict)
    }
    for index, finding in enumerate(report.get("findings", [])):
        unknown = sorted(set(finding["confirmed_gap_refs"]) - gaps.keys())
        require(
            not unknown,
            f"findings[{index}] has unknown confirmed_gap_refs: "
            + ", ".join(unknown),
        )
        for gap_id in finding["confirmed_gap_refs"]:
            gap = gaps[gap_id]
            require(
                gap["target_capability_id"] in report_confirmed,
                f"findings[{index}] confirmed gap {gap_id} does not point to a report-confirmed target capability",
            )
            require(
                gap["status"] in {"partial", "missing", "blocked"},
                f"findings[{index}] confirmed gap {gap_id} must be partial, missing, or blocked",
            )
            require(
                isinstance(gap.get("evidence_refs"), list) and gap["evidence_refs"],
                f"findings[{index}] confirmed gap {gap_id} must cite current evidence_refs",
            )
