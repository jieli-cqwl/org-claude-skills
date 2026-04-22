# fix-5.md

## 输入分析

- 输入来源清单:
  - `bash tests/run-all.sh` failed at `[32/39] skill format unification test`.
  - Direct reproduction: `bash tests/test-skill-format-unification.sh` first failed with `dot flow definition missing in: shared/skills/design/SKILL.md`.
  - After fixing `design`, the same owning test failed with `dot flow definition missing in: shared/skills/delivery-owner/SKILL.md`.
  - Diagnostic reads: `tests/test-skill-format-unification.sh`, `shared/skills/design/SKILL.md`, and `shared/skills/delivery-owner/SKILL.md`.
- work_dir 解析结果: `docs/deep-research/2026-04-21-deep-research-skill`
- 问题数量汇总: 2

差异说明（N > 1 时 REQUIRED）:
- `fix-1.md` addressed a ShellCheck failure in delivery-owner phase3 tests.
- `fix-2.md` addressed product-director output sidecar navigation.
- `fix-3.md` addressed delivery-owner code-review template routing.
- `fix-4.md` addressed product-manager review orchestration visibility.
- This fix targets a different gate: unified skill documentation format requires DOT flow definitions in selected orchestration skills.

## 诊断阶段

### 环境快照

- 当前分支: `codex/deep-research-rename`
- 工作树状态: deep-research rename changes plus four prior gate fixes before this report.
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
  - `shared/skills/design/SKILL.md`

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Design skill format gate failed | `bash tests/test-skill-format-unification.sh` | `[FAIL] dot flow definition missing in: shared/skills/design/SKILL.md` |
| 2 | Delivery-owner skill format gate failed | `bash tests/test-skill-format-unification.sh` after design fix | `[FAIL] dot flow definition missing in: shared/skills/delivery-owner/SKILL.md` |

当前环境复现结论:
- 可复现: yes.
- 不可复现时环境差异证据: not applicable.

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Design skill format gate failed | H1: The gate forbids Mermaid and requires DOT in every target file. | Read `tests/test-skill-format-unification.sh:13-37`; target files include `shared/skills/design/SKILL.md`, and lines 34-36 fail unless a DOT fence or `digraph` exists. | 确认 |
| 1 | Design skill format gate failed | H2: `design/SKILL.md` already had a hidden DOT block and the test pattern was too narrow. | Searched `shared/skills/design/SKILL.md` for DOT fence / `digraph`; no match existed before the fix. | 排除 |
| 2 | Delivery-owner skill format gate failed | H1: After design was fixed, the same target-list rule reached `delivery-owner/SKILL.md`. | Re-ran `bash tests/test-skill-format-unification.sh`; it failed on `shared/skills/delivery-owner/SKILL.md`. | 确认 |
| 2 | Delivery-owner skill format gate failed | H2: Delivery Owner had Mermaid syntax that should be migrated instead of adding a new DOT block. | Searched `shared/skills/delivery-owner/SKILL.md` for Mermaid and DOT flow markers; no flow block existed before the fix. | 排除 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Design skill format gate failed | `shared/skills/design/SKILL.md:87` | The format unification gate targets `design/SKILL.md` and requires a DOT flow definition, but the skill only had numbered textual workflow steps under `## 流程`. | Static trace: `tests/test-skill-format-unification.sh:13-37` lists the target and assertion; `shared/skills/design/SKILL.md:87-122` now contains the DOT flow before the numbered steps. |
| 2 | Delivery-owner skill format gate failed | `shared/skills/delivery-owner/SKILL.md:75` | The same gate targets `delivery-owner/SKILL.md` and requires a DOT flow definition, but the skill only had Phase headings and prose under `## 流程`. | Static trace: `tests/test-skill-format-unification.sh:13-37` lists the target and assertion; `shared/skills/delivery-owner/SKILL.md:75-112` now contains the DOT flow before Phase 1. |

## 处置阶段

### 决策

Add one DOT flow to each affected skill, using only existing workflow states and loops. The change is documentation format alignment; it does not alter runtime authority, gate logic, or execution stages.

失败分类:

| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Design skill format gate failed | FIXABLE | Add DOT flow under `## 流程`, then rerun owning test and full suite. |
| 2 | Delivery-owner skill format gate failed | FIXABLE | Add DOT flow under `## 流程`, then rerun owning test and full suite. |

### FAIL-1: Design DOT flow missing

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/design/SKILL.md:87` lacked a DOT flow block required by `tests/test-skill-format-unification.sh`. |
| 2 | 修复是否完整？ | The added `design_flow` covers canonical input read, code/runtime scan, co-creation, decision exploration, review loop, final confirmation, and `design.json` output. |
| 3 | 是否引入新问题？ | The block is documentation-only and uses DOT, so it satisfies the gate without changing design execution rules. |
| 4 | 是否需要补充测试覆盖？ | Existing `tests/test-skill-format-unification.sh` covers the required DOT definition. |

### FAIL-2: Delivery Owner DOT flow missing

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/delivery-owner/SKILL.md:75` lacked a DOT flow block required by `tests/test-skill-format-unification.sh`. |
| 2 | 修复是否完整？ | The added `delivery_owner_flow` covers kickoff, user confirmation, task verification loop, Phase 3 gates, signoff, and block paths. |
| 3 | 是否引入新问题？ | The block is documentation-only and preserves existing Phase 1-4 prose and gate definitions. |
| 4 | 是否需要补充测试覆盖？ | Existing `tests/test-skill-format-unification.sh` covers the required DOT definition. |

RED:
- `bash tests/test-skill-format-unification.sh` failed with missing DOT flow in `shared/skills/design/SKILL.md`.
- After fixing Design, `bash tests/test-skill-format-unification.sh` failed with missing DOT flow in `shared/skills/delivery-owner/SKILL.md`.
- `bash tests/run-all.sh` failed at `[32/39] skill format unification test`.

GREEN:
- `bash tests/test-skill-format-unification.sh` passed.
- `bash tests/run-all.sh` passed with all 39 groups completed and final output `All tests passed`.

## 产出

### 修复清单

| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Design skill format gate failed | Missing DOT flow in selected skill target | `shared/skills/design/SKILL.md` | `bash tests/test-skill-format-unification.sh`; `bash tests/run-all.sh` |
| 2 | Delivery-owner skill format gate failed | Missing DOT flow in selected skill target | `shared/skills/delivery-owner/SKILL.md` | `bash tests/test-skill-format-unification.sh`; `bash tests/run-all.sh` |

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

- 根因分析结论与定位文件: `shared/skills/design/SKILL.md:87`, `shared/skills/delivery-owner/SKILL.md:75`.
- 修复范围与回归测试清单: two skill documentation DOT blocks plus format gate and full suite.
- 非 FIXABLE 问题的后续处理动作: none.
