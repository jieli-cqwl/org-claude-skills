#!/usr/bin/env python3
"""Validate skill-quality-audit alignment artifacts."""

from __future__ import annotations

import sys
from pathlib import Path

from skill_audit_alignment_contract import load_alignment


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_skill_audit_alignment.py <alignment.json>", file=sys.stderr)
        return 2
    load_alignment(Path(argv[1]))
    print("[PASS] skill audit alignment valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
