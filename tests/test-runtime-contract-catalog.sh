#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

CATALOG="$ROOT/shared/runtime/runtime-catalog.json"
RENDERER="$ROOT/tools/community/render_runtime_contract.py"

test -d "$ROOT/shared/runtime" || fail "missing shared/runtime directory"
test -f "$CATALOG" || fail "missing runtime catalog: $CATALOG"
test -f "$RENDERER" || fail "missing runtime renderer: $RENDERER"

python3 - "$CATALOG" <<'PY' || fail "runtime catalog schema invalid"
import json
import sys
from pathlib import Path

catalog_path = Path(sys.argv[1])
data = json.loads(catalog_path.read_text(encoding="utf-8"))

targets = data.get("targets")
if not isinstance(targets, list) or not targets:
    raise SystemExit("targets must be a non-empty list")

required_targets = {
    "assistant",
    "rules/铁律.md",
    "rules/代码规范.md",
    "rules/执行纪律.md",
    "rules/文档管理.md",
}
seen_targets = set()
seen_ids = set()
allowed_modes = {"inline_summary", "runtime_link", "human_only"}

for item in targets:
    if not isinstance(item, dict):
        raise SystemExit("target item must be a mapping")

    target = item.get("target")
    if not isinstance(target, str) or not target:
        raise SystemExit("target must be a non-empty string")
    seen_targets.add(target)

    entries = item.get("entries")
    if not isinstance(entries, list) or not entries:
        raise SystemExit(f"{target}: entries must be a non-empty list")

    for entry in entries:
        if not isinstance(entry, dict):
            raise SystemExit(f"{target}: entry must be a mapping")

        entry_id = entry.get("id")
        if not isinstance(entry_id, str) or not entry_id:
            raise SystemExit(f"{target}: missing entry id")
        if entry_id in seen_ids:
            raise SystemExit(f"duplicate entry id: {entry_id}")
        seen_ids.add(entry_id)

        mode = entry.get("mode")
        if mode not in allowed_modes:
            raise SystemExit(f"{target}: invalid mode for {entry_id}: {mode}")

        owner = entry.get("owner")
        if not isinstance(owner, str) or owner not in {"assistant", "rules", "reference"}:
            raise SystemExit(f"{target}: invalid owner for {entry_id}: {owner}")

        source_path = entry.get("source_path")
        if not isinstance(source_path, str) or not source_path:
            raise SystemExit(f"{target}: missing source_path for {entry_id}")
        if not (catalog_path.parent.parent / source_path).exists():
            raise SystemExit(f"{target}: source_path missing for {entry_id}: {source_path}")

        if mode != "human_only":
            runtime_summary = entry.get("runtime_summary")
            if not isinstance(runtime_summary, str) or not runtime_summary.strip():
                raise SystemExit(f"{target}: runtime_summary required for {entry_id}")

if not required_targets.issubset(seen_targets):
    missing = sorted(required_targets - seen_targets)
    raise SystemExit(f"missing required targets: {missing}")

shared_entry_targets = {
    "reference/测试规范.md": ["assistant"],
    "reference/代码复用.md": ["assistant"],
    "reference/完成前验证.md": ["assistant"],
    "reference/全栈开发.md": ["assistant"],
    "reference/性能效率.md": ["assistant"],
    "reference/硬编码治理规范.md": ["assistant"],
    "reference/代码质量.md": ["assistant"],
}
forbidden_runtime_paths = {
    "reference/mcp-server开发.md",
    "reference/Skill质量标准.md",
}

reference_runtime_targets = {}
mounted_targets = {key: [] for key in shared_entry_targets}
for item in targets:
    target = item["target"]
    for entry in item["entries"]:
        runtime_path = entry.get("runtime_path")
        if isinstance(runtime_path, str) and runtime_path.startswith("reference/"):
            reference_runtime_targets.setdefault(runtime_path, []).append(target)
        if runtime_path in mounted_targets:
            mounted_targets[runtime_path].append(target)

for runtime_path, actual_targets in sorted(reference_runtime_targets.items()):
    if len(actual_targets) != 1:
        raise SystemExit(
            f"{runtime_path}: reference runtime paths must be mounted exactly once, got {actual_targets}"
        )

for runtime_path, expected_targets in shared_entry_targets.items():
    actual_targets = mounted_targets[runtime_path]
    if actual_targets != expected_targets:
        raise SystemExit(
            f"{runtime_path}: expected targets {expected_targets}, got {actual_targets}"
        )

for runtime_path in sorted(forbidden_runtime_paths):
    if runtime_path in reference_runtime_targets:
        raise SystemExit(
            f"{runtime_path}: should not be mounted in runtime contract, got {reference_runtime_targets[runtime_path]}"
        )
PY

echo "[PASS] runtime contract catalog"
