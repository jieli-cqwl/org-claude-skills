#!/usr/bin/env bash
# Validate canonical inputs before test-design creates test-cases.json.
set -euo pipefail

usage() {
  cat <<'USAGE'
test-design/preflight_check.sh --phase-dir <docs/{feature}/phase-N> [--unit UNIT-N|unit-N]

Checks only canonical input presence and JSON readability. It does not judge
product or design semantic quality.
USAGE
}

PHASE_DIR=""
UNIT_ID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase-dir)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        printf 'Missing value for --phase-dir\n' >&2
        usage >&2
        exit 1
      fi
      PHASE_DIR="${2:-}"
      shift 2
      ;;
    --unit)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        printf 'Missing value for --unit\n' >&2
        usage >&2
        exit 1
      fi
      UNIT_ID="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$PHASE_DIR" ]; then
  printf 'Missing required --phase-dir\n' >&2
  usage >&2
  exit 1
fi

python3 - "$PHASE_DIR" "$UNIT_ID" <<'PY'
import json
import re
import sys
from pathlib import Path

phase_dir = Path(sys.argv[1]).resolve()
unit_id = sys.argv[2].strip()
failures: list[str] = []


def add(message: str) -> None:
    failures.append(message)


def load_object(path: Path) -> None:
    if not path.is_file():
        add(f"missing canonical input: {path}")
        return
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        add(f"invalid JSON: {path}: {exc}")
        return
    if not isinstance(payload, dict):
        add(f"canonical input must be a JSON object: {path}")


if not phase_dir.is_dir():
    add(f"phase-dir not found: {phase_dir}")
else:
    if not re.fullmatch(r"phase-[0-9]{1,4}", phase_dir.name):
        add(f"invalid --phase-dir: {phase_dir}; expected docs/{{feature}}/phase-N")
    if phase_dir.parent.parent.name != "docs":
        add(f"invalid --phase-dir root: {phase_dir}; expected docs/{{feature}}/phase-N")

    feature_dir = phase_dir.parent
    load_object(feature_dir / "brief.json")
    load_object(phase_dir / "phase-prd.json")
    load_object(phase_dir / "design.json")

    units_dir = phase_dir / "units"
    if not units_dir.is_dir():
        add(f"units directory not found: {units_dir}")
    else:
        if unit_id:
            stem = unit_id[:-5] if unit_id.endswith(".json") else unit_id
            match = re.fullmatch(r"(UNIT|unit)-([0-9]{1,4})", stem)
            if not match:
                add(f"invalid --unit: {unit_id}; expected UNIT-N or unit-N")
                unit_paths = []
            else:
                unit_paths = [units_dir / f"UNIT-{match.group(2)}.json"]
        else:
            unit_paths = sorted(units_dir.glob("UNIT-*.json"))
            if not unit_paths:
                add(f"no UNIT-*.json files found: {units_dir}")
        for path in unit_paths:
            load_object(path)

if failures:
    print('{"status":"FAIL","failures":[' + ",".join(json.dumps(item) for item in failures) + "]}")
    raise SystemExit(1)

print('{"status":"PASS","phase_dir":' + json.dumps(str(phase_dir)) + "}")
PY
