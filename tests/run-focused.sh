#!/usr/bin/env bash
set -euo pipefail

# Run a focused validation slice for a changed skill or workflow area.
# Full release confidence still comes from tests/run-all.sh.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE=""
LIST_ONLY=0
FORMAT="text"

usage() {
  cat <<'USAGE'
Usage:
  bash tests/run-focused.sh <profile> [--list] [--format=json]

Profiles:
  design           Design skill, design handoff, and standard-chain pilot checks.
  research         Research skill and related eval contract checks.
  skill-refiner    Skill refiner package and eval contract checks.
  standard-chain   Standard-chain validators, contracts, and readiness checks.
  product-stage2   Product and Stage 2 handoff package checks.
  install-runtime  Install/runtime surface checks.
  docs-context     Active docs and context recovery checks.
  codex-runtime    Codex runtime adapter and runtime surface checks.

Options:
  --list         Print the planned steps without executing them.
  --format=json Print machine-readable JSON with --list.
  -h, --help    Show this help text.
USAGE
}

fail() {
  printf '[run-focused][ERROR] %s\n' "$*" >&2
  exit 1
}

available_profiles() {
  python3 - "$ROOT/tests/gate-plan.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for name in sorted(data.get("profiles", {})):
    print(name)
PY
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --list)
      LIST_ONLY=1
      shift
      ;;
    --format=json)
      FORMAT="json"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      if [ -n "$PROFILE" ]; then
        fail "multiple profiles provided: $PROFILE and $1"
      fi
      PROFILE="$1"
      shift
      ;;
  esac
done

[ -n "$PROFILE" ] || fail "missing profile. Available profiles: $(available_profiles | paste -sd ', ' -)"

if [ "$LIST_ONLY" -eq 1 ]; then
  python3 "$ROOT/tools/community/gate_plan.py" --repo-root "$ROOT" --profile "$PROFILE" --list --format "$FORMAT"
else
  python3 "$ROOT/tools/community/gate_plan.py" --repo-root "$ROOT" --profile "$PROFILE" --run
fi
