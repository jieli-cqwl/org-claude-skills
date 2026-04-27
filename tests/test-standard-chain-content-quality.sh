#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures/standard-chain-content-quality"
VALIDATOR="$ROOT/tools/community/validate_standard_chain_content_quality.py"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

run_ok() {
  local label="$1"
  shift
  "$@" >/tmp/standard_chain_content_quality.out 2>/tmp/standard_chain_content_quality.err || {
    cat /tmp/standard_chain_content_quality.out >&2
    cat /tmp/standard_chain_content_quality.err >&2
    fail "$label should pass"
  }
}

run_rejects() {
  local label="$1"
  local expected="$2"
  shift 2
  if "$@" >/tmp/standard_chain_content_quality.out 2>/tmp/standard_chain_content_quality.err; then
    cat /tmp/standard_chain_content_quality.out >&2
    fail "$label should fail"
  fi
  if ! rg -q "$expected" /tmp/standard_chain_content_quality.out /tmp/standard_chain_content_quality.err; then
    cat /tmp/standard_chain_content_quality.out >&2
    cat /tmp/standard_chain_content_quality.err >&2
    fail "$label did not report $expected"
  fi
}

test -f "$VALIDATOR" || fail "missing validator: ${VALIDATOR#$ROOT/}"

run_ok "valid content layers" \
  python3 "$VALIDATOR" --skill "$FIXTURES/valid-skill.md"

run_rejects "hidden MUST inside Why" "hidden_must_in_why" \
  python3 "$VALIDATOR" --skill "$FIXTURES/invalid-hidden-must-in-why.md"

run_rejects "concrete command inside How" "how_concrete_instruction" \
  python3 "$VALIDATOR" --skill "$FIXTURES/invalid-how-with-file-command.md"

run_rejects "unowned failure statement" "unowned_failure_statement" \
  python3 "$VALIDATOR" --skill "$FIXTURES/invalid-unowned-failure.md"

run_rejects "repeated source-of-truth claims" "repeated_source_of_truth" \
  python3 "$VALIDATOR" --skill "$FIXTURES/invalid-repeated-source-of-truth.md"

run_rejects "vague ambiguous action wording" "vague_ambiguous_action" \
  python3 "$VALIDATOR" --skill "$FIXTURES/invalid-vague-action-wording.md"

run_ok "valid audit records" \
  python3 "$VALIDATOR" --audit "$FIXTURES/valid-noise-migration-audit.json"

run_rejects "audit required field type" "missing_audit_field" \
  python3 "$VALIDATOR" --audit "$FIXTURES/invalid-audit-field-type.json"

run_rejects "audit reverse touched skill coverage" "audit_entry_without_touched_skill" \
  python3 "$VALIDATOR" --audit "$FIXTURES/invalid-audit-reverse-coverage.json"

run_rejects "invalid audit content layer" "invalid_content_layer" \
  python3 "$VALIDATOR" --audit "$FIXTURES/invalid-content-layer-audit.json"

run_rejects "invalid audit migration action" "invalid_migration_action" \
  python3 "$VALIDATOR" --audit "$FIXTURES/invalid-migration-action-audit.json"

run_rejects "delete audit without proof" "delete_without_reason_or_verification" \
  python3 "$VALIDATOR" --audit "$FIXTURES/invalid-delete-without-proof.json"

run_ok "fixture content plus audit" \
  python3 "$VALIDATOR" \
    --skill "$FIXTURES/valid-skill.md" \
    --audit "$FIXTURES/valid-noise-migration-audit.json"

run_ok "active standard-chain target discovery" \
  python3 "$VALIDATOR" --repo-root "$ROOT" --active-standard-chain --list-targets

target_count="$(python3 "$VALIDATOR" --repo-root "$ROOT" --active-standard-chain --list-targets | wc -l | tr -d ' ')"
[[ "$target_count" == "10" ]] || fail "expected 10 active standard-chain targets, got $target_count"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/contracts"
cat >"$tmp_root/contracts/standard-chain.yaml" <<'YAML'
chain:
  - name: quoted-role
    position: "main"
  - name: sidecar-role
    position: "sidecar"
context_handoff: {}
YAML
quoted_targets="$(python3 "$VALIDATOR" --repo-root "$tmp_root" --active-standard-chain --list-targets)"
[[ "$quoted_targets" == "shared/skills/quoted-role/SKILL.md" ]] || fail "quoted YAML active discovery failed: $quoted_targets"

tmp_skill="$tmp_root/source-truth-valid.md"
cat >"$tmp_skill" <<'MD'
# Fixture Skill

## HARD-GATE

- Stop when the declared task scope is missing.

## Protocol

1. Read the scoped task contract.

## Why

These checks keep role guidance unambiguous.

## How

Use layer definitions to separate rationale from runtime behavior.

## Script Contract

Run the content-quality validator.

## Failure Routing

If a finding appears, owner `delivery-owner` takes next action `repair_skill_or_audit_record` and continuation waits for a fresh validator pass.

## Reference Link

The reference note says methodology files are not a source of truth for runtime fields.

## Output Contract

The output contract source of truth is the validator result emitted for the current run.
MD
run_ok "non-authoritative source truth mention plus output contract" \
  python3 "$VALIDATOR" --skill "$tmp_skill"

printf '[PASS] standard-chain content quality gate\n'
