# fix-12: product eval CI bash compatibility

## 输入分析

- 输入来源清单：GitHub Actions `validate` job 在 `[17/36] product eval contract test` 退出 1，日志没有 `[FAIL]` 明细；本地 feature 分支与 PR merge ref 运行同一测试均通过。
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：1

差异说明（N > 1 时 REQUIRED）：
- `fix-1..fix-11` 聚焦 standard-chain readiness、canonical schema/template/gate、product split 与 Agent Team review 闭环。
- 本轮不改变 standard-chain 契约目标，只处理合并后 CI 环境暴露的 eval runner Bash 兼容性问题。

## 诊断阶段

### 环境快照

- 当前分支：`codex/standard-chain-contract-foundation`
- 最近 5 条提交：
  - `d2fdfb4 test: make codex capability probe fail closed in CI`
  - `5190611 ci: install ripgrep for repository tests`
  - `dc40417 merge: align main updates with standard-chain PR`
  - `a3e542b feat: implement standard-chain contract foundation`
  - `e179e9a chore: harden skill quality and optimizer contracts`
- 当前 CI 失败点：`tests/run-all.sh` 第 17 步 `bash tests/test-product-eval-contract.sh`

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | GitHub Actions product eval contract 无明细失败 | 查看 run `24560947524` / job `71809154391` 日志 | `[17/36] product eval contract test` 后直接 `Process completed with exit code 1`。 |
| 2 | 本地正式分支未复现 | `bash tests/test-product-eval-contract.sh` | 输出 `[PASS] product eval contract`。 |
| 3 | 本地 PR merge ref 未复现 | `git fetch origin pull/2/merge:refs/tmp/pr-2-merge` 后在 detached worktree 运行同一测试 | 输出 `[PASS] product eval contract`。 |

当前环境复现结论：
- 直接 CI 失败可通过 GitHub Actions 日志复现。
- 本地无法用 macOS Bash 3.2 复现退出行为；环境差异证据为本地 `GNU bash, version 3.2.57`，CI 运行在 Ubuntu 24.04 的 `/usr/bin/bash -e`。

### 假设验证过程

| # | 假设 | 验证方法 | 结果 |
|---|------|---------|------|
| 1 | PR merge ref 丢失 product eval 文件或 benchmark fixture | 在 `refs/tmp/pr-2-merge` detached worktree 运行 `bash tests/test-product-eval-contract.sh`。 | 排除。PR merge ref 输出 `[PASS] product eval contract`。 |
| 2 | CI 缺少 `rg` 导致 test helper 失败 | CI 已在前序步骤通过 `eval fixtures`、`eval summary compatibility`，且 workflow 已安装 `ripgrep`。 | 排除。失败点发生在 product eval runner 调用后，非 `rg` 缺失。 |
| 3 | `run_skill_eval.sh check` 在 CI Bash 下被 `set -e` + arithmetic post-increment 误杀 | 静态追踪 `tests/test-product-eval-contract.sh:100` 调用 runner；runner `cmd_check()` 在 `tools/eval/run_skill_eval.sh:151,154,162,165,173,176,185,188` 使用 `((ok++)) / ((fail++))`。 | 确认。CI 日志无 `[FAIL]` 明细，符合子进程在 runner 内部直接退出；本地 Bash 3.2 行为差异解释本地绿、CI 红。 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | product eval contract CI-only failure | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/eval/run_skill_eval.sh:151,154,162,165,173,176,185,188` | `tests/run-all.sh` 调 `tests/test-product-eval-contract.sh`；后者第 100 行运行 `bash tools/eval/run_skill_eval.sh check`；runner 在 `set -euo pipefail` 下执行 `((ok++))`，新 Bash 会把第一次表达式值 0 当作失败退出码，从而无 test-level `[FAIL]` 明细退出。 | 等效静态追踪：`tests/run-all.sh:144` -> `tests/test-product-eval-contract.sh:100` -> `tools/eval/run_skill_eval.sh:141-199`。 |

## 处置阶段

### 决策

处置策略：最小修复，不改变 eval contract 内容，只消除 `set -e` 下的 arithmetic command 退出码风险，并补回归门禁防止同类写法回流。

失败分类：

| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | product eval contract CI-only failure | FIXABLE | 补 RED 回归，改用 assignment increment，运行 targeted 与语法/静态检查。 |

## RED/GREEN 证据

RED：
- 新增回归后，修复前运行 `bash tests/test-product-eval-contract.sh` 输出 `[FAIL] run_skill_eval.sh must avoid arithmetic inc/dec command status under set -e`。

GREEN：
- `bash tests/test-product-eval-contract.sh` -> `[PASS] product eval contract`
- `bash -n tools/eval/run_skill_eval.sh tests/test-product-eval-contract.sh` -> exit 0
- `shellcheck -x tools/eval/run_skill_eval.sh tests/test-product-eval-contract.sh` -> exit 0

## 修复四问

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `run_skill_eval.sh` 在 `set -e` 下使用 arithmetic post-increment，CI Bash 把第一次 `((ok++))` 的表达式值 0 转成失败退出码。 |
| 2 | 修复是否完整？ | 已替换 runner 中全部四组 `ok/fail` post-increment，并加测试拒绝 arithmetic inc/dec 命令状态。 |
| 3 | 是否引入新问题？ | 行为保持为计数加一，输出与业务语义不变；只去掉跨 Bash 版本不稳定退出码。 |
| 4 | 是否需要补测试？ | 需要，已在 `tests/test-product-eval-contract.sh` 增加回归门禁。 |

## 产出

### 修复清单

| # | 范围 | 主要文件 |
|---|------|----------|
| 1 | eval runner Bash 兼容性 | `tools/eval/run_skill_eval.sh` |
| 2 | product eval regression gate | `tests/test-product-eval-contract.sh` |

### 交接项清单

- 非 FIXABLE 问题的后续处理动作：无。
- 当前状态：等待完整 `tests/run-all.sh` 与 GitHub Actions 重新验证。
