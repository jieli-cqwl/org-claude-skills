## 输入分析
- 输入来源清单：用户确认采用 code review Finding 1；review 结论指向 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:18-109`，并给出两组复现现象：删除 `phase-1/code-review-result.json` 后仍返回 0；将 `phase-1/unit-1/test-cases.json` 替换为 stub object 后仍返回 0。
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：1

## 诊断阶段

### 环境快照
- 当前分支：`codex/standard-chain-contract-foundation`
- 工作树状态：`M tests/test-standard-chain-readiness-gate.sh`、`M tools/community/validate_standard_chain_readiness.py`
- 最近 5 条提交：
  - `5c3ef5a feat: complete standard-chain canonical cutover`
  - `ab27358 feat: add standard chain projection and replay`
  - `28f4240 feat: add standard chain user decision writer`
  - `66d0245 feat: add standard chain validator stack`
  - `f5b514d feat: add standard chain runtime state tooling`
- 最近改动文件：
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | readiness gate 未覆盖完整交付工件集 | 1. 从 golden pilot 复制 `sample-feature`。2. 删除 `phase-1/code-review-result.json`。3. 运行 `python3 tools/community/validate_standard_chain_readiness.py --phase-dir ...`。 | 修复前命令退出码为 0，缺失 `code-review-result.json` 未被 gate 拦截。 |
| 2 | readiness gate 未验证 unit/task 上游 payload | 1. 从 golden pilot 复制 `sample-feature`。2. 将 `phase-1/unit-1/test-cases.json` 改为 `{\"artifact_type\":\"test-cases\"}`。3. 运行同一命令。 | 修复前命令退出码为 0，非法 `test-cases.json` 未被 phase validator 拦截。 |

当前环境复现结论:
- 可复现：是。新增 RED 用例后，修复前 `bash tests/test-standard-chain-readiness-gate.sh` 会在 “missing code-review-result” 场景失败，证明 review 现象真实存在。
- 不可复现时环境差异证据：无。

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | readiness gate 未覆盖完整工件 | `assert_required_phase_files()` 的必需列表只覆盖 closeout 子集，所以缺失 `code-review-result.json` 不会失败。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:18-32,73-77`；再用删除 `code-review-result.json` 的 RED 用例执行 `bash tests/test-standard-chain-readiness-gate.sh`。 | 确认。修复前列表缺失该文件，RED 复现通过。 |
| 2 | readiness gate 未覆盖 unit/task 上游 payload | `build_phase_scenario()` 只把 `brief + REQUIRED_PHASE_FILES` 喂给 phase validator，没有把 `units/*.json`、`unit-*/test-cases.json`、`developer-report.json`、`verify-result.json` 加入场景。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:98-125` 的静态调用链；再用 stub `test-cases.json` 的 RED 用例执行 `bash tests/test-standard-chain-readiness-gate.sh`。 | 确认。修复前 scenario 缺少这些上游 payload，非法 `test-cases.json` 未被发现。 |
| 3 | artifact registry active entries 已足够覆盖所有交付物 | `assert_required_active_entries()` 的 `REQUIRED_ACTIVE_TYPES` 也许已经保证了 code-review / task artifact 的存在。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:42-49,110-118`。 | 排除。active type 只包含 `plan/tasks/delivery-state/qa-result/signoff-package/user-decision`，无法覆盖 review/test-cases/task 级工件。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | readiness gate 未覆盖完整交付工件集 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:18-41,98-125,205-216` | `validate_phase_dir()` 只校验 `REQUIRED_PHASE_FILES` 子集，并通过 `run_phase_validator()` 调用 `build_phase_scenario()`；后者只装载 `brief + REQUIRED_PHASE_FILES`，导致 `code-review-result.json`、`units/*.json`、`unit-*/test-cases.json`、task 级 `developer-report.json`/`verify-result.json` 既不做存在性断言，也不进入 canonical schema validator。 | 等效静态追踪：`validate_phase_dir()` 在 `205-216` 行调用 `run_phase_validator()`；`run_phase_validator()` 在 `135-153` 行调用 `build_phase_scenario()`；`build_phase_scenario()` 在 `121-125` 行依赖 `collect_validation_artifact_paths()`；修复前 `collect_validation_artifact_paths()` 不存在，场景来源仅限 `REQUIRED_PHASE_FILES`。 |

## 处置阶段

### 决策
处置策略：保持 canonical-only 行为不变，只对 readiness gate 做最小收紧。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | readiness gate 未覆盖完整交付工件集 | FIXABLE | 先补 RED 回归，再把 phase required set 和 validation scenario 扩到完整交付工件集，最后跑 closeout 相关回归。 |

### FAIL-1: Readiness gate 未覆盖完整交付工件集

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:18-41,98-125` 只覆盖 closeout 子集，没有把 review/unit/task 级 canonical artifact 纳入存在性和 schema 校验。 |
| 2 | 修复是否完整？ | 已同时覆盖 phase 级 `phase-prd/design/code-review-result/views/phase-operational.html`、unit 级 `units/UNIT-*.json` / `test-cases.json`、task 级 `developer-report.json` / `verify-result.json`。`validate_phase_dir()` 现在既断言这些工件存在，也把 JSON 工件装入 scenario 交给 phase validator。 |
| 3 | 是否引入新问题？ | 收紧 gate 后，原先被漏检的残缺 fixture 会被正确拦截；为避免把 replay oracle 当普通 artifact 送进 schema validator，新增了 `NON_ARTIFACT_PHASE_FILES` 排除逻辑。 |
| 4 | 是否需要补充测试覆盖？ | 需要。已在 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh` 新增缺失 `code-review-result.json`、缺失 `developer-report.json`、非法 `test-cases.json` 三个回归场景。 |

RED: `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh` 在修复前因 “readiness gate should reject phase when code-review-result.json is missing” 失败。
GREEN:
- `python3 -m py_compile /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-cutover.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-skill-output-and-gate-contract.sh`
- `git -C /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation diff --check`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | readiness gate 未覆盖完整交付工件集 | phase required set 与 validation scenario 只覆盖 closeout 子集 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py` | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh` |

### 全量测试结果
TEST_CMD:
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-cutover.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-skill-output-and-gate-contract.sh`
- `python3 -m py_compile /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py`
- `git -C /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation diff --check`

通过: 5 / 失败: 0 / 跳过: 0

### 交接项清单
- 根因分析结论与定位文件:行号：`/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:18-41,98-125,205-216`
- 修复范围与回归测试清单：readiness gate + 3 个新增负向回归场景
- 非 FIXABLE 问题的后续处理动作：无。本轮问题归类为 `FIXABLE`
