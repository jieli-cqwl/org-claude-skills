# fix-8.md

## 输入分析

- 输入来源清单:
  - Final `bash tests/run-all.sh` after `fix-7` failed at `[5/39] install systematic test`.
  - Failure message: `same-version product split repair should not silently skip`.
  - Direct diagnostic reads: `/tmp/org_install_product_split_second.out`, `tests/test-install-systematic.sh`, and `install.sh`.
- work_dir 解析结果: `docs/deep-research/2026-04-21-deep-research-skill`
- 问题数量汇总: 1

差异说明（N > 1 时 REQUIRED）:
- `fix-7.md` addressed ShellCheck on the Delivery Owner phase3 contract test.
- This fix targets a different test fragility: install logs can be treated as non-text by plain `grep` when full-suite install output interleaves target logs.

## 诊断阶段

### 环境快照

- 当前分支: `codex/deep-research-rename`
- 当前提交 before amend: one commit ahead of `origin/main`.
- 最近 5 条提交:
  - current rename commit
  - `0c07c46 test: add delivery-owner positive dispatch eval`
  - `ec10b1c chore: update delivery owner control plane and eval baseline`
  - `88fab87 Merge branch 'skill-harness-std-governance'`
  - `beba1b4 fix: validate user decision canonical shape`

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Product split repair assertion failed in full suite | `bash tests/run-all.sh` | Full suite stopped at install systematic product split repair assertion. |
| 1 | Same install log matched with text-forced grep | `grep -a -q "运行面不完整" /tmp/org_install_product_split_second.out` | Exit code 0 on the failed-run log. |

当前环境复现结论:
- 可复现: yes in full-suite path.
- 不可复现时环境差异证据: not applicable.

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Product split assertion failed | H1: The product split repair did not run. | Checked restored files immediately before the log assertion in the test; direct rerun restored both missing skill files and passed file existence assertions. | 排除 |
| 1 | Product split assertion failed | H2: Plain `grep` treated the captured install output as non-text and failed even though the marker bytes existed. | Compared `grep -q "运行面不完整"` and `grep -a -q "运行面不完整"` against `/tmp/org_install_product_split_second.out`; plain grep failed, text-forced grep passed. | 确认 |
| 1 | Product split assertion failed | H3: The full Chinese sentence is too brittle because install target logs can interleave. | Inspected failed log; target output interrupted the longer message, while the stable marker `运行面不完整` remained present. | 确认 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Product split repair assertion failed in full suite | `tests/test-install-systematic.sh:182` | The assertion used plain `grep` on an install log captured from target installation. In full-suite runs the log can contain interleaved or non-text-classified bytes, so plain grep returned 1 even though the repair marker was present. | Static trace: `tests/test-install-systematic.sh:176-181` already proves repair by deleting and restoring two skill files; line 182 now uses `grep -a` with the stable marker to prove the non-silent reinstall log path. |

## 处置阶段

### 决策

Keep the file restoration assertions as the primary proof and make the log assertion robust by using `grep -a -q "运行面不完整"`. This preserves the behavior check while avoiding false negatives from log stream classification and target-output interleaving.

失败分类:

| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Product split repair assertion failed in full suite | FIXABLE | Use text-forced grep on the stable marker, then rerun ShellCheck, owning systematic test, and full suite. |

### FAIL-1: Product split repair log assertion

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tests/test-install-systematic.sh:182` used plain grep on an install log that full-suite execution can classify as non-text. |
| 2 | 修复是否完整？ | The assertion now uses `grep -a` and matches the stable marker while existing file restoration checks still prove the repair happened. |
| 3 | 是否引入新问题？ | ShellCheck passed and the full install systematic test passed 20 items with 0 skipped. |
| 4 | 是否需要补充测试覆盖？ | Existing `tests/test-install-systematic.sh` covers this exact product split repair scenario. |

RED:
- `bash tests/run-all.sh` failed at `[5/39] install systematic test`.
- `grep -q "运行面不完整" /tmp/org_install_product_split_second.out` returned 1 on the failed-run log.

GREEN:
- `grep -a -q "运行面不完整" /tmp/org_install_product_split_second.out` returned 0 on the failed-run log.
- `shellcheck -x tests/test-install-systematic.sh` passed.
- `bash tests/test-install-systematic.sh` passed with `Systematic tests passed: 20, skipped: 0`.

## 产出

### 修复清单

| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Product split repair log assertion false negative | Plain grep on non-text-classified install log | `tests/test-install-systematic.sh` | `shellcheck -x tests/test-install-systematic.sh`; `bash tests/test-install-systematic.sh`; `bash tests/run-all.sh` |

### 全量测试结果

TEST_CMD: `bash tests/run-all.sh`

- 通过: pending final rerun after this report.
- 失败: pending final rerun after this report.
- 跳过: pending final rerun after this report.

### 阻断清单（全部/部分非 FIXABLE 时必填）

| # | 问题 | 阻断原因 | 下一步动作 | 责任归属 |
|---|------|---------|-----------|---------|
| none | none | none | none | none |

### 交接项清单

- 根因分析结论与定位文件: `tests/test-install-systematic.sh:182`.
- 修复范围与回归测试清单: one test assertion plus ShellCheck, install systematic test, and final full suite.
- 非 FIXABLE 问题的后续处理动作: none.
