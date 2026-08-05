#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 "$ROOT/tests/test-rule-runtime-eval-contracts.py"
printf '[PASS] rule runtime eval focused contracts\n'
