#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

printf '== Claude ==\n'
bash "$SCRIPT_DIR/probe-claude-capabilities.sh" "$ROOT_DIR"

printf '\n== Codex ==\n'
bash "$SCRIPT_DIR/probe-codex-capabilities.sh" "$ROOT_DIR"
