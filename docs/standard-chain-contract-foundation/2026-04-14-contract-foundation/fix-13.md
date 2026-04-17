# fix-13: delivery-owner mtime gate Linux stat compatibility

## 输入分析

- 输入来源清单：GitHub Actions run `24565159812` / job `71823356910` 与 run `24565157912` / job `71823351230` 均在 `[22/36] skill output/gate contract test` 失败。
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：1

差异说明（N > 1 时 REQUIRED）：
- `fix-12` 修复的是 product eval runner 的 Bash arithmetic 兼容性，CI 已证明 `[17/36] product eval contract test` 通过。
- 本轮处理后续暴露的 delivery-owner stale-proof 时间戳读取兼容性，不改变 stale-proof 验收标准。

## 诊断阶段

### 环境快照

- 当前分支：`codex/standard-chain-contract-foundation`
- 最近提交：`09c87bc fix: harden product eval runner for ci bash`
- CI 失败点：`tests/run-all.sh` 第 22 步 `bash tests/test-skill-output-and-gate-contract.sh`

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | CI stale-proof 负例误放行 | 查看 GitHub Actions 日志 | `completion_check.sh: line 1688: [: File: ... integer expression expected`，随后 `[FAIL] delivery-owner stale proving or test evidence after fix should fail`。 |
| 2 | 本地 macOS 原先未复现 | 直接运行 `bash tests/test-skill-output-and-gate-contract.sh` | 修复前本地通过，因为 BSD `stat -f %m` 返回纯数字。 |
| 3 | 本地 GNU-stat shim 可复现 | 给 stale-proof 场景注入 fake GNU `stat`，让 `stat -f %m` 返回文件系统信息且退出 0 | 修复前本地输出同类 `integer expression expected` 并失败。 |

当前环境复现结论：
- 可复现：是。新增 GNU-stat shim 后，本地修复前稳定复现 CI 错误。
- 环境差异证据：macOS `stat -f %m file` 返回 mtime epoch；GNU `stat -f %m file` 表示 filesystem mode，会输出多行文件系统信息并退出 0，导致 fallback 到 `stat -c %Y` 不会发生。

### 假设验证过程

| # | 假设 | 验证方法 | 结果 |
|---|------|---------|------|
| 1 | product eval 修复未生效导致 CI 继续失败 | 查看 CI 日志 `[17/36] product eval contract test`。 | 排除。CI 输出 `[PASS] product eval contract`。 |
| 2 | stale-proof fixture 时间戳本身设置错误 | 检查 `tests/test-skill-output-and-gate-contract.sh:4645-4673`，fixture 明确把 `fix-1.md` touch 到 2026-04-11 11:00，proving/test evidence 早于 fix。 | 排除。负例设计正确，应当 fail-close。 |
| 3 | `file_mtime_epoch()` 先调用 BSD `stat -f %m`，GNU 环境下拿到非数字 stdout | 静态追踪 `shared/skills/delivery-owner/scripts/completion_check.sh:861-869`，并用 fake GNU `stat` 复现。 | 确认。非数字多行 stdout 进入 `-gt` 比较，导致比较报错且未设置 latest fix epoch。 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | delivery-owner stale-proof gate 在 GNU stat 下误放行 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/delivery-owner/scripts/completion_check.sh:861-869` | `file_mtime_epoch()` 先执行 `stat -f %m`；GNU stat 将 `-f` 解释为 filesystem stats 并成功输出多行文本；调用方 `completion_check.sh:1687-1688` 把该文本用于整数比较，比较失败后没有更新 `LATEST_FIX_EPOCH`，最终 stale proof 未被挡住。 | 等效静态追踪：`tests/test-skill-output-and-gate-contract.sh:4666-4673` -> `run_completion_check_with_payload` -> `completion_check.sh:1682-1692` -> `file_mtime_epoch()`。 |

## 处置阶段

### 决策

处置策略：保持 stale-proof fail-closed 语义不变，只把 mtime 读取改成跨平台安全实现：优先 GNU `stat -c %Y`，再回退 BSD `stat -f %m`，且只接受纯数字输出。

失败分类：

| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | delivery-owner stale-proof gate Linux stat compatibility | FIXABLE | 补 GNU-stat 回归，修 `file_mtime_epoch()`，运行 targeted 与全量门禁。 |

## RED/GREEN 证据

RED：
- 新增 GNU-stat shim 后，修复前运行 `bash tests/test-skill-output-and-gate-contract.sh` 输出 `integer expression expected` 与 `[FAIL] delivery-owner stale proving or test evidence after fix should fail`。

GREEN：
- `bash -n shared/skills/delivery-owner/scripts/completion_check.sh tests/test-skill-output-and-gate-contract.sh` -> exit 0
- `bash tests/test-skill-output-and-gate-contract.sh` -> `[PASS] skill output/gate contract`

## 修复四问

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `file_mtime_epoch()` 用 BSD `stat -f %m` 作为第一选择，GNU 环境下该命令成功但输出非数字文件系统信息。 |
| 2 | 修复是否完整？ | 已覆盖 GNU 与 BSD 两条路径，并拒绝非纯数字输出，避免同类非数字 mtime 进入整数比较。 |
| 3 | 是否引入新问题？ | 业务语义不变，仍返回文件 mtime epoch；只改变平台选择顺序与输出校验。 |
| 4 | 是否需要补测试？ | 需要，已在 stale-proof 负例中加入 GNU-stat shim，确保 macOS 本地也能覆盖 CI 行为。 |

## 产出

### 修复清单

| # | 范围 | 主要文件 |
|---|------|----------|
| 1 | delivery-owner mtime helper | `shared/skills/delivery-owner/scripts/completion_check.sh` |
| 2 | GNU-stat regression | `tests/test-skill-output-and-gate-contract.sh` |

### 交接项清单

- 非 FIXABLE 问题的后续处理动作：无。
- 当前状态：等待完整 `tests/run-all.sh` 与 GitHub Actions 重新验证。
