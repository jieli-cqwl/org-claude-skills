#!/usr/bin/env python3
"""Validate and normalize review-fix-loop adversarial review output.

Responsibilities:
- parse either a direct JSON object or the final assistant message from codex exec JSONL
- fail-close on contradictory or structurally invalid review results
- normalize valid findings and classify skip-only warnings

Boundary:
- only reads the provided input file and repository files
- never edits repository contents
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Sequence


ALLOWED_VERDICTS = {"approve", "needs-attention"}
ALLOWED_SEVERITIES = ("critical", "high", "medium", "low")


class ValidationError(RuntimeError):
    """Raised when the review output must fail closed."""


def emit_json(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))


def strip_code_fence(text: str) -> str:
    """Strip a single surrounding markdown code fence when present."""

    lines = text.strip().splitlines()
    if len(lines) >= 2 and lines[0].startswith("```") and lines[-1].strip() == "```":
        return "\n".join(lines[1:-1]).strip()
    return text.strip()


def parse_jsonl_message(text: str) -> dict[str, Any]:
    """Extract the last assistant message JSON from codex exec JSONL output."""

    assistant_messages: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        item = event.get("item")
        if event.get("type") != "item.completed" or not isinstance(item, dict):
            continue
        if item.get("type") != "agent_message":
            continue

        message = item.get("text", "")
        if isinstance(message, str) and message.strip():
            assistant_messages.append(message.strip())

    if not assistant_messages:
        raise ValidationError("无法从 Codex JSONL 输出中提取评审 JSON")

    final_message = strip_code_fence(assistant_messages[-1])
    try:
        payload = json.loads(final_message)
    except json.JSONDecodeError as exc:
        raise ValidationError("Codex 最终消息不是合法 JSON") from exc

    if not isinstance(payload, dict):
        raise ValidationError("评审结果必须是 JSON object")
    return payload


def load_review_payload(input_file: Path) -> dict[str, Any]:
    """Load a review payload from direct JSON or JSONL."""

    raw_text = input_file.read_text(encoding="utf-8")
    try:
        payload = json.loads(raw_text)
    except json.JSONDecodeError:
        return parse_jsonl_message(raw_text)

    if not isinstance(payload, dict):
        raise ValidationError("评审结果必须是 JSON object")
    return payload


def is_safe_repo_relative_path(path_text: Any) -> bool:
    """Check whether the path is a safe repo-relative posix path."""

    if not isinstance(path_text, str) or not path_text or "\\" in path_text:
        return False

    path_obj = PurePosixPath(path_text)
    if path_obj.is_absolute():
        return False

    parts = path_obj.parts
    if not parts or any(part in {"", ".", ".."} for part in parts):
        return False

    normalized = str(path_obj)
    if normalized == ".git" or normalized.startswith(".git/") or "/.git/" in normalized:
        return False

    return True


def count_file_lines(file_path: Path) -> int:
    """Count lines in a text file while tolerating undecodable bytes."""

    with file_path.open("r", encoding="utf-8", errors="ignore") as handle:
        return sum(1 for _ in handle)


def resolve_repo_file(repo_root: Path, file_text: str) -> Path | None:
    """Resolve a repo-relative file and reject symlink escapes outside the repo."""

    candidate = repo_root / file_text
    try:
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError:
        return None

    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ValidationError(f"finding 指向仓库外路径: {file_text}") from exc

    return resolved


def parse_positive_int(value: Any) -> int | None:
    """Parse a strictly positive integer."""

    if not isinstance(value, int):
        return None
    if value <= 0:
        return None
    return value


def validate_top_level(review: dict[str, Any]) -> tuple[str, list[Any]]:
    """Validate top-level verdict/findings invariants."""

    verdict = review.get("verdict")
    findings = review.get("findings")

    if verdict not in ALLOWED_VERDICTS:
        raise ValidationError("verdict 必须是 approve 或 needs-attention")
    if not isinstance(findings, list):
        raise ValidationError("findings 必须是数组")
    if verdict == "approve" and findings:
        raise ValidationError("verdict=approve 时 findings 必须为空")
    if verdict == "needs-attention" and not findings:
        raise ValidationError("verdict=needs-attention 时 findings 不可为空")

    return verdict, findings


def warning(index: int, code: str, message: str) -> dict[str, Any]:
    """Build a structured warning entry."""

    return {"code": code, "finding_index": index, "message": message}


def validate_finding(
    repo_root: Path,
    finding: Any,
    index: int,
) -> tuple[dict[str, Any] | None, list[dict[str, Any]], str | None]:
    """Validate one finding and return normalized data, warnings, or fail reason."""

    warnings: list[dict[str, Any]] = []

    if not isinstance(finding, dict):
        warnings.append(warning(index, "INVALID_FINDING", "finding 不是 object，已跳过"))
        return None, warnings, None

    file_text = finding.get("file")
    if not is_safe_repo_relative_path(file_text):
        warnings.append(warning(index, "INVALID_PATH", "file 必须是 repo 内相对路径，已跳过"))
        return None, warnings, None

    line_start = parse_positive_int(finding.get("line_start"))
    line_end = parse_positive_int(finding.get("line_end"))
    if line_start is None or line_end is None or line_end < line_start:
        warnings.append(warning(index, "INVALID_LINE_RANGE", "line_start/line_end 非法，已跳过"))
        return None, warnings, None

    severity_raw = finding.get("severity")
    severity = severity_raw.lower() if isinstance(severity_raw, str) else None
    if severity not in ALLOWED_SEVERITIES:
        warnings.append(warning(index, "INVALID_SEVERITY", "severity 非法，已跳过"))
        return None, warnings, None

    try:
        repo_file = resolve_repo_file(repo_root, file_text)
    except ValidationError as exc:
        if severity in {"critical", "high"}:
            return None, warnings, str(exc)
        warnings.append(warning(index, "OUTSIDE_REPO", f"{exc}，已跳过"))
        return None, warnings, None

    if repo_file is None or not repo_file.is_file():
        message = f"finding 指向的文件不存在: {file_text}"
        if severity in {"critical", "high"}:
            return None, warnings, message
        warnings.append(warning(index, "UNLOCATABLE_FILE", f"{message}，已跳过"))
        return None, warnings, None

    line_count = count_file_lines(repo_file)
    if line_start > line_count or line_end > line_count:
        message = f"finding 行号超出文件范围: {file_text}:{line_start}-{line_end}"
        if severity in {"critical", "high"}:
            return None, warnings, message
        warnings.append(warning(index, "UNLOCATABLE_LINES", f"{message}，已跳过"))
        return None, warnings, None

    normalized = {
        "description": str(finding.get("description", "")).strip(),
        "file": file_text,
        "line_end": line_end,
        "line_start": line_start,
        "recommendation": str(finding.get("recommendation", "")).strip(),
        "severity": severity,
    }
    return normalized, warnings, None


def build_summary(valid_findings: list[dict[str, Any]], warnings: list[dict[str, Any]]) -> dict[str, int]:
    """Build severity counts for valid findings."""

    summary = {
        "critical": 0,
        "high": 0,
        "low": 0,
        "medium": 0,
        "skipped_findings": len(warnings),
        "total_findings": len(valid_findings),
    }
    for finding in valid_findings:
        summary[finding["severity"]] += 1
    return summary


def validate_review(repo_root: Path, review: dict[str, Any]) -> dict[str, Any]:
    """Validate the review payload and return normalized findings."""

    verdict, findings = validate_top_level(review)
    valid_findings: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    for index, finding in enumerate(findings):
        normalized, item_warnings, fail_reason = validate_finding(repo_root, finding, index)
        warnings.extend(item_warnings)
        if fail_reason:
            raise ValidationError(fail_reason)
        if normalized:
            valid_findings.append(normalized)

    if verdict == "needs-attention" and not valid_findings:
        raise ValidationError("所有 findings 都无法定位或被过滤，已 fail-close")

    valid_findings.sort(key=lambda item: (item["file"], -item["line_end"], -item["line_start"]))
    return {
        "valid_findings": valid_findings,
        "verdict": verdict,
        "warnings": warnings,
        "summary": build_summary(valid_findings, warnings),
    }


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    """Parse CLI arguments."""

    parser = argparse.ArgumentParser(description="Validate review-fix-loop review JSON")
    parser.add_argument("--repo", required=True, help="git repository root")
    parser.add_argument("--input", required=True, help="review JSON or codex JSONL file")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    """Entrypoint."""

    args = parse_args(argv)
    repo_root = Path(args.repo).resolve()
    input_file = Path(args.input)

    try:
        payload = load_review_payload(input_file)
        emit_json(validate_review(repo_root, payload))
        return 0
    except (ValidationError, json.JSONDecodeError, OSError) as exc:
        emit_json({"code": "FAIL_CLOSED", "error": str(exc)})
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
