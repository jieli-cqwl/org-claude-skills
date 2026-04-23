#!/usr/bin/env bash
# shellcheck disable=SC2016
# 文件职责：验证 standard-chain 全链路 skill 不再依赖集中式 Canonical Runtime Contract 或单独权限板块。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/docs/standard-chain-skill-structure-20260421/structure-decision.md"
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

flow_candidates = ["## 流程", "## 固定主流程"]
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

read_standard_chain_skills() {
  awk '
    /^  - name: / { name=$3 }
    /position: main/ { print name }
  ' "$CHAIN"
}

test -f "$DOC" || fail "missing structure decision doc: $DOC"
test -f "$CHAIN" || fail "missing standard-chain contract: $CHAIN"

assert_present 'Standard-Chain Skill Structure Decision' "$DOC"
assert_present '覆盖 `shared/skills` 标准流程' "$DOC"
assert_present '运行时权限由 frontmatter `allowed-tools`' "$DOC"
assert_present '不得新增单独运行时权限板块' "$DOC"
assert_present '禁止语义' "$DOC"
assert_present '允许表达变化' "$DOC"
assert_present '全链路门禁' "$DOC"

STANDARD_CHAIN_SKILLS=()
while IFS= read -r skill; do
  STANDARD_CHAIN_SKILLS+=("$skill")
done < <(read_standard_chain_skills)

[ "${#STANDARD_CHAIN_SKILLS[@]}" -eq 10 ] || fail "expected 10 standard-chain main skills, got ${#STANDARD_CHAIN_SKILLS[@]}: ${STANDARD_CHAIN_SKILLS[*]}"

OLD_RUNTIME_HEADING='^## Runtime '"Authority"'$'
for skill in "${STANDARD_CHAIN_SKILLS[@]}"; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  test -f "$skill_file" || fail "missing standard-chain skill: $skill_file"

  assert_present '^allowed-tools: ' "$skill_file"
  assert_absent '^## Canonical Runtime Contract$|^## Standard-Chain Canonical Lane$' "$skill_file"
  assert_absent "$OLD_RUNTIME_HEADING" "$skill_file"
  assert_absent '^合同模板：$|^运行时输入：$|^运行时输出：$|^完成前必须运行：$' "$skill_file"
  assert_absent 'v1 catalog|产品域|角色拆分|authoritative fields|authority refs|lock sidecar|legacy projection lane|product-manager-review\.md|producer' "$skill_file"
  assert_structural_order "$skill_file"
  assert_reference_use_point_contracts "$skill_file"
done

DIRECTOR="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER="$ROOT/shared/skills/product-manager/SKILL.md"
DEVELOPER="$ROOT/shared/skills/developer/SKILL.md"

assert_present '^## 流程使用点引用$' "$DIRECTOR"
assert_present 'D-S2~D-S6.*Trigger:.*Read: .*references/product-thinking-contract.md#Product-Thinking Contract v1.*Expect:.*Consume:.*Evidence:.*Sync:' "$DIRECTOR"
assert_present 'D-S6.*Trigger:.*Read: .*references/phase-splitting-guide.md.*Expect:.*Consume:.*Evidence:.*Sync:' "$DIRECTOR"
assert_present 'references/output-contract\.md#Director-Output Contract v1' "$DIRECTOR"
assert_present 'validate_standard_chain_phase.py' "$DIRECTOR"

assert_present '^## 流程使用点引用$' "$MANAGER"
assert_present 'M-S7.*Trigger:.*Read: .*references/completeness-checklist.md.*Expect:.*Consume:.*Evidence:.*Sync:' "$MANAGER"
assert_present 'M-S8 / M-G1.*Trigger:.*Read: .*references/review-orchestration-contract.md#Review-Orchestration Contract v1.*Expect:.*Consume:.*Evidence:.*Sync:' "$MANAGER"
assert_present 'M-S9.*Trigger:.*Read: .*references/output-contract.md#Manager-Output Contract v1.*Expect:.*Consume:.*Evidence:.*Sync:' "$MANAGER"
assert_present 'references/output-contract\.md#Manager-Output Contract v1' "$MANAGER"
assert_present 'validate_standard_chain_phase.py' "$MANAGER"

assert_present 'Trigger: TDD 循环前；Read: .*references/execution-decomposition-guide.md.*Expect:.*Consume:.*Evidence:.*Sync:' "$DEVELOPER"
assert_present 'Trigger: TDD 循环完成后；Read: .*references/self-testing-methodology.md.*Expect:.*Consume:.*Evidence:.*Sync:' "$DEVELOPER"
assert_present 'Trigger: 输出 developer-report 前；Read: .*references/self-review-methodology.md.*Expect:.*Consume:.*Evidence:.*Sync:' "$DEVELOPER"
assert_present 'artifact-registry.json' "$DEVELOPER"
assert_present 'contracts/canonical/templates/runtime/developer-report.template.json' "$DEVELOPER"

printf '[PASS] standard-chain skill structure full gate\n'
