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

install_runtime_file() {
  local source="$1"
  local target="$2"

  if [[ "${FAKE_INSTALL_SKIP_TARGET:-}" == "$target" ]]; then
    return
  fi
  mkdir -p "$CODEX_HOME/$(dirname "$target")"
  {
    printf 'fake-installed\n'
    cat "$source"
  } > "$CODEX_HOME/$target"
}

if [[ -z "${FAKE_INSTALL_SKIP_RUNTIME_TARGETS:-}" ]]; then
  install_runtime_file shared/assistant.md AGENTS.md
  install_runtime_file shared/rules/code-changes.md rules/code-changes.md
  install_runtime_file shared/rules/completion-claims.md rules/completion-claims.md
  install_runtime_file shared/reference/协作判断.md reference/协作判断.md
  install_runtime_file shared/reference/测试规范.md reference/测试规范.md
  install_runtime_file shared/reference/code-structure-reuse.md reference/code-structure-reuse.md
  install_runtime_file shared/reference/code-comments.md reference/code-comments.md
  install_runtime_file shared/reference/error-handling.md reference/error-handling.md
  install_runtime_file shared/reference/constants-and-configuration.md reference/constants-and-configuration.md
  if [[ -f shared/reference/authentication-and-authorization.md ]]; then
    install_runtime_file shared/reference/authentication-and-authorization.md reference/authentication-and-authorization.md
  fi
  install_runtime_file shared/reference/performance-and-efficiency.md reference/performance-and-efficiency.md
  install_runtime_file shared/reference/技术方案设计.md reference/技术方案设计.md
  install_runtime_file shared/reference/impact-analysis.md reference/impact-analysis.md
  install_runtime_file shared/reference/系统调试.md reference/系统调试.md
  install_runtime_file shared/reference/全栈开发.md reference/全栈开发.md
fi

if [[ -n "${FAKE_INSTALL_REQUIRED_PYTHON_USER_SITE:-}" ]]; then
  case ":${PYTHONPATH:-}:" in
    *":${FAKE_INSTALL_REQUIRED_PYTHON_USER_SITE}:"*) ;;
    *)
      printf 'FATAL: PyYAML not installed\n'
      exit 1
      ;;
  esac
fi

if [[ -n "${FAKE_INSTALL_STDOUT:-}" ]]; then
  printf '%s\n' "$FAKE_INSTALL_STDOUT"
fi

if [[ -n "${FAKE_INSTALL_STDERR:-}" ]]; then
  printf '%s\n' "$FAKE_INSTALL_STDERR" >&2
fi
