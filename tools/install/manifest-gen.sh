#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
find "$ROOT/claude" "$ROOT/codex" -type f | sed "s|$ROOT/||" | sort
