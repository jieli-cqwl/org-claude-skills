#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

try:
    import sync_canonical_from_upstream as sync  # type: ignore
except ModuleNotFoundError:
    from tools.community import sync_canonical_from_upstream as sync


ROOT = Path(__file__).resolve().parents[2]


REQUIRED = [
    ROOT / "community" / "SOURCES.yaml",
    ROOT / "contracts" / "standard-chain.yaml",
    ROOT / "contracts" / "superpowers-boundary.yaml",
    *(ROOT / "community" / "superpowers" / "skills" / skill / "SKILL.md" for skill in sync.OFFICIAL_SUPERPOWERS_SKILLS),
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
