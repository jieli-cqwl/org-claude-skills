# Team Review Parallelization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement Team-based parallel cross-review for `/product` S11 and `/design` S9 without changing the outer review-fix semantics or breaking existing `cross-review.md` consumption.

**Architecture:** Add one Team-specific protocol plus two shared agents, then wire `/product` and `/design` onto the new execution model. Keep `cross-review.md` main parsing contract intact by letting Review Lead own all file writes and treating challenge records as an auxiliary appendix.

**Tech Stack:** Markdown skill specs, shared protocol/agent docs, Bash contract tests, Python task-plan consistency checker

---

### Task 1: Team Protocol And Agent Definitions [T1]

Files:
- Create: `shared/protocols/team-review-protocol.md`
- Create: `shared/agents/cross-review-lead.md`
- Create: `shared/agents/cross-reviewer.md`
- Create: `tests/test-team-review-contract.sh`

1. [T1] Add failing assertions to `tests/test-team-review-contract.sh` for the new protocol file, both new agent files, the required `R1 -> R2 -> R2.5 -> R3` flow text, and the required tool names `SendMessage`, `TaskGet`, and `TaskList`.
2. [T1] Run `bash tests/test-team-review-contract.sh`.
Expected: FAIL with missing file or missing pattern errors for `team-review-protocol.md`, `cross-review-lead.md`, or `cross-reviewer.md`.
3. [T1] Write `shared/protocols/team-review-protocol.md` with these required sections:

```md
# Team Review 协议

## 角色
- Caller: 管外层循环、用户确认、仅 FAIL 视角重审
- Review Lead: 协调 R1 / R2 / R2.5 / R3，唯一落盘
- Reviewer: 产出 stable issue id 与结构化 review_result

## 内层流程
- R1: 并行广度扫描
- R2: 本视角深度聚焦
- R2.5: 横向质疑协调（不计入共享轮次）
- R3: 任一 active 视角触发新 FAIL 时，全部 active 视角进入

## 回退
- Team 失败时显式回退
- 仅处理当前 active 视角集合
- [FALLBACK-MODE] 只允许出现在独立说明块或横向质疑记录
```

4. [T1] Write `shared/agents/cross-review-lead.md` and `shared/agents/cross-reviewer.md` with YAML headers that include the exact tool names required by the protocol.

```yaml
tools:
  - Read
  - Write
  - Glob
  - Grep
  - SendMessage
  - TaskGet
  - TaskList
```

```yaml
tools:
  - Read
  - Glob
  - Grep
  - SendMessage
  - TaskGet
```

5. [T1] Run `bash tests/test-team-review-contract.sh`.
Expected: PASS.
6. [T1] Commit task changes.

### Task 2: Product Team Review Integration [T2]

Files:
- Modify: `shared/skills/product/SKILL.md`
- Modify: `shared/skills/product/references/prd-reviewer-prompt.md`
- Modify: `shared/skills/product/references/architect-reviewer-prompt.md`
- Modify: `shared/skills/product/references/tester-reviewer-prompt.md`
- Modify: `tests/test-team-review-contract.sh`

1. [T2] Extend `tests/test-team-review-contract.sh` with failing assertions for `/product`:

```bash
assert_present 'protocols/team-review-protocol.md' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'R2\.5' "$ROOT/shared/skills/product/SKILL.md"
assert_present '仅对 FAIL 视角重审' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/product/references/prd-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/product/references/prd-reviewer-prompt.md"
```

2. [T2] Run `bash tests/test-team-review-contract.sh`.
Expected: FAIL with missing Team review assertions in `/product` skill or prompts.
3. [T2] Update `shared/skills/product/SKILL.md` so `allowed-tools` includes `TeamCreate`, `TeamDelete`, `SendMessage`, `TaskCreate`, `TaskUpdate`, `TaskList`, and `TaskGet`, and replace S11 text with Team-mode semantics:

```md
- R1: active Reviewer 并行广度扫描
- R2: active Reviewer 按共享协议做深度聚焦
- R2.5: active 视角数 >= 2 时执行横向质疑协调
- R3: 任一 active 视角在 R2.5 后仍有新 FAIL，则全部 active Reviewer 进入 R3
- FAIL -> 上报用户、修正文档、仅对 FAIL 视角重审
```

4. [T2] Update the three product reviewer prompts to support dual-mode output:

```md
- Team 模式：将结构化审查结果发送给 Review Lead，不直接写 cross-review 文件
- fallback 单代理模式：继续直接写入目标 section
```

5. [T2] Run `bash tests/test-team-review-contract.sh`.
Expected: PASS.
6. [T2] Run `bash tests/test-skill-output-and-gate-contract.sh`.
Expected: PASS.
7. [T2] Commit task changes.

### Task 3: Design Team Review Integration [T3]

Files:
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/references/design-reviewer-prompt.md`
- Modify: `shared/skills/design/references/design-product-reviewer-prompt.md`
- Modify: `shared/skills/design/references/design-test-reviewer-prompt.md`
- Modify: `tests/test-team-review-contract.sh`

1. [T3] Extend `tests/test-team-review-contract.sh` with failing assertions for `/design`:

```bash
assert_present 'protocols/team-review-protocol.md' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'R2\.5' "$ROOT/shared/skills/design/SKILL.md"
assert_present '仅对 FAIL 视角重审' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
```

2. [T3] Run `bash tests/test-team-review-contract.sh`.
Expected: FAIL with missing Team review assertions in `/design` skill or prompts.
3. [T3] Update `shared/skills/design/SKILL.md` so `allowed-tools` and S9 mirror the Team review semantics used by `/product`, with design-specific prompt and output paths.
4. [T3] Update the three design reviewer prompts to support the same dual-mode contract:

```md
- Team 模式：发送结构化结果给 Review Lead，由 Lead 统一写 `design-cross-review.md`
- fallback 单代理模式：继续直接写目标 section 和 `审查结论`
```

5. [T3] Run `bash tests/test-team-review-contract.sh`.
Expected: PASS.
6. [T3] Run `bash tests/test-skill-output-and-gate-contract.sh`.
Expected: PASS.
7. [T3] Commit task changes.

### Task 4: Cross-Review And Handoff Template Updates [T4]

Files:
- Modify: `shared/skills/product/references/templates/product-cross-review-template.md`
- Modify: `shared/skills/design/references/templates/design-cross-review-template.md`
- Modify: `shared/skills/product/references/templates/prd-template.md`
- Modify: `shared/skills/design/references/templates/design-template.md`
- Modify: `tests/test-team-review-contract.sh`

1. [T4] Extend `tests/test-team-review-contract.sh` with failing assertions for template changes:

```bash
assert_present '状态' "$ROOT/shared/skills/product/references/templates/product-cross-review-template.md"
assert_present '^## 横向质疑记录$' "$ROOT/shared/skills/product/references/templates/product-cross-review-template.md"
assert_present '\\[DISPUTED\\]' "$ROOT/shared/skills/product/references/templates/prd-template.md"
assert_present '\\[DISPUTED\\]' "$ROOT/shared/skills/design/references/templates/design-template.md"
```

2. [T4] Run `bash tests/test-team-review-contract.sh`.
Expected: FAIL with missing status column, appendix section, or handoff status preservation.
3. [T4] Update the two cross-review templates so the Findings table starts with:

```md
| Issue ID | Severity | 状态 | 维度 | 发现 | 证据 | 建议承接位置 |
```

and append:

```md
## 横向质疑记录

> 说明：本节为说明性附录，不作为最终 Verdict / Issue Count 的唯一真相来源。
```

4. [T4] Update `prd-template.md` and `design-template.md` examples so handoff entries preserve state tags:

```md
AR-002 [DISPUTED]: 承接到 DD-003，design 阶段必须显式裁决。
```

5. [T4] Run `bash tests/test-team-review-contract.sh`.
Expected: PASS.
6. [T4] Commit task changes.

### Task 5: Verification Coverage And Final Consistency [T5]

Files:
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-single-source-layout.sh`
- Modify: `tests/test-team-review-contract.sh`
- Modify: `docs/team-review-parallelization/2026-04-02-product-design-cross-review/tasks.md`

1. [T5] Add failing runtime/source assertions for the new protocol and agent files:

```bash
test -f "$ROOT/shared/protocols/team-review-protocol.md" || fail "missing shared/protocols/team-review-protocol.md"
test -f "$ROOT/shared/agents/cross-review-lead.md" || fail "missing shared/agents/cross-review-lead.md"
test -f "$ROOT/shared/agents/cross-reviewer.md" || fail "missing shared/agents/cross-reviewer.md"
test -f "$TMP_HOME/.claude/protocols/team-review-protocol.md" || fail "missing ~/.claude/protocols/team-review-protocol.md"
test -f "$TMP_HOME/.codex/protocols/team-review-protocol.md" || fail "missing ~/.codex/protocols/team-review-protocol.md"
```

2. [T5] Run `bash tests/test-single-source-layout.sh` and `bash tests/test-runtime-integrity.sh`.
Expected: FAIL with missing Team review protocol or runtime distribution assertions.
3. [T5] Update `tests/test-single-source-layout.sh` and `tests/test-runtime-integrity.sh` with the new protocol and agent checks, keeping the existing test style and failure messages.
4. [T5] Run:

```bash
bash tests/test-team-review-contract.sh
bash tests/test-single-source-layout.sh
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-runtime-integrity.sh
python3 tools/community/check_task_plan_consistency.py docs/team-review-parallelization/2026-04-02-product-design-cross-review/tasks.md docs/team-review-parallelization/2026-04-02-product-design-cross-review/plan.md
```

Expected: all commands return PASS.
5. [T5] Update `docs/team-review-parallelization/2026-04-02-product-design-cross-review/tasks.md` so T1-T5 are marked `[x]` only after all review and verification steps pass.
6. [T5] Commit task changes.
