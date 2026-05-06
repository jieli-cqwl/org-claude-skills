#!/usr/bin/env bash
set -euo pipefail

# File responsibility: prove github-repo-radar keeps evidence-backed
# repository radar behavior without adding unconsumed runtime artifacts.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/github-repo-radar/SKILL.md"
RUBRIC="$ROOT/shared/skills/github-repo-radar/references/evaluation-rubric.md"
EVALS="$ROOT/shared/skills/github-repo-radar/evals/evals.json"
ADAPTER="$ROOT/shared/skills/github-repo-radar/agents/openai.yaml"
RUN_ALL="$ROOT/tests/run-all.sh"

fail() {
  printf '[github-repo-radar-contract][FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  local label="$3"

  grep -Eq "$pattern" "$file" || fail "$label missing pattern: $pattern"
}

assert_not_present() {
  local pattern="$1"
  local file="$2"
  local label="$3"

  ! grep -Eq "$pattern" "$file" || fail "$label should not contain pattern: $pattern"
}

assert_absent_path() {
  local path="$1"
  local label="$2"

  [ ! -e "$path" ] || fail "$label should not exist: $path"
}

test -f "$SKILL" || fail "missing SKILL.md"
test -f "$RUBRIC" || fail "missing evaluation rubric"
test -f "$EVALS" || fail "missing evals.json"
test -f "$ADAPTER" || fail "missing Codex adapter"

assert_present '^allowed-tools: .*WebSearch.*WebFetch.*AskUserQuestion' "$SKILL" "Skill current-evidence tools"
assert_present '^allowed-tools: .*Read.*Write' "$SKILL" "Skill report IO tools"
assert_present '证据计划|Evidence Plan' "$SKILL" "Skill flow"
assert_present '来源类别|source class|source_type' "$SKILL" "Skill evidence source classes"
assert_present '抓取日期|crawl date|crawled_at' "$SKILL" "Skill crawl date"
assert_present '证据缺口|evidence gap|降级原因|downgrade reason' "$SKILL" "Skill evidence gap or downgrade"
assert_present '不得.*adopt|不得.*采用|downgrade.*adopt|降级.*adopt' "$SKILL" "Skill adoption downgrade gate"
assert_present 'research|deep-research|security|scan|overview|法律|legal|最终审批|final approval' "$SKILL" "Skill adjacent routing"
assert_present 'source class|来源类别|抓取日期|crawl date|证据缺口|evidence gap' "$RUBRIC" "Rubric evidence contract"
assert_present '正式选型|受控试用|controlled validation|not final approval|不是最终' "$SKILL" "Adopt is not final approval"
assert_present 'evidence-backed action|证据.*动作状态|action states with evidence' "$ADAPTER" "Adapter responsibility wording"
assert_not_present '好项目|consumer|acceptance|failure_state|proof|合同清晰|质量标准|审稿|S[1-8]|G[0-2]|E[1-5]' "$SKILL" "Skill user-facing noise"
assert_not_present 'consumer|acceptance|failure_state|proof|合同清晰|质量标准|审稿|S[1-8]|G[0-2]|E[1-5]' "$RUBRIC" "Rubric user-facing noise"

assert_absent_path "$ROOT/shared/skills/github-repo-radar/schemas" "unconsumed schemas"
assert_absent_path "$ROOT/shared/skills/github-repo-radar/templates" "unconsumed templates"
assert_absent_path "$ROOT/shared/skills/github-repo-radar/scripts" "unconsumed scripts"

python3 - "$EVALS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
assert data.get("skill_name") == "github-repo-radar", "skill_name mismatch"
evals = data.get("evals")
assert isinstance(evals, list) and len(evals) >= 7, "expected at least 7 evals"
ids = [item.get("id") for item in evals]
assert len(ids) == len(set(ids)), "eval ids must be unique"
for item in evals:
    assert isinstance(item.get("prompt"), str) and item["prompt"].strip(), "prompt required"
    assert isinstance(item.get("expected_output"), str) and item["expected_output"].strip(), "expected_output required"
    assert isinstance(item.get("files"), list), "files must be a list"

text = "\n".join(item["prompt"] + "\n" + item["expected_output"] for item in evals)
required = [
    ("source class", ["来源类别", "source class", "source_type"]),
    ("crawl date", ["抓取日期", "crawl date", "crawled_at"]),
    ("evidence gap", ["证据缺口", "evidence gap", "降级原因", "downgrade reason"]),
    ("missing scenario", ["目标场景不清", "缺少目标场景", "先确认目标场景"]),
    ("scorecard-only negative", ["Scorecard-only", "Scorecard 单点", "Scorecard 总分"]),
    ("anti-trigger", ["security", "安全扫描", "$security", "转交 security"]),
    ("adopt downgrade", ["不得直接 adopt", "不得 adopt", "降级为 watch", "降级为 trial"]),
]
for label, options in required:
    assert any(option in text for option in options), f"missing eval coverage: {label}"
PY

assert_present 'tests/test-github-repo-radar-contract\.sh' "$RUN_ALL" "run-all registration"

printf 'github-repo-radar contract ok\n'
