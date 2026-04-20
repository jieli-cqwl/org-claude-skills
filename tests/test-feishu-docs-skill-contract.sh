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

skill_dir="$ROOT/shared/skills/feishu-docs"
skill_file="$skill_dir/SKILL.md"

test -f "$skill_file" || fail "missing feishu-docs SKILL.md"
grep -Fq 'name: feishu-docs' "$skill_file" || fail "wrong skill name"
grep -Fq 'user-invocable: true' "$skill_file" || fail "feishu-docs must be user-invocable"
grep -Fq 'disable-model-invocation: true' "$skill_file" || fail "feishu-docs must be manual-only"
grep -Fq 'lark-cli' "$skill_file" || fail "skill must use official lark-cli"
grep -Fq 'docs +fetch' "$skill_file" || fail "skill must cover document reads"
grep -Fq 'docs +create' "$skill_file" || fail "skill must cover document creation"
grep -Fq 'docs +update' "$skill_file" || fail "skill must cover document updates"
grep -Fq '确认' "$skill_file" || fail "skill must require confirmation for writes"

for ref in auth-and-config.md document-read-playbook.md document-write-playbook.md; do
  test -f "$skill_dir/references/$ref" || fail "missing reference: $ref"
done

test -f "$skill_dir/scripts/manifest.json" || fail "missing script manifest"
test -f "$skill_dir/evals/evals.json" || fail "missing evals"
test -f "$skill_dir/agents/openai.yaml" || fail "missing Codex adapter source"

python3 -m json.tool "$skill_dir/scripts/manifest.json" >/dev/null || fail "manifest must be valid JSON"
python3 -m json.tool "$skill_dir/evals/evals.json" >/dev/null || fail "evals must be valid JSON"

if rg -n 'app_secret|tenant_access_token|user_access_token|Authorization: Bearer|cli_[a-zA-Z0-9]{20,}' "$skill_dir" >/tmp/org_feishu_docs_secret_scan.out 2>&1; then
  cat /tmp/org_feishu_docs_secret_scan.out >&2
  fail "feishu-docs source must not contain committed secrets"
fi

grep -Fq '"skill_name": "feishu-docs"' "$skill_dir/evals/evals.json" || fail "evals skill name mismatch"
grep -Fq '"read-docx-link"' "$skill_dir/evals/evals.json" || fail "missing read eval"
grep -Fq '"create-development-doc"' "$skill_dir/evals/evals.json" || fail "missing create eval"
grep -Fq '"delete-requires-confirmation"' "$skill_dir/evals/evals.json" || fail "missing delete protection eval"

echo "[PASS] feishu-docs skill contract"
