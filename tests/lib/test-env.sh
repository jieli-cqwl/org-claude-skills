#!/usr/bin/env bash
set -euo pipefail

ensure_test_rg() {
  if command -v rg >/dev/null 2>&1; then
    return 0
  fi

  local candidate shim_dir
  for candidate in \
    "$HOME"/.npm-global/lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/*/rg \
    /opt/homebrew/bin/rg \
    /usr/local/bin/rg; do
    [ -e "$candidate" ] || continue

    if [ -x "$candidate" ]; then
      PATH="$(dirname "$candidate"):$PATH"
      export PATH
      command -v rg >/dev/null 2>&1 && return 0
    fi

    [ -r "$candidate" ] || continue
    shim_dir="${TMPDIR:-/tmp}/org-test-rg-${UID:-$(id -u)}"
    mkdir -p "$shim_dir"
    cp "$candidate" "$shim_dir/rg"
    chmod +x "$shim_dir/rg"
    PATH="$shim_dir:$PATH"
    export PATH
    command -v rg >/dev/null 2>&1 && return 0
  done

  printf 'missing rg in test environment\n' >&2
  return 1
}

prepare_fake_openspec() {
  local home_dir="$1"
  local bin_dir="$home_dir/.org-test-bin"

  mkdir -p "$bin_dir"
  cat > "$bin_dir/openspec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  --version|version)
    printf 'openspec test stub\n'
    ;;
  *)
    printf 'openspec test stub: %s\n' "$*" >&2
    ;;
esac
EOF
  chmod +x "$bin_dir/openspec"
  printf '%s\n' "$bin_dir"
}

run_with_fake_openspec() {
  local home_dir="$1"
  shift
  local bin_dir
  bin_dir="$(prepare_fake_openspec "$home_dir")"
  PATH="$bin_dir:$PATH" "$@"
}

run_without_openspec() {
  local filtered_path=""
  local dir

  IFS=':' read -r -a _org_test_path_parts <<< "${PATH:-}"
  for dir in "${_org_test_path_parts[@]}"; do
    [ -n "$dir" ] || continue
    if [ -x "$dir/openspec" ]; then
      continue
    fi
    if [ -z "$filtered_path" ]; then
      filtered_path="$dir"
    else
      filtered_path="$filtered_path:$dir"
    fi
  done

  PATH="$filtered_path" "$@"
}
