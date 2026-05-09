#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
find "$ROOT/shared" "$ROOT/claude" "$ROOT/codex" -type d -name '__pycache__' -prune -o \
  -type f ! -name '*.pyc' ! -name '.DS_Store' -print \
  | sed "s|$ROOT/||" | sort
