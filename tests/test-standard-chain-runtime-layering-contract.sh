#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/reference/StandardChain运行面分层标准.md"
QUALITY="$ROOT/shared/reference/Skill质量标准.md"
AUDIT="$ROOT/docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/developer-migration-audit.json"

require_pattern() {
  local pattern="$1" file="$2" label="$3"
  if ! rg -n "$pattern" "$file" >/dev/null 2>&1; then
    printf '[FAIL] %s\n' "$label" >&2
    exit 1
  fi
}

test -f "$STANDARD"
test -f "$AUDIT"

require_pattern '^## Main Runtime Layer$' "$STANDARD" "missing main runtime layer"
require_pattern '^## Runtime Integration Layer$' "$STANDARD" "missing runtime integration layer"
require_pattern '^## Governance And Evidence Layer$' "$STANDARD" "missing governance evidence layer"
require_pattern '唯一权威裁决源' "$STANDARD" "missing source-of-truth rule"
require_pattern '按需加载' "$STANDARD" "missing progressive disclosure rule"
require_pattern 'status.*failure_code.*safe_to_continue' "$STANDARD" "missing fixed failure shape"
require_pattern '命令字符串.*replay instruction' "$STANDARD" "missing fresh proof boundary"
require_pattern 'projection.*display' "$STANDARD" "missing projection display-only rule"
require_pattern 'StandardChain运行面分层标准\.md' "$QUALITY" "quality standard does not link runtime layering standard"

jq -e '
  type == "array"
  and length >= 8
  and all(.[]; has("source_ref") and has("content_type") and has("action") and has("destination_ref") and has("consumer") and has("verification_ref") and has("reason") and has("owner"))
  and all(.[]; .action as $action | ["keep","move","rewrite","archive","delete"] | index($action))
  and all(.[]; .content_type as $type | ["hard_gate","protocol","reference_methodology","schema_shape","template_skeleton","script_check","projection_display","history","obsolete"] | index($type))
  and all(.[]; if .action == "delete" then .consumer == "none" else true end)
  and all(.[]; if (.destination_ref | test("shared/skills/developer/references/")) then (.content_type != "hard_gate" and .content_type != "protocol") else true end)
  and all(.[]; if (.content_type == "projection_display" or .content_type == "history") then (.consumer != "runtime") else true end)
' "$AUDIT" >/dev/null

printf '[PASS] standard-chain runtime layering contract\n'
