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

  assert_absent "$OLD_RUNTIME_HEADING" "$skill_file"
  assert_absent '^## Canonical Runtime Contract$|^## Standard-Chain Canonical Lane$' "$skill_file"
  assert_absent '^合同模板：$|^运行时输入：$|^运行时输出：$|^完成前必须运行：$' "$skill_file"
  assert_absent 'v1 catalog|产品域|角色拆分|authoritative fields|authority refs|lock sidecar|legacy projection lane|standard-chain lane|product-manager-review\.md|producer' "$skill_file"
  assert_structural_order "$skill_file"
  assert_reference_use_point_contracts "$skill_file"
done

DIRECTOR="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_OUTPUT_CONTRACT="$ROOT/shared/skills/product-director/references/output-contract.md"
MANAGER="$ROOT/shared/skills/product-manager/SKILL.md"
DEVELOPER="$ROOT/shared/skills/developer/SKILL.md"

assert_absent '^## 按需 references$' "$DIRECTOR"
assert_absent '^## 流程导航$' "$DIRECTOR"
assert_absent '按需读取' "$DIRECTOR"
assert_present 'D-S2.*references/conversation-guide\.md.*references/product-thinking-contract\.md|references/conversation-guide\.md.*references/product-thinking-contract\.md' "$DIRECTOR"
assert_present 'D-S3.*references/product-thinking-contract\.md|references/product-thinking-contract\.md.*价值假设.*Appetite' "$DIRECTOR"
assert_present 'D-S6.*references/phase-splitting-guide\.md|references/phase-splitting-guide\.md.*Phase' "$DIRECTOR"
assert_absent 'D-S2~D-S6.*Trigger:|D-S6.*Trigger:|D-G1 输出收口.*Trigger:' "$DIRECTOR"
assert_present 'references/output-contract\.md#Director-Output Contract v1' "$DIRECTOR"
assert_present 'D-G1 使用 Bash 执行 Director canonical schema gate' "$DIRECTOR"
assert_present 'validate_canonical_schema.py' "$DIRECTOR_OUTPUT_CONTRACT"
assert_absent 'validate_standard_chain_phase.py' "$DIRECTOR_OUTPUT_CONTRACT"

assert_present '^## 流程使用点引用$' "$MANAGER"
assert_present 'M-S7.*Trigger:.*Read: .*references/completeness-checklist.md.*Expect:.*Consume:.*Evidence:.*Sync:' "$MANAGER"
assert_present 'M-S8 / M-G1.*Trigger:.*Read: .*references/review-orchestration-contract.md#Review-Orchestration Contract v1.*Expect:.*Consume:.*Evidence:.*Sync:' "$MANAGER"
assert_present 'M-S9.*Trigger:.*Read: .*references/output-contract.md#Manager-Output Contract v1.*Expect:.*Consume:.*Evidence:.*Sync:' "$MANAGER"
assert_present 'references/output-contract\.md#Manager-Output Contract v1' "$MANAGER"
assert_present 'validate_standard_chain_phase.py' "$MANAGER"
assert_present 'validate_product_closure.py' "$MANAGER"
assert_present '当前验证命令|证明命令' "$MANAGER"
python3 - "$MANAGER" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
runtime_line = next((line for line in text.splitlines() if "Bash 只用于只读验证" in line), "")
if "validate_standard_chain_phase.py" not in runtime_line or "validate_product_closure.py" not in runtime_line:
    raise SystemExit("manager Bash boundary must list both PM fresh proving commands")
PY
assert_absent 'product-manager/scripts/completion_check\.sh|hook payload' "$MANAGER"

assert_present '按需读取 .*references/execution-decomposition-guide.md.*mini-plan.*复用判断.*步骤规划.*风险标注' "$DEVELOPER"
assert_present '按需读取 .*references/self-testing-methodology.md.*覆盖缺口.*验证层面.*不适用理由' "$DEVELOPER"
assert_present '按需读取 .*references/self-review-methodology.md.*AC.*TDD.*自测.*范围.*代码规范.*报告完整性' "$DEVELOPER"
assert_present 'digraph developer_flow' "$DEVELOPER"
assert_absent 'Trigger: TDD 循环前|Trigger: TDD 循环完成后|Trigger: 输出 developer-report 前' "$DEVELOPER"
assert_absent 'artifact-registry.json.*只用于理解 AC|存在性、active 状态和引用解析由前置脚本或 gate 判定' "$DEVELOPER"
assert_present 'shared/skills/developer/templates/developer-report.template.json' "$DEVELOPER"

printf '[PASS] standard-chain skill structure full gate\n'
