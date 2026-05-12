from __future__ import annotations

import re

from canonical_rule_common import (
    _require_non_empty_dict,
    _require_non_empty_list,
    _require_non_empty_string,
    _require_string_list,
    _resolve_dotted_path,
)
from review_digest_common import canonical_payload_digest, is_sha256_digest
from canonical_test_case_semantic_rules import (
    SOURCE_REF_RE,
    assert_test_case_semantics,
    supporting_artifacts,
)

QA_STAGES = {"QA_A", "QA_B", "QA_C", "QA_D", "NFR"}
EXECUTION_MODES = {"browser_required", "non_browser_ok"}
REVIEW_PERSPECTIVES = {"test_quality", "product", "architecture"}
POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger"}


def assert_test_cases_contract(payload: dict, artifacts: list[dict]) -> None:
    if payload.get("artifact_type") != "test-cases":
        return

    support = supporting_artifacts(artifacts)
    _assert_ac_coverage_matrix(payload)
    assert_test_case_semantics(payload, support)
    verdict = _assert_review_conclusion(payload)
    _assert_issue_ledger(payload, verdict)
    _assert_qa_handoff_contract(payload, support["design.json"])


def _assert_ac_coverage_matrix(payload: dict) -> None:
    case_types = _case_type_index(payload)
    rows = _require_non_empty_list(
        payload.get("ac_coverage_matrix"), "ac_coverage_matrix"
    )
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(
                f"test-cases ac_coverage_matrix[{index}] must be an object"
            )
        positive_refs = _require_string_list(
            row.get("positive_case_refs"),
            f"ac_coverage_matrix[{index}].positive_case_refs",
        )
        negative_refs = _require_string_list(
            row.get("negative_case_refs"),
            f"ac_coverage_matrix[{index}].negative_case_refs",
        )
        boundary_refs = _require_string_list(
            row.get("boundary_case_refs"),
            f"ac_coverage_matrix[{index}].boundary_case_refs",
        )
        _assert_refs_match_case_type(
            positive_refs, case_types, "positive", f"ac_coverage_matrix[{index}].positive_case_refs"
        )
        _assert_refs_match_case_type(
            negative_refs, case_types, "negative", f"ac_coverage_matrix[{index}].negative_case_refs"
        )
        _assert_refs_match_case_type(
            boundary_refs, case_types, "boundary", f"ac_coverage_matrix[{index}].boundary_case_refs"
        )
        if len(negative_refs) + len(boundary_refs) < len(positive_refs):
            raise ValueError(
                "test-cases negative+boundary coverage must be >= positive coverage "
                f"for ac_coverage_matrix[{index}]"
            )


def _case_type_index(payload: dict) -> dict[str, str]:
    case_types: dict[str, str] = {}
    for index, row in enumerate(_require_non_empty_list(payload.get("test_cases"), "test_cases")):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases test_cases[{index}] must be an object")
        case_id = row.get("case_id")
        _require_non_empty_string(case_id, f"test_cases[{index}].case_id")
        if case_id in case_types:
            raise ValueError(f"test-cases duplicate case_id: {case_id}")
        case_type = row.get("case_type")
        _require_non_empty_string(case_type, f"test_cases[{index}].case_type")
        case_types[str(case_id)] = str(case_type)
    return case_types


def _assert_refs_match_case_type(
    refs: list[str], case_types: dict[str, str], expected_type: str, path: str
) -> None:
    unknown = sorted(set(refs) - set(case_types))
    if unknown:
        raise ValueError(f"test-cases unknown refs in {path}: {unknown}")
    mismatched = sorted(ref for ref in set(refs) if case_types[ref] != expected_type)
    if mismatched:
        raise ValueError(
            f"test-cases {path} must reference {expected_type} cases only: "
            f"{[(ref, case_types[ref]) for ref in mismatched]}"
        )


def _assert_review_conclusion(payload: dict) -> str:
    review = _require_non_empty_dict(
        payload.get("review_conclusion"), "review_conclusion"
    )
    verdict = review.get("verdict")
    if verdict not in {"PASS", "WARN"}:
        raise ValueError(
            "test-cases review_conclusion.verdict must be PASS or WARN at completion"
        )
    _require_non_empty_string(review.get("summary"), "review_conclusion.summary")
    review_round = review.get("review_round")
    if not isinstance(review_round, str) or not re.fullmatch(r"R[0-9]+", review_round):
        raise ValueError("test-cases review_conclusion.review_round must be R<N>")
    reviewed_digest = _assert_reviewed_test_cases_digest(payload, review)
    _assert_convergence_evidence(review)
    _assert_reviewer_verdicts(review, verdict, reviewed_digest)
    return verdict


def _assert_reviewed_test_cases_digest(payload: dict, review: dict) -> str:
    digest = review.get("reviewed_test_cases_digest")
    if not is_sha256_digest(digest):
        raise ValueError(
            "test-cases review_conclusion.reviewed_test_cases_digest must be sha256:<64 hex>"
        )
    expected = canonical_payload_digest(payload, POST_REVIEW_FIELDS)
    if digest != expected:
        raise ValueError(
            "test-cases review_conclusion.reviewed_test_cases_digest mismatch: "
            f"expected={expected} actual={digest!r}"
        )
    return str(digest)


def _assert_reviewer_verdicts(
    review: dict, aggregate_verdict: str, reviewed_digest: str
) -> None:
    rows = _require_non_empty_list(
        review.get("reviewer_verdicts"), "review_conclusion.reviewer_verdicts"
    )
    seen: set[str] = set()
    warn_count = 0
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases reviewer_verdicts[{index}] must be an object")
        perspective = row.get("perspective")
        if perspective not in REVIEW_PERSPECTIVES:
            raise ValueError(
                f"test-cases reviewer_verdicts[{index}].perspective is invalid"
            )
        if perspective in seen:
            raise ValueError(f"test-cases duplicate reviewer perspective: {perspective}")
        seen.add(str(perspective))
        verdict = row.get("verdict")
        if verdict not in {"PASS", "WARN", "FAIL"}:
            raise ValueError(f"test-cases reviewer_verdicts[{index}].verdict is invalid")
        if verdict == "FAIL":
            raise ValueError(
                f"test-cases reviewer_verdicts[{index}] has unresolved FAIL verdict"
            )
        if verdict == "WARN":
            warn_count += 1
        if not isinstance(row.get("issue_count"), int) or row.get("issue_count") < 0:
            raise ValueError(
                f"test-cases reviewer_verdicts[{index}].issue_count must be a non-negative integer"
            )
        review_round = row.get("review_round")
        if not isinstance(review_round, str) or not re.fullmatch(r"R[0-9]+", review_round):
            raise ValueError(
                f"test-cases reviewer_verdicts[{index}].review_round must be R<N>"
            )
        if row.get("reviewed_test_cases_digest") != reviewed_digest:
            raise ValueError(
                f"test-cases reviewer_verdicts[{index}].reviewed_test_cases_digest must match review_conclusion.reviewed_test_cases_digest"
            )
        _require_non_empty_string(row.get("evidence"), f"reviewer_verdicts[{index}].evidence")
    missing = REVIEW_PERSPECTIVES - seen
    if missing:
        raise ValueError(f"test-cases missing reviewer perspectives: {sorted(missing)}")
    if warn_count and aggregate_verdict != "WARN":
        raise ValueError("test-cases reviewer WARN verdicts require aggregate WARN")
    if aggregate_verdict == "WARN" and not warn_count:
        raise ValueError("test-cases aggregate WARN requires at least one reviewer WARN")


def _assert_convergence_evidence(review: dict) -> None:
    rows = _require_non_empty_list(
        review.get("convergence_evidence"), "review_conclusion.convergence_evidence"
    )
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(
                f"test-cases convergence_evidence[{index}] must be an object"
            )
        round_id = row.get("round")
        if not isinstance(round_id, str) or not re.fullmatch(r"R[0-9]+", round_id):
            raise ValueError(
                f"test-cases convergence_evidence[{index}].round must be R<N>"
            )
        if row.get("result") not in {"PASS", "WARN", "FAIL"}:
            raise ValueError(
                f"test-cases convergence_evidence[{index}].result must be PASS/WARN/FAIL"
            )
        _assert_convergence_control(row, index)


def _assert_convergence_control(row: dict, index: int) -> None:
    if not isinstance(row.get("fail_count"), int) or row.get("fail_count") < 0:
        raise ValueError(
            f"test-cases convergence_evidence[{index}].fail_count must be a non-negative integer"
        )
    if row.get("control_action") not in {
        "CONTINUE",
        "CONFIRMATION",
        "ASK_USER",
        "BLOCKED",
        "COMPLETE",
    }:
        raise ValueError(
            f"test-cases convergence_evidence[{index}].control_action is invalid"
        )
    _require_non_empty_string(
        row.get("evidence"), f"convergence_evidence[{index}].evidence"
    )


def _assert_issue_ledger(payload: dict, verdict: str) -> None:
    issue_ledger = payload.get("issue_ledger")
    if not isinstance(issue_ledger, list):
        raise ValueError("test-cases issue_ledger must be an array")
    if verdict == "WARN" and not issue_ledger:
        raise ValueError(
            "test-cases WARN review_conclusion requires issue_ledger handling records"
        )
    for index, row in enumerate(issue_ledger):
        _assert_issue_ledger_row(row, index)


def _assert_issue_ledger_row(row: object, index: int) -> None:
    if not isinstance(row, dict):
        raise ValueError(f"test-cases issue_ledger[{index}] must be an object")
    for field in (
        "issue_id",
        "review_round",
        "status",
        "evidence",
        "handling_record",
    ):
        _require_non_empty_string(row.get(field), f"issue_ledger[{index}].{field}")
    if row.get("status") not in {"CLOSED", "DEFERRED"}:
        raise ValueError(
            f"test-cases issue_ledger[{index}].status must be CLOSED or DEFERRED"
        )
    if not re.fullmatch(r"R[0-9]+", row["review_round"]):
        raise ValueError(f"test-cases issue_ledger[{index}].review_round must be R<N>")


def _assert_qa_handoff_contract(payload: dict, design: dict) -> None:
    expected_refs = _expected_manager_refs(design)
    actual_refs = _actual_qa_design_refs(payload, design)
    missing_refs = sorted(expected_refs - actual_refs)
    if missing_refs:
        raise ValueError(
            f"test-cases design_source_refs missing manager refs: {missing_refs}"
        )


def _expected_manager_refs(design: dict) -> set[str]:
    return {
        f"design.json#verification_mapping[{index}].manager_vp_ref"
        for index, _mapping in enumerate(
            _require_non_empty_list(
                design.get("verification_mapping"), "design.verification_mapping"
            )
        )
    }


def _actual_qa_design_refs(payload: dict, design: dict) -> set[str]:
    actual_refs: set[str] = set()
    rows = _require_non_empty_list(
        payload.get("qa_handoff_contract"), "qa_handoff_contract"
    )
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(
                f"test-cases qa_handoff_contract[{index}] must be an object"
            )
        _assert_qa_handoff_row(row, index)
        refs = _require_non_empty_list(
            row.get("design_source_refs"),
            f"qa_handoff_contract[{index}].design_source_refs",
        )
        for ref_index, ref in enumerate(refs):
            actual_refs.add(
                _assert_design_source_ref(
                    ref,
                    design,
                    f"qa_handoff_contract[{index}].design_source_refs[{ref_index}]",
                )
            )
    return actual_refs


def _assert_qa_handoff_row(row: dict, index: int) -> None:
    for field in (
        "test_obligation",
        "trigger_source",
        "skip_rule",
        "evidence_expectation",
    ):
        _require_non_empty_string(row.get(field), f"qa_handoff_contract[{index}].{field}")
    _assert_enum(row.get("qa_stage"), QA_STAGES, f"qa_handoff_contract[{index}].qa_stage")
    _assert_enum(
        row.get("requiredness"),
        {"REQUIRED", "CONDITIONAL"},
        f"qa_handoff_contract[{index}].requiredness",
    )
    _assert_enum(
        row.get("execution_mode"),
        EXECUTION_MODES,
        f"qa_handoff_contract[{index}].execution_mode",
    )


def _assert_design_source_ref(ref: object, design: dict, path: str) -> str:
    if not isinstance(ref, str):
        raise ValueError(f"test-cases design source ref must be a string: {path}")
    match = SOURCE_REF_RE.match(ref)
    if not match or match.group(1) != "design.json":
        raise ValueError(f"test-cases unsupported design source ref: {path}={ref}")
    try:
        _resolve_dotted_path(design, match.group(2))
    except ValueError as exc:
        raise ValueError(
            f"test-cases design source ref does not resolve at {path}: {ref} ({exc})"
        ) from exc
    return ref


def _assert_enum(value: object, allowed: set[str], path: str) -> str:
    if value not in allowed:
        raise ValueError(f"test-cases invalid {path}: {value}")
    return str(value)
