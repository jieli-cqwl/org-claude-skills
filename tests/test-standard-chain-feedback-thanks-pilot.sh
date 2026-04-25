#!/usr/bin/env bash
set -euo pipefail

# File responsibility: replay the feedback/thanks pilot as a standard-chain
# smoke baseline without depending on human-readable projection files.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHASE_DIR="$ROOT/tests/fixtures/standard-chain-pilots/feedback-thanks-pilot/phase-1"
CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"
PROFILES="$ROOT/shared/runtime/replay-profiles.json"
ORACLE="$PHASE_DIR/replay/phase-operational.replay-oracle.json"

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s "$ROOT/tests" \
  -p "test_feedback_thanks_app.py"

python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG" \
  --enforce-canonical-only

python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG"

python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --profiles "$PROFILES" \
  --oracle "$ORACLE"

printf '[PASS] standard-chain feedback thanks pilot\n'
