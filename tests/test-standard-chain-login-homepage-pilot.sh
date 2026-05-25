#!/usr/bin/env bash
set -euo pipefail

# File responsibility: replay the login/homepage pilot as a standard-chain
# smoke baseline without depending on human-readable projection files.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHASE_DIR="$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot/phase-1"
CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"
PROFILES="$ROOT/shared/runtime/replay-profiles.json"
ORACLE="$PHASE_DIR/replay/phase-operational.replay-oracle.json"

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s "$ROOT/tests" \
  -p "test_login_homepage_app.py"

python3 - "$ROOT/tests/test_login_homepage_app.py" "$PHASE_DIR/unit-1/test-cases.json" <<'PY'
import ast
import json
import sys
from pathlib import Path

test_source = ast.parse(Path(sys.argv[1]).read_text(encoding="utf-8"))
test_cases = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))["test_cases"]
methods = [
    item.name
    for node in test_source.body
    if isinstance(node, ast.ClassDef) and node.name == "LoginHomepageAcceptanceTests"
    for item in node.body
    if isinstance(item, ast.FunctionDef) and item.name.startswith("test_")
]
if len(methods) != len(test_cases):
    raise SystemExit(
        f"login homepage pilot declared {len(test_cases)} canonical test cases but has {len(methods)} real unittest methods"
    )
PY

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

printf '[PASS] standard-chain login homepage pilot\n'
