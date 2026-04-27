#!/usr/bin/env bash
# Shared routing helpers for standard-chain core checkers.

sc_repo_root() {
  local source_dir
  source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$source_dir/../../.." && pwd
}

sc_failure_routing_validator() {
  local root="${1:-$(sc_repo_root)}"
  printf '%s\n' "$root/tools/community/validate_failure_routing_contract.py"
}

sc_validate_routing_json() {
  local payload="$1"
  local root="${2:-$(sc_repo_root)}"
  python3 "$(sc_failure_routing_validator "$root")" \
    --repo-root "$root" \
    --result-json "$payload" >/dev/null
}

sc_emit_routing_json() {
  local root stage failure_code owner next_action continuation_condition user_message
  root="$(sc_repo_root)"
  stage=""
  failure_code=""
  owner=""
  next_action=""
  continuation_condition="__SC_USE_REGISTRY_DEFAULT__"
  user_message=""
  local evidence_refs=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root | --stage | --failure-code | --owner | --next-action | --continuation-condition | --user-message | --evidence-ref)
        if [[ $# -lt 2 ]]; then
          printf '[FAIL] routing option %s requires a value\n' "$1" >&2
          return 2
        fi
        ;;
    esac

    case "$1" in
      --repo-root)
        root="$2"
        shift 2
        ;;
      --stage)
        stage="$2"
        shift 2
        ;;
      --failure-code)
        failure_code="$2"
        shift 2
        ;;
      --owner)
        owner="$2"
        shift 2
        ;;
      --next-action)
        next_action="$2"
        shift 2
        ;;
      --continuation-condition)
        continuation_condition="$2"
        shift 2
        ;;
      --user-message)
        user_message="$2"
        shift 2
        ;;
      --evidence-ref)
        evidence_refs+=("$2")
        shift 2
        ;;
      *)
        printf '[FAIL] unknown routing option: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done

  if [[ -z "$stage" || -z "$failure_code" ]]; then
    printf '[FAIL] --stage and --failure-code are required\n' >&2
    return 2
  fi

  local validator summary payload
  validator="$(sc_failure_routing_validator "$root")"
  summary="$(
    python3 "$validator" \
      --repo-root "$root" \
      --print-registry-summary
  )" || return 1

  payload="$(
    python3 - "$summary" "$stage" "$failure_code" "$owner" "$next_action" \
      "$continuation_condition" "$user_message" "${evidence_refs[@]}" <<'PY'
import json
import sys

summary = json.loads(sys.argv[1])
stage, code, owner, next_action, condition, message = sys.argv[2:8]
evidence_refs = [ref for ref in sys.argv[8:] if ref]
entries = summary["entries_by_code"]
schema_version = summary["schema_version"]

unknown_code = code not in entries
if unknown_code:
    code = "UNREGISTERED_FAILURE_CODE"
    evidence_refs.append("diagnostic://failure-routing/unregistered-condition")

entry = entries[code]
resolved_condition = entry.get("continuation_condition") or "none"
if condition != "__SC_USE_REGISTRY_DEFAULT__":
    resolved_condition = condition
resolved_owner = owner or entry["default_owner"]
resolved_next_action = next_action or entry["default_next_action"]
if unknown_code:
    resolved_owner = entry["default_owner"]
    resolved_next_action = entry["default_next_action"]
    resolved_condition = entry.get("continuation_condition") or "none"

payload = {
    "schema_version": schema_version,
    "status": entry["status"],
    "stage": stage,
    "failure_code": code,
    "owner": resolved_owner,
    "next_action": resolved_next_action,
    "safe_to_continue": entry["safe_to_continue"],
    "human_decision_required": entry["human_decision_required"],
    "continuation_condition": resolved_condition,
    "evidence_refs": evidence_refs,
    "user_message": message or entry["message_template"],
}
print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
PY
  )" || return 1

  sc_validate_routing_json "$payload" "$root" || return 1
  printf '%s\n' "$payload"
}

sc_core_cli_guard() {
  local stage allowed_options required_options
  stage=""
  allowed_options=""
  required_options=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stage | --allowed-options | --required-options)
        if [[ $# -lt 2 ]]; then
          sc_emit_core_cli_reject "${stage:-standard-chain.preflight}" "Core checker guard option $1 requires a value." "diagnostic://standard-chain/core-cli/guard-argv"
          return 1
        fi
        ;;
    esac

    case "$1" in
      --stage)
        stage="$2"
        shift 2
        ;;
      --allowed-options)
        allowed_options="$2"
        shift 2
        ;;
      --required-options)
        required_options="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        sc_emit_core_cli_reject "${stage:-standard-chain.preflight}" "Malformed core checker guard arguments." "diagnostic://standard-chain/core-cli/guard-argv"
        return 1
        ;;
    esac
  done

  if [[ -z "$stage" ]]; then
    sc_emit_core_cli_reject "standard-chain.preflight" "Core checker guard requires a stage." "diagnostic://standard-chain/core-cli/missing-stage"
    return 1
  fi

  if [[ -p /dev/stdin || -f /dev/stdin ]]; then
    sc_emit_core_cli_reject "$stage" "Core checkers are argv-only; hook payload stdin must use an adapter." "diagnostic://standard-chain/core-cli/stdin-hook-payload"
    return 1
  fi

  sc_validate_core_argv "$stage" "$allowed_options" "$required_options" "$@"
}

sc_validate_core_argv() {
  local stage="$1"
  local allowed_options="$2"
  local required_options="$3"
  shift 3
  local -a args=("$@")
  local seen=","
  local index token option value

  index=0
  while [[ $index -lt ${#args[@]} ]]; do
    token="${args[$index]}"
    if [[ "$token" != --* || "$token" == "--" ]]; then
      sc_emit_core_cli_reject "$stage" "Core checker arguments must use --name value pairs." "diagnostic://standard-chain/core-cli/malformed-argv"
      return 1
    fi
    option="${token#--}"
    if ! sc_csv_contains "$allowed_options" "$option"; then
      sc_emit_core_cli_reject "$stage" "Core checker received unsupported argument --$option." "diagnostic://standard-chain/core-cli/unsupported-argv"
      return 1
    fi
    if [[ $((index + 1)) -ge ${#args[@]} ]]; then
      sc_emit_core_cli_reject "$stage" "Core checker argument --$option is missing a value." "diagnostic://standard-chain/core-cli/malformed-argv"
      return 1
    fi
    value="${args[$((index + 1))]}"
    if [[ -z "$value" || "$value" == --* ]]; then
      sc_emit_core_cli_reject "$stage" "Core checker argument --$option is missing a value." "diagnostic://standard-chain/core-cli/malformed-argv"
      return 1
    fi
    seen="${seen}${option},"
    index=$((index + 2))
  done

  local required
  IFS=',' read -r -a required <<<"$required_options"
  for required in "${required[@]}"; do
    [[ -z "$required" ]] && continue
    if [[ "$seen" != *",$required,"* ]]; then
      sc_emit_core_cli_reject "$stage" "Core checker is missing required argument --$required." "diagnostic://standard-chain/core-cli/missing-required-argv"
      return 1
    fi
  done
}

sc_csv_contains() {
  local csv="$1"
  local needle="$2"
  [[ ",$csv," == *",$needle,"* ]]
}

sc_emit_core_cli_reject() {
  local stage="$1"
  local message="$2"
  local evidence_ref="$3"
  sc_emit_routing_json \
    --stage "$stage" \
    --failure-code AMBIGUOUS_TARGET \
    --owner delivery-owner \
    --user-message "$message" \
    --evidence-ref "$evidence_ref"
}
