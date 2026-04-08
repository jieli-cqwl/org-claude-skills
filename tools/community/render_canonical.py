#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


REQUIRED = [
    ROOT / "community" / "SOURCES.yaml",
    ROOT / "contracts" / "small-chain.yaml",
    ROOT / "contracts" / "superpowers-boundary.yaml",
    ROOT / "community" / "superpowers" / "skills" / "brainstorming" / "SKILL.md",
    ROOT / "community" / "superpowers" / "skills" / "writing-plans" / "SKILL.md",
    ROOT / "community" / "superpowers" / "skills" / "subagent-driven-development" / "SKILL.md",
    ROOT / "community" / "superpowers" / "skills" / "using-superpowers" / "SKILL.md",
    ROOT / "community" / "superpowers" / "skills" / "verify-change" / "SKILL.md",
    ROOT / "community" / "superpowers" / "skills" / "archive" / "SKILL.md",
]


def main() -> None:
    missing = [str(path) for path in REQUIRED if not path.exists()]
    if missing:
        for item in missing:
            print(f"[FAIL] 缺少 canonical 资产: {item}", file=sys.stderr)
        raise SystemExit(1)
    print("[PASS] canonical assets present")


if __name__ == "__main__":
    main()
