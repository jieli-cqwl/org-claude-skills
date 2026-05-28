#!/usr/bin/env python3
"""Validate delivery-owner minimal behavior replay contract."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


class ReplayFailure(Exception):
    def __init__(self, code: str, reason: str, section: str | None = None) -> None:
        super().__init__(reason)
        self.code = code
        self.reason = reason
        self.section = section


CASE_CONTRACTS = {
    "verifier FAIL replay": {
        "required": (
            "Delivery Status Card",
            "current_step: DO-S5",
            "current_gap:",
            "next_owner: developer agent",
            "progress_signal: gap_judgment_changed",
            "consecutive_no_progress_count: 0",
            "resume_condition:",
            "developer packet",
            "role: developer",
            "input_refs:",
            "expected_evidence:",
            "rerun verifier agent",
            "Resume Checkpoint:",
            "verifier packet",
            "role: verifier",
            "fresh developer-report.json",
        ),
        "forbidden": (
            "role: qa",
            "qa agent PASS",
            "dispatch /commit",
        ),
    },
    "qa FAIL replay": {
        "required": (
            "Delivery Status Card",
            "current_step: DO-S7",
            "current_gap:",
            "next_owner: fixer agent",
            "progress_signal: gap_judgment_changed",
            "stale_evidence_refs:",
            "resume_condition:",
            "fixer packet",
            "role: fixer",
            "root cause",
            "minimal fix",
            "freshness judgement",
            "rerun affected verifier agent, fresh code-reviewer agent, and qa agent",
            "Resume Checkpoint:",
            "verifier packet",
            "role: verifier",
            "fresh verify-result.json",
            "code-reviewer packet",
            "role: code-reviewer",
            "fresh code-review-result.json",
            "qa packet",
            "role: qa",
            "qa-result.json",
        ),
        "forbidden": (
            "dispatch /commit",
            "role: developer",
        ),
    },
    "two no-progress rounds replay": {
        "required": (
            "Delivery Status Card",
            "status: PAUSED_FOR_USER_DECISION",
            "current_gap:",
            "next_owner: user",
            "progress_signal: no_progress",
            "consecutive_no_progress_count: 2",
            "User Decision Package",
            "decision_needed:",
            "required_user_answer:",
            "resume_condition:",
            "next_action_after_decision:",
        ),
        "forbidden": (
            "progress_signal: gap_judgment_changed",
            "next_owner: developer agent",
            "next_owner: fixer agent",
        ),
    },
    "qa non-PASS routing replay": {
        "required": (
            "Delivery Status Card",
            "current_step: DO-S7",
            "CONDITIONAL",
            "NOT_RUN",
            "N_A",
            "CONDITIONAL_ALLOW",
            "BLOCK",
            "DEFER",
            "next_owner: user",
            "waiver",
            "resume_condition:",
        ),
        "forbidden": (
            "dispatch /commit",
            "status: DELIVERED",
        ),
    },
}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replay", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def load_text(path: Path) -> str:
    if not path.is_file():
        raise ReplayFailure("MISSING_REPLAY", f"replay file not found: {path}")
    return path.read_text(encoding="utf-8")


def section_text(text: str, heading: str) -> str:
    marker = "## Replay "
    target = f": {heading}"
    start = text.find(target)
    if start == -1:
        raise ReplayFailure(
            "MISSING_SECTION", f"missing replay section: {heading}", heading
        )
    heading_start = text.rfind(marker, 0, start)
    if heading_start == -1:
        raise ReplayFailure(
            "MALFORMED_SECTION", f"malformed replay heading: {heading}", heading
        )
    next_heading = text.find(marker, heading_start + len(marker))
    if next_heading == -1:
        return text[heading_start:]
    return text[heading_start:next_heading]


def assert_contains_terms(section: str, terms: tuple[str, ...], heading: str) -> None:
    missing = [term for term in terms if term not in section]
    if missing:
        raise ReplayFailure(
            "REPLAY_REQUIRED_TERM_MISSING",
            f"{heading} missing required terms: {', '.join(missing)}",
            heading,
        )


def assert_forbidden_terms_absent(
    section: str, terms: tuple[str, ...], heading: str
) -> None:
    present = [term for term in terms if term in section]
    if present:
        raise ReplayFailure(
            "REPLAY_FORBIDDEN_TERM_PRESENT",
            f"{heading} contains forbidden terms: {', '.join(present)}",
            heading,
        )


def validate(text: str) -> dict[str, object]:
    assert_contains_terms(
        text,
        (
            "Replay Result: PASS",
            "expected-behavior contract",
            "不表示 live subagent eval 已运行",
        ),
        "header",
    )
    checked_sections: list[str] = []
    for heading, contract in CASE_CONTRACTS.items():
        body = section_text(text, heading)
        assert_contains_terms(body, contract["required"], heading)
        assert_forbidden_terms_absent(body, contract["forbidden"], heading)
        checked_sections.append(heading)
    return {
        "status": "PASS",
        "decision": "REPLAY_CONTRACT_READY",
        "checked_sections": checked_sections,
        "case_count": len(checked_sections),
    }


def failure_payload(exc: ReplayFailure) -> dict[str, object]:
    return {
        "status": "BLOCKED",
        "decision": "REPLAY_CONTRACT_BLOCKED",
        "failure_code": exc.code,
        "reason": exc.reason,
        "section": exc.section,
    }


def emit(payload: dict[str, object], output: Path | None) -> None:
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    if output:
        output.write_text(text + "\n", encoding="utf-8")
    print(text)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        payload = validate(load_text(args.replay))
        code = 0
    except ReplayFailure as exc:
        payload = failure_payload(exc)
        code = 1
    emit(payload, args.output)
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
