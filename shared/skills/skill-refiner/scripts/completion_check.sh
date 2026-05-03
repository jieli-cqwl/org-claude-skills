#!/usr/bin/env bash
# skill-refiner completion gate: validates skill-refiner-result.json before Stop can finish.
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
skill-refiner/completion_check.sh — canonical refinement result gate
Execution: skill-local Stop or PostToolUse(Edit|Write)
Input: stdin JSON (cwd, session_id, transcript_path, optional tool_input.file_path)
Output: stdout JSON decision + stderr diagnostics
USAGE
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_LIB="$(cd "$SCRIPT_DIR/../../../hooks/lib" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate_refinement_result.py"

# shellcheck source=shared/hooks/lib/common.sh
source "$HOOKS_LIB/common.sh"
hook_init

is_result_path() {
  case "$1" in
    skill-refiner-result.json|*/skill-refiner-result.json) return 0 ;;
    *) return 1 ;;
  esac
}

select_result_path() {
  local candidates candidate candidate_count tool_path

  HOOK_MATCHED_PATH=""
  if [ -n "${TOOL_FILE_PATH:-}" ]; then
    tool_path=$(hook_repo_relative_path "$TOOL_FILE_PATH")
    if is_result_path "$tool_path"; then
      HOOK_MATCHED_PATH="$tool_path"
    fi
    return 0
  fi

  if [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    candidates=$(python3 - "$TRANSCRIPT_PATH" "$REPO_ROOT" <<'PY'
import re
import sys

transcript_path, repo_root = sys.argv[1], sys.argv[2].rstrip("/")
text = open(transcript_path, encoding="utf-8", errors="replace").read()
pattern = re.compile(
    r'(?<![\w./-])((?:[^\s"{}<>]+/)?skill-refiner-result\.json)(?![\w/-]|\.[A-Za-z0-9_])'
)
seen = set()
for match in pattern.finditer(text):
    candidate = match.group(1)
    if repo_root and candidate.startswith(repo_root + "/"):
        candidate = candidate[len(repo_root) + 1:]
    if candidate.startswith("./"):
        candidate = candidate[2:]
    if candidate not in seen:
        seen.add(candidate)
        print(candidate)
PY
    )
  else
    candidates=""
  fi

  candidate_count=0
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate_count=$((candidate_count + 1))
    [ "$candidate_count" = "1" ] && HOOK_MATCHED_PATH="$candidate"
  done <<< "$candidates"

  if [ "$candidate_count" = "1" ]; then
    return 0
  fi
  if [ "$candidate_count" -gt 1 ]; then
    HOOK_MATCHED_PATH=""
    add_failure "skill-refiner-result.json matched multiple candidates in hook context; use tool_input.file_path to select one"
    while IFS= read -r candidate; do
      [ -n "$candidate" ] && add_failure "candidate: $candidate"
    done <<< "$candidates"
  fi
}

validate_result() {
  local target="$1"
  local output_file

  if [ ! -f "$target" ]; then
    add_failure "skill-refiner-result.json not found: $target"
    return 0
  fi

  output_file="$(mktemp)"
  if ! python3 "$VALIDATOR" "$target" >"$output_file" 2>&1; then
    add_failure "skill-refiner-result.json validation failed: $target"
    while IFS= read -r line; do
      [ -n "$line" ] && add_failure "$line"
    done < "$output_file"
  fi
  rm -f "$output_file"
}

run_gate() {
  local target

  select_result_path
  target="$HOOK_MATCHED_PATH"
  if [ -z "$target" ]; then
    if [ -n "$FAILURES" ]; then
      output_failures "skill-refiner completion gate failed" ""
    fi
    if is_stop_dispatch_context; then
      add_failure "skill-refiner-result.json path not found in hook context"
      output_failures "skill-refiner completion gate failed" ""
    fi
    emit_decision_json "allow" "skill-refiner completion gate not targeted"
    return 0
  fi

  validate_result "$target"
  output_failures "skill-refiner completion gate failed" "$target"
  emit_decision_json "allow" "skill-refiner result validated"
}

run_gate
