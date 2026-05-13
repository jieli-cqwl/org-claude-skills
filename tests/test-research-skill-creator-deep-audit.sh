#!/usr/bin/env bash
# File role: prove the research retain decision has a skill-creator deep audit
# boundary, not just a static retain label.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/shared/skills/research/evals/skill-creator-deep-audit-2026-05-12/research-skill-creator-deep-audit.json"
LIFECYCLE="$ROOT/shared/skills/research/evals/lifecycle-review.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$AUDIT" || fail "missing skill-creator deep audit artifact: ${AUDIT#"$ROOT"/}"
test -f "$LIFECYCLE" || fail "missing research lifecycle artifact"

jq empty "$AUDIT" "$LIFECYCLE" >/dev/null || fail "invalid JSON in research deep audit artifacts"

jq -e '
  .artifact_type == "research-skill-creator-deep-audit"
  and .schema_version == 1
  and .target.skill_name == "research"
  and .target.current_lifecycle_decision == "retain"
  and .method.primary_skill == "skill-creator"
  and .method.evaluation_kind == "local_artifact_contract_audit"
  and .retain_assessment.decision == "retain"
  and .retain_assessment.confidence == "bounded"
  and (.retain_assessment.not_proven | index("skill-creator eval viewer human feedback loop") != null)
  and (.retain_assessment.not_proven | index("multi-run statistical confidence") != null)
  and (.retain_assessment.required_before_stronger_claim | length) >= 2
  and .quick_validate.status == "incompatible_with_local_slash_skill_frontmatter"
  and (.quick_validate.compatibility_evidence.commands | index("bash tests/test-codex-skill-adapter.sh") != null)
  and (.quick_validate.compatibility_evidence.commands | index("bash tests/test-skill-runtime-surface-contract.sh") != null)
  and (.runtime_checks | map(select(.status == "pass")) | length) >= 4
  and (.findings | map(select(.severity == "blocking")) | length) == 0
  and (.findings | map(select(.id == "SCDA-01" and .status == "partially_closed")) | length) == 1
' "$AUDIT" >/dev/null || fail "research skill-creator deep audit does not satisfy retain boundary"

jq -e '
  .decision == "retain"
  and (.evidence_refs | index("shared/skills/research/evals/skill-creator-deep-audit-2026-05-12/research-skill-creator-deep-audit.json") != null)
' "$LIFECYCLE" >/dev/null || fail "research lifecycle must reference skill-creator deep audit"

run_all_list="$(bash "$ROOT/tests/run-all.sh" --quick --list)"
rg -q 'test-research-skill-creator-deep-audit\.sh' <<<"$run_all_list" \
  || fail "run-all quick plan must include research skill-creator deep audit"

printf '[PASS] research skill-creator deep audit\n'
