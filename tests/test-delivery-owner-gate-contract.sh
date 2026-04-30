#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Historical test name kept for callers. Active gate behavior is split into:
# - SOP contract: role/SOP, intake preflight, task packet preflight
# - contract closure: closeout readiness hook
bash "$ROOT/tests/test-delivery-owner-sop-contract.sh"
bash "$ROOT/tests/test-delivery-owner-contract-closure.sh"

printf '[PASS] delivery-owner gate contract compatibility\n'
