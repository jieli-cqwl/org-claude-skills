#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from types import ModuleType
from typing import Any

SCENARIOS = {
    "create-dev",
    "dev-sync",
    "release-merge",
    "bugfix",
    "bugfix-finish",
    "release-sync-before",
    "release-sync-after",
}


def load_core() -> ModuleType:
    module_path = Path(__file__).resolve().with_name("qft_branch_flow_core.py")
    spec = importlib.util.spec_from_file_location("qft_branch_flow_core", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load {module_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate and validate QFT branch flow plans."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan_parser = subparsers.add_parser("plan", help="generate a branch operation plan")
    plan_parser.add_argument("scenario", choices=sorted(SCENARIOS))
    plan_parser.add_argument("--projects", required=True)
    plan_parser.add_argument("--version", required=True)
    plan_parser.add_argument("--bug-version")
    plan_parser.add_argument("--owner")
    plan_parser.add_argument("--requirement")
    plan_parser.add_argument("--delay", action="store_true")
    plan_parser.add_argument("--business-branches")
    plan_parser.add_argument("--business-branch")

    validate_parser = subparsers.add_parser(
        "validate", help="validate a branch operation plan"
    )
    validate_parser.add_argument("--input")

    preflight_parser = subparsers.add_parser(
        "preflight", help="check repositories before executing a plan"
    )
    preflight_parser.add_argument("--input")
    preflight_parser.add_argument(
        "--repo-root",
        default=".",
        help="directory containing selected project repositories",
    )

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    core: Any = load_core()
    try:
        if args.command == "plan":
            plan = core.make_plan(args)
            core.validate_plan(plan)
            print(json.dumps(plan, ensure_ascii=False, indent=2))
            return 0
        plan = core.read_input_plan(args.input)
        core.validate_plan(plan)
        if args.command == "preflight":
            result = core.preflight_plan(plan, args.repo_root)
            print(json.dumps(result, ensure_ascii=False, indent=2))
            return 0 if result["status"] == "ok" else 1
        return 0
    except core.FlowError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
