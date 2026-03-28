#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def move_tree(src: Path, dst: Path) -> None:
    if not src.exists():
        return
    dst.mkdir(parents=True, exist_ok=True)
    for item in sorted(src.iterdir()):
        target = dst / item.name
        if target.exists():
            raise SystemExit(f"[FAIL] 目标已存在，拒绝覆盖: {target}")
        shutil.move(str(item), str(target))
    try:
        src.rmdir()
    except OSError:
        pass


def main() -> None:
    move_tree(ROOT / "docs" / "superpowers" / "specs", ROOT / "openspec" / "designs")
    move_tree(ROOT / "docs" / "superpowers" / "plans", ROOT / "openspec" / "plans")
    print("[PASS] workspace paths migrated")


if __name__ == "__main__":
    main()
