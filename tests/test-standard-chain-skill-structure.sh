#!/usr/bin/env bash
# shellcheck disable=SC2016
# 文件职责：验证 standard-chain 全链路 skill 不再依赖集中式 Canonical Runtime Contract 或单独运行时权限板块。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

DOC="$ROOT/tests/fixtures/standard-chain-skill-structure-20260421/structure-decision.md"
CHAIN="$ROOT/contracts/standard-chain.yaml"

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
  if rg -n "$pattern" "$file" >/tmp/t6_structure_absent.out 2>&1; then
    cat /tmp/t6_structure_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_structural_order() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
headings = {}
for idx, line in enumerate(lines, start=1):
    if line.startswith("## ") and line not in headings:
        headings[line] = idx

def need(name: str) -> int:
    if name not in headings:
        raise SystemExit(f"{path}: missing section {name}")
    return headings[name]

hard_gate = need("## HARD-GATE")
completion = need("## 完成校验")

role = headings.get("## 角色")
if role is not None and role <= hard_gate:
    raise SystemExit(f"{path}: 角色 must come after HARD-GATE")

for flexible in ("## Red Flags", "## 前置条件", "## Scope 参数", "## Scope", "## 运行边界", "## 何时停下来问"):
    if role is not None and flexible in headings and headings[flexible] <= role:
        raise SystemExit(f"{path}: {flexible} must not appear before 角色")

flow_candidates = ["## 流程", "## 固定主流程", "## 流程细节"]
flow_lines = [headings[name] for name in flow_candidates if name in headings]
anchor = role if role is not None else hard_gate
if flow_lines and min(flow_lines) <= anchor:
    raise SystemExit(f"{path}: flow must come after role or HARD-GATE")

output_lines = [headings[name] for name in ("## 输出", "## 输出格式") if name in headings]
if not output_lines:
    raise SystemExit(f"{path}: missing output section")
if min(output_lines) >= completion:
    raise SystemExit(f"{path}: output section must come before completion check")
PY
}

assert_reference_use_point_contracts() {
  local file="$1"
  python3 - "$file" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
skill_dir = path.parent
labels = ["Trigger", "Read", "Expect", "Consume", "Evidence", "Sync"]
for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
    if "Trigger:" not in line:
        continue
    missing = [label for label in labels if f"{label}:" not in line]
    if missing:
        raise SystemExit(f"{path}:{line_no}: incomplete use-point reference contract, missing {missing}")
    for token in re.findall(r"`([^`]+)`", line):
        if not token.startswith("references/"):
            continue
        ref_path = token.split("#", 1)[0]
        if not (skill_dir / ref_path).is_file():
            raise SystemExit(f"{path}:{line_no}: missing referenced file {ref_path}")
PY
}

assert_retired_runtime_lane_absent() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
retired_terms = {
    "legacy_runtime_lane": [
        "v1 catalog",
        "authoritative fields",
        "authority refs",
        "lock sidecar",
        "legacy projection lane",
        "standard-chain lane",
        "producer 口头解释",
    ],
    "retired_product_review_lane": ["product-manager-review.md"],
}
violations = [name for name, terms in retired_terms.items() if any(term in text for term in terms)]
if violations:
    raise SystemExit(f"{path}: retired runtime lane content remains: {', '.join(violations)}")
PY
}

read_standard_chain_skills() {
  awk '
    /^  - name: / { name=$3 }
    /position: main/ { print name }
  ' "$CHAIN"
}

test -f "$DOC" || fail "missing structure decision doc: $DOC"
test -f "$CHAIN" || fail "missing standard-chain contract: $CHAIN"

STANDARD_CHAIN_SKILLS=()
while IFS= read -r skill; do
  STANDARD_CHAIN_SKILLS+=("$skill")
done < <(read_standard_chain_skills)

[ "${#STANDARD_CHAIN_SKILLS[@]}" -eq 10 ] || fail "expected 10 standard-chain main skills, got ${#STANDARD_CHAIN_SKILLS[@]}: ${STANDARD_CHAIN_SKILLS[*]}"

OLD_RUNTIME_HEADING='^## Runtime '"Authority"'$'
for skill in "${STANDARD_CHAIN_SKILLS[@]}"; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  test -f "$skill_file" || fail "missing standard-chain skill: $skill_file"

  assert_absent "$OLD_RUNTIME_HEADING" "$skill_file"
  assert_absent '^合同模板：$|^运行时输入：$|^运行时输出：$|^完成前必须运行：$' "$skill_file"
  assert_structural_order "$skill_file"
  assert_reference_use_point_contracts "$skill_file"
  assert_retired_runtime_lane_absent "$skill_file"
done

DIRECTOR="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_OUTPUT_REFERENCE="$ROOT/shared/skills/product-director/references/output.md"
MANAGER="$ROOT/shared/skills/product-manager/SKILL.md"
DEVELOPER="$ROOT/shared/skills/developer/SKILL.md"

assert_present 'references/evidence-map\.md' "$DIRECTOR"
assert_present 'references/root-problem\.md' "$DIRECTOR"
assert_present 'references/success-investment\.md' "$DIRECTOR"
assert_present 'references/scope-minimum-loop\.md' "$DIRECTOR"
assert_present 'references/risk-phase\.md' "$DIRECTOR"
assert_present 'references/freeze-handoff\.md' "$DIRECTOR"
assert_absent '只提取' "$DIRECTOR"
assert_present '`references/output\.md`' "$DIRECTOR"
assert_absent 'references/output\.md#' "$DIRECTOR"
assert_present 'bash shared/skills/product-director/scripts/completion_check\.sh' "$DIRECTOR"
assert_present 'validate_canonical_schema.py' "$DIRECTOR_OUTPUT_REFERENCE"
assert_absent 'validate_standard_chain_phase.py' "$DIRECTOR_OUTPUT_REFERENCE"

assert_absent '^运行边界：$' "$MANAGER"
assert_present 'M-S0.*preflight_check\.sh --brief "\$BRIEF_JSON" --phase-prd "\$PHASE_PRD_JSON"|preflight_check\.sh --brief "\$BRIEF_JSON" --phase-prd "\$PHASE_PRD_JSON".*M-S0' "$MANAGER"
assert_present '验证关键业务假设.*references/conversation-guide\.md|references/conversation-guide\.md.*每轮回应结构' "$MANAGER"
assert_absent '只提取' "$MANAGER"
assert_present 'M-S1.*references/business-flow-refinement\.md|references/business-flow-refinement\.md.*M-S1' "$MANAGER"
assert_present 'M-S2.*references/business-flow-refinement\.md|references/business-flow-refinement\.md.*M-S2' "$MANAGER"
assert_present 'M-S3.*references/business-flow-refinement\.md|references/business-flow-refinement\.md.*M-S3' "$MANAGER"
assert_present 'M-S4.*references/closed-loop-unit-spec\.md|references/closed-loop-unit-spec\.md.*M-S4' "$MANAGER"
assert_present 'M-S6.*references/design-handoff-decisions\.md|references/design-handoff-decisions\.md.*M-S6' "$MANAGER"
assert_present 'M-S7.*references/completeness-checklist\.md|references/completeness-checklist\.md.*M-S7' "$MANAGER"
assert_present 'M-S8.*references/review-orchestration\.md|references/review-orchestration\.md.*M-S8' "$MANAGER"
assert_present 'M-S9.*references/output\.md|references/output\.md.*M-S9' "$MANAGER"
assert_present 'references/output\.md' "$MANAGER"
assert_absent 'references/(review-orchestration|output)\.md#|references/[^`[:space:]]+-contract\.md' "$MANAGER"
assert_present 'validate_standard_chain_phase.py' "$MANAGER"
assert_present 'validate_product_closure.py' "$MANAGER"
assert_present 'PM handoff gate 命令' "$MANAGER"
assert_absent 'product-manager/scripts/completion_check\.sh|hook payload' "$MANAGER"

assert_present 'digraph developer_flow' "$DEVELOPER"
assert_absent 'artifact-registry.json.*只用于理解 AC|存在性、active 状态和引用解析由前置脚本或 gate 判定' "$DEVELOPER"
assert_present 'shared/skills/developer/templates/developer-report.template.json' "$DEVELOPER"

printf '[PASS] standard-chain skill structure full gate\n'
