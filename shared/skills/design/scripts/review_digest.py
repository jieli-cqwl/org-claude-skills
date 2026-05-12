#!/usr/bin/env python3
"""Compute or verify the digest for a reviewed design artifact."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


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


def reviewed_design_digest(payload: dict) -> str:
    reviewed_design = dict(payload)
    reviewed_design.pop("review_closure", None)
    reviewed_design.pop("final_confirmation", None)
    serialized = json.dumps(
        reviewed_design, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(serialized).hexdigest()


def emit(status: str, path: Path, digest: str) -> None:
    print(
        json.dumps(
            {
                "status": status,
                "path": str(path),
                "reviewed_design_digest": digest,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


def compute_review_payload(path: Path) -> None:
    payload = load_json_object(path, "review payload")
    forbidden_fields = sorted({"review_closure", "final_confirmation"} & set(payload))
    if forbidden_fields:
        raise SystemExit(
            "review payload must not contain post-review fields: "
            + ", ".join(forbidden_fields)
        )
    emit("PASS", path, reviewed_design_digest(payload))


def check_design(path: Path) -> None:
    payload = load_json_object(path, "design file")
    review_closure = payload.get("review_closure")
    if not isinstance(review_closure, dict):
        raise SystemExit("design.review_closure must be an object")
    expected = review_closure.get("reviewed_design_digest")
    actual = reviewed_design_digest(payload)
    if expected != actual:
        raise SystemExit(
            f"reviewed_design_digest mismatch: expected {expected!r}, actual {actual!r}"
        )
    reviewers = review_closure.get("reviewers")
    if not isinstance(reviewers, list):
        raise SystemExit("design.review_closure.reviewers must be an array")
    for index, reviewer in enumerate(reviewers):
        if not isinstance(reviewer, dict):
            raise SystemExit(f"design.review_closure.reviewers[{index}] must be an object")
        if reviewer.get("reviewed_design_digest") != expected:
            raise SystemExit(
                "reviewed_design_digest mismatch at "
                f"review_closure.reviewers[{index}]"
            )
    emit("PASS", path, actual)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Compute or verify the digest for a reviewed design artifact."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--review-payload",
        action="store_true",
        help="Compute the digest for a self-checked design JSON object prepared for review.",
    )
    mode.add_argument(
        "--check",
        action="store_true",
        help="Verify review_closure.reviewed_design_digest in a design.json.",
    )
    parser.add_argument("json_path", help="Path to review payload JSON or phase design.json.")
    args = parser.parse_args(argv)

    path = Path(args.json_path)
    if args.review_payload:
        compute_review_payload(path)
    else:
        check_design(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
