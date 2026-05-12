#!/usr/bin/env python3
"""Compute or verify the test-design owner self-checked payload digest."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "community"))

from normalize_canonical_artifact import load_json  # noqa: E402
from review_digest_common import canonical_payload_digest  # noqa: E402


POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger"}


def assert_no_post_review_fields(payload: dict, source: Path) -> None:
    present = sorted(field for field in POST_REVIEW_FIELDS if field in payload)
    if present:
        raise ValueError(
            f"{source} must be the owner self-checked review payload before post-review fields: {present}"
        )


def digest_payload(path: Path, *, require_pre_review: bool) -> str:
    payload = load_json(path)
    if require_pre_review:
        assert_no_post_review_fields(payload, path)
    return canonical_payload_digest(payload, POST_REVIEW_FIELDS)


def check_artifact(path: Path) -> str:
    payload = load_json(path)
    expected = canonical_payload_digest(payload, POST_REVIEW_FIELDS)
    review = payload.get("review_conclusion")
    if not isinstance(review, dict):
        raise ValueError(f"{path} missing review_conclusion")
    actual = review.get("reviewed_test_cases_digest")
    if actual != expected:
        raise ValueError(
            f"{path} reviewed_test_cases_digest mismatch: expected={expected} actual={actual!r}"
        )
    for index, reviewer in enumerate(review.get("reviewer_verdicts", [])):
        if reviewer.get("reviewed_test_cases_digest") != expected:
            raise ValueError(
                f"{path} reviewer_verdicts[{index}].reviewed_test_cases_digest mismatch"
            )
    return expected


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--review-payload", type=Path)
    parser.add_argument("--check", type=Path)
    args = parser.parse_args()
    if bool(args.review_payload) == bool(args.check):
        parser.error("use exactly one of --review-payload or --check")
    return args


def main() -> None:
    args = parse_args()
    if args.review_payload:
        digest = digest_payload(args.review_payload.resolve(), require_pre_review=True)
    else:
        digest = check_artifact(args.check.resolve())
    print(json.dumps({"reviewed_test_cases_digest": digest}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (FileNotFoundError, ValueError) as exc:
        raise SystemExit(str(exc)) from exc
