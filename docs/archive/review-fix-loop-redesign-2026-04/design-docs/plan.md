# Review-Fix Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Replace the legacy `review-fix-loop` / `codex-doc-review` stack with separate `code-review-fix` and `doc-review-fix` Claude-only skills, retire the old helper-based implementation, and keep the repository’s install/runtime/test gates green.

**Architecture:** First add a contract test that describes the new skill surface and then implement the two new skill documents plus the DECEPTION knowledge base. Next switch install/runtime/layout/contract assertions to the new topology, remove the retired helper logic and obsolete tests, add a scenario test that exercises the redesign negative-path matrix, archive the old implementation under `docs/archive/`, and finish with a full suite run plus task-plan consistency verification.

**Tech Stack:** Markdown skill specs, Bash install/runtime/layout tests, shell test runner, YAML contract file, Python task-plan consistency checker

---

### Task 1: New Skill Contracts And Docs [T1]

Files:
- Create: `tests/test-review-fix-redesign-contract.sh`
- Create: `claude/skills/code-review-fix/SKILL.md`
- Create: `claude/skills/doc-review-fix/SKILL.md`
- Create: `claude/skills/doc-review-fix/references/deception-patterns.md`

1. [T1] Add failing assertions to `tests/test-review-fix-redesign-contract.sh` for the new files and the required redesign markers:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null || fail "missing pattern [$pattern] in $file"
}

test -f "$ROOT/claude/skills/code-review-fix/SKILL.md" || fail "missing claude/skills/code-review-fix/SKILL.md"
test -f "$ROOT/claude/skills/doc-review-fix/SKILL.md" || fail "missing claude/skills/doc-review-fix/SKILL.md"
test -f "$ROOT/claude/skills/doc-review-fix/references/deception-patterns.md" || fail "missing deception-patterns.md"
assert_present 'AskUserQuestion' "$ROOT/claude/skills/code-review-fix/SKILL.md"
assert_present 'baseline_ref' "$ROOT/claude/skills/code-review-fix/SKILL.md"
assert_present '禁止.*静默切换' "$ROOT/claude/skills/code-review-fix/SKILL.md"
assert_present '连续两轮零 findings' "$ROOT/claude/skills/doc-review-fix/SKILL.md"
assert_present '需用户介入' "$ROOT/claude/skills/doc-review-fix/SKILL.md"
assert_present 'DECEPTION' "$ROOT/claude/skills/doc-review-fix/references/deception-patterns.md"
```

2. [T1] Run `bash tests/test-review-fix-redesign-contract.sh`.
Expected: FAIL with missing-file or missing-pattern errors for the new skill files.
3. [T1] Write `claude/skills/code-review-fix/SKILL.md` with Claude-only frontmatter and the required controller flow:

```md
---
name: code-review-fix
user-invocable: true
description: 代码评审修复循环。Use when 需要对当前 working tree 做代码评审、修复、验证和重审直到通过或 fail-close 停止。
argument-hint: "[focus ...]"
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# /code-review-fix -- 代码评审修复循环

## HARD-GATE
- 先 AskUserQuestion 确认评审方式、focus、验证命令和收敛标准，再进入循环。
- 进入时记录 `baseline_ref`，dirty tree 用 `git stash` 保护；异常路径禁止 `git reset --hard`。
- codex / 自评审路径都必须输出统一 Finding schema；非 JSON、缺字段、超时都立即 fail-close。
- 禁止静默从 codex 路径切到自评审路径；只能报告原因并 AskUserQuestion。
- 最终报告必须包含 `baseline_ref`、`stash_ref`、各轮统计、验证命令、剩余 findings、恢复状态。
```

4. [T1] Write `claude/skills/doc-review-fix/SKILL.md` with the document-specific loop contract and the DECEPTION handling rules:

```md
---
name: doc-review-fix
user-invocable: true
description: 文档评审修复循环。Use when 需要对指定文档做动态维度评审、修复和确认轮直到通过或 fail-close 停止。
argument-hint: "[文档路径或 focus ...]"
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# /doc-review-fix -- 文档评审修复循环

## HARD-GATE
- 先 AskUserQuestion 确认评审方式、评审对象、关联上下文和收敛标准。
- 评审维度必须从文档内容和上下游上下文动态发现，禁止回退到固定维度清单。
- `dimension` 含 `DECEPTION` 的 finding 必须标记“需用户介入”，不得自动修复。
- 文档路径通过条件是连续两轮零 findings；单轮零 findings 不得直接宣称通过。
- 最终报告必须包含各轮维度、各轮 findings 统计、baseline 信息和 residual findings。
```

5. [T1] Write `claude/skills/doc-review-fix/references/deception-patterns.md` with 12 DECEPTION patterns reorganized by pattern type:

```md
# DECEPTION Patterns

## 范围伪装
- 模式名：把未交付能力包装成“已覆盖边界”
  - 检测信号：正文把本期不交付写成“默认支持”或“后续补充即可上线”

## 证据挪用
- 模式名：用上游结论替代当前文档证据
  - 检测信号：引用 review 结论，但当前文档没有对应事实或验收落点

## 状态偷换
- 模式名：把风险、假设或待办项说成已完成事实
  - 检测信号：出现“已完成/已支持”，但没有实现、验证或责任落点
```

6. [T1] Run `bash tests/test-review-fix-redesign-contract.sh`.
Expected: PASS.
7. [T1] Commit task changes.

### Task 2: Install, Layout, Runtime, And Contract Migration [T2]

Files:
- Modify: `install.sh`
- Modify: `contracts/skill-chain.yaml`
- Modify: `tests/test-install-smoke.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-codex-skill-adapter.sh`

1. [T2] Add failing assertions for the new Claude-only topology and remove the old skill expectations:

```bash
test -f "$TMP_HOME/.claude/skills/code-review-fix/SKILL.md" || fail "missing ~/.claude/skills/code-review-fix/SKILL.md"
test -f "$TMP_HOME/.claude/skills/doc-review-fix/SKILL.md" || fail "missing ~/.claude/skills/doc-review-fix/SKILL.md"
test ! -e "$TMP_HOME/.codex/skills/code-review-fix" || fail "codex runtime should not contain claude-only skill code-review-fix"
test ! -e "$TMP_HOME/.codex/skills/doc-review-fix" || fail "codex runtime should not contain claude-only skill doc-review-fix"
test ! -e "$TMP_HOME/.claude/agents/codex-doc-reviewer.md" || fail "legacy claude-only agent should be retired"
```

2. [T2] Run:

```bash
bash tests/test-install-smoke.sh
bash tests/test-runtime-integrity.sh
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: FAIL with stale `review-fix-loop` / `codex-doc-review` assertions.
3. [T2] Update `install.sh` quick check so Claude runtime requires the two new skill paths instead of `review-fix-loop`:

```bash
[ -f "$CLAUDE_DIR/skills/code-review-fix/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/code-review-fix/SKILL.md 不存在"
[ -f "$CLAUDE_DIR/skills/doc-review-fix/SKILL.md" ] || fail "Quick Check 失败: ~/.claude/skills/doc-review-fix/SKILL.md 不存在"
```

4. [T2] Update `tests/test-runtime-integrity.sh`, `tests/test-install-smoke.sh`, `tests/test-single-source-layout.sh`, and `tests/test-codex-skill-adapter.sh` so the active source/runtime checks look like this:

```bash
test -f "$ROOT/claude/skills/code-review-fix/SKILL.md" || fail "missing claude-only skill source: code-review-fix"
test -f "$ROOT/claude/skills/doc-review-fix/SKILL.md" || fail "missing claude-only skill source: doc-review-fix"
test ! -e "$TMP_HOME/.codex/skills/code-review-fix" || fail "codex runtime should not install claude-only skill code-review-fix"
test ! -e "$TMP_HOME/.codex/skills/doc-review-fix" || fail "codex runtime should not install claude-only skill doc-review-fix"
```

5. [T2] Update `contracts/skill-chain.yaml` to remove the retired `codex-doc-review` node and its optional artifact from `project-manager` inputs:

```yaml
  - name: project-manager
    position: main
    inputs:
      required: [plan.md, design.md, test-cases.md]
      optional: []
```

6. [T2] Re-run:

```bash
bash tests/test-install-smoke.sh
bash tests/test-runtime-integrity.sh
bash tests/test-single-source-layout.sh
bash tests/test-codex-skill-adapter.sh
```

Expected: PASS.
7. [T2] Commit task changes.

### Task 3: Legacy Retirement, Hook Cleanup, And Archive [T3]

Files:
- Modify: `shared/hooks/lib/common.sh`
- Delete: `claude/skills/review-fix-loop/SKILL.md`
- Delete: `claude/skills/review-fix-loop/references/execution-spec.md`
- Delete: `claude/skills/review-fix-loop/references/review-schema.md`
- Delete: `claude/skills/review-fix-loop/scripts/capture_baseline.py`
- Delete: `claude/skills/review-fix-loop/scripts/completion_check.sh`
- Delete: `claude/skills/review-fix-loop/scripts/validate_review_json.py`
- Delete: `claude/skills/codex-doc-review/SKILL.md`
- Delete: `claude/skills/codex-doc-review/agents/openai.yaml`
- Delete: `claude/skills/codex-doc-review/references/execution-spec.md`
- Delete: `claude/skills/codex-doc-review/references/review-guide-base.md`
- Delete: `claude/skills/codex-doc-review/references/review-guide-design.md`
- Delete: `claude/skills/codex-doc-review/references/review-guide-product.md`
- Delete: `claude/skills/codex-doc-review/references/review-guide-tech-lead.md`
- Delete: `claude/skills/codex-doc-review/references/review-guide-test-design.md`
- Delete: `claude/skills/codex-doc-review/references/templates/codex-doc-review-report.md`
- Delete: `claude/skills/codex-doc-review/scripts/completion_check.sh`
- Delete: `claude/skills/codex-doc-review/scripts/repair_misplaced_reports.py`
- Delete: `claude/agents/codex-doc-reviewer.md`
- Delete: `tests/test-codex-doc-review-repair.sh`
- Delete: `tests/test-codex-doc-review-routing.sh`
- Delete: `tests/test-review-fix-loop-skill.sh`
- Create: `docs/archive/review-fix-loop-redesign-2026-04/claude/skills/review-fix-loop/...`
- Create: `docs/archive/review-fix-loop-redesign-2026-04/claude/skills/codex-doc-review/...`
- Create: `docs/archive/review-fix-loop-redesign-2026-04/claude/agents/codex-doc-reviewer.md`

1. [T3] Confirm the `codex-doc-review` helper block in `shared/hooks/lib/common.sh` is only tied to the retired flow, then add a failing grep check:

```bash
rg -n 'resolve_codex_doc_review_context|codex-doc-review-report|codex-doc-reviewer|review-fix-loop' \
  shared/hooks/lib/common.sh claude install.sh contracts tests
```

Expected: matches the old helper section, legacy tests, and retired skill files.
2. [T3] Copy the retired skill trees and agent file into `docs/archive/review-fix-loop-redesign-2026-04/`, excluding `__pycache__`, then delete the active source copies.
3. [T3] Remove the entire `codex-doc-review` parsing block from `shared/hooks/lib/common.sh`, starting at the comment:

```sh
# --- codex-doc-review 上下文解析 ---
```

and ending after `resolve_codex_doc_review_context`.
4. [T3] Delete `tests/test-codex-doc-review-repair.sh`, `tests/test-codex-doc-review-routing.sh`, and `tests/test-review-fix-loop-skill.sh`; these tests validate the retired helper/script implementation and should not remain active after the redesign.
5. [T3] Run the grep check again:

```bash
rg -n 'resolve_codex_doc_review_context|codex-doc-review-report|codex-doc-reviewer' \
  shared/hooks/lib/common.sh claude
```

Expected: no matches in active source files.
6. [T3] Commit task changes.

### Task 4: Suite Rewire And Final Verification [T4]

Files:
- Modify: `tests/run-all.sh`
- Create: `tests/test-review-fix-redesign-scenarios.sh`
- Modify: `docs/review-fix-loop/2026-04-03-redesign/tasks.md`

1. [T4] Add `tests/test-review-fix-redesign-scenarios.sh` to mechanically覆盖 redesign 负路径矩阵，至少包含 dirty tree restore、clean tree skip-stash、stash pop conflict、non-JSON fail-close、缺字段 fail-close、max-round termination、不收敛和用户中止恢复提示。
2. [T4] Update `tests/run-all.sh` syntax-check and execution lists so the new contract test and scenario test are included and the removed legacy tests are dropped:

```bash
bash -n "$ROOT/tests/test-review-fix-redesign-contract.sh"
bash -n "$ROOT/tests/test-review-fix-redesign-scenarios.sh"
...
bash "$ROOT/tests/test-review-fix-redesign-contract.sh"
bash "$ROOT/tests/test-review-fix-redesign-scenarios.sh"
```

and remove:

```bash
bash -n "$ROOT/tests/test-codex-doc-review-repair.sh"
bash -n "$ROOT/tests/test-codex-doc-review-routing.sh"
bash -n "$ROOT/tests/test-review-fix-loop-skill.sh"
```

3. [T4] Run `bash tests/run-all.sh`.
Expected: FAIL first on stale runner numbering or references to deleted tests.
4. [T4] Fix the runner labels and ordering so the full suite has a contiguous count and includes `test-review-fix-redesign-contract.sh` and `test-review-fix-redesign-scenarios.sh` once.
5. [T4] Run:

```bash
bash tests/run-all.sh
python3 tools/community/check_task_plan_consistency.py docs/review-fix-loop/2026-04-03-redesign/tasks.md docs/review-fix-loop/2026-04-03-redesign/plan.md
```

Expected: both commands return PASS.
6. [T4] Update `docs/review-fix-loop/2026-04-03-redesign/tasks.md` so T1-T4 are marked `[x]` only after all commands above and the task-specific review steps pass。
7. [T4] Commit task changes.
