---
name: commit
user-invocable: true
disable-model-invocation: true
argument-hint: "[--force] [--changelog 版本号]"
description: Git 提交与推送。Use when 需要提交代码、推送到远程仓库。
model: sonnet
---

# /commit -- 安全 Git 交付

## HARD-GATE

1. NO commit without user confirming both the commit message and file scope.
2. NO push to main/master without explicit second confirmation.
3. NO conflict resolution -- stop immediately, list conflict files, hand off to user.
4. NO changelog entry without a traceable commit hash.

## 角色

你是交付执行者。定位：commit/pull --rebase/push 全流程。驱动：最小流程、显式确认、质量门控前置。锚点：冲突即停，拒绝跳过质量检查。

## 前置条件

1. 确认在 Git 仓库内且有变更；main/master 分支默认阻断
2. 检查 `code-review-report.md` / `qa-report.md` 是否存在且含 `PASS`
   - 缺失或非 PASS 时：**终止并提示**用户先执行 code-review + `/qa`
   - 若 `fix-N.md` 存在：确认 review/qa 报告已覆盖修复后的代码（报告日期应晚于 fix）
   - 用户传入 `--force` 时：警告风险后继续（在输出中标记 `FORCED`）

## 流程

1. 展示变更：`git diff --stat` + `git status --short` + `git log --oneline -3`
2. 确认提交：展示建议的 commit message（`<type>: <描述>`）和文件范围，等待用户确认
3. 提交：`git add -- <pathspec>` + `git commit -m "<message>"`
4. 同步推送：
   - `git pull --rebase origin <branch>`
   - rebase 冲突 -> 列出冲突文件，执行 `git rebase --abort`，**终止并上报**
   - push 失败 -> 重试 1 次；仍失败则**终止并上报**错误信息
   - 成功 -> `git push`
5. Changelog（可选）：仅当用户传入 `--changelog [版本号]` 时执行
   - 版本号有 tag 则 `git log <上一个tag>..HEAD --oneline`；否则 `git log -20 --oneline`
   - 分类规则：BREAKING 置顶 > feat > fix > perf > other（refactor/docs/chore）
   - 每条附 commit hash，禁止模糊描述

type 约定：feat / fix / docs / refactor / chore / perf

## 输出

```
## Ship Report
- 提交信息: <message>
- 分支: <branch> -> origin/<branch>
- 质量门控: code-review=<PASS|FAIL|FORCED> /qa=<PASS|FAIL|FORCED>
- 推送状态: <成功|失败(原因)>
```

Changelog 输出（仅 `--changelog` 时）：

```markdown
## [版本号] - YYYY-MM-DD

### BREAKING CHANGES
- 模块名: 描述 (`commit-hash`)

### Features / Fixes / Performance / Other
- 模块名: 描述 (`commit-hash`)
```

## 完成校验

- [ ] 用户已确认 commit message 和文件范围
- [ ] 质量门控通过（PASS）或用户显式 `--force`
- [ ] commit + push 成功，或异常已终止并上报用户
- [ ] Changelog（若生成）每条有 commit hash，BREAKING 置顶，分类正确
