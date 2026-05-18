#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/product-director/SKILL.md"
OUTPUT_REF="$ROOT/shared/skills/product-director/references/output.md"
EVALS="$ROOT/shared/skills/product-director/evals/evals.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Fq "$pattern" "$file" || fail "missing content in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2"
  ! grep -Fq "$pattern" "$file" || fail "unexpected content in ${file#"$ROOT"/}: $pattern"
}

assert_present "业务产品负责人" "$SKILL"
assert_absent "产品总监" "$SKILL"
assert_absent "需要进入 standard-chain" "$SKILL"
assert_absent "完成前运行" "$SKILL"

test ! -e "$ROOT/shared/skills/product-director/references/agent-teams.md" \
  || fail "agent teams must not be a global product-director reference"

assert_present "协作判断" "$SKILL"
assert_present "D-S1" "$SKILL"
assert_present "D-S5.5" "$SKILL"
assert_present "D-G1" "$SKILL"
assert_present "agent teams" "$SKILL"
assert_present "竞争假设" "$SKILL"
assert_present "分层评审" "$SKILL"
assert_present "冻结前一致性复检" "$SKILL"
assert_absent "使用 sub Agent 扫描" "$SKILL"

assert_present "## 台账写入契约" "$SKILL"
assert_present "decision_summary" "$SKILL"
assert_present "source_refs" "$SKILL"
assert_present "output_refs" "$SKILL"
assert_present "supersedes" "$SKILL"
assert_present "finalization_basis" "$SKILL"
assert_present "禁止 finalized" "$SKILL"

assert_present "hooks 运行面通过 \`product-director/scripts/completion_check.sh\` 执行同等 gate" "$OUTPUT_REF"

python3 - "$EVALS" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
eval_ids = {item["id"] for item in payload["evals"]}
required = {
    "business-product-owner-role",
    "agent-teams-stage-gated",
    "ledger-write-contract-finalization",
    "technical-scenario-baseline-boundary",
    "implementation-task-blocked",
    "defect-blocked",
    "minimum-loop-scope-control",
}
missing = sorted(required - eval_ids)
if missing:
    raise SystemExit(f"missing product-director tuning evals: {missing}")

anchor_text = "\n".join(anchor["anchor"] for anchor in payload.get("preference_anchors", []))
for term in ("业务产品负责人", "agent teams", "台账", "阻断", "最小场景闭环"):
    if term not in anchor_text:
        raise SystemExit(f"missing preference anchor term: {term}")
PY

printf '[PASS] product-director runtime tuning contract\n'
