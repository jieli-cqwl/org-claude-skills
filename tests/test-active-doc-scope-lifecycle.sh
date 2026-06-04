#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$ROOT/contracts/active-doc-scope.yaml" ] || fail "missing active-doc-scope registry"
[ -f "$ROOT/contracts/context-artifact-ownership.yaml" ] || fail "missing context artifact ownership contract"

python3 - "$ROOT" <<'PY' || exit 1
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "community"))
from runtime_yaml import load_yaml


def ensure(condition, message):
    if not condition:
        raise SystemExit(f"[FAIL] {message}")


registry = load_yaml(root / "contracts" / "active-doc-scope.yaml")
ensure(registry.get("version") == 2, "active-doc-scope version must be 2")
ensure(registry.get("context_contract_phase") == "cleanup", "context_contract_phase must be cleanup")

record_contract = registry.get("record_contract")
ensure(isinstance(record_contract, dict), "record_contract must be present")
required = set(record_contract.get("required", []))
for field in ["feature_path", "mode", "management_status", "layout", "entry_ref", "context_owner"]:
    ensure(field in required, f"record_contract.required missing {field}")

enums = record_contract.get("enums", {})
ensure(enums.get("management_status") == ["legacy", "managed", "migrated"], "management_status enum mismatch")
ensure(enums.get("mode") == ["standard-chain"], "mode enum must be standard-chain only")
ensure(enums.get("layout") == ["dated-workset", "phase-tree"], "layout enum mismatch")
ensure(enums.get("context_contract_phase") == ["cleanup"], "phase enum must be cleanup only")

entries = registry.get("scope_entries")
ensure(isinstance(entries, list), "scope_entries must be a list")
for entry in entries:
    ensure(entry.get("mode") == "standard-chain", f"active scope entry must be standard-chain: {entry}")

ownership = load_yaml(root / "contracts" / "context-artifact-ownership.yaml")
ensure(ownership.get("version") == 1, "ownership contract version must be 1")
repo_owners = ownership.get("repo_owners")
ensure(isinstance(repo_owners, dict), "repo_owners must be present")
for owner in ["context_registry_owner", "context_contract_owner", "context_validator_owner"]:
    ensure(owner in repo_owners and repo_owners[owner], f"repo_owners missing {owner}")

artifacts = ownership.get("artifacts")
ensure(isinstance(artifacts, list) and artifacts, "artifacts must be a non-empty list")
artifact_ids = {artifact.get("artifact_id") for artifact in artifacts}
for artifact_id in ["scope_registry", "context_artifact_ownership"]:
    ensure(artifact_id in artifact_ids, f"artifacts missing {artifact_id}")

for artifact in artifacts:
    artifact_id = artifact.get("artifact_id")
    owner = artifact.get("artifact_owner")
    path = artifact.get("path")
    ensure(owner in repo_owners, f"{artifact_id} artifact_owner does not resolve: {owner}")
    ensure(isinstance(path, str) and (root / path).exists(), f"{artifact_id} path is unreachable: {path}")

print("[PASS] active doc scope lifecycle cleanup")
PY

python3 - "$ROOT" <<'PY' || exit 1
import builtins
import os
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "community"))
from runtime_yaml import load_yaml


def ensure(condition, message):
    if not condition:
        raise SystemExit(f"[FAIL] {message}")


tmp_root = Path(os.environ.get("TMPDIR") or "/tmp")
path = tmp_root / f"runtime-yaml-fallback-{os.getpid()}.yaml"
try:
    path.write_text(
        "version: 2\nscope_entries: []\nrequired: [feature_path, mode]\n",
        encoding="utf-8",
    )

    real_import = builtins.__import__

    def import_without_yaml(name, *args, **kwargs):
        if name == "yaml":
            raise AssertionError("runtime yaml loader must not import PyYAML")
        return real_import(name, *args, **kwargs)

    builtins.__import__ = import_without_yaml
    os.environ["ORG_RUNTIME_YAML_FORCE_FALLBACK"] = "1"
    try:
        data = load_yaml(path)
    finally:
        builtins.__import__ = real_import
        os.environ.pop("ORG_RUNTIME_YAML_FORCE_FALLBACK", None)
finally:
    path.unlink(missing_ok=True)

ensure(data.get("version") == 2, "runtime yaml fallback must parse integer scalars")
ensure(data.get("scope_entries") == [], "runtime yaml fallback must parse empty inline lists")
ensure(
    data.get("required") == ["feature_path", "mode"],
    "runtime yaml fallback must parse string inline lists",
)
print("[PASS] runtime yaml fallback scalar parsing")
PY

python3 - "$ROOT" <<'PY' || exit 1
import builtins
import sys

root = sys.argv[1]
sys.path.insert(0, f"{root}/tools/community")

real_import = builtins.__import__


def ensure(condition, message):
    if not condition:
        raise SystemExit(f"[FAIL] {message}")


def import_without_dataclasses(name, *args, **kwargs):
    if name == "dataclasses":
        raise AssertionError("context contract hook runtime must not import dataclasses")
    return real_import(name, *args, **kwargs)


builtins.__import__ = import_without_dataclasses
try:
    import context_contract_common
finally:
    builtins.__import__ = real_import

error = context_contract_common.ContractFailure("reason", "path", "expected", "actual", "next")
ensure(error.reason == "reason", "ContractFailure keeps reason field")
print("[PASS] context contract hook stdlib dependency boundary")
PY
