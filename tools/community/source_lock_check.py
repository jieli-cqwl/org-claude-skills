#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "community" / "SOURCES.yaml"
EXPECTED_REPOS = {
    "openspec": "https://github.com/Fission-AI/OpenSpec",
    "superpowers": "https://github.com/obra/superpowers",
}


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def extract_source_block(text: str, source_name: str) -> str:
    pattern = re.compile(
        rf"^  {re.escape(source_name)}:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
        flags=re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        fail(f"SOURCES.yaml 缺少 source 节点: {source_name}")
    return m.group("body")


def require_pattern(block: str, pattern: str, message: str) -> None:
    if not re.search(pattern, block, flags=re.MULTILINE):
        fail(message)


def require_nonempty_list(block: str, key: str, source_name: str) -> None:
    m = re.search(
        rf"^    {re.escape(key)}:\s*$\n(?P<items>(?:^      - .*(?:\n|$))+)",
        block,
        flags=re.MULTILINE,
    )
    if not m:
        fail(f"SOURCES.yaml 中 {source_name}.{key} 缺失或为空列表")


def validate_source(text: str, source_name: str, expected_repo: str) -> None:
    block = extract_source_block(text, source_name)
    require_pattern(
        block,
        rf"^    repo: {re.escape(expected_repo)}$",
        f"SOURCES.yaml 中 {source_name}.repo 不匹配预期: {expected_repo}",
    )
    require_pattern(
        block,
        r"^    ref: \S.+$",
        f"SOURCES.yaml 中 {source_name}.ref 缺失或为空",
    )
    require_pattern(
        block,
        r"^    captured_at: \d{4}-\d{2}-\d{2}$",
        f"SOURCES.yaml 中 {source_name}.captured_at 格式错误",
    )
    require_nonempty_list(block, "scope", source_name)
    require_nonempty_list(block, "notes", source_name)


def main(argv: list[str]) -> None:
    if len(argv) > 2:
        fail("用法: source_lock_check.py [<SOURCES.yaml 路径>]")

    lock_path = Path(argv[1]) if len(argv) == 2 else LOCK
    if not lock_path.is_file():
        fail(f"缺少 source lock 文件: {lock_path}")

    text = lock_path.read_text(encoding="utf-8")

    require_pattern(text, r"^sources:\s*$", "SOURCES.yaml 缺少顶层 sources 节点")
    for source_name, expected_repo in EXPECTED_REPOS.items():
        validate_source(text, source_name, expected_repo)

    print("[PASS] source lock valid")


if __name__ == "__main__":
    main(sys.argv)
