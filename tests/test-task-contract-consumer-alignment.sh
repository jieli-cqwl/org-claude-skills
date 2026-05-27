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
sys.path.insert(0, str(root / "tools" / "community"))
from runtime_yaml import load_yaml

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


field_contract = load_yaml(root / "contracts" / "standard-chain-field-consumption.yaml")
fields_by_path = {
    artifact["path"]: artifact.get("fields", {})
    for artifact in field_contract.get("artifacts", [])
}


def consumers_for(path: str, field: str) -> dict[str, str]:
    consumers = fields_by_path[path][field]["consumers"]
    return {entry["consumer"]: entry["consume_mode"] for entry in consumers}


def require_consumer(path: str, field: str, consumer: str, mode: str) -> None:
    consumers = consumers_for(path, field)
    require(
        consumers.get(consumer) == mode,
        f"{path}#{field} must be consumed by {consumer} as {mode}",
    )


brief_path = "docs/{feature}/brief.json"
phase_prd_path = "docs/{feature}/phase-{N}/phase-prd.json"
unit_path = "docs/{feature}/phase-{N}/units/UNIT-{N}.json"
design_path = "docs/{feature}/phase-{N}/design.json"

require_consumer(brief_path, "acceptance_criteria", "test-design", "transform")
require_consumer(unit_path, "verification_plan", "test-design", "transform")
for field in ("risk_ledger", "release_readiness"):
    require_consumer(phase_prd_path, field, "qa", "gate")
    require_consumer(phase_prd_path, field, "delivery-owner", "gate")
for field in ("design_decision_candidates", "technical_evidence_requirements"):
    require_consumer(phase_prd_path, field, "design", "handoff")
require_consumer(design_path, "verification_mapping", "test-design", "transform")
for field in ("planning_constraints", "migration_plan", "rollback_plan"):
    require_consumer(design_path, field, "tech-lead", "transform" if field != "planning_constraints" else "gate")
    require_consumer(design_path, field, "delivery-owner", "gate")

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
