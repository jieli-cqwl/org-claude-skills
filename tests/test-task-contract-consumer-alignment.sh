#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BT='`'
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 \
    || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

python3 - "$ROOT" <<'PY' || fail "Task contract consumer alignment failed"
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
failures: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


schema = json.loads(
    (root / "shared/skills/tech-lead/contracts/tasks.schema.json").read_text(encoding="utf-8")
)
task_schema = schema["allOf"][1]["properties"]["tasks"]["items"]
required = set(task_schema["required"])
properties = task_schema["properties"]
require("file_range" not in required, "tasks.schema.json must not require file_range")
require("file_range" not in properties, "tasks.schema.json must not define file_range property")
require(
    "not the writable implementation boundary" in properties["scope_item_refs"]["description"],
    "scope_item_refs description must deny writable-boundary semantics",
)

developer_report_schema = json.loads(
    (root / "shared/skills/developer/contracts/developer-report.schema.json").read_text(
        encoding="utf-8"
    )
)
developer_report_properties = developer_report_schema["allOf"][1]["properties"]
require(
    "impact" in developer_report_properties["task_scope"]["description"].lower(),
    "developer-report.task_scope must reference impact analysis, not file_range",
)
require(
    "file_range" not in developer_report_properties["task_scope"]["description"],
    "developer-report.task_scope must not reference file_range",
)


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


source = root / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
with tempfile.TemporaryDirectory(prefix="task-contract-consumer-") as tmp:
    feature = Path(tmp) / "sample-feature"
    shutil.copytree(source, feature)
    phase_dir = feature / "phase-1"

    delivery = run(
        [
            "python3",
            "shared/skills/delivery-owner/scripts/intake_preflight_check.py",
            "--phase-dir",
            str(phase_dir),
        ],
        root,
    )
    require(delivery.returncode == 0, "delivery-owner intake must pass without file_range")

    developer = run(
        [
            "python3",
            "shared/skills/developer/scripts/preflight_check.py",
            "--phase-dir",
            str(phase_dir),
            "--task-id",
            "T1",
        ],
        root,
    )
    require(developer.returncode == 0, "developer preflight must pass without file_range")

    verify = run(
        [
            "python3",
            "shared/skills/verify/scripts/preflight_check.py",
            "--phase-dir",
            str(phase_dir),
            "--task-id",
            "T1",
        ],
        root,
    )
    require(verify.returncode == 0, "verify preflight must pass without file_range")

if failures:
    raise SystemExit("\n".join(failures))
PY

assert_present "scope_item_refs.*范围来源" "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/developer/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/verify/SKILL.md"
assert_present "QA ${BT}scope${BT} 只裁剪 QA_A-D 执行阶段" "$ROOT/shared/skills/qa/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/qa/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_absent "file_range" "$ROOT/shared/skills/consistency-audit/references/check-matrix.md"

printf '[PASS] task contract consumer alignment\n'
