#!/usr/bin/env bash
# File role: prove skill-harness runtime fields have consumers and controlled validation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIELD="$ROOT/shared/skills/skill-harness/schemas/field-consumers.json"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
FIXTURES="$ROOT/tests/fixtures/skill-harness/field-consumers"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-harness-field-consumers.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local label="$1"
  local expected="$2"
  shift 2
  local stdout_file
  local stderr_file
  stdout_file="$(mktemp "$TMP_DIR/stdout.XXXXXX")"
  stderr_file="$(mktemp "$TMP_DIR/stderr.XXXXXX")"
  set +e
  "$@" >"$stdout_file" 2>"$stderr_file"
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label unexpectedly passed"
  fi
  if ! grep -Fq "$expected" "$stdout_file" "$stderr_file"; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label did not report $expected"
  fi
}

[ -f "$FIELD" ] || fail "missing field-consumers.json"

python3 - "$FIELD" "$ROOT" <<'PY'
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

path = Path(sys.argv[1])
root = Path(sys.argv[2])
data = json.load(path.open(encoding="utf-8"))
required_keys = {
    "field",
    "consumer",
    "read_purpose",
    "validation_command",
    "drop_condition",
    "failure_state",
}
required_fields = {
    "overall_verdict",
    "dimension",
    "dimension_result",
    "finding_severity",
    "priority",
    "skill_id",
    "runtime_target",
    "scope",
    "owner",
    "file_line",
    "evidence",
    "impact",
    "recommendation",
    "audit_proof_type",
    "proof_command",
    "gate_type",
    "allowed_final_decision_sources",
    "must_verify_authority_proof_refs",
    "must_verify_payload_digest",
    "must_match_actor_and_channel",
    "decision_payload_digest",
    "baseline_plan_version_ref",
    "active_plan_version_ref",
    "dry_run_verdict",
    "high_value_finding",
    "next_implementation_object",
    "expected_benefit",
    "stop_condition",
    "proof_or_gate_ref",
    "legacy_baseline_label",
}
allowed_consumers = {
    "check_skill_harness_contract.py",
    "human_projection",
    "hook_adapter",
    "release_gate",
    "runner",
    "validator",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def resolve_validation_script(command: str) -> Path:
    parts = shlex.split(command)
    if len(parts) < 2 or parts[0] not in {"bash", "python3", "python"}:
        fail(f"validation command is not repo-local script: {command}")
    candidate = root / parts[1]
    if not candidate.exists() or not candidate.is_file():
        fail(f"validation command is not repo-local script: {command}")
    rel = candidate.relative_to(root)
    if rel.parts and rel.parts[0] == "docs":
        fail(f"validation command must not live under docs: {command}")
    return candidate


def validate_consumer(consumer: str) -> None:
    if consumer in allowed_consumers:
        return
    candidate = root / consumer
    if candidate.exists():
        return
    fail(f"consumer does not resolve to allowed type or repo path: {consumer}")


if not isinstance(data, dict) or not isinstance(data.get("fields"), list):
    fail("field-consumers.json must contain a fields array")

seen = set()
for row in data["fields"]:
    if not isinstance(row, dict):
        fail("field consumer row must be object")
    missing = sorted(required_keys - row.keys())
    if missing:
        fail(f"missing keys: {missing}")
    for key in required_keys:
        if not isinstance(row[key], str) or not row[key].strip():
            fail(f"incomplete consumer row: {row.get('field')}")
    validate_consumer(row["consumer"])
    resolve_validation_script(row["validation_command"])
    if os.environ.get("SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF") != "1":
        env = os.environ.copy()
        env["SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF"] = "1"
        subprocess.run(
            shlex.split(row["validation_command"]),
            cwd=root,
            env=env,
            timeout=30,
            check=True,
        )
    seen.add(row["field"])

file_line = next((row for row in data["fields"] if row["field"] == "file_line"), None)
if file_line is None:
    fail("missing file_line consumer")
purpose = file_line["read_purpose"]
for token in ("file_ref", "file:line", "repo-local path:line"):
    if token not in purpose:
        fail(f"file_line consumer must document locator mapping token: {token}")

missing_fields = sorted(required_fields - seen)
if missing_fields:
    fail(f"missing consumer coverage: {missing_fields}")

print("[PASS] field consumer coverage")
PY

expect_fail "invalid command" "FIELD_CONSUMER_INVALID_COMMAND" \
  python3 "$CHECKER" "$FIXTURES/invalid-command.json"
expect_fail "invalid consumer" "FIELD_CONSUMER_INVALID_CONSUMER" \
  python3 "$CHECKER" "$FIXTURES/invalid-consumer.json"
expect_fail "missing drop condition" "FIELD_CONSUMER_MISSING_DROP_CONDITION" \
  python3 "$CHECKER" "$FIXTURES/missing-drop-condition.json"
expect_fail "failing validation command with ambient guard" "FIELD_CONSUMER_VALIDATION_FAILED" \
  env SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF=1 python3 "$CHECKER" "$FIXTURES/failing-validation-command.json"

printf '[PASS] skill-harness field consumers\n'
