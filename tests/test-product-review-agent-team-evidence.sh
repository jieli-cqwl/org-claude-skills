#!/usr/bin/env bash
# Verify PM review closure cannot PASS without verifiable agent-team evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_FEATURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
VALIDATOR="$ROOT/tools/community/validate_product_closure.py"
BRIEF_SCHEMA="$ROOT/shared/skills/product-manager/contracts/brief.schema.json"
PHASE_SCHEMA="$ROOT/shared/skills/product-manager/contracts/phase-prd.schema.json"
PM_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
PM_REVIEW="$ROOT/shared/skills/product-manager/references/review-orchestration.md"
TEST_DESIGN_SKILL="$ROOT/shared/skills/test-design/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
RESEARCH_SKILL="$ROOT/shared/skills/research/SKILL.md"

TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "forbidden pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_schema_requires_agent_team_review() {
  python3 - "$BRIEF_SCHEMA" "$PHASE_SCHEMA" <<'PY'
import json
import sys
from pathlib import Path

for path in map(Path, sys.argv[1:]):
    schema = json.loads(path.read_text(encoding="utf-8"))
    review = schema["allOf"][1]["properties"]["review_conclusion"]
    required = set(review.get("required", []))
    if "agent_team_review" not in required:
        raise SystemExit(f"{path.name} review_conclusion must require agent_team_review")
    team_review = review["properties"].get("agent_team_review", {})
    team_required = set(team_review.get("required", []))
    expected = {
        "mode",
        "round",
        "reviewed_artifact_refs",
        "reviewed_bundle_digest",
        "reviewer_verdicts",
        "convergence_evidence",
    }
    missing = sorted(expected - team_required)
    if missing:
        raise SystemExit(f"{path.name} agent_team_review missing required fields: {missing}")
    digest = team_review.get("properties", {}).get("reviewed_bundle_digest", {})
    if digest.get("pattern") != "^sha256:[0-9a-f]{64}$":
        raise SystemExit(f"{path.name} reviewed_bundle_digest must be a sha256 digest")
    verdict = team_review["properties"]["reviewer_verdicts"]["items"]
    verdict_required = set(verdict.get("required", []))
    if "reviewed_bundle_digest" not in verdict_required:
        raise SystemExit(f"{path.name} reviewer_verdicts items must require reviewed_bundle_digest")
    reviewer_digest = verdict.get("properties", {}).get("reviewed_bundle_digest", {})
    if reviewer_digest.get("pattern") != "^sha256:[0-9a-f]{64}$":
        raise SystemExit(f"{path.name} reviewer reviewed_bundle_digest must be a sha256 digest")
PY
}

prepare_workspace() {
  local workspace
  workspace="$(mktemp -d "$TMP_DIR/workspace.XXXXXX")"
  mkdir -p "$workspace/docs"
  cp -R "$BASE_FEATURE" "$workspace/docs/sample-feature"
  printf '%s\n' "$workspace"
}

strip_agent_team_review() {
  local target="$1"
  python3 - "$target" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data.setdefault("review_conclusion", {}).pop("agent_team_review", None)
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

mutate_review_digest() {
  local target="$1"
  python3 - "$target" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
team = data["review_conclusion"]["agent_team_review"]
team["reviewed_bundle_digest"] = "sha256:" + "0" * 64
for reviewer in team["reviewer_verdicts"]:
    reviewer["reviewed_bundle_digest"] = "sha256:" + "1" * 64
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

assert_validator_blocks_summary_only() {
  local artifact="$1"
  local expected="$2"
  local delivery_flag="${3:-}"
  local stdout="$TMP_DIR/validator.stdout"
  local stderr="$TMP_DIR/validator.stderr"
  local args=(--artifact "$artifact" --require-review)

  if [ -n "$delivery_flag" ]; then
    args+=("$delivery_flag")
  fi

  if python3 "$VALIDATOR" "${args[@]}" >"$stdout" 2>"$stderr"; then
    cat "$stdout" >&2
    cat "$stderr" >&2
    fail "validator should block summary-only review closure: ${artifact#"$TMP_DIR"/}"
  fi
  grep -Eq "$expected" "$stdout" "$stderr" || {
    cat "$stdout" >&2
    cat "$stderr" >&2
    fail "validator failure should mention agent-team evidence"
  }
}

assert_agent_team_runtime_tools() {
  for skill in "$PM_SKILL" "$TEST_DESIGN_SKILL" "$DESIGN_SKILL" "$RESEARCH_SKILL"; do
    assert_present '^allowed-tools: .*TeamCreate' "$skill"
    assert_present '^allowed-tools: .*SendMessage' "$skill"
    assert_present '^allowed-tools: .*TeamDelete' "$skill"
  done
  assert_present 'agent_team_review' "$PM_REVIEW"
  assert_present 'Owner Self-Check|owner 自检|自检后.*送审' "$PM_SKILL"
  assert_present 'reviewed_bundle_digest' "$PM_SKILL"
  assert_present 'reviewed_bundle_digest' "$PM_REVIEW"
  assert_absent '同一批冻结 JSON|上下文草稿|context 草稿' "$PM_SKILL"
  assert_absent '同一批冻结 JSON|上下文草稿|context 草稿' "$PM_REVIEW"
}

assert_schema_requires_agent_team_review

workspace="$(prepare_workspace)"
strip_agent_team_review "$workspace/docs/sample-feature/brief.json"
strip_agent_team_review "$workspace/docs/sample-feature/phase-1/phase-prd.json"

assert_validator_blocks_summary_only \
  "$workspace/docs/sample-feature/brief.json" \
  'review_conclusion\.agent_team_review' \
  '--require-delivery'
assert_validator_blocks_summary_only \
  "$workspace/docs/sample-feature/phase-1/phase-prd.json" \
  'review_conclusion\.agent_team_review'

workspace="$(prepare_workspace)"
mutate_review_digest "$workspace/docs/sample-feature/brief.json"
mutate_review_digest "$workspace/docs/sample-feature/phase-1/phase-prd.json"

assert_validator_blocks_summary_only \
  "$workspace/docs/sample-feature/brief.json" \
  'reviewed_bundle_digest|digest' \
  '--require-delivery'
assert_validator_blocks_summary_only \
  "$workspace/docs/sample-feature/phase-1/phase-prd.json" \
  'reviewed_bundle_digest|digest'

assert_agent_team_runtime_tools

printf '[PASS] product review agent-team evidence contract\n'
