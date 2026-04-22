# fix-9.md

## 输入分析

- 输入来源清单:
  - Final `bash tests/run-all.sh` after `fix-8` failed at `[8/39] runtime integrity test`.
  - Failure message: installed runtime retained a bare runtime doc reference in `skill-harness/references/permission-script-contract.md`.
  - Diagnostic reads: `tests/test-runtime-integrity.sh`, `shared/skills/skill-harness/references/permission-script-contract.md`, and `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json`.
- work_dir 解析结果: `docs/deep-research/2026-04-21-deep-research-skill`
- 问题数量汇总: 1

差异说明（N > 1 时 REQUIRED）:
- `fix-8.md` hardened install-systematic log assertions.
- This fix targets runtime integrity after installation: active skill runtime docs must not retain bare global reference fragments from archived paths.

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
| 1 | Runtime integrity failed on bare doc reference | `bash tests/run-all.sh` | Suite stopped at `[8/39] runtime integrity test`; installed skill-harness reference line was printed as violation. |
| 1 | Owning test failed directly before fix | `bash tests/test-runtime-integrity.sh` | The bare runtime reference scan rejected the installed `permission-script-contract.md` line. |

当前环境复现结论:
- 可复现: yes.
- 不可复现时环境差异证据: not applicable.

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Runtime integrity failed | H1: Installed runtime should include archived docs, so the test is too strict. | Read `tests/test-runtime-integrity.sh:256-306`; active runtime docs must not retain bare `reference / protocols / rules` fragments unless explicitly local or runtime-prefixed. | 排除 |
| 1 | Runtime integrity failed | H2: `permission-script-contract.md` contains an archived path whose `rules/permission-profiles.md` segment is parsed as a bare runtime doc reference. | Read `shared/skills/skill-harness/references/permission-script-contract.md:10`; the archived path contained `rules/permission-profiles.md`. | 确认 |
| 1 | Runtime integrity failed | H3: Removing the inline archived path loses ownership evidence. | Read `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json`; full source paths and ownership evidence remain recorded there. | 排除 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Runtime integrity failed on bare doc reference | `shared/skills/skill-harness/references/permission-script-contract.md:10` | The active runtime reference doc embedded archived source paths. The `rules/permission-profiles.md` segment matched the runtime bare-reference scanner after installation. | Static trace: `tests/test-runtime-integrity.sh:273-300` defines the bare-reference pattern; `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json` keeps the full archive source paths as the ownership evidence source. |

## 处置阶段

### 决策

Replace inline archived paths in the active runtime doc with asset ids and point to `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json` for path-level evidence. This removes the runtime bare reference while preserving traceability.

失败分类:

| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Runtime integrity failed on bare doc reference | FIXABLE | Rewrite active runtime doc line, then rerun runtime integrity and skill-harness gates. |

### FAIL-1: Bare runtime doc reference in skill-harness

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/skill-harness/references/permission-script-contract.md:10` embedded an archived path segment parsed as a bare runtime doc reference. |
| 2 | 修复是否完整？ | The active runtime line now references asset ids and the fixture that stores full archived paths. |
| 3 | 是否引入新问题？ | `runtime integrity`, `skill-harness migration`, and `skill-harness contract` passed. |
| 4 | 是否需要补充测试覆盖？ | Existing `tests/test-runtime-integrity.sh` covers this runtime installation path. |

RED:
- `bash tests/run-all.sh` failed at `[8/39] runtime integrity test`.

GREEN:
- `bash tests/test-runtime-integrity.sh` passed.
- `bash tests/test-skill-harness-migration.sh` passed.
- `bash tests/test-skill-harness-contract.sh` passed.

## 产出

### 修复清单

| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Runtime integrity bare reference failure | Active runtime doc embedded archived `rules/...` path segment | `shared/skills/skill-harness/references/permission-script-contract.md` | `bash tests/test-runtime-integrity.sh`; `bash tests/test-skill-harness-migration.sh`; `bash tests/test-skill-harness-contract.sh`; `bash tests/run-all.sh` |

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

- 根因分析结论与定位文件: `shared/skills/skill-harness/references/permission-script-contract.md:10`.
- 修复范围与回归测试清单: one active skill-harness reference doc plus runtime integrity and skill-harness gates.
- 非 FIXABLE 问题的后续处理动作: none.
