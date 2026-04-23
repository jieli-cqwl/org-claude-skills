#!/usr/bin/env bash
set -euo pipefail

# File responsibility: replay the fresh login-homepage-v2 pilot baseline
# without accepting historical login-homepage-pilot evidence as proof.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHASE_DIR="$ROOT/docs/login-homepage-v2/phase-1"
ROLE_EVIDENCE="$PHASE_DIR/evidence/role-capability-evidence.json"
CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"
PROFILES="$ROOT/shared/runtime/replay-profiles.json"
ORACLE="$PHASE_DIR/replay/phase-operational.replay-oracle.json"

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s "$ROOT/tests" \
  -p "test_login_homepage_v2_app.py"

python3 "$ROOT/tools/community/validate_standard_chain_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG" \
  --enforce-canonical-only

python3 - "$PHASE_DIR" "$ROLE_EVIDENCE" <<'PY'
import json
import sys
from pathlib import Path

phase_dir = Path(sys.argv[1])
path = Path(sys.argv[2])
payload = json.loads(path.read_text(encoding="utf-8"))
roles = payload.get("roles", [])
if len(roles) < 10:
    raise SystemExit("role-capability evidence is missing standard-chain roles")
if any(row.get("noise_result") != "PASS" for row in roles):
    raise SystemExit("role-capability evidence contains non-PASS noise result")
required_outputs = {
    "review": ["code-review-result.json"],
    "verify": [
        "unit-1/tasks/T1/verify-result.json",
        "unit-2/tasks/T2/verify-result.json",
        "unit-3/tasks/T3/verify-result.json",
    ],
    "qa": ["qa-result.json"],
    "consistency-auditor": ["consistency-audit-result.json"],
    "delivery-owner": [
        "artifact-registry.json",
        "delivery-state.json",
        "signoff-package.json",
        "user-decision.json",
    ],
}
for role_name, relative_paths in required_outputs.items():
    if not any(row.get("role") == role_name and row.get("noise_result") == "PASS" for row in roles):
        raise SystemExit(f"missing PASS role row for {role_name}")
    for relative_path in relative_paths:
        if not (phase_dir / relative_path).is_file():
            raise SystemExit(f"{role_name} output is missing: {relative_path}")
if "login-homepage-pilot" in path.read_text(encoding="utf-8"):
    raise SystemExit("old login-homepage-pilot evidence leaked into v2 support evidence")
PY

python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$PHASE_DIR" \
  --catalog "$CATALOG" \
  --profiles "$PROFILES"

python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --profiles "$PROFILES" \
  --oracle "$ORACLE"

printf '[PASS] standard-chain login homepage v2 phase smoke\n'
