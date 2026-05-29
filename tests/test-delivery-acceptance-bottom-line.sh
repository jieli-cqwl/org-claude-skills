#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" <<'PY' || fail "delivery acceptance bottom line contract violated"
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
path = root / "shared" / "rules" / "交付验收底线.md"
text = path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


require(text.startswith("# 交付验收底线\n"), "title should name delivery acceptance bottom line")
require("Why：" not in text, "rules should not keep explanation-only Why blocks")
require("铁律" not in text, "old metaphor should not remain in active rule source")
require("红灯" not in text, "verification failures should use direct wording")

required_sections = [
    "失败处理",
    "验收证据",
    "验证失败",
    "真实实现",
    "完成声明",
]
for section in required_sections:
    require(f"## {section}" in text, f"missing section: {section}")

required_anchors = [
    "原目标、原成功标准和原验证口径",
    "停止交付并请求用户裁决",
    "只允许无副作用采证",
    "验收结论必须来自真实依赖、真实测试环境或已验证集成路径",
    "不能单独证明真实集成通过",
    "目标内失败必须修根因；目标外失败只报告",
    "禁止用 skip、xfail、注释、删除测试或放宽断言绕过失败",
    "完成状态必须来自真实实现",
    "必须重新执行并看到本次成功输出",
]
for anchor in required_anchors:
    require(anchor in text, f"missing bottom-line anchor: {anchor}")
PY

echo "[PASS] delivery acceptance bottom line"
