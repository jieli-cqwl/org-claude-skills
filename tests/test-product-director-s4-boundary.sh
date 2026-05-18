#!/usr/bin/env bash
set -euo pipefail

# product-director 是 standard-chain 的场景基线生产者。
# 它必须冻结 brief.json / phase-prd.json，或输出阻断/不做结论。
# 它不能充当调度器、PRD 作者、架构设计者，也不能写 PM 负责的 UNIT/AC。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_OUTPUT_REFERENCE="$ROOT/shared/skills/product-director/references/output.md"
BRIEF_SCHEMA="$ROOT/shared/skills/product-manager/contracts/brief.schema.json"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Fq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern '$pattern' in $file"
  fi
}

assert_file "$DIRECTOR_SKILL"
assert_file "$DIRECTOR_OUTPUT_REFERENCE"
assert_file "$BRIEF_SCHEMA"

assert_present "业务产品负责人" "$DIRECTOR_SKILL"
assert_present "Director 场景基线" "$DIRECTOR_SKILL"
assert_present "brief.json" "$DIRECTOR_SKILL"
assert_present "phase-prd.json" "$DIRECTOR_SKILL"
assert_present "阻断结论" "$DIRECTOR_SKILL"
assert_present "不得输出 UNIT" "$DIRECTOR_SKILL"
assert_present "不得写 AC" "$DIRECTOR_SKILL"
assert_present "建议承接方只作为恢复信息" "$DIRECTOR_SKILL"
assert_present "不是调度动作" "$DIRECTOR_SKILL"

assert_absent 'D-S[0-9]|D-G[0-9]|Handoff to|转 `/|转交|负责在下游角色介入前|产品总监确认|总监确认门|业务语义收口' "$DIRECTOR_SKILL"
assert_absent 'references/(problem-clarification|success-investment-boundary|scope-constraints|phase-planning|risks-unknowns|business-semantics|conversation-guide)\.md' "$DIRECTOR_SKILL"

assert_present "shared/skills/product-director/templates/brief.template.json" "$DIRECTOR_OUTPUT_REFERENCE"
assert_present "shared/skills/product-director/templates/phase-prd.template.json" "$DIRECTOR_OUTPUT_REFERENCE"
assert_present "director_confirmation.locked_fields" "$DIRECTOR_OUTPUT_REFERENCE"
assert_absent '产品总监输出|总监确认门 handoff|Handoff' "$DIRECTOR_OUTPUT_REFERENCE"

python3 - "$BRIEF_SCHEMA" <<'PY' || fail "brief.schema.json missing PM-owned not/anyOf ban block"
import json, sys
schema = json.load(open(sys.argv[1], encoding="utf-8"))
banned = {"business_flows", "user_paths", "rule_mappings",
          "semantic_draft", "business_semantics_draft", "semantics_gaps"}
for sub in schema.get("allOf", []):
    nb = sub.get("not", {}).get("anyOf", [])
    if nb:
        found = {req[0] for c in nb for req in [c.get("required", [])] if req}
        if banned.issubset(found):
            sys.exit(0)
sys.exit(1)
PY

echo "[PASS] product-director 场景基线边界"
