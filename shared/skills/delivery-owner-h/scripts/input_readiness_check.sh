#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: input_readiness_check.sh --phase-dir <docs/{feature}/phase-{N}>

Validates delivery-owner kickoff input readiness before dispatching experts.
EOF
}

PHASE_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase-dir)
      [ "$#" -ge 2 ] || {
        printf '[FAIL] --phase-dir requires a value\n' >&2
        exit 1
      }
      PHASE_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf '[FAIL] unsupported argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$PHASE_DIR" ]; then
  printf '[FAIL] --phase-dir is required\n' >&2
  usage >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR=""

for candidate_root in "$SCRIPT_DIR/../../../.." "$SCRIPT_DIR/../../.."; do
  candidate_root="$(cd "$candidate_root" && pwd)"
  candidate="$candidate_root/tools/community/validate_delivery_owner_input_readiness.py"
  if [ -f "$candidate" ]; then
    VALIDATOR="$candidate"
    break
  fi
done

if [ -z "$VALIDATOR" ]; then
  printf '[FAIL] validate_delivery_owner_input_readiness.py not found from %s\n' "$SCRIPT_DIR" >&2
  exit 1
fi

exec python3 "$VALIDATOR" \
  --phase-dir "$PHASE_DIR"
