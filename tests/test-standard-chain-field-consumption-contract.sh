#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$ROOT/contracts/standard-chain-field-consumption.yaml"
VALIDATOR="$ROOT/tools/community/validate_standard_chain_field_consumption.py"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contracts/standard-chain-field-consumption.yaml"
[[ -f "$VALIDATOR" ]] || fail "missing validate_standard_chain_field_consumption.py"

python3 "$VALIDATOR" \
  --standard-chain "$ROOT/contracts/standard-chain.yaml" \
  --field-consumption "$CONTRACT"

python3 - "$ROOT/contracts/standard-chain.yaml" "$CONTRACT" <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[1]).parents[1] / "tools" / "community"))
from runtime_yaml import load_yaml

standard_chain = load_yaml(Path(sys.argv[1]))
field_consumption = load_yaml(Path(sys.argv[2]))

duplicates = []
for stage in standard_chain.get("chain", []):
    for output in stage.get("outputs", []) or []:
        key_fields = output.get("key_fields")
        if not isinstance(key_fields, list):
            continue
        seen = set()
        for field in key_fields:
            if field in seen:
                duplicates.append(f"{stage.get('name')}:{output.get('artifact')}:{field}")
            seen.add(field)
if duplicates:
    raise SystemExit("standard-chain key_fields must not contain duplicates: " + ", ".join(duplicates))

director_lock_artifacts = {
    "brief.json": "docs/{feature}/brief.json",
    "phase-{N}/phase-prd.json": "docs/{feature}/phase-{N}/phase-prd.json",
}
for stage in standard_chain.get("chain", []):
    if stage.get("name") not in {"product-director", "product-manager"}:
        continue
    for output in stage.get("outputs", []) or []:
        artifact = output.get("artifact")
        if artifact not in director_lock_artifacts:
            continue
        key_fields = output.get("key_fields") or []
        if "locked_field_digest" in key_fields:
            raise SystemExit(f"{stage.get('name')}:{artifact} must not expose flat locked_field_digest")
        if "director_confirmation.locked_field_digest" not in key_fields:
            raise SystemExit(f"{stage.get('name')}:{artifact} must expose director_confirmation.locked_field_digest")

fields_by_path = {
    artifact.get("path"): artifact.get("fields", {})
    for artifact in field_consumption.get("artifacts", [])
}
for artifact_path in director_lock_artifacts.values():
    fields = fields_by_path.get(artifact_path)
    if not isinstance(fields, dict):
        raise SystemExit(f"field consumption missing artifact: {artifact_path}")
    if "locked_field_digest" in fields:
        raise SystemExit(f"{artifact_path} must not declare flat locked_field_digest")
    if "director_confirmation.locked_field_digest" not in fields:
        raise SystemExit(f"{artifact_path} must declare director_confirmation.locked_field_digest")

artifact_registry_fields = fields_by_path.get("docs/{feature}/phase-{N}/artifact-registry.json", {})
if "runtime_artifact_policy.required_runtime_artifacts" not in artifact_registry_fields:
    raise SystemExit("artifact-registry field consumption must declare runtime_artifact_policy.required_runtime_artifacts")

fix_result_fields = fields_by_path.get("docs/{feature}/phase-{N}/fix-result.json")
if not isinstance(fix_result_fields, dict):
    raise SystemExit("field consumption must declare fix-result artifact")
required_fix_fields = {
    "active_tasks_version_ref",
    "trigger_refs",
    "attempt",
    "completion_status",
    "issues",
    "red_green_evidence",
    "regression_evidence",
}
missing_fix_fields = sorted(required_fix_fields - set(fix_result_fields))
if missing_fix_fields:
    raise SystemExit("fix-result field consumption missing fields: " + ", ".join(missing_fix_fields))
PY

python3 - "$ROOT/shared/skills/delivery-owner/contracts/artifact-registry.schema.json" <<'PY'
import json
import sys
from pathlib import Path

schema = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
schema_object = next(item for item in reversed(schema["allOf"]) if "properties" in item)
required = set(schema_object.get("required", []))
if "runtime_artifact_policy" not in required:
    raise SystemExit("artifact-registry schema must require runtime_artifact_policy")
policy = schema_object["properties"]["runtime_artifact_policy"]
if "owner_responsibility" in policy.get("required", []):
    raise SystemExit("artifact-registry runtime_artifact_policy must not require owner_responsibility prose")
if "owner_responsibility" in policy.get("properties", {}):
    raise SystemExit("artifact-registry runtime_artifact_policy must not define owner_responsibility prose")
PY

python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = [
    root / "shared/skills/delivery-owner/templates/artifact-registry.template.json",
    *sorted((root / "tests/fixtures").rglob("*.json")),
]
violations = []


def visit(node, path):
    if isinstance(node, dict):
        if node.get("artifact_type") == "artifact-registry":
            policy = node.get("runtime_artifact_policy", {})
            if isinstance(policy, dict) and "owner_responsibility" in policy:
                violations.append(str(path))
        for value in node.values():
            visit(value, path)
    elif isinstance(node, list):
        for item in node:
            visit(item, path)


for path in paths:
    text = path.read_text(encoding="utf-8")
    if "artifact-registry" not in text:
        continue
    visit(json.loads(text), path)

if violations:
    raise SystemExit(
        "artifact-registry runtime_artifact_policy owner_responsibility prose remains in: "
        + ", ".join(violations)
    )
PY

python3 - "$ROOT/contracts/standard-chain.yaml" <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[1]).parents[1] / "tools" / "community"))
from runtime_yaml import load_yaml

consumed_runtime_artifacts = {
    "phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
    "phase-{N}/code-review-result.json",
    "phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
}
data = load_yaml(Path(sys.argv[1]))
violations = []
for stage in data.get("chain", []):
    for output in stage.get("outputs", []) or []:
        artifact = output.get("artifact")
        if artifact in consumed_runtime_artifacts and output.get("terminal") is True:
            violations.append(f"{stage.get('name')}:{artifact}")
if violations:
    raise SystemExit(
        "downstream-consumed runtime artifacts must not be terminal: "
        + ", ".join(violations)
    )
PY

# negative assertion only
python3 - "$ROOT" "$CONTRACT" "$ROOT/contracts/co-creation-ledgers.yaml" "$ROOT/contracts/standard-chain.yaml" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
contract_paths = [Path(path) for path in sys.argv[2:]]
scan_roots = [
    root / "shared" / "skills" / "product-manager",
    root / "tools" / "eval" / "scripts",
    root / "contracts",
    root / "tests",
]
excluded_parts = {
    ("tools", "eval", "results"),
    ("docs", "superpowers", "plans"),
}
text_suffixes = {".json", ".md", ".py", ".sh", ".yaml", ".yml"}
negative_assertion_files = {
    root / "tests" / "test-standard-chain-field-consumption-contract.sh",
    root / "tests" / "test-standard-chain-co-creation-ledger-contract.sh",
}
# negative assertion only: forbidden active PM ledger dependency tokens.
pattern = re.compile(
    r"product-manager-ledger\.json|product_manager_ledger|--producer product-manager"
)


def is_excluded(path):
    try:
        relative_parts = path.relative_to(root).parts
    except ValueError:
        return False
    return any(
        relative_parts[: len(excluded)] == excluded for excluded in excluded_parts
    )


def iter_files():
    seen = set()
    for path in contract_paths:
        if path.is_file() and path not in seen:
            seen.add(path)
            yield path
    for scan_root in scan_roots:
        if scan_root.is_file():
            candidates = [scan_root]
        else:
            candidates = scan_root.rglob("*")
        for path in candidates:
            if (
                path in seen
                or not path.is_file()
                or is_excluded(path)
                or path.suffix not in text_suffixes
            ):
                continue
            seen.add(path)
            yield path


violations = []
for path in iter_files():
    if path in negative_assertion_files:
        continue
    lines = path.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        if pattern.search(line):
            violations.append(f"{path}:{index + 1}:{line}")

if violations:
    print("\n".join(violations))
    raise SystemExit("active runtime must not depend on product-manager-ledger")
PY

# negative assertion only: active ledger contracts must not mention Product Manager ledger producers.
python3 - "$ROOT" "$ROOT/contracts/co-creation-ledgers.yaml" "$ROOT/contracts/standard-chain.yaml" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "community"))
from runtime_yaml import load_yaml

for path in map(Path, sys.argv[2:]):
    data = load_yaml(path)
    ledgers = data.get("co_creation_ledgers", {})
    text = str(ledgers)
    if "product-manager" in text or "product-manager-ledger.json" in text:
        raise SystemExit(f"active co-creation ledger contract still mentions product-manager: {path}")
PY

python3 - "$CONTRACT" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
expected_field = "co_creation_summary"
legacy_field = "design_stage" + "_confirmations"
if expected_field not in text:
    raise SystemExit("field contract must include co_creation_summary")
if legacy_field in text:
    raise SystemExit("field contract must not include legacy design_stage_confirmations field")
PY

python3 - "$ROOT" "$VALIDATOR" "$CONTRACT" <<'PY'
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

root = Path(sys.argv[1])
validator = Path(sys.argv[2])
contract = Path(sys.argv[3])
standard_chain = root / "contracts" / "standard-chain.yaml"


def write_yaml(path, data):
    path.write_text(yaml.safe_dump(data, allow_unicode=True, sort_keys=False), encoding="utf-8")


def remove_contract_field(contract_path, target_path, field_name, output_path):
    data = yaml.safe_load(contract_path.read_text(encoding="utf-8"))
    for artifact in data["artifacts"]:
        if artifact.get("path") == target_path:
            artifact["fields"].pop(field_name, None)
            write_yaml(output_path, data)
            return
    raise SystemExit(f"missing artifact in field consumption contract: {target_path}")


def expect_validator_failure(standard_chain_path, field_consumption_path, expected):
    result = subprocess.run(
        [
            "python3",
            str(validator),
            "--standard-chain",
            str(standard_chain_path),
            "--field-consumption",
            str(field_consumption_path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr
    if result.returncode == 0:
        raise SystemExit(f"validator unexpectedly accepted {expected}")
    if expected not in output:
        raise SystemExit(f"validator failure for {expected} did not mention the rejected contract")


def duplicate_standard_chain_key_field(standard_chain_path, output_path):
    data = yaml.safe_load(standard_chain_path.read_text(encoding="utf-8"))
    for stage in data["chain"]:
        if stage.get("name") != "product-director":
            continue
        for output in stage.get("outputs", []):
            if output.get("artifact") == "brief.json":
                output["key_fields"].append(output["key_fields"][0])
                write_yaml(output_path, data)
                return
    raise SystemExit("missing product-director brief output")


with tempfile.TemporaryDirectory() as tmp:
    tmp_dir = Path(tmp)

    duplicate_key_fields = tmp_dir / "duplicate-key-fields.standard-chain.yaml"
    duplicate_standard_chain_key_field(standard_chain, duplicate_key_fields)
    expect_validator_failure(
        duplicate_key_fields,
        contract,
        "duplicate key_fields",
    )

    missing_runtime_contract = tmp_dir / "missing-runtime-field-consumption.yaml"
    remove_contract_field(
        contract,
        "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
        "runtime_status",
        missing_runtime_contract,
    )
    expect_validator_failure(
        standard_chain,
        missing_runtime_contract,
        "developer-report",
    )

    missing_qa_contract = tmp_dir / "missing-qa-field-consumption.yaml"
    remove_contract_field(
        contract,
        "docs/{feature}/phase-{N}/qa-result.json",
        "release_recommendation",
        missing_qa_contract,
    )
    expect_validator_failure(
        standard_chain,
        missing_qa_contract,
        "qa-result",
    )

    missing_qa_obligation_contract = tmp_dir / "missing-qa-obligation-field-consumption.yaml"
    remove_contract_field(
        contract,
        "docs/{feature}/phase-{N}/qa-result.json",
        "obligation_results",
        missing_qa_obligation_contract,
    )
    expect_validator_failure(
        standard_chain,
        missing_qa_obligation_contract,
        "qa-result",
    )

    missing_signoff_contract = tmp_dir / "missing-signoff-field-consumption.yaml"
    remove_contract_field(
        contract,
        "docs/{feature}/phase-{N}/signoff-package.json",
        "active_tasks_version_ref",
        missing_signoff_contract,
    )
    expect_validator_failure(
        standard_chain,
        missing_signoff_contract,
        "signoff-package",
    )

    mutated_contract = tmp_dir / "field-consumption.yaml"
    contract_text = contract.read_text(encoding="utf-8")
    field_probe = """  - path: docs/{feature}/phase-{N}/pm-ledger.json\n    producer: product-manager\n    fields:\n      root_problem:\n        producer: product-manager\n        authority: product-manager\n        consumers:\n          - consumer: design\n            consumed_for: forbidden product-manager ledger probe\n            consume_mode: reference\n        required_when: negative probe runs\n        failure_effect: validator must reject product-manager ledgers\n"""
    mutated_contract.write_text(
        contract_text.replace("artifacts:\n", f"artifacts:\n{field_probe}", 1),
        encoding="utf-8",
    )
    expect_validator_failure(standard_chain, mutated_contract, "product-manager ledger")

    mutated_standard_chain = tmp_dir / "standard-chain.yaml"
    standard_chain_text = standard_chain.read_text(encoding="utf-8")
    director_block = """    product-director:\n      path: docs/{feature}/product-director-ledger.json\n      scope: feature\n      producer: product-director\n"""
    pm_block = """    product-manager:\n      path: docs/{feature}/phase-{N}/pm-ledger.json\n      scope: phase\n      producer: product-manager\n"""
    design_block = """    design:\n      path: docs/{feature}/phase-{N}/design-checkpoints.json\n      scope: phase\n      producer: design\n"""
    mutated_standard_chain.write_text(
        standard_chain_text.replace(director_block, director_block + pm_block, 1),
        encoding="utf-8",
    )
    expect_validator_failure(
        mutated_standard_chain,
        contract,
        "unsupported active co-creation ledger producer: product-manager",
    )

    mutated_standard_chain.write_text(
        standard_chain_text.replace(director_block, director_block + design_block, 1),
        encoding="utf-8",
    )
    expect_validator_failure(
        mutated_standard_chain,
        contract,
        "unsupported active co-creation ledger producer: design",
    )
PY
