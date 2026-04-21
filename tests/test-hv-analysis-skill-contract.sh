#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

skill_dir="$ROOT/shared/skills/hv-analysis"
skill_file="$skill_dir/SKILL.md"

test -f "$skill_file" || fail "missing hv-analysis SKILL.md"
grep -Fq 'name: hv-analysis' "$skill_file" || fail "wrong skill name"
grep -Fq 'user-invocable: true' "$skill_file" || fail "hv-analysis must be user-invocable"
grep -Fq 'disable-model-invocation: true' "$skill_file" || fail "hv-analysis must be manual-only"
grep -Fq '横纵分析法' "$skill_file" || fail "skill must name the method"
grep -Fq 'research-report.md' "$skill_file" || fail "skill must declare markdown artifact"
grep -Fq 'research-report.pdf' "$skill_file" || fail "skill must declare pdf artifact"
grep -Fq 'sources.json' "$skill_file" || fail "skill must declare source artifact"
grep -Fq 'full completion is blocked' "$skill_file" || fail "skill must block completion when required artifacts fail"

for ref in methodology.md source-policy.md arxiv-policy.md report-template.md; do
  test -f "$skill_dir/references/$ref" || fail "missing reference: $ref"
done

test -f "$skill_dir/scripts/manifest.json" || fail "missing script manifest"
test -f "$skill_dir/scripts/arxiv_search.py" || fail "missing arxiv script"
test -f "$skill_dir/scripts/render_report.py" || fail "missing pdf renderer script"
test -f "$skill_dir/evals/evals.json" || fail "missing evals"
test -f "$skill_dir/agents/openai.yaml" || fail "missing Codex adapter source"

python3 -m json.tool "$skill_dir/scripts/manifest.json" >/dev/null || fail "manifest must be valid JSON"
python3 -m json.tool "$skill_dir/evals/evals.json" >/dev/null || fail "evals must be valid JSON"

grep -Fq 'Primary sources' "$skill_dir/references/source-policy.md" || fail "source policy must define primary sources"
grep -Fq 'Community sources' "$skill_dir/references/source-policy.md" || fail "source policy must define community sources"
grep -Fq 'sample bias' "$skill_dir/references/source-policy.md" || fail "source policy must mention sample bias"
grep -Fq 'technology concepts' "$skill_dir/references/arxiv-policy.md" || fail "arxiv policy must cover technology concepts"
grep -Fq 'skip arxiv' "$skill_dir/references/arxiv-policy.md" || fail "arxiv policy must cover skip cases"
grep -Fq 'do not add weak matches' "$skill_dir/references/arxiv-policy.md" || fail "arxiv policy must reject weak matches"
grep -Fq 'Markdown is the fact source' "$skill_dir/references/report-template.md" || fail "report template must state markdown fact source"

grep -Fq '"skill_name": "hv-analysis"' "$skill_dir/evals/evals.json" || fail "evals skill name mismatch"
for eval_id in product-quickstart company-no-arxiv technology-arxiv strict-evidence pdf-render-failure; do
  grep -Fq "\"$eval_id\"" "$skill_dir/evals/evals.json" || fail "missing eval: $eval_id"
done

echo "[PASS] hv-analysis skill contract"
