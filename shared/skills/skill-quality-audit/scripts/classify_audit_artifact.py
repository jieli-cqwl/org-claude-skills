#!/usr/bin/env python3
"""Classify a skill-quality-audit artifact before treating it as evidence."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


TRANSCRIPT_RE = re.compile(
    r"(Claude Code|^⏺|ctrl\+o to expand|^✻ Cooked|^※ recap:|Read \d+ file|Searched for \d+ pattern)",
    re.MULTILINE,
)


def classify(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if TRANSCRIPT_RE.search(text):
        return "transcript"
    if path.suffix == ".json":
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            return "invalid_json"
        if isinstance(data, dict) and data.get("artifact_type") == "skill-audit-report":
            return "formal_json"
        if isinstance(data, dict) and data.get("artifact_type") == "skill-audit-alignment":
            return "alignment_json"
        return "json"
    if re.search(r"(?m)^Verdict:\s*`?(fit|conditional|unfit|blocked)`?", text):
        return "summary_markdown"
    return "markdown"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: classify_audit_artifact.py <artifact-path>", file=sys.stderr)
        return 2
    path = Path(argv[1])
    if not path.is_file():
        print(f"[FAIL] artifact does not exist: {path}", file=sys.stderr)
        return 1
    print(f"artifact_type={classify(path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
