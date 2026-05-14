#!/usr/bin/env bash
# 文件职责：验证 active developer 回到 TDD 实现职责，不承载 runtime-layering 治理正文。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/developer/SKILL.md"
REVIEW="$ROOT/shared/skills/developer/evals/lifecycle-review.json"
DECOMP="$ROOT/shared/skills/developer/references/execution-decomposition-guide.md"
SELF_TEST="$ROOT/shared/skills/developer/references/self-testing-methodology.md"
SELF_REVIEW="$ROOT/shared/skills/developer/references/self-review-methodology.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  test -f "$1" || fail "missing file: ${1#"$ROOT"/}"
}

assert_developer_skill_contract() {
  python3 - "$SKILL" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

headings = set(re.findall(r"^##\s+(.+)$", text, flags=re.M))
required_headings = {"HARD-GATE", "角色", "输入识别", "流程", "输出", "常见暗坑", "完成校验"}
missing_headings = sorted(required_headings - headings)
if missing_headings:
    raise SystemExit(f"developer skill missing active TDD sections: {', '.join(missing_headings)}")

forbidden_headings = {
    "Runtime Layering Contract",
    "工具边界",
    "前置条件",
    "流程合规输出合同",
    "失败路由合同",
}
found_forbidden_headings = sorted(forbidden_headings & headings)
if found_forbidden_headings:
    raise SystemExit(f"developer skill still carries runtime-governance sections: {', '.join(found_forbidden_headings)}")

required_concepts = {
    "input_boundary": ["Task", "AC", "Scope", "Report target"],
    "tdd_loop": ["RED", "GREEN", "REFACTOR"],
    "scope_discipline": ["forbidden_scope", "范围外变更"],
    "report_evidence": ["developer-report.json", "RED/GREEN/REFACTOR 证据"],
    "self_testing": ["self-testing", "目标测试", "相关回归"],
}
missing_concepts = [
    name for name, terms in required_concepts.items() if not all(term in text for term in terms)
]
if missing_concepts:
    raise SystemExit(f"developer skill missing active execution contract concepts: {', '.join(missing_concepts)}")

forbidden_concepts = {
    "hook_gate_ownership": [
        "shared/skills/developer/scripts/completion_check.sh",
        "shared/hooks/registry.json",
        "completion gate",
        "hook payload",
    ],
    "runtime_layering_authority": [
        "Runtime Inputs And Authority",
        "scope registry",
        "worklog.md",
        "canonical: active refs",
        "确定性 preflight",
    ],
    "reference_contract_metadata": ["Trigger:", "Read:", "Expect:", "Consume:", "Evidence:", "Sync:"],
    "template_projection_ownership": ["projections/developer-report-template.md"],
}
violations = [
    name
    for name, terms in forbidden_concepts.items()
    if any(term in text for term in terms)
]
if violations:
    raise SystemExit(f"developer skill still contains non-owner governance content: {', '.join(violations)}")
PY
}

assert_developer_references_contract() {
  python3 - "$DECOMP" "$SELF_TEST" "$SELF_REVIEW" <<'PY'
import sys
from pathlib import Path

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    text = path.read_text(encoding="utf-8")
    forbidden_metadata = [
        "引用者：",
        "Trigger:",
        "Triggered by",
        "Read:",
        "Expect:",
        "Consume:",
        "Consumer",
        "Evidence:",
        "Sync:",
    ]
    present = [term for term in forbidden_metadata if term in text]
    if present:
        raise SystemExit(f"{path}: reference still carries routing metadata: {', '.join(present)}")

exploration_text = Path(sys.argv[1]).read_text(encoding="utf-8")
legacy_exploration_noise = ["### 主动探索", "`ls`", "Grep 搜索"]
present_noise = [term for term in legacy_exploration_noise if term in exploration_text]
if present_noise:
    raise SystemExit(f"{sys.argv[1]}: decomposition guide still carries tool-specific exploration noise: {', '.join(present_noise)}")
PY
}

for file in "$SKILL" "$REVIEW" "$DECOMP" "$SELF_TEST" "$SELF_REVIEW"; do
  assert_file "$file"
done

assert_developer_skill_contract
assert_developer_references_contract

python3 - "$REVIEW" <<'PY'
import json
import sys
from pathlib import Path

review = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
rationale = review.get("existence_rationale")
if not isinstance(rationale, dict):
    raise SystemExit("developer effectiveness review missing existence_rationale")
if rationale.get("primary_value") != "task_execution_tdd_report_evidence":
    raise SystemExit("developer primary_value must be task_execution_tdd_report_evidence")
if rationale.get("capability_uplift") != "pending_redesign_eval":
    raise SystemExit("developer capability_uplift must be pending_redesign_eval after rebuild")
PY

printf '[PASS] developer process compliance contract\n'
