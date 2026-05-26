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
if "design_stage_confirmations" not in text:
    raise SystemExit("field contract must include design_stage_confirmations")
if "co_creation_summary" in text:
    raise SystemExit("field contract must not include co_creation_summary")
PY

python3 - "$ROOT" "$VALIDATOR" "$CONTRACT" <<'PY'
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
validator = Path(sys.argv[2])
contract = Path(sys.argv[3])
standard_chain = root / "contracts" / "standard-chain.yaml"


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


with tempfile.TemporaryDirectory() as tmp:
    tmp_dir = Path(tmp)

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
