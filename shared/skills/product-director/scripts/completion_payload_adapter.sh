#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ROLE="${SC_COMPLETION_ROLE:-product-director}"
CORE="$ROOT/shared/skills/$ROLE/scripts/check_completion.sh"

# shellcheck source=/dev/null
source "$ROOT/shared/skills/lib/standard-chain-routing.sh"

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

emit_decision() {
  printf '{"decision":"%s","reason":"%s"}\n' "$1" "$(json_escape "$2")"
}

payload="$(cat)"
extract_status=0
extract_output="$(
  python3 - "$ROOT/shared/runtime/standard-chain-completion-profiles.json" "$ROLE" "$payload" <<'PY'
import json, sys
profile_path, role, raw = sys.argv[1:]
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    raise SystemExit(1)
targets = payload.get("active_targets")
if isinstance(targets, list) and len(targets) > 1:
    raise SystemExit(1)
target = {}
if isinstance(targets, list) and len(targets) == 1 and isinstance(targets[0], dict):
    target.update(targets[0])
else:
    for key in ("standard_chain", "inputs", "arguments"):
        value = payload.get(key)
        if isinstance(value, dict):
            target.update(value)
    for key in ("feature", "phase_dir", "phase-dir", "unit", "task_id", "task-id"):
        if key in payload:
            target[key] = payload[key]
profile = json.loads(open(profile_path, encoding="utf-8").read())["roles"][role]
args = []
for name in profile["required_arguments"]:
    lookup = name.replace("-", "_")
    value = target.get(name, target.get(lookup))
    if value is not None:
        args.extend([f"--{name}", str(value)])
print("\n".join(args))
PY
)" || extract_status=$?

if [[ "$extract_status" -ne 0 ]]; then
  emit_decision block "completion hook payload could not resolve one unambiguous standard-chain target"
  exit 2
fi

core_args=()
while IFS= read -r arg; do
  [[ -n "$arg" ]] && core_args+=("$arg")
done <<<"$extract_output"
timeout_seconds="${SC_COMPLETION_ADAPTER_TIMEOUT_SECONDS:-15}"
output_limit="${SC_COMPLETION_ADAPTER_OUTPUT_LIMIT_BYTES:-65536}"

runner_status=0
runner_output="$(
  python3 - "$timeout_seconds" "$output_limit" "$CORE" "${core_args[@]+"${core_args[@]}"}" <<'PY'
import os, subprocess, sys
timeout = float(sys.argv[1])
limit = int(sys.argv[2])
command = [sys.argv[3], *sys.argv[4:]]
try:
    completed = subprocess.run(command, env=os.environ.copy(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
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
  0|1)
    if [[ -z "$runner_output" ]] || ! sc_validate_routing_json "$runner_output" "$ROOT"; then
      emit_decision block "completion adapter received no valid routing JSON from the core checker"
      exit 2
    fi
    decision_reason="$(python3 - "$runner_output" <<'PY'
import json, sys
payload = json.loads(sys.argv[1])
print(json.dumps({"decision": "allow" if payload["status"] == "PASS" else "block", "reason": payload.get("user_message") or payload["failure_code"]}, ensure_ascii=False, sort_keys=True))
PY
)"
    printf '%s\n' "$decision_reason"
    [[ "$runner_status" -eq 0 ]] || exit 2
    ;;
  124)
    emit_decision block "completion adapter timed out while invoking the core checker"
    exit 2
    ;;
  125)
    emit_decision block "completion adapter output exceeded the configured byte limit"
    exit 2
    ;;
  *)
    emit_decision block "completion adapter could not execute the core checker"
    exit 2
    ;;
esac
