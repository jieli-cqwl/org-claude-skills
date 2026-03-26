#!/usr/bin/env bash
set -euo pipefail

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
