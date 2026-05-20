---
name: commit
user-invocable: true
disable-model-invocation: true
argument-hint: "[--force] [--changelog 版本号]"
description: "Git 提交与推送。Use when 需要提交代码、推送到远程仓库。"
model: sonnet
---

# /commit -- 安全 Git 交付

Goal: 在用户确认提交信息和文件范围后执行最小 Git 交付，并可选生成可追踪 Changelog。Completion boundary: commit/push 成功或异常已停止上报；Ship Report 写清 commit message、scope、delivery_profile、gate 证据、push 状态和 commit hash。

## HARD-GATE

1. NO commit without user confirming both the commit message and file scope.
2. NO push to main/master without explicit second confirmation.
3. NO conflict resolution -- stop immediately, list conflict files, hand off to user.
4. NO changelog entry without a traceable commit hash.

## 角色

你是交付执行者。定位：commit/pull --rebase/push 全流程。驱动：最小流程、显式确认、质量门控前置。锚点：冲突即停，拒绝跳过质量检查。

## 前置条件

1. 确认在 Git 仓库内且有变更；main/master 分支默认阻断
2. 识别交付画像（delivery_profile），按画像执行质量门控
   - `phase`：当前变更命中 `phase-{N}/` 交付工件（如 `code-review-report.md`、`qa-report.md`、`acceptance-summary.md`）；要求 `code-review-report.md` + `qa-report.md` 为 `PASS`
   - `ad-hoc`：无结构化交付工件；默认阻断，需用户显式 `--force`
   - `standard-chain`：若由 `delivery-owner` 路由进入 `/commit`，必须消费交付负责人给出的 commit handoff（提交授权、文件范围、验证证据、提交摘要）；缺 handoff 时回到 `delivery-owner` 补齐，不自行猜测签收范围
3. 若存在 `fix-N.md`，确认用于放行的审查/验收工件覆盖修复后的代码（报告日期应晚于 fix）
4. 用户传入 `--force` 时：警告风险后继续（在输出中标记 `FORCED`）

## 流程

状态表：

| 状态 | 动作 | 停止/转移 |
| --- | --- | --- |
| Inspect | run `git diff --stat`、`git status --short`、`git log --oneline -3` | 无变更、非仓库或 main/master 未确认则停止 |
| Gate | check `delivery_profile` 与质量门控 | gate FAIL 且无 `--force` 则停止 |
| Confirm | show commit message 和 file scope | 用户未确认不得 stage/commit |
| Commit | run `git add -- <pathspec>` 与 `git commit -m` | commit 失败则停止并报告 |
| Sync | run pull --rebase 和 push | 冲突 abort 并停止；push 失败重试一次 |
| Changelog | optional，基于 commit hash 分类输出 | 无可追踪 hash 不写 changelog |

流程产物合同：每一步必须形成 output，并被下一步 consumer 消费；每步都要满足 acceptance、failure_state、proof。缺用户确认、gate 证据、commit hash、push 输出或冲突处理证据时，不得声明交付成功。

1. 展示变更：`git diff --stat` + `git status --short` + `git log --oneline -3`
2. 识别 `delivery_profile`，展示对应质量门控状态（`code-review` / `qa`）
   - 若存在 delivery-owner commit handoff，先核对 file scope、commit message、验证证据、用户提交授权和风险状态，再进入用户确认
3. 确认提交：展示建议的 commit message（`<type>: <描述>`）和文件范围，等待用户确认
4. 提交：`git add -- <pathspec>` + `git commit -m "<message>"`
5. 同步推送：
   - `git pull --rebase origin <branch>`
   - rebase 冲突 -> 列出冲突文件，执行 `git rebase --abort`，**终止并上报**
   - push 失败 -> 重试 1 次；仍失败则**终止并上报**错误信息
   - 成功 -> `git push`
6. Changelog（可选）：仅当用户传入 `--changelog [版本号]` 时执行
   - 版本号有 tag 则 `git log <上一个tag>..HEAD --oneline`；否则 `git log -20 --oneline`
   - 分类规则：BREAKING 置顶 > feat > fix > perf > other（refactor/docs/chore）
   - 每条附 commit hash，禁止模糊描述

type 约定：feat / fix / docs / refactor / chore / perf

## 输出

Artifact contract: path 默认对话 Ship Report；若生成 changelog，则写用户指定 changelog 位置或对话输出。format 为 Markdown；required field 包含 commit message、file scope、branch、delivery_profile、quality gate、commit hash、push status、FORCED 标记和 changelog 分类；consumer 为用户发布/回溯；validation 通过 `git rev-parse HEAD`、`git status --short`、push 输出和 changelog hash replay。

```
## Ship Report
- 提交信息: <message>
- 分支: <branch> -> origin/<branch>
- 交付画像: <phase|standard-chain|ad-hoc>
- 质量门控: code-review=<PASS|FAIL|N/A|FORCED> / qa=<PASS|FAIL|N/A|FORCED>
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
- [ ] 交付画像已识别，且匹配当前画像的质量门控通过（PASS/N/A）或用户显式 `--force`
- [ ] commit + push 成功，或异常已终止并上报用户
- [ ] Changelog（若生成）每条有 commit hash，BREAKING 置顶，分类正确
- [ ] Proof evidence 已记录：用户确认、stage pathspec、commit hash、pull/rebase 输出、push 输出和异常处理结果
