#!/usr/bin/env bash
set -euo pipefail

: "${FAKE_INSTALL_LOG:?FAKE_INSTALL_LOG is required}"

test "$#" -eq 2
test "$1" = "--target"
test "$2" = "codex"

printf 'HOME=%s\tCODEX_HOME=%s\tCWD=%s\tCOMMIT=%s\tARGS=%s\tAUTH=%s\tCONFIG=%s\tAGENTS=%s\tPOISON=%s\n' \
  "$HOME" \
  "$CODEX_HOME" \
  "$PWD" \
  "$(git rev-parse HEAD)" \
  "$*" \
  "$(test -f "$CODEX_HOME/auth.json" && printf present || printf absent)" \
  "$(test -f "$CODEX_HOME/config.toml" && printf present || printf absent)" \
  "$(test -e "$CODEX_HOME/AGENTS.md" && printf present || printf absent)" \
  "$(test -e "$CODEX_HOME/rules/poison.md" && printf present || printf absent)" \
  >> "$FAKE_INSTALL_LOG"

printf 'installed\n' > "$CODEX_HOME/installed-marker"

if [[ -n "${FAKE_INSTALL_STDERR:-}" ]]; then
  printf '%s\n' "$FAKE_INSTALL_STDERR" >&2
fi
