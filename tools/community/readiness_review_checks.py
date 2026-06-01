from __future__ import annotations

from pathlib import Path
from typing import Callable

LoadJson = Callable[[Path], dict]


def assert_code_review_pass(phase_dir: Path, load_json: LoadJson) -> None:
    review = load_json(phase_dir / "code-review-result.json")
    delivery_state = load_json(phase_dir / "delivery-state.json")
    if review.get("active_tasks_version_ref") != delivery_state.get(
        "active_tasks_version_ref"
    ):
        raise ValueError(
            "code-review-result active_tasks_version_ref must match active delivery-state tasks ref"
        )
    if review.get("gate_result") != "PASS":
        raise ValueError("code-review-result gate_result must be PASS at readiness")
    if review.get("review_conclusion") != "APPROVE":
        raise ValueError(
            "code-review-result review_conclusion must be APPROVE at readiness"
        )
    verdicts = review.get("dimension_verdicts")
    if not isinstance(verdicts, dict):
        raise ValueError("code-review-result dimension_verdicts must be an object")
    expected = {
        "review_a": "REVIEW_A_OK",
        "review_b": "REVIEW_B_OK",
        "review_c": "REVIEW_C_OK",
        "correctness": "OK",
        "safety": "OK",
        "error_handling": "OK",
        "concurrency_state": "OK",
        "design": "OK",
        "test_coverage": "OK",
        "backward_compatibility": "OK",
        "comment_accuracy": "OK",
        "performance": "OK",
        "observability": "OK",
    }
    for field, expected_value in expected.items():
        if verdicts.get(field) != expected_value:
            raise ValueError(
                f"code-review-result {field} must be {expected_value} at readiness"
            )
    findings = review.get("findings", [])
    if not isinstance(findings, list):
        raise ValueError("code-review-result findings must be an array")
    blocking_severities = {"S0", "S1", "S2"}
    unresolved_statuses = {"Verified", "Inconclusive"}
    for index, finding in enumerate(findings, start=1):
        if not isinstance(finding, dict):
            raise ValueError(f"code-review-result findings[{index}] must be an object")
        if (
            finding.get("severity") in blocking_severities
            and finding.get("verification_status") in unresolved_statuses
        ):
            raise ValueError(
                "code-review-result contains unresolved blocking finding at readiness: "
                f"{finding.get('finding_id', index)}"
            )
