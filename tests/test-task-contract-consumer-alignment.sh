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

python3 - "$ROOT" <<'PY' || fail "Task contract consumer alignment failed"
import ast
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


def function_strings(path: Path, function_name: str) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and node.name == function_name:
            return {
                item.value
                for item in ast.walk(node)
                if isinstance(item, ast.Constant) and isinstance(item.value, str)
            }
    failures.append(f"{path}: missing function {function_name}")
    return set()


schema = json.loads(
    (root / "shared/skills/tech-lead/contracts/tasks.schema.json").read_text(encoding="utf-8")
)
task_schema = schema["allOf"][1]["properties"]["tasks"]["items"]
required = set(task_schema["required"])
properties = task_schema["properties"]
require("file_range" in required, "tasks.schema.json must require file_range")
require(
    "not the writable implementation boundary" in properties["scope_item_refs"]["description"],
    "scope_item_refs description must deny writable-boundary semantics",
)
require(
    "writable implementation boundary" in properties["file_range"]["description"],
    "file_range description must define writable-boundary semantics",
)

developer_report_schema = json.loads(
    (root / "shared/skills/developer/contracts/developer-report.schema.json").read_text(
        encoding="utf-8"
    )
)
developer_report_properties = developer_report_schema["allOf"][1]["properties"]
require(
    "Task.file_range" in developer_report_properties["task_scope"]["description"],
    "developer-report.task_scope must be described as a Task.file_range snapshot",
)

consumer_functions = [
    (
        root / "shared/skills/delivery-owner/scripts/intake_preflight_check.py",
        "task_scope",
    ),
    (root / "shared/skills/developer/scripts/preflight_check.py", "task_scope"),
    (root / "shared/skills/verify/scripts/preflight_check.py", "task_scope"),
    (root / "tools/community/validate_developer_runtime_contract.py", "allowed_files"),
]
for path, function_name in consumer_functions:
    strings = function_strings(path, function_name)
    require("file_range" in strings, f"{path}: {function_name} must consume file_range")
    for forbidden in ("scope_item_refs", "files", "task_scope", "scope"):
        require(
            forbidden not in strings,
            f"{path}: {function_name} must not accept {forbidden} as writable scope",
        )


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


source = root / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
with tempfile.TemporaryDirectory(prefix="task-contract-consumer-") as tmp:
    feature = Path(tmp) / "sample-feature"
    shutil.copytree(source, feature)
    phase_dir = feature / "phase-1"
    tasks_path = phase_dir / "tasks.json"
    tasks = json.loads(tasks_path.read_text(encoding="utf-8"))
    task = tasks["tasks"][0]
    task.pop("file_range", None)
    task["scope_item_refs"] = ["examples/not-a-writable-boundary.py"]
    tasks_path.write_text(json.dumps(tasks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    delivery = run(
        [
            "python3",
            "shared/skills/delivery-owner/scripts/intake_preflight_check.py",
            "--phase-dir",
            str(phase_dir),
        ],
        root,
    )
    require(delivery.returncode != 0, "delivery-owner intake must reject missing file_range")
    require('"failure_code": "MISSING_SCOPE"' in delivery.stdout, "delivery-owner failure must be MISSING_SCOPE")
    require("task.file_range" in delivery.stdout, "delivery-owner failure must name task.file_range")

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
    require(developer.returncode != 0, "developer preflight must reject missing file_range")
    require('"failure_code": "AMBIGUOUS_SCOPE"' in developer.stdout, "developer failure must be AMBIGUOUS_SCOPE")

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
    require(verify.returncode != 0, "verify preflight must reject missing file_range")
    require('"failure_code": "AMBIGUOUS_SCOPE"' in verify.stdout, "verify failure must be AMBIGUOUS_SCOPE")

    runtime = run(
        [
            "python3",
            "tools/community/validate_developer_runtime_contract.py",
            "--phase-dir",
            str(phase_dir),
            "--task-id",
            "T1",
            "--report",
            str(phase_dir / "unit-1/tasks/T1/developer-report.json"),
        ],
        root,
    )
    require(runtime.returncode != 0, "developer runtime validator must reject missing file_range")
    require(
        '"failure_code": "AMBIGUOUS_SCOPE"' in runtime.stdout,
        "developer runtime failure must be AMBIGUOUS_SCOPE",
    )

if failures:
    raise SystemExit("\n".join(failures))
PY

assert_present "${BT}scope_item_refs${BT} 只说明范围来源；${BT}file_range${BT}" \
  "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present "Task ${BT}file_range${BT}" "$ROOT/shared/skills/developer/SKILL.md"
assert_present "Task ${BT}file_range${BT}" "$ROOT/shared/skills/verify/SKILL.md"
assert_present "QA ${BT}scope${BT} 只裁剪 QA_A-D 执行阶段" "$ROOT/shared/skills/qa/SKILL.md"
assert_present "可写边界只来自 Task ${BT}file_range${BT}" \
  "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_present "L2-5.*${BT}file_range${BT}" \
  "$ROOT/shared/skills/consistency-audit/references/check-matrix.md"

printf '[PASS] task contract consumer alignment\n'
