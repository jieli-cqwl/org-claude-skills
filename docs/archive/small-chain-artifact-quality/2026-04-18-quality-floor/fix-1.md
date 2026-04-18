# fix-1.md

## 输入分析

输入来源：
- 用户粘贴的 review findings。
- `docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/code-review-report.md`。
- 当前复现命令输出。

work_dir 解析结果：`docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/`

问题数量汇总：2 个 review finding 均确认为 `FIXABLE`。

差异说明（N > 1 时 REQUIRED）：N = 1，无历史 `fix-*.md`。

## 诊断阶段

### 环境快照

- 当前分支：`main`
- 工作树状态：`main...origin/main [ahead 9]`，存在本轮修改与其他未提交改动；本轮直接修复范围限定为 `tools/community/sync_canonical_from_upstream.py`、`tests/test-community-tools.sh`、`docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/verify-change-report.md`。
- 最近 5 条提交：
  - `34682dd merge: sync origin/main into local main`
  - `173c062 docs: archive standard-chain contract foundation`
  - `e868027 docs: archive small-chain artifact quality floor`
  - `4e25787 docs: add small-chain quality floor verify report`
  - `8fe80ca docs: add small-chain quality floor execution plan`
- 最近改动文件：见 `git status --short --branch`；其中 Darwin skill / Claude API upstream 相关改动不是本轮 review finding 修复范围。

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | 新 checklist overlay 会在 upstream sync 后丢失 | 用临时 upstream/community 目录调用 `sync_superpowers()`，本地只放 `design-completeness-checklist.md`，upstream 不放该文件 | 修复前输出 `checklist_exists_after_sync= False`；`design-template.md` 同场景能恢复为本地内容 |
| 2 | 归档后的 verify report 复跑路径失效 | 执行报告里的 active workset 命令：`python3 tools/community/check_task_plan_consistency.py docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md` | 输出 `[FAIL] 缺少 tasks 文件: docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md` |

当前环境复现结论：
- 问题 1：可复现。
- 问题 2：可复现。

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | checklist overlay 丢失 | H1: 新 checklist 未进入 `SUPERPOWERS_FULL_FILE_OVERLAYS`，所以未被 capture/apply | `rg -n "SUPERPOWERS_FULL_FILE_OVERLAYS|design-completeness-checklist" tools/community/sync_canonical_from_upstream.py contracts/superpowers-boundary.yaml`；查看 `tools/community/sync_canonical_from_upstream.py:61-69` | 确认 |
| 1 | checklist overlay 丢失 | H2: `copy_tree()` 删除目标 skill 目录，导致未捕获文件被移除 | 查看 `tools/community/sync_canonical_from_upstream.py:214-217` 与 `:637-646`，临时 sync 复现 | 确认 |
| 1 | checklist overlay 丢失 | H3: 测试已有覆盖但断言不完整 | 查看 `tests/test-community-tools.sh` 的 sync fixture 与断言；修复前无 checklist 保留断言 | 确认 |
| 2 | verify report 路径失效 | H1: 归档移动后报告未改 active workset 路径 | `nl -ba verify-change-report.md` 查看 `:18-20`、`:36`、`:46` | 确认 |
| 2 | verify report 路径失效 | H2: active 路径仍存在，因此命令失败来自别处 | `python3 tools/community/check_task_plan_consistency.py docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md` | 排除；命令明确缺少 active `tasks.md` |
| 2 | verify report 路径失效 | H3: archive 路径本身也不可复跑 | `python3 tools/community/check_task_plan_consistency.py docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md` | 排除；输出 `[PASS] tasks-plan consistency (5 tasks, 30 plan steps)` |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | checklist overlay 丢失 | `tools/community/sync_canonical_from_upstream.py:61` | `contracts/superpowers-boundary.yaml:51` 声明 checklist 为 overlay；`capture_superpowers_local_overlays()` 只遍历 `SUPERPOWERS_FULL_FILE_OVERLAYS`；`sync_superpowers()` 调用 `copy_tree()` 重建 skill 目录；未捕获的 checklist 不会被 `apply_superpowers_local_overlays()` 写回 | `rg` 静态追踪到 `SUPERPOWERS_FULL_FILE_OVERLAYS` 在 `capture_superpowers_local_overlays()` 中消费；`sync_superpowers()` 在复制后调用 `apply_superpowers_local_overlays()` |
| 2 | verify report 路径失效 | `docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/verify-change-report.md:18` | archive 已把 workset 移到 `docs/archive/...`；报告仍保留 `docs/small-chain-artifact-quality/2026-04-18-quality-floor/...`；按报告命令复跑时 active 文件不存在 | `git ls-files` 显示 workset 文件在 archive 路径；active 路径命令失败，archive 路径命令通过 |

## 处置阶段

### 决策

处置策略：两个问题均为代码/文档层可修复缺陷，采用最小修复。

失败分类：

| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | 新 checklist overlay 会在 upstream sync 后丢失 | FIXABLE | 先补失败测试，再把 checklist 加入 full-file overlay 列表 |
| 2 | 归档后的 verify report 复跑路径失效 | FIXABLE | 将 verify report 的 workset 文件和复跑命令更新为 archive 路径 |

### FAIL-1: 新 checklist overlay 会在 upstream sync 后丢失

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tools/community/sync_canonical_from_upstream.py:61` 的 full-file overlay 列表缺少 `skills/brainstorming/references/design-completeness-checklist.md` |
| 2 | 修复是否完整？ | 覆盖 capture/apply 路径；`tests/test-community-tools.sh` fixture 现在创建 checklist 并断言 sync 后仍保留 |
| 3 | 是否引入新问题？ | 影响范围为 superpowers sync 的 full-file overlay 捕获集合；新增项是已有 boundary contract 声明的文件，不改变其他 overlay 语义 |
| 4 | 是否需要补充测试覆盖？ | 已补充 `tests/test-community-tools.sh` 回归断言 |

RED:
- 命令：`bash tests/test-community-tools.sh`
- 修复前输出：`FileNotFoundError: ... design-completeness-checklist.md`，随后 `[FAIL] sync_superpowers 应保留 superpowers 本地 overlay，并刷新其余官方正文`

GREEN:
- 命令：`bash tests/test-community-tools.sh`
- 修复后输出：`[PASS] community tools`
- 复现脚本输出：`checklist_exists_after_sync= True`、`checklist_text_after_sync= # local checklist`

### FAIL-2: 归档后的 verify report 复跑路径失效

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/verify-change-report.md:18` 起的 files checked 和复跑命令仍指向归档前 active workset |
| 2 | 修复是否完整？ | 更新 `files checked`、`task-plan mapping`、`fresh verification commands` 三处 active workset 路径 |
| 3 | 是否引入新问题？ | 影响范围为归档报告可复现性；不改变 runtime 代码 |
| 4 | 是否需要补充测试覆盖？ | 使用真实 `check_task_plan_consistency.py` 对 archive 路径复跑；同时 `rg` 确认 report 中不再残留 active workset 路径 |

RED:
- 命令：`python3 tools/community/check_task_plan_consistency.py docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md`
- 修复前输出：`[FAIL] 缺少 tasks 文件: docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md`

GREEN:
- 命令：`python3 tools/community/check_task_plan_consistency.py docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md`
- 修复后输出：`[PASS] tasks-plan consistency (5 tasks, 30 plan steps)`
- 命令：`rg -n "docs/small-chain-artifact-quality/2026-04-18-quality-floor" docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/verify-change-report.md`
- 修复后输出：exit 1，无匹配

### 附加环境事件

第一次 `bash tests/run-all.sh` 在 install systematic 阶段失败，输出 `/Users/lijieli/org-claude-skills/install.sh: line 1905: syntax error near unexpected token 'fi'`。随后当前文件状态下 `bash -n install.sh` exit 0，`bash tests/test-install-systematic.sh` 输出 `Systematic tests passed: 20, skipped: 0`，第二次 `bash tests/run-all.sh` 输出 `All tests passed`。该事件归类为 `ENV_ISSUE`，原因是全量测试期间工作区出现了 Darwin skill / Claude API upstream 相关并发改动；本轮未回滚这些改动。

## 产出

### 修复清单

| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | 新 checklist overlay 会在 upstream sync 后丢失 | full-file overlay 列表漏项 | `tools/community/sync_canonical_from_upstream.py`、`tests/test-community-tools.sh` | `bash tests/test-community-tools.sh` |
| 2 | 归档后的 verify report 复跑路径失效 | report 仍记录 active workset 路径 | `docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/verify-change-report.md` | `python3 tools/community/check_task_plan_consistency.py docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md` |

### 全量测试结果

TEST_CMD: `bash tests/run-all.sh`

结果：
- `All tests passed`
- `skill context budget test` 保留 warning：`design`、`delivery-owner`、`tech-lead` 超 800 行 soft budget

### 阻断清单

| # | 问题 | 阻断原因 | 下一步动作 | 责任归属 |
|---|------|---------|-----------|---------|
| - | - | - | - | - |

### 交接项清单

- 根因分析结论与定位文件：`tools/community/sync_canonical_from_upstream.py:61`、`docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/verify-change-report.md:18`
- 修复范围：`tools/community/sync_canonical_from_upstream.py`、`tests/test-community-tools.sh`、`docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/verify-change-report.md`
- 回归测试清单：`bash tests/test-community-tools.sh`、`bash tests/test-small-chain-boundary.sh`、`bash tests/test-superpowers-boundary.sh`、`python3 tools/community/check_task_plan_consistency.py docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/archive/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md`、`git diff --check`、`bash tests/test-install-systematic.sh`、`bash tests/run-all.sh`
