#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT

HELPER="$ROOT/shared/skills/lib/standard-chain-routing.sh"
VALIDATOR="$ROOT/tools/community/validate_failure_routing_contract.py"
PREFLIGHT_PROFILES="$ROOT/shared/runtime/standard-chain-preflight-profiles.json"
COMPLETION_PROFILES="$ROOT/shared/runtime/standard-chain-completion-profiles.json"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

validate_result_json() {
  local payload="$1"
  python3 "$VALIDATOR" --repo-root "$ROOT" --result-json "$payload" >/dev/null
}

[[ -f "$HELPER" ]] || fail "missing shared routing helper: ${HELPER#$ROOT/}"
[[ -f "$PREFLIGHT_PROFILES" ]] || fail "missing preflight profile catalog: ${PREFLIGHT_PROFILES#$ROOT/}"
[[ -f "$COMPLETION_PROFILES" ]] || fail "missing completion profile catalog: ${COMPLETION_PROFILES#$ROOT/}"

# shellcheck source=/dev/null
source "$HELPER"

pass_payload="$(
  sc_emit_routing_json \
    --stage qa.preflight \
    --failure-code NONE \
    --owner qa \
    --user-message "QA preflight passed." \
    --evidence-ref "test://standard-chain/checker/pass"
)"
validate_result_json "$pass_payload"

unknown_payload="$(
  sc_emit_routing_json \
    --stage qa.preflight \
    --failure-code NOT_REGISTERED_ANYWHERE \
    --owner qa \
    --next-action continue \
    --user-message "unknown code must ignore unsafe owner/action overrides" \
    --evidence-ref "test://standard-chain/checker/unknown-code"
)"
validate_result_json "$unknown_payload"
python3 - "$unknown_payload" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["failure_code"] == "UNREGISTERED_FAILURE_CODE", payload
assert payload["status"] == "BLOCKED", payload
assert payload["owner"] == "delivery-owner", payload
assert payload["next_action"] == "register_failure_code_or_fix_checker", payload
assert payload["safe_to_continue"] is False, payload
PY

python3 - "$VALIDATOR" "$ROOT" "$unknown_payload" <<'PY'
import json
import subprocess
import sys

validator, root, payload = sys.argv[1:]
bad = json.loads(payload)
bad["owner"] = "qa"
bad["next_action"] = "continue"
completed = subprocess.run(
    [sys.executable, validator, "--repo-root", root, "--result-json", json.dumps(bad, sort_keys=True)],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if completed.returncode == 0:
    raise SystemExit("validator accepted UNREGISTERED_FAILURE_CODE owner/action drift")
PY

if warn_output="$(
  sc_emit_routing_json \
    --stage qa.preflight \
    --failure-code CONDITIONAL_CONTINUE \
    --owner qa \
    --continuation-condition "" \
    --user-message "warning without continuation condition" 2>/dev/null
)"; then
  fail "WARN without continuation_condition was accepted: $warn_output"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
core_checker="$tmp_dir/check_preflight.sh"
cat >"$core_checker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ROOT/shared/skills/lib/standard-chain-routing.sh"

if ! sc_core_cli_guard \
  --stage qa.preflight \
  --allowed-options "feature,phase-dir" \
  --required-options "feature" \
  -- "$@"; then
  exit 1
fi

sc_emit_routing_json \
  --stage qa.preflight \
  --failure-code NONE \
  --owner qa \
  --user-message "argv-only core checker accepted explicit arguments." \
  --evidence-ref "test://standard-chain/checker/core-argv"
SH
chmod +x "$core_checker"

core_pass="$("$core_checker" --feature login-homepage)"
validate_result_json "$core_pass"

if stdin_reject="$(printf '{"hook":"payload"}\n' | "$core_checker" --feature login-homepage)"; then
  fail "core checker accepted stdin hook payload: $stdin_reject"
fi
validate_result_json "$stdin_reject"
python3 - "$stdin_reject" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "BLOCKED", payload
assert payload["failure_code"] == "AMBIGUOUS_TARGET", payload
assert payload["safe_to_continue"] is False, payload
PY

if stdin_file_reject="$("$core_checker" --feature login-homepage <<< '{"hook":"payload"}')"; then
  fail "core checker accepted redirected stdin hook payload: $stdin_file_reject"
fi
validate_result_json "$stdin_file_reject"
python3 - "$stdin_file_reject" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "BLOCKED", payload
assert payload["failure_code"] == "AMBIGUOUS_TARGET", payload
assert payload["safe_to_continue"] is False, payload
PY

stdin_payload_file="$tmp_dir/hook-payload.json"
printf '{"hook":"payload"}\n' >"$stdin_payload_file"
if stdin_redirect_reject="$("$core_checker" --feature login-homepage < "$stdin_payload_file")"; then
  fail "core checker accepted file-redirected stdin hook payload: $stdin_redirect_reject"
fi
validate_result_json "$stdin_redirect_reject"
python3 - "$stdin_redirect_reject" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "BLOCKED", payload
assert payload["failure_code"] == "AMBIGUOUS_TARGET", payload
assert payload["safe_to_continue"] is False, payload
PY

if malformed_reject="$("$core_checker" --feature)"; then
  fail "core checker accepted malformed argv: $malformed_reject"
fi
validate_result_json "$malformed_reject"
python3 - "$malformed_reject" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "BLOCKED", payload
assert payload["failure_code"] == "AMBIGUOUS_TARGET", payload
assert payload["safe_to_continue"] is False, payload
PY

python3 <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
validator = root / "tools" / "community" / "validate_failure_routing_contract.py"
preflight_path = root / "shared" / "runtime" / "standard-chain-preflight-profiles.json"
completion_path = root / "shared" / "runtime" / "standard-chain-completion-profiles.json"
roles = [
    "product-director",
    "product-manager",
    "design",
    "test-design",
    "tech-lead",
    "delivery-owner",
    "developer",
    "verify",
    "review",
    "qa",
]
policy_keys = {
    "status",
    "default_owner",
    "default_next_action",
    "safe_to_continue",
    "human_decision_required",
    "continuation_condition",
    "message_template",
}


def fail(message: str) -> None:
    raise AssertionError(message)


def registry_codes() -> set[str]:
    completed = subprocess.run(
        [sys.executable, str(validator), "--repo-root", str(root), "--print-registry-summary"],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    summary = json.loads(completed.stdout)
    return set(summary["entries_by_code"])


def walk(obj: object):
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from walk(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from walk(item)


def check_catalog(path: Path, expected_type: str, codes: set[str]) -> None:
    catalog = json.loads(path.read_text(encoding="utf-8"))
    if catalog.get("schema_version") != "1.0.0":
        fail(f"{path.name}: schema_version must be 1.0.0")
    if catalog.get("profile_type") != expected_type:
        fail(f"{path.name}: profile_type must be {expected_type}")
    role_profiles = catalog.get("roles")
    if not isinstance(role_profiles, dict):
        fail(f"{path.name}: roles must be an object")
    actual_roles = list(role_profiles)
    if actual_roles != roles:
        fail(f"{path.name}: expected exact main role coverage {roles}, got {actual_roles}")
    for node in walk(catalog):
        forbidden = policy_keys & set(node)
        if forbidden:
            fail(f"{path.name}: profile catalog defines routing policy keys {sorted(forbidden)}")
        failure_code = node.get("failure_code")
        if failure_code is not None and failure_code not in codes:
            fail(f"{path.name}: unregistered failure_code {failure_code}")
    for role, profile in role_profiles.items():
        checks = profile.get("checks")
        if not isinstance(checks, list) or not checks:
            fail(f"{path.name}: {role} must define non-empty checks")
        for check in checks:
            if check.get("role_boundary") != "role-owned-detection":
                fail(f"{path.name}: {role}.{check.get('check_id')} is not role-owned detection")


codes = registry_codes()
check_catalog(preflight_path, "preflight", codes)
check_catalog(completion_path, "completion", codes)
PY

echo "[PASS] standard-chain checker contract"
