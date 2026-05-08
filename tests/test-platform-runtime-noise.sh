#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
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

mkdir -p "$TMP_HOME/.claude" "$TMP_HOME/.codex"
cat > "$TMP_HOME/.claude/settings.json" <<'JSON'
{"hooks":{}}
JSON
cat > "$TMP_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"
TOML

run_with_fake_openspec "$TMP_HOME" env HOME="$TMP_HOME" ORG_STATE_ROOT="$STATE_ROOT" ORG_SKIP_CONTRACT_VALIDATION=1 bash "$ROOT/install.sh" --target all --force --check quick >/tmp/org_platform_noise_install.out 2>&1 || {
  cat /tmp/org_platform_noise_install.out >&2
  fail "install failed"
}

grep -Fxq '# CLAUDE.md' "$TMP_HOME/.claude/CLAUDE.md" || fail "claude entry doc title should be # CLAUDE.md"
grep -Fxq '# AGENTS.md' "$TMP_HOME/.codex/AGENTS.md" || fail "codex entry doc title should be # AGENTS.md"

if rg -n \
  -e '^# CLAUDE\.md$' \
  -e 'Claude Code Skill 创建与改进' \
  -e 'Claude 工作时需要查阅' \
  -e 'description 被注入 system prompt 后由 Claude 读取' \
  -e '过时文档隔离（Claude 不参考）' \
  "$TMP_HOME/.codex/AGENTS.md" \
  "$TMP_HOME/.codex/skills" \
  "$TMP_HOME/.codex/reference" \
  "$TMP_HOME/.codex/agents" >/tmp/org_platform_noise_rg.out 2>&1; then
  cat /tmp/org_platform_noise_rg.out >&2
  fail "codex runtime still contains claude-only noise"
fi

python3 - "$ROOT" "$TMP_HOME/.codex/skills" <<'PY' || fail "codex skill description budget exceeded"
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skills_dir = Path(sys.argv[2])
max_total_chars = 10000
max_single_chars = 220
max_first_party_source_chars = 180
official_superpowers = {
    "brainstorming",
    "dispatching-parallel-agents",
    "executing-plans",
    "finishing-a-development-branch",
    "receiving-code-review",
    "requesting-code-review",
    "subagent-driven-development",
    "systematic-debugging",
    "test-driven-development",
    "using-git-worktrees",
    "using-superpowers",
    "verification-before-completion",
    "writing-plans",
    "writing-skills",
}


def frontmatter(text: str) -> str | None:
    if not text.startswith("---\n"):
        return None
    parts = text.split("---\n", 2)
    if len(parts) != 3:
        return None
    return parts[1]


def description_from(front: str) -> str:
    lines = front.splitlines()
    for idx, line in enumerate(lines):
        if not line.startswith("description:"):
            continue
        value = line.split(":", 1)[1].strip()
        if value in {"|", ">"}:
            block = []
            for next_line in lines[idx + 1 :]:
                if next_line.startswith((" ", "\t")) or not next_line.strip():
                    block.append(next_line.strip())
                    continue
                break
            return " ".join(block).strip()
        return value.strip("'\"")
    return ""


rows = []
for skill_file in skills_dir.rglob("SKILL.md"):
    front = frontmatter(skill_file.read_text(encoding="utf-8"))
    if front is None:
        continue
    root_name = skill_file.relative_to(skills_dir).parts[0]
    if root_name in official_superpowers:
        continue
    description = re.sub(r"\s+", " ", description_from(front)).strip()
    rows.append((len(description), skill_file.relative_to(skills_dir).as_posix()))

total = sum(length for length, _ in rows)
too_long = [(path, length) for length, path in rows if length > max_single_chars]

if total > max_total_chars or too_long:
    print(f"total_description_chars={total} max_total={max_total_chars}", file=sys.stderr)
    for path, length in sorted(too_long, key=lambda item: item[1], reverse=True)[:20]:
        print(f"{path}: description_chars={length}", file=sys.stderr)
    raise SystemExit(1)

first_party_too_long = []
first_party_mismatches = []
for source_file in sorted((root / "shared" / "skills").glob("*/SKILL.md")):
    source_front = frontmatter(source_file.read_text(encoding="utf-8"))
    if source_front is None:
        continue

    source_description = re.sub(r"\s+", " ", description_from(source_front)).strip()
    if len(source_description) > max_first_party_source_chars:
        first_party_too_long.append(
            (source_file.relative_to(root).as_posix(), len(source_description))
        )

    runtime_file = skills_dir / source_file.relative_to(root / "shared" / "skills")
    if not runtime_file.exists():
        continue
    runtime_front = frontmatter(runtime_file.read_text(encoding="utf-8"))
    runtime_description = re.sub(r"\s+", " ", description_from(runtime_front or "")).strip()
    if runtime_description != source_description:
        first_party_mismatches.append(
            (
                source_file.relative_to(root).as_posix(),
                source_description,
                runtime_description,
            )
        )

if first_party_too_long or first_party_mismatches:
    for path, length in first_party_too_long:
        print(
            f"{path}: first-party source description_chars={length} "
            f"max={max_first_party_source_chars}",
            file=sys.stderr,
        )
    for path, source_description, runtime_description in first_party_mismatches[:20]:
        print(
            f"{path}: runtime description must match first-party source "
            f"(source={source_description!r}, runtime={runtime_description!r})",
            file=sys.stderr,
        )
    raise SystemExit(1)
PY

echo "[PASS] platform runtime noise"
