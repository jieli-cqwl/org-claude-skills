#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ROLE="${SC_PREFLIGHT_ROLE:-$(basename "$(cd "$SCRIPT_DIR/.." && pwd)")}"
CORE="$SCRIPT_DIR/check_preflight.sh"

# shellcheck source=/dev/null
source "$ROOT/shared/skills/lib/standard-chain-routing.sh"

payload="$(cat)"

extract_status=0
extract_output="$(
  python3 - "$ROOT/shared/runtime/standard-chain-preflight-profiles.json" "$ROLE" "$payload" <<'PY'
import json
import sys

profile_path, role, raw = sys.argv[1:]
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    raise SystemExit(1)

active_targets = payload.get("active_targets")
if isinstance(active_targets, list) and len(active_targets) > 1:
    raise SystemExit(1)

target = {}
for key in ("standard_chain", "inputs", "arguments"):
    value = payload.get(key)
    if isinstance(value, dict):
        target.update(value)
for key in ("feature", "phase_dir", "phase-dir", "unit", "task_id", "task-id"):
    if key in payload:
        target[key] = payload[key]

try:
    profile = json.loads(open(profile_path, encoding="utf-8").read())["roles"][role]
except Exception:
    raise SystemExit(2)
args = []
for name in profile["required_arguments"]:
    lookup = name.replace("-", "_")
    value = target.get(name, target.get(lookup))
    if value is not None:
        args.extend([f"--{name}", str(value)])
for name in ("artifact", "scope"):
    value = target.get(name)
    if value is not None:
        args.extend([f"--{name}", str(value)])
print("\n".join(args))
PY
)" || extract_status=$?

if [[ "$extract_status" -ne 0 ]]; then
  if [[ "$extract_status" -eq 2 ]]; then
    sc_emit_routing_json \
      --stage "$ROLE.preflight" \
      --failure-code MALFORMED_ARTIFACT \
      --user-message "Preflight adapter profile bootstrap failed." \
      --evidence-ref "file://$ROOT/shared/runtime/standard-chain-preflight-profiles.json"
    exit 1
  fi
  sc_emit_routing_json \
    --stage "$ROLE.preflight" \
    --failure-code AMBIGUOUS_TARGET \
    --user-message "Hook payload could not resolve one unambiguous preflight target." \
    --evidence-ref "diagnostic://standard-chain/preflight-adapter/payload"
  exit 1
fi

core_args=()
while IFS= read -r arg; do
  [[ -n "$arg" ]] && core_args+=("$arg")
done <<<"$extract_output"
timeout_seconds="${SC_PREFLIGHT_ADAPTER_TIMEOUT_SECONDS:-15}"
output_limit="${SC_PREFLIGHT_ADAPTER_OUTPUT_LIMIT_BYTES:-65536}"

runner_status=0
runner_output="$(
  python3 - "$timeout_seconds" "$output_limit" "$CORE" "${core_args[@]+"${core_args[@]}"}" <<'PY'
import os
import subprocess
import sys

timeout = float(sys.argv[1])
limit = int(sys.argv[2])
command = [sys.argv[3], *sys.argv[4:]]
try:
    completed = subprocess.run(
        command,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )
except subprocess.TimeoutExpired:
    raise SystemExit(124)

output = completed.stdout
if len(output.encode("utf-8")) > limit:
    raise SystemExit(125)
print(output, end="")
raise SystemExit(completed.returncode)
PY
)" || runner_status=$?

case "$runner_status" in
  0)
    printf '%s' "$runner_output"
    ;;
	  1)
	    if [[ -z "$runner_output" ]] || ! sc_validate_routing_json "$runner_output" "$ROOT"; then
	      sc_emit_routing_json \
	        --stage "$ROLE.preflight" \
	        --failure-code MALFORMED_ARTIFACT \
	        --user-message "Preflight adapter received no valid routing JSON from the core checker." \
	        --evidence-ref "diagnostic://standard-chain/preflight-adapter/core-routing-output"
	      exit 1
	    fi
	    printf '%s' "$runner_output"
	    exit 1
	    ;;
  124)
    sc_emit_routing_json \
      --stage "$ROLE.preflight" \
      --failure-code ADAPTER_TIMEOUT \
      --user-message "Preflight adapter timed out while invoking the core checker." \
      --evidence-ref "diagnostic://standard-chain/preflight-adapter/timeout"
    exit 1
    ;;
  125)
    sc_emit_routing_json \
      --stage "$ROLE.preflight" \
      --failure-code ADAPTER_OUTPUT_OVERFLOW \
      --user-message "Preflight adapter output exceeded the configured byte limit." \
      --evidence-ref "diagnostic://standard-chain/preflight-adapter/output-overflow"
    exit 1
    ;;
  *)
    sc_emit_routing_json \
      --stage "$ROLE.preflight" \
      --failure-code MALFORMED_ARTIFACT \
      --user-message "Preflight adapter could not execute the core checker." \
      --evidence-ref "diagnostic://standard-chain/preflight-adapter/core-execution"
    exit 1
    ;;
esac
