#!/usr/bin/env python3
"""CLI wrapper for the delivery-estimator schedule-plan model."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from schedule_model import EstimateError, build_result, read_json, render_markdown


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Calculate a delivery schedule plan from task PERT inputs.")
    parser.add_argument("--input", required=True, help="Path to estimate input JSON.")
    parser.add_argument("--output", default="-", help="Path to output JSON, or '-' for stdout.")
    parser.add_argument("--markdown", help="Optional path to a human-readable Markdown schedule plan.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        result = build_result(read_json(Path(args.input)))
    except EstimateError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output == "-":
        print(output, end="")
    else:
        Path(args.output).write_text(output, encoding="utf-8")
    if args.markdown:
        Path(args.markdown).write_text(render_markdown(result), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
