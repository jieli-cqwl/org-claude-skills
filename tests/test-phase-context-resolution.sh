#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMON_SH="$ROOT/shared/hooks/lib/common.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FEATURE_DIR="$TMP_DIR/feature"
mkdir -p \
  "$FEATURE_DIR/phase-1/unit-1" \
  "$FEATURE_DIR/phase-2/unit-1"

cat > "$FEATURE_DIR/prd.md" <<'EOF'
## 交付计划

### Phase 1
- 状态: DONE
- 工作区: phase-1/

### Phase 2
- 状态: IN_PROGRESS
- 工作区: phase-2/
EOF

# shellcheck source=/dev/null
source "$COMMON_SH"

# shellcheck disable=SC2034 # used by sourced common.sh helpers
REPO_ROOT="$ROOT"
# shellcheck disable=SC2034 # used by sourced common.sh helpers
CWD="$ROOT"

resolve_current_phase_context_from_prd "$FEATURE_DIR"
[ "$CURRENT_PHASE_WORK_DIR" = "$FEATURE_DIR/phase-2" ] || fail "expected current phase to resolve to phase-2, got: ${CURRENT_PHASE_WORK_DIR:-<empty>}"

resolve_all_unit_work_dirs "$FEATURE_DIR"
[ "$ALL_UNIT_WORK_DIRS" = "$FEATURE_DIR/phase-2/unit-1" ] || fail "resolve_all_unit_work_dirs should stay inside current phase, got: ${ALL_UNIT_WORK_DIRS:-<empty>}"

resolve_work_dir_from_prd "$FEATURE_DIR" "dev-report.md"
[ "$UNIT_WORK_DIR" = "$FEATURE_DIR/phase-2/unit-1" ] || fail "resolve_work_dir_from_prd should stay inside current phase, got: ${UNIT_WORK_DIR:-<empty>}"

echo "[PASS] phase context resolution"
