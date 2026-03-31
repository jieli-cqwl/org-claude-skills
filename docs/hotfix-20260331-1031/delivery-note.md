# delivery-note

## 目标

本说明只覆盖本轮“修复循环”已经验证通过的最小提交边界，用于从当前脏工作树中安全摘取可交付变更。

提交边界口径：
- 以文件最终状态为边界，不按局部 hunk 拆分。
- 只提交本轮已修复并完成验证的 contract 收敛文件。
- 当前 `git status` 中未列入本说明的其他修改，均不建议混入本次提交。

## 建议提交边界

### Phase/UNIT 解析
- `shared/hooks/lib/common.sh`

### 前置约束门禁统一
- `shared/skills/product/scripts/completion_check.sh`
- `shared/skills/tech-lead/scripts/completion_check.sh`
- `shared/skills/tech-lead/references/templates/plan-template.md`
- `shared/skills/project-manager/scripts/completion_check.sh`
- `shared/skills/project-manager/references/templates/acceptance-summary-template.md`

### QA 报告 contract 统一
- `shared/skills/project-manager/references/templates/qa-report-template.md`
- `shared/skills/qa/references/templates/qa-report-template.md`

### 回归测试
- `tests/run-all.sh`
- `tests/test-phase-context-resolution.sh`
- `tests/test-project-manager-phase3-contract.sh`

### 修复记录
- `docs/hotfix-20260331-1031/fix-2.md`
- `docs/hotfix-20260331-1031/delivery-note.md`

## 明确排除范围

以下变更当前不在本轮“可直接交付”的验证边界内，建议继续保留在工作树，不要混入本次提交：
- `shared/agents/*.md`
- `shared/protocols/phase-selection-protocol.md`
- `shared/reference/文档规范.md`
- `shared/skills/design/**`
- `shared/skills/developer/SKILL.md`
- `shared/skills/fix/**`
- `shared/skills/product/SKILL.md`
- `shared/skills/product/references/**`
- `shared/skills/project-manager/SKILL.md`
- `shared/skills/project-manager/references/dispatch-guide.md`
- `shared/skills/project-manager/references/phase3-dispatch.md`
- `shared/skills/project-manager/references/templates/dev-report-template.md`
- `shared/skills/qa/SKILL.md`
- `shared/skills/test-design/**`
- `tests/lib/test-env.sh`
- `docs/rfcs/2026-03-30_标准skill链路Contract收敛与前置约束闭环RFC.md`
- `shared/skills/qa/scripts/`

如果要把上述文件一起提交，需要再做一轮独立的提交边界审查。

## 建议操作

当前状态说明：
- 当前工作树里已经存在不少边界外的 staged 文件。
- 因此不建议直接在当前 index 上执行 `git commit`，否则会混入未纳入本说明的修改。

推荐做法是先在干净分支或独立 worktree 摘取这批文件，再提交。

如需在新 worktree 中摘取，可直接拷贝本说明列出的文件最终状态。

如果你确认要在当前工作树内整理 index，再按下面命令摘取本次提交边界：

```bash
git add \
  shared/hooks/lib/common.sh \
  shared/skills/product/scripts/completion_check.sh \
  shared/skills/tech-lead/scripts/completion_check.sh \
  shared/skills/tech-lead/references/templates/plan-template.md \
  shared/skills/project-manager/scripts/completion_check.sh \
  shared/skills/project-manager/references/templates/qa-report-template.md \
  shared/skills/project-manager/references/templates/acceptance-summary-template.md \
  shared/skills/qa/references/templates/qa-report-template.md \
  tests/run-all.sh \
  tests/test-phase-context-resolution.sh \
  tests/test-project-manager-phase3-contract.sh \
  docs/hotfix-20260331-1031/fix-2.md \
  docs/hotfix-20260331-1031/delivery-note.md
```

提交前再确认一次：

```bash
git status --short
git diff --cached --stat
```

只有在 `git diff --cached --stat` 中只剩本说明列出的文件时，才建议继续提交。

建议提交信息：

```text
fix: align phase context and delivery contract gates
```

## 已执行验证

- `bash tests/test-phase-context-resolution.sh`
- `bash tests/test-project-manager-phase3-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/run-all.sh`
- `git diff --check`

## 交付结论

这批文件已经完成：
- 当前 Phase 解析修复
- QA 报告模板与门禁统一
- 前置约束 `Constraint ID` / `test_ref` / `BLOCKED` 状态机统一
- 新增回归测试入总测试入口

按本说明摘取后，可作为一笔独立修复提交进入团队使用。
