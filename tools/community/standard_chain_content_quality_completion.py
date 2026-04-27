"""Semantic completion review checks for standard-chain content quality."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

COMPLETION_BASIS_REQUIRED = {
    "script_proof",
    "semantic_audit",
    "residual_noise_scan",
    "adversarial_review",
}


@dataclass(frozen=True)
class CompletionIssue:
    path: Path
    line: int
    code: str
    message: str

    def format(self) -> str:
        location = f"{self.path}:{self.line}" if self.line else str(self.path)
        return f"{location}: {self.code}: {self.message}"


def validate_string_list(path: Path, value: object, field: str) -> list[CompletionIssue]:
    if not isinstance(value, list) or not value:
        return [CompletionIssue(path, 0, "invalid_audit_completion_review", f"{field} must be a non-empty list")]
    for item in value:
        if not isinstance(item, str) or not item.strip():
            return [
                CompletionIssue(
                    path,
                    0,
                    "invalid_audit_completion_review",
                    f"{field} entries must be non-empty strings",
                )
            ]
    return []


def entries_by_source(entries: list[object]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {}
    for entry in entries:
        if isinstance(entry, dict) and isinstance(entry.get("source_file"), str):
            grouped.setdefault(entry["source_file"], []).append(entry)
    return grouped


def validate_review_flags(path: Path, review: dict) -> list[CompletionIssue]:
    issues: list[CompletionIssue] = []
    if review.get("proxy_metrics_rejected") is not True:
        issues.append(
            CompletionIssue(
                path,
                0,
                "proxy_metrics_not_rejected",
                "semantic completion must reject script-pass/title-presence as standalone completion evidence",
            )
        )
    if review.get("adversarial_review_required") is not True:
        issues.append(
            CompletionIssue(
                path,
                0,
                "adversarial_review_not_blocking",
                "adversarial review must be required as a blocking gate",
            )
        )
    return issues


def validate_review_strings(path: Path, review: dict) -> list[CompletionIssue]:
    issues: list[CompletionIssue] = []
    for field in ("reviewed_by", "reviewed_at", "status_reason"):
        value = review.get(field)
        if not isinstance(value, str) or not value.strip():
            issues.append(
                CompletionIssue(path, 0, "invalid_audit_completion_review", f"{field} must be a non-empty string")
            )
    return issues


def validate_completion_basis(path: Path, review: dict) -> list[CompletionIssue]:
    issues: list[CompletionIssue] = []
    for field in ("scope", "residual_noise_scan_refs", "completion_basis"):
        issues.extend(validate_string_list(path, review.get(field), field))
    basis = set(review.get("completion_basis", [])) if isinstance(review.get("completion_basis"), list) else set()
    missing_basis = sorted(COMPLETION_BASIS_REQUIRED - basis)
    if missing_basis:
        issues.append(
            CompletionIssue(
                path,
                0,
                "incomplete_completion_basis",
                f"semantic completion basis missing {', '.join(missing_basis)}",
            )
        )
    return issues


def minimum_entries_per_skill(path: Path, review: dict) -> tuple[int, list[CompletionIssue]]:
    value = review.get("minimum_entries_per_touched_skill", 2)
    if isinstance(value, int) and value >= 2:
        return value, []
    return 2, [
        CompletionIssue(
            path,
            0,
            "invalid_audit_completion_review",
            "minimum_entries_per_touched_skill must be an integer >= 2",
        )
    ]


def validate_entry_granularity(path: Path, payload: dict, entries: list[object], review: dict) -> list[CompletionIssue]:
    min_entries, issues = minimum_entries_per_skill(path, review)
    grouped = entries_by_source(entries)
    for source in payload.get("touched_skills", []):
        if isinstance(source, str) and len(grouped.get(source, [])) < min_entries:
            issues.append(
                CompletionIssue(
                    path,
                    0,
                    "insufficient_migration_entries",
                    f"{source} has fewer than {min_entries} audit entries",
                )
            )
    return issues


def validate_required_pass(path: Path, review: dict) -> list[CompletionIssue]:
    issues: list[CompletionIssue] = []
    if review.get("status") != "PASS":
        issues.append(
            CompletionIssue(path, 0, "migration_completion_not_passed", "semantic_completion_review.status must be PASS")
        )
    findings = review.get("blocking_findings")
    if not isinstance(findings, list):
        issues.append(CompletionIssue(path, 0, "invalid_audit_completion_review", "blocking_findings must be a list"))
    elif findings:
        issues.append(
            CompletionIssue(path, 0, "migration_completion_has_blockers", "blocking_findings must be empty for PASS")
        )
    return issues


def validate_completion_review(path: Path, payload: dict, entries: list[object], require_pass: bool) -> list[CompletionIssue]:
    if "semantic_completion_review" not in payload:
        if not require_pass:
            return []
        return [
            CompletionIssue(
                path,
                0,
                "missing_audit_completion_review",
                "semantic_completion_review is required before marking migration complete",
            )
        ]
    review = payload.get("semantic_completion_review")
    if not isinstance(review, dict):
        return [CompletionIssue(path, 0, "missing_audit_completion_review", "semantic_completion_review must be an object")]

    issues: list[CompletionIssue] = []
    if review.get("status") not in {"PASS", "BLOCKED"}:
        issues.append(
            CompletionIssue(
                path,
                0,
                "invalid_audit_completion_review",
                "semantic completion status must be PASS or BLOCKED",
            )
        )
    issues.extend(validate_review_flags(path, review))
    issues.extend(validate_review_strings(path, review))
    issues.extend(validate_completion_basis(path, review))
    issues.extend(validate_entry_granularity(path, payload, entries, review))
    if require_pass:
        issues.extend(validate_required_pass(path, review))
    return issues
