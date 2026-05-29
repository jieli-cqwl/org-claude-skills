#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" <<'PY' || fail "QA minimal field contract drift"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
failures: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


schema = json.loads(
    (root / "shared/skills/qa/contracts/qa-result.schema.json").read_text(encoding="utf-8")
)
props = schema["allOf"][1]["properties"]
for field_name in ("stage_results", "obligation_results"):
    item = props[field_name]["items"]
    require(
        "summary" not in item.get("required", []),
        f"qa-result.{field_name} must not require summary prose",
    )
    require(
        "summary" not in item.get("properties", {}),
        f"qa-result.{field_name} must not define summary prose",
    )
    require(
        item.get("additionalProperties") is False,
        f"qa-result.{field_name} must reject undeclared prose fields",
    )

template = json.loads(
    (root / "shared/skills/qa/templates/qa-result.template.json").read_text(encoding="utf-8")
)
for field_name in ("stage_results", "obligation_results"):
    for index, row in enumerate(template.get(field_name, [])):
        require(
            "summary" not in row,
            f"qa-result.template.json {field_name}[{index}] must not include summary",
        )

for source_root in (
    root / "tests/fixtures/standard-chain-foundation",
    root / "tests/fixtures/standard-chain-pilots",
):
    for path in sorted(source_root.rglob("qa-result.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        for field_name in ("stage_results", "obligation_results"):
            for index, row in enumerate(payload.get(field_name, [])):
                require(
                    "summary" not in row,
                    f"{path.relative_to(root)} {field_name}[{index}] must not include summary",
                )

completion_text = (root / "shared/skills/qa/scripts/completion_check.sh").read_text(
    encoding="utf-8"
)
require(
    ".summary" not in completion_text,
    "QA completion_check must not require stage/obligation summary prose",
)

if failures:
    raise SystemExit("\n".join(failures))
PY

echo "[PASS] QA minimal field contract"
