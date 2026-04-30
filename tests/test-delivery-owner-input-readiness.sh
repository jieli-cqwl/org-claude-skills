#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Historical test name kept for discoverability. Active delivery-owner intake
# readiness is now covered by the SOP contract and intake_preflight_check.
bash "$ROOT/tests/test-delivery-owner-sop-contract.sh"

printf '[PASS] delivery-owner input readiness compatibility\n'
