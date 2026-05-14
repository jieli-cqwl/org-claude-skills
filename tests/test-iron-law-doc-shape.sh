#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" <<'PY' || fail "iron law doc shape contract violated"
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
path = root / "shared" / "rules" / "铁律.md"
text = path.read_text(encoding="utf-8")
line_count = len(text.splitlines())

if line_count > 65:
    raise SystemExit(f"铁律.md too verbose: {line_count} lines > 65")

required_sections = [
    "禁止静默降级",
    "禁止伪造验收",
    "禁止绕过失败测试",
    "完成必须有证据",
    "明确状态与不确定性",
]


def section_body(title: str) -> str:
    pattern = re.compile(
        rf"^## {re.escape(title)}\n(?P<body>.*?)(?=^## |\Z)",
        re.M | re.S,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"missing section: {title}")
    return match.group("body")


if "## 总原则" not in text:
    raise SystemExit("missing 总原则 section")

legacy_buckets = ["## 零容忍行为", "## 常见绕过借口"]
for bucket in legacy_buckets:
    if bucket in text:
        raise SystemExit(f"legacy bucket should be removed: {bucket}")

for title in required_sections:
    body = section_body(title)
    positions = []
    for marker in ["Why：", "核心思路：", "常见坑："]:
        index = body.find(marker)
        if index == -1:
            raise SystemExit(f"{title} missing marker: {marker}")
        positions.append(index)
    if positions != sorted(positions):
        raise SystemExit(f"{title} markers are out of order")

required_anchors = [
    "同一方案、同一成功标准、同一验证口径",
    "Mock",
    "skip",
    "xfail",
    "先实现再补测试",
    "{{RUNTIME_HOME}}/reference/完成前验证.md",
    "{{RUNTIME_HOME}}/rules/代码规范.md",
]
for anchor in required_anchors:
    if anchor not in text:
        raise SystemExit(f"missing required anchor: {anchor}")
PY

echo "[PASS] iron law doc shape"
