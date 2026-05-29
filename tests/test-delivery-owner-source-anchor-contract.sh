#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/do_source_anchor_absent.out 2>&1; then
    cat /tmp/do_source_anchor_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

python3 - "$ROOT/contracts/standard-chain.yaml" <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[1]).parents[1] / "tools" / "community"))
from runtime_yaml import load_yaml

standard_chain = load_yaml(Path(sys.argv[1]))
outputs = {
    output.get("artifact"): output.get("key_fields", [])
    for stage in standard_chain.get("chain", [])
    if stage.get("name") == "delivery-owner"
    for output in stage.get("outputs", []) or []
}
expected_fields = {
    "phase-{N}/delivery-state.json": {
        "active_tasks_version_ref",
        "current_stage",
        "status",
        "control_action",
        "progress_signal",
        "consecutive_no_progress_count",
        "owner_action_consumption",
        "blocker_id",
        "blocker_owner",
        "blocker_basis_refs",
        "resume_stage",
        "next_action",
        "resume_condition",
    },
    "phase-{N}/signoff-package.json": {
        "baseline_tasks_version_ref",
        "active_tasks_version_ref",
        "runtime_evidence_matrix",
        "decision_basis_refs",
    },
    "phase-{N}/user-decision.json": {
        "baseline_tasks_version_ref",
        "active_tasks_version_ref",
        "authority_proof_refs",
        "decision_basis_refs",
        "director_lock_digests",
        "decision_payload_digest",
    },
}
for artifact, required in expected_fields.items():
    key_fields = outputs.get(artifact)
    if not isinstance(key_fields, list) or not key_fields:
        raise SystemExit(f"delivery-owner output missing key_fields: {artifact}")
    duplicates = sorted({field for field in key_fields if key_fields.count(field) > 1})
    if duplicates:
        raise SystemExit(f"{artifact} has duplicate key_fields: {duplicates}")
    missing = sorted(required - set(key_fields))
    if missing:
        raise SystemExit(f"{artifact} missing source anchor key_fields: {missing}")
PY
assert_present 'plan_version: \{plan-vN\}' "$ROOT/shared/skills/tech-lead/projections/plan-template.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
assert_present 'enforce-canonical-only' "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"

python3 - "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json" <<'PY'
import json
import sys
from pathlib import Path

schema = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
props = schema["allOf"][1]["properties"]
required = {"traceability_matrix", "qa_handoff_contract", "cross_unit_obligations", "review_conclusion", "issue_ledger"}
missing = sorted(required - set(props))
if missing:
    raise SystemExit(f"test-cases schema missing anchor carriers: {missing}")
PY

assert_present '"business_goals"' "$ROOT/shared/skills/product-director/templates/brief.template.json"
assert_present '"phase_goal"' "$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
assert_present '"authoritative_fields"' "$ROOT/shared/skills/product-director/templates/brief.template.json"
assert_present '"\$\.director_confirmation"' "$ROOT/shared/skills/product-director/templates/brief.template.json"
assert_present 'director_confirmation' "$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
assert_absent '"unit_index"|"review_conclusion"|"issue_ledger"' "$ROOT/shared/skills/product-director/templates/phase-prd.template.json"

assert_present '"verification_mapping"' "$ROOT/shared/skills/design/templates/design.template.json"
assert_present '"evidence_ref"' "$ROOT/shared/skills/design/templates/design.template.json"
assert_present '"verification_mapping"' "$ROOT/shared/skills/design/contracts/design.schema.json"
assert_present '"evidence_ref"' "$ROOT/shared/skills/design/contracts/design.schema.json"

assert_present 'Task Packet' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present '调度 `/commit`' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'developer agent' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'verifier agent' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'qa agent' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'fixer agent' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'NEEDS_RESOURCE' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'references/plan-review\.md' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'references/dispatch-packet\.md' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'references/followup-loops\.md' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_absent 'codex/agents/(developer|verifier|qa|fixer)\.toml' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_present 'developer-report\.json' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_present 'forbidden_scope:' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_absent '^[[:space:]]*scope:' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_present '"forbidden_scope"' "$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py"
assert_absent '"scope"' "$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py"
assert_present 'verify-result\.json' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_present 'qa-result\.json' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_present 'templates/user-decision-package\.template\.md' "$ROOT/shared/skills/delivery-owner/references/followup-loops.md"
assert_present 'PAUSED_FOR_USER_DECISION' "$ROOT/shared/skills/delivery-owner/templates/status-card.template.md"
assert_absent 'PAUSED_RISK' "$ROOT/shared/skills/delivery-owner/templates/status-card.template.md"
assert_present 'PAUSED_FOR_USER_DECISION' "$ROOT/shared/skills/delivery-owner/templates/user-decision-package.template.md"
assert_present 'NEEDS_RESOURCE' "$ROOT/shared/skills/delivery-owner/templates/user-decision-package.template.md"

assert_absent 'signoff_ready|control_decision_check|gap_delta|rebaseline_needed|主 Agent|不是 developer|不要用于|你只保留交付状态|对应 role agent' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_absent 'routing-and-packet|evidence-and-followup|intake-and-state|escalation-and-signoff' "$ROOT/shared/skills/delivery-owner/SKILL.md"
[ ! -d "$ROOT/shared/skills/delivery-owner-h" ] \
  || fail "historical delivery-owner-h must be deleted"
[ ! -d "$ROOT/shared/skills/delivery-owner/projections" ] \
  || fail "active delivery-owner must not retain old human projection templates"
[ ! -d "$ROOT/shared/skills/qa/projections" ] \
  || fail "active qa must not retain projections directory"

echo "[PASS] delivery-owner source anchor contract"
