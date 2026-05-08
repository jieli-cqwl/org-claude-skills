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
ensure(
    registry.get("context_contract_phase") == "bootstrap",
    "context_contract_phase must start at bootstrap",
)

record_contract = registry.get("record_contract")
ensure(isinstance(record_contract, dict), "record_contract must be present")
required = set(record_contract.get("required", []))
for field in ["feature_path", "mode", "management_status", "layout", "entry_ref", "context_owner"]:
    ensure(field in required, f"record_contract.required missing {field}")

enums = record_contract.get("enums", {})
ensure(enums.get("management_status") == ["legacy", "managed", "migrated"], "management_status enum mismatch")
ensure(enums.get("mode") == ["small-chain", "standard-chain"], "mode enum mismatch")
ensure(enums.get("layout") == ["dated-workset", "phase-tree"], "layout enum mismatch")

entries = registry.get("scope_entries")
ensure(isinstance(entries, list), "scope_entries must be a list")
ensure(entries, "scope_entries must contain current managed features")
for entry in entries:
    feature_path = entry.get("feature_path")
    entry_ref = entry.get("entry_ref")
    layout = entry.get("layout")
    status = entry.get("management_status")
    ensure(status in {"managed", "migrated", "legacy"}, f"{feature_path} management_status mismatch: {status!r}")
    ensure(entry.get("status") == status, f"{feature_path} status mismatch: {entry.get('status')!r}")
    ensure(entry.get("owner") == entry.get("context_owner"), f"{feature_path} owner/context_owner mismatch")

    if status in {"managed", "migrated"}:
        current_entry = root / feature_path / entry_ref
        ensure(current_entry.is_file(), f"entry_ref is unreachable: {current_entry}")
        if layout == "dated-workset":
            workset = root / feature_path / entry["primary_workset_relpath"]
            ensure(workset.is_dir(), f"primary workset is unreachable: {workset}")
    else:
        archive_ref = entry.get("archive_ref")
        archived_at = entry.get("archived_at")
        ensure(archive_ref, f"{feature_path} legacy entry missing archive_ref")
        ensure(archived_at, f"{feature_path} legacy entry missing archived_at")
        archive_path = root / archive_ref
        ensure(archive_path.is_dir(), f"legacy archive_ref is unreachable: {archive_path}")
        archived_entry = archive_path / entry_ref
        ensure(archived_entry.is_file(), f"legacy archived entry_ref is unreachable: {archived_entry}")

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
    triggers = artifact.get("update_triggers")
    checks = artifact.get("mechanical_checks")
    ensure(owner in repo_owners, f"{artifact_id} artifact_owner does not resolve: {owner}")
    ensure(isinstance(path, str) and (root / path).exists(), f"{artifact_id} path is unreachable: {path}")
    ensure(isinstance(triggers, list) and triggers, f"{artifact_id} update_triggers must be non-empty")
    ensure(isinstance(checks, list) and checks, f"{artifact_id} mechanical_checks must be non-empty")

waiver_approvers = ownership.get("waiver_approvers")
ensure(isinstance(waiver_approvers, dict) and waiver_approvers, "waiver_approvers must be present")

print("[PASS] active doc scope lifecycle bootstrap/archive")
PY
