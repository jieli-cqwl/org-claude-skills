#!/usr/bin/env python3
"""Validate final consistency-audit runtime evidence closure."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

CANONICAL_REF_RE = re.compile(
    r"^artifact://[a-z][a-z0-9-]*/[A-Za-z0-9._-]+@[A-Za-z0-9._-]+#[A-Za-z0-9._:-]+$"
)
PASSING_RESULTS = {"PASS"}
NON_REQUIRED_RESULTS = {"PASS", "N_A", "NOT_RUN"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    return parser.parse_args(argv)


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise FileNotFoundError(f"missing required runtime-chain artifact: {path}") from None
    if not isinstance(payload, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return payload


def canonical_ref_list(value: Any, field: str) -> list[str]:
    if not isinstance(value, list) or not value:
        raise ValueError(f"{field} must be a non-empty canonical ref array")
    refs: list[str] = []
    for index, item in enumerate(value, start=1):
        if not isinstance(item, str) or not CANONICAL_REF_RE.match(item):
            raise ValueError(f"{field}[{index}] must be a canonical artifact ref")
        refs.append(item)
    return refs


def collect_test_obligations(phase_dir: Path) -> dict[str, dict[str, Any]]:
    obligations: dict[str, dict[str, Any]] = {}
    test_case_paths = sorted(phase_dir.glob("unit-*/test-cases.json"))
    if not test_case_paths:
        raise FileNotFoundError(f"{phase_dir / 'unit-*/test-cases.json'} (test-cases)")

    payloads: list[tuple[str, dict[str, Any]]] = []
    for test_cases_path in test_case_paths:
        payload = load_json(test_cases_path)
        payloads.append((str(test_cases_path), payload))
        rows = payload.get("qa_handoff_contract")
        if not isinstance(rows, list) or not rows:
            raise ValueError(f"{test_cases_path} qa_handoff_contract must be a non-empty array")
        for index, row in enumerate(rows, start=1):
            if not isinstance(row, dict):
                raise ValueError(f"{test_cases_path} qa_handoff_contract[{index}] must be an object")
            obligation_id = str(row.get("obligation_id", "")).strip()
            if not obligation_id:
                raise ValueError(f"{test_cases_path} qa_handoff_contract[{index}] missing obligation_id")
            if obligation_id in obligations:
                raise ValueError(f"duplicate QA handoff obligation_id: {obligation_id}")
            obligations[obligation_id] = {
                "obligation_id": obligation_id,
                "qa_stage": str(row.get("qa_stage", "")).strip(),
                "requiredness": str(row.get("requiredness", "")).strip() or "REQUIRED",
                "execution_mode": str(row.get("execution_mode", "")).strip(),
                "source_path": str(test_cases_path),
            }
    for label, payload in payloads:
        assert_handoff_refs_resolve(payload, obligations, label)
    return obligations


def assert_handoff_refs_resolve(payload: dict[str, Any], obligations: dict[str, dict[str, Any]], label: str) -> None:
    known_ids = set(obligations)
    for field_name in ("cross_unit_obligations", "special_test_triggers"):
        rows = payload.get(field_name, [])
        if not isinstance(rows, list):
            continue
        for index, row in enumerate(rows, start=1):
            if not isinstance(row, dict):
                continue
            ref_field = "handoff_obligation_refs"
            if field_name == "special_test_triggers":
                if row.get("handling") != "QA_HANDOFF":
                    continue
                ref_field = "qa_handoff_obligation_refs"
            refs = row.get(ref_field, [])
            if not isinstance(refs, list):
                raise ValueError(f"{label} {field_name}[{index}].{ref_field} must be an array")
            unknown = sorted(str(ref) for ref in refs if str(ref) not in known_ids)
            if unknown:
                raise ValueError(f"{label} {field_name}[{index}] references unknown obligations: {', '.join(unknown)}")


def collect_obligation_results(qa_result: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = qa_result.get("obligation_results")
    if not isinstance(rows, list):
        raise ValueError("qa-result obligation_results must be an array")
    results: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            raise ValueError(f"qa-result obligation_results[{index}] must be an object")
        obligation_id = str(row.get("obligation_id", "")).strip()
        if not obligation_id:
            raise ValueError(f"qa-result obligation_results[{index}] missing obligation_id")
        if obligation_id in results:
            raise ValueError(f"qa-result duplicate obligation_results obligation_id: {obligation_id}")
        canonical_ref_list(row.get("source_refs"), f"qa-result obligation_results[{index}].source_refs")
        canonical_ref_list(row.get("evidence_refs"), f"qa-result obligation_results[{index}].evidence_refs")
        results[obligation_id] = row
    return results


def assert_runtime_chain_closed(phase_dir: Path) -> None:
    phase_dir = phase_dir.resolve()
    obligations = collect_test_obligations(phase_dir)
    results = collect_obligation_results(load_json(phase_dir / "qa-result.json"))

    unknown_results = sorted(set(results) - set(obligations))
    if unknown_results:
        raise ValueError(f"qa-result obligation_results references unknown obligations: {', '.join(unknown_results)}")

    missing_required = [
        obligation_id
        for obligation_id, obligation in obligations.items()
        if obligation["requiredness"] == "REQUIRED" and obligation_id not in results
    ]
    if missing_required:
        raise ValueError(f"qa-result obligation_results missing required obligations: {', '.join(missing_required)}")

    for obligation_id, obligation in obligations.items():
        result = results.get(obligation_id)
        if result is None:
            continue
        gate_result = str(result.get("gate_result", "")).strip()
        qa_stage = str(result.get("qa_stage", "")).strip()
        if qa_stage != obligation["qa_stage"]:
            raise ValueError(f"qa-result obligation_results {obligation_id} qa_stage drift: {qa_stage}")
        if obligation["requiredness"] == "REQUIRED" and gate_result not in PASSING_RESULTS:
            raise ValueError(f"qa-result obligation_results {obligation_id} must PASS at readiness")
        if obligation["requiredness"] != "REQUIRED" and gate_result not in NON_REQUIRED_RESULTS:
            raise ValueError(f"qa-result obligation_results {obligation_id} has invalid non-required result: {gate_result}")


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        assert_runtime_chain_closed(args.phase_dir)
    except (FileNotFoundError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps({"status": "PASS", "decision": "RUNTIME_CHAIN_CLOSED"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
