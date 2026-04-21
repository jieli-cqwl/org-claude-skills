# fix-2.md

## 输入分析

- 输入来源清单:
  - `bash tests/run-all.sh` failed at `[18/39] product stability guidance contract test`.
  - Direct reproduction: `bash tests/test-product-stability-guidance-contract.sh` failed with missing pattern `brief\.lock\.json` in `shared/skills/product-director/SKILL.md`.
  - Diagnostic reads: `shared/skills/product-director/SKILL.md`, `shared/skills/product-director/references/output-contract.md`, `shared/skills/product-director/scripts/completion_check.sh`, `contracts/product-artifacts.yaml`, and `tests/test-product-stability-guidance-contract.sh`.
- work_dir 解析结果: `docs/deep-research/2026-04-21-deep-research-skill`
- 问题数量汇总: 1

差异说明（N > 1 时 REQUIRED）:
- Previous `fix-1.md` addressed a ShellCheck `SC2016` CI failure in `tests/test-delivery-owner-phase3-contract.sh`.
- This fix targets a different gate: product-director stability guidance drift between `SKILL.md` and the legacy sidecar contract.

## 诊断阶段

### 环境快照

- 当前分支: `codex/deep-research-rename`
- 工作树状态: deep-research rename changes plus one failing-gate fix before this report.
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
  - `tests/test-single-source-layout.sh`
  - `tests/test-install-smoke.sh`
  - `tests/test-runtime-integrity.sh`
  - `tests/test-codex-skill-adapter.sh`
  - `tests/run-all.sh`
  - `shared/skills/product-director/SKILL.md`

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Full suite failed on product stability guidance | `bash tests/run-all.sh` | The suite stopped at `[18/39] product stability guidance contract test`. |
| 1 | Owning test failed directly | `bash tests/test-product-stability-guidance-contract.sh` | `[FAIL] missing pattern in .../shared/skills/product-director/SKILL.md: brief\.lock\.json` |

当前环境复现结论:
- 可复现: yes.
- 不可复现时环境差异证据: not applicable.

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Product stability guidance gate failed | H1: The deep-research rename changed product-director files. | Ran `git diff --name-only origin/main...HEAD`; product-director was absent before the fix. | 排除 |
| 1 | Product stability guidance gate failed | H2: The product-director test still expects legacy lock sidecars while `SKILL.md` only documents canonical JSON outputs. | Read `tests/test-product-stability-guidance-contract.sh:50-51` and `shared/skills/product-director/SKILL.md:75-76`; test expects `brief.lock.json` / `phase-{N}/prd.lock.json`, while `SKILL.md` listed only `brief.json` / `phase-prd.json`. | 确认 |
| 1 | Product stability guidance gate failed | H3: Legacy sidecars are obsolete and the test should be relaxed. | Read `shared/skills/product-director/references/output-contract.md:9-10`, `contracts/product-artifacts.yaml:7-15`, and `shared/skills/product-director/scripts/completion_check.sh:323-341`; these still define and validate legacy sidecars. | 排除 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Product stability guidance gate failed | `shared/skills/product-director/SKILL.md:75` | The test requires the Product Director skill to route both canonical JSON outputs and legacy markdown lane sidecars. The output contract and completion check still define `brief.lock.json` and `phase-{N}/prd.lock.json`, but the skill navigation did not mention them. | Static trace: `tests/test-product-stability-guidance-contract.sh:50-51` asserts sidecar names; `shared/skills/product-director/references/output-contract.md:9-10` defines them; `shared/skills/product-director/scripts/completion_check.sh:323-341` validates them. |

## 处置阶段

### 决策

Add one Product Director output navigation bullet that names the legacy markdown lane sidecars and explicitly keeps them out of the standard-chain runtime authority. This preserves the current canonical `brief.json / phase-prd.json` rule.

失败分类:

| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Product stability guidance gate failed | FIXABLE | Add the missing output-contract route, then rerun the owning test and full suite. |

### FAIL-1: Product Director output sidecar route missing

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/product-director/SKILL.md:75` did not mention legacy `brief.lock.json` / `phase-{N}/prd.lock.json` sidecars while the contract and gate still require them. |
| 2 | 修复是否完整？ | The added bullet references both sidecars and the authoritative `references/output-contract.md#Director-Output Contract v1` route. |
| 3 | 是否引入新问题？ | The bullet states the sidecars are not standard-chain runtime truth, preserving the existing canonical JSON boundary. |
| 4 | 是否需要补充测试覆盖？ | Existing `tests/test-product-stability-guidance-contract.sh` covers the changed wording. |

RED:
- `bash tests/test-product-stability-guidance-contract.sh` failed with missing `brief\.lock\.json`.
- `bash tests/run-all.sh` failed at `[18/39] product stability guidance contract test`.

GREEN:
- `bash tests/test-product-stability-guidance-contract.sh` passed.
- `bash tests/test-deep-research-skill-contract.sh` passed after the product-director fix.

## 产出

### 修复清单

| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Product stability guidance gate failed | Missing legacy sidecar navigation in Product Director skill output section | `shared/skills/product-director/SKILL.md` | `bash tests/test-product-stability-guidance-contract.sh`; `bash tests/run-all.sh` |

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

- 根因分析结论与定位文件: `shared/skills/product-director/SKILL.md:75`.
- 修复范围与回归测试清单: one Product Director skill line plus product stability gate and full suite.
- 非 FIXABLE 问题的后续处理动作: none.
