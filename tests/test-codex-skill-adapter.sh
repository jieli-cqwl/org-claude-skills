#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
STATE_ROOT="$TMP_HOME/.org-skills-state"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP_HOME/.codex"
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"
TOML

HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target codex --force --check quick >/tmp/org_codex_skill_adapter_install.out 2>&1 || {
  cat /tmp/org_codex_skill_adapter_install.out >&2
  fail "install failed"
}

[ ! -e "$TMP_HOME/.codex/skills/codex-doc-review" ] || fail "codex runtime should not install claude-only skill codex-doc-review"
[ ! -e "$TMP_HOME/.codex/agents/codex-doc-reviewer.md" ] || fail "codex runtime should not install claude-only agent codex-doc-reviewer.md"

found=0
while IFS= read -r completion_check; do
  [ -n "$completion_check" ] || continue
  found=1
  skill_dir="$(dirname "$(dirname "$completion_check")")"
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  frontmatter="$(sed -n '/^---$/,/^---$/p' "$skill_file")"

  printf '%s\n' "$frontmatter" | grep -q '^hooks:' && fail "$skill_name frontmatter should not contain hooks"
  grep -Fq "Codex 运行说明：当前 Codex 不会自动执行 \`SKILL.md\` frontmatter 中的 hooks。" "$skill_file" || fail "$skill_name missing codex runtime note"
done < <(find "$TMP_HOME/.codex/skills" -path '*/scripts/completion_check.sh' | sort)

[ "$found" -eq 1 ] || fail "expected at least one completion_check.sh in codex skills"

if rg -n 'Stop hook（`completion_check\.sh`）执行通过，无 FAIL 项' "$TMP_HOME/.codex/skills" -g 'SKILL.md' >/tmp/org_codex_skill_adapter_legacy.out 2>&1; then
  cat /tmp/org_codex_skill_adapter_legacy.out >&2
  fail "codex skills should not retain legacy Stop hook wording"
fi

echo "[PASS] codex skill adapter"
