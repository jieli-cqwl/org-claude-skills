# Install-Layer Manual-Only Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 在安装层集中维护低频 skill 的 manual-only 策略，并让 Claude/Codex 运行面对同一组 skill 呈现一致的可见性行为。

**Architecture:** 继续使用 `install.sh` 作为运行时装配真源，在安装过程中为目标 skill 注入 `disable-model-invocation: true`，并在 Codex 侧同步裁掉 `agents/openai.yaml`。实现不修改 vendored `SKILL.md`，只扩展 manual-only 列表与对应测试断言，保留 `webapp-testing` 自动可见。

**Tech Stack:** Bash install pipeline, embedded Python frontmatter rewrite in `install.sh`, shell contract tests.

---

### Task 1: Add failing assertions for install-layer manual-only visibility [T1]

Context: 先把目标行为写成失败测试，锁定“低频 skill 通过安装层变成 manual-only，webapp-testing 保持自动可见”的边界。测试必须只检查运行时装配结果，不要求修改 vendored 正文。

Files:
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Test: `tests/test-single-source-layout.sh`
- Test: `tests/test-runtime-integrity.sh`

1. [T1] Add source-layout assertions for install-layer manual-only governance

```bash
for skill in ai-cli-updater h5 skill-auditor; do
  test -f "$ROOT/shared/skills/$skill/SKILL.md" || fail "missing shared skill source: $skill"
done
for skill in algorithmic-art brand-guidelines canvas-design doc-coauthoring docx internal-comms mcp-builder pdf pptx slack-gif-creator theme-factory web-artifacts-builder xlsx; do
  test -f "$ROOT/community/anthropic/skills/$skill/SKILL.md" || fail "missing Anthropic skill source: $skill"
done
for skill in agent-browser; do
  test -f "$ROOT/community/vercel/skills/$skill/SKILL.md" || fail "missing Vercel skill source: $skill"
done
test -f "$ROOT/community/alchaincyf/skills/darwin-skill/SKILL.md" || fail "missing Alchaincyf skill source: darwin-skill"
test -f "$ROOT/shared/skills/refactor/SKILL.md" || fail "missing shared skill source: refactor"
test -f "$ROOT/shared/skills/research/SKILL.md" || fail "missing shared skill source: research"
test -f "$ROOT/community/anthropic/skills/webapp-testing/SKILL.md" || fail "missing Anthropic skill source: webapp-testing"
```

2. [T1] Add runtime-integrity assertions that should fail before the install change

```bash
for skill in ai-cli-updater h5 skill-auditor algorithmic-art brand-guidelines canvas-design darwin-skill doc-coauthoring docx internal-comms mcp-builder pdf pptx slack-gif-creator theme-factory web-artifacts-builder xlsx agent-browser; do
  grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/$skill/SKILL.md" || fail "$skill should be manual-only in claude runtime"
  test ! -f "$TMP_HOME/.codex/skills/$skill/agents/openai.yaml" || fail "$skill should be manual-only in codex runtime"
done
test -f "$TMP_HOME/.claude/skills/webapp-testing/SKILL.md" || fail "missing ~/.claude/skills/webapp-testing/SKILL.md"
if grep -Fq 'disable-model-invocation: true' "$TMP_HOME/.claude/skills/webapp-testing/SKILL.md"; then
  fail "webapp-testing should remain auto-visible in claude runtime"
fi
test -f "$TMP_HOME/.codex/skills/webapp-testing/agents/openai.yaml" || fail "webapp-testing should remain auto-visible in codex runtime"
```

3. [T1] Run source-layout test to confirm existing source invariants still pass

Run: `bash tests/test-single-source-layout.sh`
Expected: PASS, because the source tree remains unchanged and vendored SKILL.md are not modified.

4. [T1] Run runtime-integrity test to confirm the new runtime assertions fail before implementation

Run: `bash tests/test-runtime-integrity.sh`
Expected: FAIL on the first newly asserted low-frequency skill because install-time manual-only handling has not been extended yet.

### Task 2: Implement install.sh manual-only maintenance for low-frequency skills [T2]

Context: 安装层是唯一真源。这里要扩展 manual-only 列表与消费逻辑，让 Claude 和 Codex 使用同一组低频 skill 清单；`webapp-testing` 必须继续留在 auto-visible 路径里。

Files:
- Modify: `install.sh`
- Test: `tests/test-runtime-integrity.sh`

1. [T2] Add a low-frequency manual-only skill list to install.sh

```bash
low_frequency_manual_only_skills() {
  printf '%s\n' \
    "ai-cli-updater" \
    "h5" \
    "skill-auditor" \
    "algorithmic-art" \
    "brand-guidelines" \
    "canvas-design" \
    "darwin-skill" \
    "doc-coauthoring" \
    "docx" \
    "internal-comms" \
    "mcp-builder" \
    "pdf" \
    "pptx" \
    "slack-gif-creator" \
    "theme-factory" \
    "web-artifacts-builder" \
    "xlsx" \
    "agent-browser"
}
```

2. [T2] Merge the low-frequency list into Claude visibility rewriting

```bash
ORG_LOW_FREQUENCY_MANUAL_ONLY="$(low_frequency_manual_only_skills | paste -sd, -)" \
python3 <<'PY'
import os

skills_dir = os.environ["ORG_SKILLS_DIR"]
local_manual_only = {item for item in os.environ.get("ORG_LOCAL_MANUAL_ONLY", "").split(",") if item}
community_manual_only = {item for item in os.environ.get("ORG_COMMUNITY_MANUAL_ONLY", "").split(",") if item}
low_frequency_manual_only = {item for item in os.environ.get("ORG_LOW_FREQUENCY_MANUAL_ONLY", "").split(",") if item}
community_auto = {item for item in os.environ.get("ORG_COMMUNITY_AUTO", "").split(",") if item}
manual_only = local_manual_only | community_manual_only | low_frequency_manual_only
community_skills = community_manual_only | community_auto | low_frequency_manual_only
PY
```

3. [T2] Extend Codex manual-only pruning to the same low-frequency list

```bash
while IFS= read -r skill; do
  [ -n "$skill" ] || continue
  rm -f "$skills_dir/$skill/agents/openai.yaml"
  rmdir "$skills_dir/$skill/agents" 2>/dev/null || true
done < <(
  {
    local_manual_only_skills
    low_frequency_manual_only_skills
  } | awk 'NF && !seen[$0]++'
)
```

4. [T2] Re-run runtime-integrity to verify the implementation turns GREEN

Run: `bash tests/test-runtime-integrity.sh`
Expected: PASS, with all target low-frequency skills manual-only in Claude runtime and without `agents/openai.yaml` in Codex runtime, while `webapp-testing` still keeps its adapter.

### Task 3: Prove runtime behavior and formatting hygiene [T3]

Context: 最后要用 fresh proving commands 证明 source invariants、runtime behavior、small-chain 文档一致性与 diff 格式都成立，避免只靠局部观察结束任务。

Files:
- Test: `tests/test-single-source-layout.sh`
- Test: `tests/test-runtime-integrity.sh`
- Test: `docs/feature--skill-runtime--manual-only-visibility/2026-04-18-install-layer-manual-only/tasks.md`
- Test: `docs/feature--skill-runtime--manual-only-visibility/2026-04-18-install-layer-manual-only/plan.md`

1. [T3] Run source-layout proving command

Run: `bash tests/test-single-source-layout.sh`
Expected: PASS with `[PASS] single-source layout`.

2. [T3] Run runtime-integrity proving command

Run: `bash tests/test-runtime-integrity.sh`
Expected: PASS without missing manual-only or auto-visible runtime assertion failures.

3. [T3] Run task-plan consistency checker

Run: `python3 tools/community/check_task_plan_consistency.py docs/feature--skill-runtime--manual-only-visibility/2026-04-18-install-layer-manual-only/tasks.md docs/feature--skill-runtime--manual-only-visibility/2026-04-18-install-layer-manual-only/plan.md`
Expected: PASS with no missing task mappings, trace gaps, or dependency errors.

4. [T3] Run whitespace and patch formatting check

Run: `git diff --check`
Expected: no output.
