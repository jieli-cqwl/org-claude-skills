#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT

python3 <<'PY'
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(os.environ["ROOT"])
schema_path = root / "contracts" / "canonical" / "schemas" / "runtime" / "failure-routing-result.schema.json"
registry_path = root / "contracts" / "standard-chain-failure-routing.yaml"
catalog_path = root / "shared" / "runtime" / "standard-chain-failure-routing.json"
tool_path = root / "tools" / "community" / "validate_failure_routing_contract.py"


def fail(message: str) -> None:
    raise AssertionError(message)


def run_tool(*args: str, expect: int = 0) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        [sys.executable, str(tool_path), "--repo-root", str(root), *args],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != expect:
        fail(
            f"validator returned {completed.returncode}, expected {expect}\n"
            f"stdout:\n{completed.stdout}\n"
            f"stderr:\n{completed.stderr}"
        )
    return completed


def expect_reject(label: str, payload: dict) -> None:
    completed = subprocess.run(
        [
            sys.executable,
            str(tool_path),
            "--repo-root",
            str(root),
            "--result-json",
            json.dumps(payload, sort_keys=True),
        ],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode == 0:
        fail(f"validator accepted invalid payload: {label}\nstdout:\n{completed.stdout}")


def valid_result(code: str, entry: dict) -> dict:
    condition = entry["continuation_condition"]
    if entry["status"] != "WARN" and not condition:
        condition = "none"
    return {
        "schema_version": "1.0.0",
        "status": entry["status"],
        "stage": "qa.preflight",
        "failure_code": code,
        "owner": entry["default_owner"],
        "next_action": entry["default_next_action"],
        "safe_to_continue": entry["safe_to_continue"],
        "human_decision_required": entry["human_decision_required"],
        "continuation_condition": condition,
        "evidence_refs": ["test://standard-chain/failure-routing"],
        "user_message": entry["message_template"],
    }


def assert_schema_rejects(validator: SimpleSchemaValidator, schema: dict, payload: dict, label: str) -> None:
    try:
        validator.validate(payload, schema)
    except SimpleValidationError:
        return
    fail(f"schema accepted invalid payload: {label}")


def assert_unknown_code_rejected(payload: dict, entries: dict[str, dict]) -> None:
    if payload["failure_code"] in entries:
        fail("unknown-code fixture accidentally uses a registered code")


if not schema_path.is_file():
    fail(f"missing schema: {schema_path.relative_to(root)}")
if not registry_path.is_file():
    fail(f"missing registry: {registry_path.relative_to(root)}")
if not tool_path.is_file():
    fail(f"missing validator: {tool_path.relative_to(root)}")

contract_check = run_tool()
registry = json.loads(run_tool("--print-registry-summary").stdout)
entries = registry["entries_by_code"]

for code in ["NONE", "CONDITIONAL_CONTINUE", "UNREGISTERED_FAILURE_CODE"]:
    if code not in entries:
        fail(f"missing required baseline failure code: {code}")

for code, entry in entries.items():
    payload = valid_result(code, entry)
    run_tool("--result-json", json.dumps(payload, sort_keys=True))

missing_field = valid_result("NONE", entries["NONE"])
missing_field.pop("owner")
expect_reject("missing required owner", missing_field)

unknown_status = valid_result("NONE", entries["NONE"])
unknown_status["status"] = "SKIPPED"
expect_reject("unknown status", unknown_status)

warn_without_condition = valid_result("CONDITIONAL_CONTINUE", entries["CONDITIONAL_CONTINUE"])
warn_without_condition["continuation_condition"] = ""
expect_reject("WARN without continuation_condition", warn_without_condition)

warn_with_none_condition = valid_result("CONDITIONAL_CONTINUE", entries["CONDITIONAL_CONTINUE"])
warn_with_none_condition["continuation_condition"] = "none"
expect_reject("WARN with none continuation_condition", warn_with_none_condition)

unknown_code = valid_result("NONE", entries["NONE"])
unknown_code["failure_code"] = "NOT_REGISTERED_ANYWHERE"
expect_reject("unregistered failure code", unknown_code)
assert_unknown_code_rejected(unknown_code, entries)

fallback = json.loads(run_tool("--emit-unregistered-fallback", "--stage", "qa.preflight").stdout)
if fallback["failure_code"] != "UNREGISTERED_FAILURE_CODE":
    fail("unmapped condition must route to UNREGISTERED_FAILURE_CODE")
if fallback["status"] != "BLOCKED":
    fail("UNREGISTERED_FAILURE_CODE must fail closed with status BLOCKED")
if fallback["owner"] != "delivery-owner":
    fail("UNREGISTERED_FAILURE_CODE owner must be delivery-owner")
if fallback["safe_to_continue"] is not False:
    fail("UNREGISTERED_FAILURE_CODE safe_to_continue must be false")

with tempfile.TemporaryDirectory() as tmp_dir:
    tmp = Path(tmp_dir)
    drift_registry = tmp / "standard-chain-failure-routing.yaml"
    drift_registry.write_text(registry_path.read_text(encoding="utf-8").replace('schema_version: "1.0.0"', 'schema_version: "9.9.9"'), encoding="utf-8")
    completed = subprocess.run(
        [
            sys.executable,
            str(tool_path),
            "--repo-root",
            str(root),
            "--registry",
            str(drift_registry),
        ],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode == 0:
        fail("validator accepted registry/schema version drift")

    drift_catalog = tmp / "standard-chain-failure-routing.json"
    drift_catalog.write_text(
        json.dumps({"failure_routing": {"entries": [{"failure_code": "NOT_REGISTERED_ANYWHERE"}]}}),
        encoding="utf-8",
    )
    completed = subprocess.run(
        [
            sys.executable,
            str(tool_path),
            "--repo-root",
            str(root),
            "--catalog",
            str(drift_catalog),
        ],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode == 0:
        fail("validator accepted runtime catalog drift")

print("[PASS] standard-chain failure routing contract")
PY
