#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: commit_preflight_check.sh --phase-dir <docs/{feature}/phase-{N}> --repo-root <repo> --allowed-path <path> [--allowed-path <path> ...] --message <commit message> [--expected-head <sha>] [--allow-main] [--output <file>]

Validates delivery-owner commit handoff before routing to /commit.
EOF
}

ARGS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase-dir|--repo-root|--allowed-path|--expected-head|--message|--output)
      [ "$#" -ge 2 ] || {
        printf '[FAIL] %s requires a value\n' "$1" >&2
        exit 1
      }
      ARGS+=("$1" "$2")
      shift 2
      ;;
    --allow-main)
      ARGS+=("$1")
      shift
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR=""

for candidate_root in "$SCRIPT_DIR/../../../.." "$SCRIPT_DIR/../../.."; do
  candidate_root="$(cd "$candidate_root" && pwd)"
  candidate="$candidate_root/tools/community/validate_delivery_owner_commit_preflight.py"
  if [ -f "$candidate" ]; then
    VALIDATOR="$candidate"
    break
  fi
done

if [ -z "$VALIDATOR" ]; then
  printf '[FAIL] validate_delivery_owner_commit_preflight.py not found from %s\n' "$SCRIPT_DIR" >&2
  exit 1
fi

exec python3 "$VALIDATOR" "${ARGS[@]}"
