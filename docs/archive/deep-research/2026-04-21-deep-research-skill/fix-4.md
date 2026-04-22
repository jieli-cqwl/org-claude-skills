# fix-4.md

## 输入分析

- 输入来源清单:
  - `bash tests/run-all.sh` failed at `[22/39] skill output/gate contract test`.
  - Direct reproduction: `bash tests/test-skill-output-and-gate-contract.sh` failed with missing pattern `^## 评审编排$` in `shared/skills/product-manager/SKILL.md`.
  - Diagnostic reads: `tests/test-skill-output-and-gate-contract.sh`, `shared/skills/product-manager/SKILL.md`, and `shared/skills/product-manager/references/review-orchestration-contract.md`.
- work_dir 解析结果: `docs/deep-research/2026-04-21-deep-research-skill`
- 问题数量汇总: 1

差异说明（N > 1 时 REQUIRED）:
- `fix-1.md` addressed a ShellCheck failure in delivery-owner phase3 tests.
- `fix-2.md` addressed product-director output sidecar navigation.
- `fix-3.md` addressed delivery-owner code-review template routing.
- This fix targets product-manager review orchestration visibility: the contract existed, but the skill body missed the required section heading.

## 诊断阶段

### 环境快照

- 当前分支: `codex/deep-research-rename`
- 工作树状态: deep-research rename changes plus three prior CI gate fixes before this report.
- 最近 5 条提交:
  - `3da2415 test: add standard chain local eval runner`
  - `ccdb605 docs: archive delivery owner role research docs`
  - `1e80241 Merge pull request #5 from jieli-cqwl/codex/deep-research-skill`
  - `c9546c2 fix: unblock deep-research ci validation`
  - `0b250b1 docs: verify deep research change`
- 最近改动文件:
  - `shared/skills/deep-research/**`
  - `tests/test-deep-research-skill-contract.sh`
  - `tests/test-deep-research-scripts.py`
  - `install.sh`
  - `README.md`
  - `tests/run-all.sh`
  - `shared/skills/product-director/SKILL.md`
  - `shared/skills/delivery-owner/SKILL.md`
  - `shared/skills/product-manager/SKILL.md`

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Skill output/gate contract failed | `bash tests/run-all.sh` | The suite stopped at `[22/39] skill output/gate contract test`. |
| 1 | Owning test failed directly | `bash tests/test-skill-output-and-gate-contract.sh` | `[FAIL] missing pattern in .../shared/skills/product-manager/SKILL.md: ^## 评审编排$` |

当前环境复现结论:
- 可复现: yes.
- 不可复现时环境差异证据: not applicable.

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Skill output/gate contract failed | H1: The deep-research rename changed product-manager files. | Ran `git diff --name-only origin/main...HEAD | rg 'product-manager|test-skill-output'`; no product-manager changes existed before this fix. | 排除 |
| 1 | Skill output/gate contract failed | H2: The review orchestration contract is missing. | Read `shared/skills/product-manager/references/review-orchestration-contract.md`; it exists and is titled `Review-Orchestration Contract v1`. | 排除 |
| 1 | Skill output/gate contract failed | H3: `product-manager/SKILL.md` references review orchestration but lacks the required `## 评审编排` section heading. | Read `tests/test-skill-output-and-gate-contract.sh:2288-2290` and `shared/skills/product-manager/SKILL.md`; the heading was absent while the contract route existed under workflow references. | 确认 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Skill output/gate contract failed | `shared/skills/product-manager/SKILL.md:67` | The gate expects product-manager review orchestration to be a first-class section. The skill had the route under flow references, but not the heading. | Static trace: `tests/test-skill-output-and-gate-contract.sh:2288-2290` asserts the heading and route; `shared/skills/product-manager/references/review-orchestration-contract.md:1` defines the contract. |

## 处置阶段

### 决策

Add a short `## 评审编排` section that points M-S8 / M-G1 to `references/review-orchestration-contract.md#Review-Orchestration Contract v1`, states 3-view review, and keeps legacy `product-manager-review.md` out of standard-chain runtime control.

失败分类:

| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Skill output/gate contract failed | FIXABLE | Add the missing section, then rerun the owning test and full suite. |

### FAIL-1: Product Manager review orchestration section missing

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/product-manager/SKILL.md:67` lacked the required `## 评审编排` section. |
| 2 | 修复是否完整？ | The new section references the existing review orchestration contract and states the canonical `review_conclusion / issue_ledger` sink. |
| 3 | 是否引入新问题？ | The change is documentation routing only; it does not alter M-S8/M-G1 behavior or completion checks. |
| 4 | 是否需要补充测试覆盖？ | Existing `tests/test-skill-output-and-gate-contract.sh` covers the required heading and contract route. |

RED:
- `bash tests/test-skill-output-and-gate-contract.sh` failed with missing `^## 评审编排$`.
- `bash tests/run-all.sh` failed at `[22/39] skill output/gate contract test`.

GREEN:
- `bash tests/test-skill-output-and-gate-contract.sh` passed.
- `bash tests/test-delivery-owner-phase3-contract.sh` passed after this fix.
- `bash tests/test-deep-research-skill-contract.sh` passed after this fix.

## 产出

### 修复清单

| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Skill output/gate contract failed | Missing review orchestration section in Product Manager skill body | `shared/skills/product-manager/SKILL.md` | `bash tests/test-skill-output-and-gate-contract.sh`; `bash tests/run-all.sh` |

### 全量测试结果

TEST_CMD: `bash tests/run-all.sh`

- 通过: all 39 groups completed; final output `All tests passed`.
- 失败: none.
- 跳过: none in systematic tests; context-budget WARN_ALLOWED entries are governed by existing owner/expiry exemptions.

### 阻断清单（全部/部分非 FIXABLE 时必填）

| # | 问题 | 阻断原因 | 下一步动作 | 责任归属 |
|---|------|---------|-----------|---------|
| none | none | none | none | none |

### 交接项清单

- 根因分析结论与定位文件: `shared/skills/product-manager/SKILL.md:67`.
- 修复范围与回归测试清单: one Product Manager section plus skill output/gate contract and full suite.
- 非 FIXABLE 问题的后续处理动作: none.
