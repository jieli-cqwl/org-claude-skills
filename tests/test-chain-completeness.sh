#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHAIN="$ROOT/contracts/small-chain.yaml"
STANDARD_CHAIN="$ROOT/contracts/skill-chain.yaml"
STANDARD_CHAIN_CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"
STANDARD_CHAIN_BUILDER="$ROOT/tools/community/build_standard_chain_catalog.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$CHAIN" ] || fail "missing contracts/small-chain.yaml"
[ -f "$STANDARD_CHAIN" ] || fail "missing contracts/skill-chain.yaml"
[ -f "$STANDARD_CHAIN_CATALOG" ] || fail "missing shared/runtime/standard-chain-catalog.json"
[ -f "$STANDARD_CHAIN_BUILDER" ] || fail "missing tools/community/build_standard_chain_catalog.py"

for skill in using-superpowers brainstorming writing-plans using-git-worktrees subagent-driven-development verification-before-completion verify-change finishing-a-development-branch archive; do
  grep -Fq "name: $skill" "$CHAIN" || fail "chain contract missing skill: $skill"
done

grep -Fq 'phase_delivery_owner: delivery-owner' "$STANDARD_CHAIN" || fail "standard chain missing delivery-owner authority"
grep -Fq 'qa_report_producer: qa' "$STANDARD_CHAIN" || fail "standard chain missing qa report producer"
grep -Fq 'plan_version' "$STANDARD_CHAIN" || fail "standard chain missing plan_version key field"

delivery_owner_block="$(awk '
  /- name: delivery-owner/ { in_block=1 }
  in_block { print }
  /- name: developer/ { if (in_block) exit }
' "$STANDARD_CHAIN")"
printf '%s\n' "$delivery_owner_block" | grep -Fq 'phase-{N}/qa-report.md' || fail "delivery-owner block missing qa-report required input"

for path in \
  "$ROOT/community/superpowers/skills/brainstorming/SKILL.md" \
  "$ROOT/community/superpowers/skills/writing-plans/SKILL.md" \
  "$ROOT/community/superpowers/skills/subagent-driven-development/SKILL.md" \
  "$ROOT/community/superpowers/skills/verification-before-completion/SKILL.md" \
  "$ROOT/community/superpowers/skills/verify-change/SKILL.md" \
  "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md" \
  "$ROOT/community/superpowers/skills/archive/SKILL.md" \
  "$ROOT/contracts/superpowers-boundary.yaml"; do
  [ -f "$path" ] || fail "small-chain completeness missing file: ${path#"$ROOT"/}"
done

python3 "$STANDARD_CHAIN_BUILDER" --check || fail "standard chain catalog drift"

python3 - "$STANDARD_CHAIN_CATALOG" "$ROOT" <<'PY' || fail "standard chain catalog completeness invalid"
import json
import sys
from pathlib import Path


catalog_path = Path(sys.argv[1])
root = Path(sys.argv[2])
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))

required = {
    "brief": "docs/{feature}/brief.json",
    "phase-prd": "docs/{feature}/phase-{N}/phase-prd.json",
    "unit-definition": "docs/{feature}/phase-{N}/units/UNIT-{N}.json",
    "design": "docs/{feature}/phase-{N}/design.json",
    "test-cases": "docs/{feature}/phase-{N}/unit-{N}/test-cases.json",
    "plan": "docs/{feature}/phase-{N}/plan.json",
    "tasks": "docs/{feature}/phase-{N}/tasks.json",
    "developer-report": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
    "verify-result": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
    "code-review-result": "docs/{feature}/phase-{N}/code-review-result.json",
    "qa-result": "docs/{feature}/phase-{N}/qa-result.json",
    "delivery-state": "docs/{feature}/phase-{N}/delivery-state.json",
    "signoff-package": "docs/{feature}/phase-{N}/signoff-package.json",
    "user-decision": "docs/{feature}/phase-{N}/user-decision.json",
    "artifact-registry": "docs/{feature}/phase-{N}/artifact-registry.json",
    "projection-manifest": "docs/{feature}/phase-{N}/views/phase-operational.projection-manifest.json",
}
required_families = {
    "brief": "planning",
    "phase-prd": "planning",
    "unit-definition": "planning",
    "design": "planning",
    "test-cases": "planning",
    "plan": "planning",
    "tasks": "planning",
    "developer-report": "runtime",
    "verify-result": "runtime",
    "code-review-result": "runtime",
    "qa-result": "runtime",
    "delivery-state": "runtime",
    "signoff-package": "runtime",
    "user-decision": "runtime",
    "artifact-registry": "runtime",
    "projection-manifest": "projection",
}
required_producers = {
    "brief": "product",
    "phase-prd": "product",
    "unit-definition": "product",
    "design": "design",
    "test-cases": "test-design",
    "plan": "tech-lead",
    "tasks": "tech-lead",
    "developer-report": "developer",
    "verify-result": "verify",
    "code-review-result": "review",
    "qa-result": "qa",
    "delivery-state": "delivery-owner",
    "signoff-package": "delivery-owner",
    "user-decision": "user-decision-writer",
    "artifact-registry": "delivery-owner",
    "projection-manifest": "materialize-canonical-html",
}

artifacts = catalog.get("artifacts")
if set(artifacts) != set(required):
    raise SystemExit(f"catalog artifact set mismatch: {sorted(artifacts)}")

for artifact_type, default_path in required.items():
    entry = artifacts[artifact_type]
    if entry.get("default_path") != default_path:
        raise SystemExit(
            f"{artifact_type}: default path mismatch: {entry.get('default_path')} != {default_path}"
        )
    for field in ("schema_path", "template_path", "scope", "chain_registry_digest", "family", "producer", "schema_version"):
        if not entry.get(field):
            raise SystemExit(f"{artifact_type}: missing {field}")
    if entry["family"] != required_families[artifact_type]:
        raise SystemExit(f"{artifact_type}: family mismatch: {entry['family']} != {required_families[artifact_type]}")
    if entry["producer"] != required_producers[artifact_type]:
        raise SystemExit(f"{artifact_type}: producer mismatch: {entry['producer']} != {required_producers[artifact_type]}")
    if entry["schema_version"] != "1.0.0":
        raise SystemExit(f"{artifact_type}: schema_version mismatch: {entry['schema_version']}")
    schema_path = root / entry["schema_path"]
    template_path = root / entry["template_path"]
    if not schema_path.is_file():
        raise SystemExit(f"{artifact_type}: schema missing at {entry['schema_path']}")
    if not template_path.is_file():
        raise SystemExit(f"{artifact_type}: template missing at {entry['template_path']}")

task_scope = {
    "developer-report": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
    "verify-result": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
}
for artifact_type, expected in task_scope.items():
    if artifacts[artifact_type]["default_path"] != expected:
        raise SystemExit(f"{artifact_type}: task scope path shrink detected")
PY

echo "[PASS] chain completeness"
