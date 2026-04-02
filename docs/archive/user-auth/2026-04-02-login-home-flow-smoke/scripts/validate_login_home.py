#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate login-home simulation cases.")
    parser.add_argument("--file", required=True, help="Path to simulation JSON file")
    parser.add_argument("--case", required=True, choices=["success", "failure"])
    parser.add_argument("--expect-status", required=True)
    parser.add_argument("--expect-route", required=True)
    parser.add_argument("--expect-error", default=None)
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"[FAIL] {message}")
    return 1


def main() -> int:
    args = parse_args()
    source = Path(args.file)
    if not source.is_file():
        return fail(f"missing simulation file: {source}")

    payload = json.loads(source.read_text(encoding="utf-8"))
    if args.case not in payload:
        return fail(f"missing case '{args.case}' in simulation file")

    case = payload[args.case]
    status = case.get("status")
    route = case.get("route_after_login")
    error = case.get("error_message")

    if status != args.expect_status:
        return fail(f"case={args.case} status mismatch: actual={status}, expected={args.expect_status}")

    if route != args.expect_route:
        return fail(f"case={args.case} route mismatch: actual={route}, expected={args.expect_route}")

    if args.expect_error is not None and error != args.expect_error:
        return fail(f"case={args.case} error mismatch: actual={error}, expected={args.expect_error}")

    print(
        f"[PASS] case={args.case} status={status} route={route}"
        + (f" error={error}" if args.expect_error is not None else "")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
