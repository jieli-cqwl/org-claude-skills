#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" <<'PY' || fail "iron law degradation boundary contract violated"
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
path = root / "shared" / "rules" / "铁律.md"
text = path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


match = re.search(r"^## 禁止静默降级\n(?P<body>.*?)(?=^## |\Z)", text, re.M | re.S)
require(match is not None, "missing section: 禁止静默降级")
body = match.group("body")

require("## 禁止降级" not in text, "ambiguous section title should be 禁止静默降级")
require("方案执行失败时，必须立即停止" not in body, "ambiguous immediate-stop wording should be removed")

required_anchors = [
    "失败时先分类",
    "同一方案、同一成功标准、同一验证口径",
    "有界重试",
    "受控诊断",
    "停止交付推进",
    "报告用户裁决",
]
for anchor in required_anchors:
    require(anchor in body, f"missing degradation boundary anchor: {anchor}")
PY

echo "[PASS] iron law degradation boundary"
