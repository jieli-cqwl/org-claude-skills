#!/usr/bin/env python3
"""Validate qa intake inputs before QA executes."""

from __future__ import annotations

import argparse
import json
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any


FAILURE_OWNER = {
    "MISSING_INPUT": "delivery-owner",
    "INVALID_JSON": "delivery-owner",
    "VERIFIER_NOT_PASS": "delivery-owner",
    "HANDOFF_INCOMPLETE": "test-design",
    "SCHEMA_FAILURE": "delivery-owner",
}

FAILURE_DECISION = {
    "MISSING_INPUT": "NEEDS_INPUT",
    "INVALID_JSON": "NEEDS_INPUT",
    "VERIFIER_NOT_PASS": "NEEDS_BASELINE",
    "HANDOFF_INCOMPLETE": "NEEDS_BASELINE",
    "SCHEMA_FAILURE": "NEEDS_BASELINE",
}

EXIT_INIT_ERROR = 1
EXIT_NEEDS_INPUT = 2
EXIT_NEEDS_BASELINE = 3


class PreflightFailure(Exception):
    def __init__(
        self, code: str, reason: str, missing: list[str] | None = None
    ) -> None:
        super().__init__(reason)
        self.code = code
        self.reason = reason
        self.missing = missing or []


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument(
        "--skip-verifier",
        action="store_true",
        help="skip verifier-result PASS check (for non-standard-chain usage)",
    )
    return parser.parse_args(argv)


def load_json(path: Path, missing_name: str) -> dict[str, Any]:
    if not path.is_file():
        raise PreflightFailure(
            "MISSING_INPUT", f"missing required file: {path}", [missing_name]
        )
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise PreflightFailure(
            "INVALID_JSON", f"malformed JSON: {path}: {exc}", [missing_name]
        ) from exc
    if not isinstance(payload, dict):
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"top-level JSON must be an object: {path}",
            [missing_name],
        )
    return payload


def list_units(phase_dir: Path) -> list[Path]:
    units_dir = phase_dir / "units"
    if not units_dir.is_dir():
        raise PreflightFailure(
            "MISSING_INPUT", f"missing units directory: {units_dir}", ["units/"]
        )
    units = sorted(p for p in units_dir.glob("UNIT-*.json") if p.is_file())
    if not units:
        raise PreflightFailure(
            "MISSING_INPUT",
            f"no UNIT-*.json found in {units_dir}",
            ["units/UNIT-*.json"],
        )
    return units


def list_test_cases(phase_dir: Path) -> list[Path]:
    candidates = sorted(phase_dir.glob("unit-*/test-cases.json"))
    if not candidates:
        raise PreflightFailure(
            "MISSING_INPUT",
            f"no unit-*/test-cases.json found under {phase_dir}",
            ["unit-*/test-cases.json"],
        )
    return [p for p in candidates if p.is_file()]


def validate_test_cases(path: Path) -> None:
    payload = load_json(path, str(path.relative_to(path.parents[1])))
    contract = payload.get("qa_handoff_contract")
    if not isinstance(contract, list) or not contract:
        raise PreflightFailure(
            "HANDOFF_INCOMPLETE",
            f"qa_handoff_contract missing or empty: {path}",
            [str(path)],
        )
    stages_seen: set[str] = set()
    for idx, item in enumerate(contract):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "HANDOFF_INCOMPLETE",
                f"qa_handoff_contract[{idx}] must be an object: {path}",
                [str(path)],
            )
        stage = item.get("qa_stage")
        if stage not in {"QA_A", "QA_B", "QA_C", "QA_D"}:
            raise PreflightFailure(
                "HANDOFF_INCOMPLETE",
                f"qa_handoff_contract[{idx}].qa_stage must be QA_A/B/C/D: {path}",
                [str(path)],
            )
        stages_seen.add(stage)
        mode = item.get("execution_mode")
        if mode not in {"browser_required", "non_browser_ok"}:
            raise PreflightFailure(
                "HANDOFF_INCOMPLETE",
                f"qa_handoff_contract[{idx}].execution_mode must be browser_required "
                f"or non_browser_ok: {path}",
                [str(path)],
            )


def validate_verifier(phase_dir: Path) -> None:
    candidates: list[Path] = []
    candidates += sorted(phase_dir.glob("unit-*/tasks/*/verify-result.json"))
    candidates += sorted(phase_dir.glob("tasks/*/verify-result.json"))
    candidates += sorted(phase_dir.glob("verify-result.json"))
    if not candidates:
        raise PreflightFailure(
            "MISSING_INPUT",
            f"no verify-result.json found under {phase_dir}",
            ["unit-*/tasks/*/verify-result.json"],
        )
    for path in candidates:
        if not path.is_file():
            continue
        payload = load_json(path, str(path))
        gate = payload.get("gate_result")
        if gate not in {"PASS", "SPEC_OK"}:
            raise PreflightFailure(
                "VERIFIER_NOT_PASS",
                f"verify-result.json gate_result must be PASS or SPEC_OK, got "
                f"{gate!r}: {path}",
                [str(path)],
            )


def resolve_phase_dir(raw: Path) -> Path:
    phase_dir = raw.expanduser().resolve()
    if not phase_dir.is_dir():
        raise PreflightFailure(
            "MISSING_INPUT", f"phase-dir does not exist: {phase_dir}", ["phase-dir"]
        )
    return phase_dir


def validate(args: argparse.Namespace) -> dict[str, Any]:
    phase_dir = resolve_phase_dir(args.phase_dir)
    load_json(phase_dir / "phase-prd.json", "phase-prd.json")
    load_json(phase_dir / "plan.json", "plan.json")
    load_json(phase_dir / "artifact-registry.json", "artifact-registry.json")
    brief_candidates = sorted(phase_dir.parent.glob("brief.json"))
    if not brief_candidates:
        raise PreflightFailure(
            "MISSING_INPUT",
            f"brief.json not found under {phase_dir.parent}",
            ["brief.json"],
        )
    load_json(brief_candidates[0], "brief.json")
    list_units(phase_dir)
    for test_cases_path in list_test_cases(phase_dir):
        validate_test_cases(test_cases_path)
    if not args.skip_verifier:
        validate_verifier(phase_dir)
    return {"status": "PASS", "phase_dir": str(phase_dir)}


def failure_payload(exc: PreflightFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "failure_code": exc.code,
        "decision": FAILURE_DECISION[exc.code],
        "owner": FAILURE_OWNER[exc.code],
        "reason": exc.reason,
        "missing_inputs": exc.missing,
    }


def exit_code_for(exc: PreflightFailure) -> int:
    decision = FAILURE_DECISION[exc.code]
    if decision == "NEEDS_INPUT":
        return EXIT_NEEDS_INPUT
    if decision == "NEEDS_BASELINE":
        return EXIT_NEEDS_BASELINE
    return EXIT_INIT_ERROR


def main(argv: list[str]) -> int:
    try:
        args = parse_args(argv)
    except SystemExit as exc:
        return exc.code if isinstance(exc.code, int) else EXIT_INIT_ERROR
    try:
        result = validate(args)
    except PreflightFailure as exc:
        print(json.dumps(failure_payload(exc), ensure_ascii=False, sort_keys=True))
        return exit_code_for(exc)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
