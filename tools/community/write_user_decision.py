#!/usr/bin/env python3
"""Canonical writer for v1 user-decision artifacts."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

from normalize_canonical_artifact import load_json


def canonical_digest(payload: dict) -> str:
    serializable = copy.deepcopy(payload)
    serializable.pop("decision_payload_digest", None)
    serial = json.dumps(serializable, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(serial.encode("utf-8")).hexdigest()


def build_decision_payload(payload: dict) -> dict:
    result = copy.deepcopy(payload)
    if not result.get("authority_proof_refs"):
        raise ValueError("authority_proof_refs 不能为空")
    if not result.get("decision_basis_refs"):
        raise ValueError("decision_basis_refs 不能为空")
    if result.get("supersedes_decision_ref") and not result.get("authority_proof_refs"):
        raise ValueError("supersede requires fresh authority proof")
    result["decision_payload_digest"] = canonical_digest(result)
    return result


def dump_json(document: dict) -> None:
    json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    fixture = load_json(args.fixture.resolve())
    payload = fixture.get("decision_payload", fixture)
    if not isinstance(payload, dict):
        raise ValueError("decision_payload 必须是对象")
    dump_json(build_decision_payload(payload))


if __name__ == "__main__":
    main()
