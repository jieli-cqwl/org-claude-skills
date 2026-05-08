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
