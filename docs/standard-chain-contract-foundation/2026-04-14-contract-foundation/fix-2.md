## 输入分析
- 输入来源清单：用户确认继续跟进剩余 review findings；本轮处理 Finding 2（`validate_standard_chain_phase.py --phase-dir` 无法验证真实 phase 目录）和 Finding 3（readiness fixture 缺失 `validator_green / replay_green` 被默认为 PASS）。
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：2

差异说明（N > 1 时 REQUIRED）:
- 上轮 `fix-1.md` 只收紧了 readiness closeout 对完整交付工件集的校验。
- 本轮不再继续扩大 closeout 工件面，而是处理两个遗留 validator 缺陷：让 `validate_standard_chain_phase.py --phase-dir` 能直接吃真实 canonical phase 目录，并把 cutover fixture 里的 green 信号改成缺失即失败。
- 与上一轮相比，本轮策略明确区分两条语义：`readiness gate` 负责 closeout 时的“完整交付物必须齐”，`phase validator` 负责“当前阶段已有 canonical 工件必须能在真实 phase-dir 上被顺序 validator 正常消费”，不再把晚期工件误设成早期阶段的硬依赖。

## 诊断阶段

### 环境快照
- 当前分支：`codex/standard-chain-contract-foundation`
- 工作树状态：
  - `M tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json`
  - `M tests/test-standard-chain-readiness-gate.sh`
  - `M tests/test-standard-chain-validator-stack.sh`
  - `M tools/community/normalize_canonical_artifact.py`
  - `M tools/community/validate_standard_chain_readiness.py`
- 最近 5 条提交：
  - `c17ca80 fix: tighten standard-chain readiness gate`
  - `5c3ef5a feat: complete standard-chain canonical cutover`
  - `ab27358 feat: add standard chain projection and replay`
  - `28f4240 feat: add standard chain user decision writer`
  - `66d0245 feat: add standard chain validator stack`
- 最近改动文件：
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/normalize_canonical_artifact.py`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-validator-stack.sh`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `validate_standard_chain_phase.py --phase-dir` 无法处理真实 phase 目录 | 运行 `python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1` | 修复前命令在 `normalize_canonical_artifact.py` 里尝试读取 `phase-1/scenario.json`，抛出 `FileNotFoundError`。 |
| 2 | readiness fixture 缺失 green 信号仍被视为通过 | 运行 `python3 tools/community/validate_standard_chain_readiness.py --fixture tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json --expect-freeze-quarantine` | 修复前 `failed-cutover.json` 即使没有 `validator_green / replay_green`，仍退出 0。 |
| 3 | phase-dir builder 若把晚期工件设为硬必需，会误伤上游技能 | 检查 `product/design/test-design/tech-lead` 技能里的“完成前必须运行”命令，并对照它们各自声明的 canonical 输出路径。 | 这些技能都要求在更早阶段运行 `validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`，因此 phase-dir loader 不能把 `developer-report / verify-result / signoff-package` 等晚期工件当成硬必需。 |

当前环境复现结论:
- 可复现：是。问题 1 在当前环境能稳定复现 `FileNotFoundError`；问题 2 在当前环境能稳定复现“缺失 green 仍返回 0”。
- 不可复现时环境差异证据：无。

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | phase-dir 命令失败 | 根因在 `validate_standard_chain_phase.py` 本身，它没有正确透传 `--phase-dir`。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_phase.py:89-103`。 | 排除。orchestrator 确实把 `--phase-dir` 原样传给了五层 validator。 |
| 2 | phase-dir 命令失败 | 根因在 `normalize_canonical_artifact.py`，它把 `--phase-dir` 解析成 `phase_dir/scenario.json`，真实 phase 目录没有这个文件。 | 运行复现命令并检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/normalize_canonical_artifact.py:23-31` 的旧实现。 | 确认。`FileNotFoundError` 直接来自这里。 |
| 3 | phase-dir 命令失败 | 可以直接把 closeout 用的“完整交付工件集”复制到 phase-dir builder，当成所有阶段的硬必需。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/{product,design,test-design,tech-lead}/SKILL.md` 的 canonical 输出路径与完成前命令。 | 排除。上游技能在 design/test-design/tech-lead 之前并不会生成晚期工件，这样会误伤早期阶段。 |
| 4 | fixture 缺失 green 仍通过 | 问题来自 `expect_freeze_quarantine` 分支没有检查 `validator_green / replay_green`。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:174-187`。 | 排除。green 检查在 `expect_freeze_quarantine` 分支之前执行。 |
| 5 | fixture 缺失 green 仍通过 | 问题来自 `.get(..., True)` 把缺失字段当作 `True`。 | 检查同一文件 `183-186` 行的旧实现，并用缺失字段的 `failed-cutover.json` 复现。 | 确认。字段缺失会被默认成通过。 |
| 6 | fixture 缺失 green 仍通过 | 测试夹具和回归脚本本身把“缺失 green 也通过”固化成了正向用例。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json` 和 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh:83-86` 的旧状态。 | 确认。正向 fixture 缺失 green 字段，测试因此没覆盖 fail-closed 语义。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | `validate_standard_chain_phase.py --phase-dir` 无法处理真实 phase 目录 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/normalize_canonical_artifact.py:56-143` | `validate_standard_chain_phase.py` 只是顺序调用五层 validator；第一层 `normalize_canonical_artifact.py` 在 `--phase-dir` 分支只认 `scenario.json`，导致真实 phase 目录在进入 schema/rules/projection 之前就失败。修复后改成：最小必需工件为 `brief + phase-prd + unit-definition`，其余 canonical 工件“存在即装载并校验”，并在存在 projection-manifest 时要求对应 HTML 存在。 | 等效静态追踪：`validate_standard_chain_phase.py:89-103` 调用 `normalize_canonical_artifact.py --phase-dir`；`normalize_canonical_artifact.py:78-143` 现在在缺少 `scenario.json` 时转向 `build_phase_scenario_from_dir()`，由真实 phase 目录构造 validator scenario。 |
| 2 | readiness fixture 缺失 green 信号仍通过 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:174-186`、`/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json:52-55` | 旧代码把 `validator_green / replay_green` 缺失解释成 `True`，同时正向 fixture 也没有显式写出这两个字段，导致缺失证据被误判为成功。修复后要求两个字段必须显式为 `true`，并让正向 fixture 自带明确 green 证明。 | 等效静态追踪：`validate_standard_chain_readiness.py:174-186` 的 `assert_fixture_rollback_contract()` 直接决定 fixture 判定；测试脚本 `tests/test-standard-chain-readiness-gate.sh:83-105` 用显式 green 的 fixture 做正向用例，再用删掉字段的临时 fixture 做负向回归。 |
| 2 | readiness fixture 缺失 green 信号仍通过 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:174-186`、`/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json:52-55` | 旧代码把 `validator_green / replay_green` 缺失解释成 `True`，同时正向 fixture 也没有显式写出这两个字段，导致缺失证据被误判为成功。修复后要求两个字段必须显式为 `true`，并让正向 fixture 自带明确 green 证明。 | 等效静态追踪：`validate_standard_chain_readiness.py:174-186` 的 `assert_fixture_rollback_contract()` 直接决定 fixture 判定；测试脚本 `tests/test-standard-chain-readiness-gate.sh:83-105` 用显式 green 的 fixture 做正向用例，再用删掉字段的临时 fixture 做负向回归。 |

## 处置阶段

### 决策
处置策略：
1. 在 `normalize_canonical_artifact.py` 增加真实 phase-dir 的 scenario builder，但保持 `validate_standard_chain_phase.py` 继续只做顺序编排，不在 orchestrator 中新增私有兜底规则。
2. 对 phase-dir builder 采用“最小必需 + 已存在即校验”的阶段友好模式，避免把 closeout 的完整工件集错误施加到 product/design/test-design/tech-lead。
3. 对 readiness fixture 改成显式 `true` 才算 green，并同步修正正向 fixture 与负向回归。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | `validate_standard_chain_phase.py --phase-dir` 无法处理真实 phase 目录 | FIXABLE | 在 normalizer 层补 phase-dir scenario builder，并补真实/早期 phase-dir 回归。 |
| 2 | readiness fixture 缺失 green 信号仍通过 | FIXABLE | 改成显式 `true` 才通过，并修正 fixture 与负向回归。 |

### FAIL-1: `validate_standard_chain_phase.py --phase-dir` 无法处理真实 phase 目录

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/normalize_canonical_artifact.py:56-143` 的 `--phase-dir` 分支只认 `scenario.json`，真实 canonical phase 目录没有这个测试专用文件。 |
| 2 | 修复是否完整？ | 已支持两类 phase-dir：有 `scenario.json` 的测试夹具继续走原路径；无 `scenario.json` 的真实 phase 目录改由 `build_phase_scenario_from_dir()` 从 canonical JSON + projection 物料构造 scenario。并额外验证了 golden pilot 真实 phase 目录和“只有上游工件”的早期 phase 目录两类场景。 |
| 3 | 是否引入新问题？ | 中途发现把晚期工件做成硬必需会误伤早期技能，于是改成“必需 `brief + phase-prd + units/UNIT-*.json`，其余存在即校验”的阶段友好模式。 |
| 4 | 是否需要补充测试覆盖？ | 需要。已在 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-validator-stack.sh` 新增真实 golden pilot phase-dir 和 upstream-only phase-dir 两个回归。 |

RED:
- `python3 /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_phase.py --phase-dir /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1`
- 修复前报错：`FileNotFoundError: .../phase-1/scenario.json`

GREEN:
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-validator-stack.sh`

### FAIL-2: readiness fixture 缺失 green 信号仍通过

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:183-186` 使用 `.get(..., True)`，把缺失字段当作成功。 |
| 2 | 修复是否完整？ | 运行时判断改成“字段值必须显式是 `true`”；正向 fixture `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json:52-55` 也已补齐 `validator_green / replay_green`。 |
| 3 | 是否引入新问题？ | 会让之前缺失 green 字段的 fixture 失败，但这正是 fail-closed 语义；已同步修复正向 fixture 避免误报。 |
| 4 | 是否需要补充测试覆盖？ | 需要。已在 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh:88-105` 新增“删除两个 green 字段后必须失败”的负向回归。 |

RED:
- `python3 /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py --fixture /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json --expect-freeze-quarantine`
- 修复前返回 0，即使 `failed-cutover.json` 缺少 `validator_green / replay_green`

GREEN:
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | `validate_standard_chain_phase.py --phase-dir` 无法处理真实 phase 目录 | normalizer 的 `--phase-dir` 只认 `scenario.json` | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/normalize_canonical_artifact.py` | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-validator-stack.sh` |
| 2 | readiness fixture 缺失 green 信号仍通过 | fixture contract 使用默认 `True`，正向 fixture 也缺少显式 green | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py`、`/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/fixtures/standard-chain-foundation/cutover/failed-cutover.json` | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh` |

### 全量测试结果
TEST_CMD:
- `python3 -m py_compile /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/normalize_canonical_artifact.py /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_phase.py /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-validator-stack.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-readiness-gate.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-standard-chain-cutover.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-runtime-integrity.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-skill-output-and-gate-contract.sh`
- `git -C /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation diff --check`

通过: 7 / 失败: 0 / 跳过: 0

### 交接项清单
- 根因分析结论与定位文件:行号：
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/normalize_canonical_artifact.py:56-143`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tools/community/validate_standard_chain_readiness.py:174-186`
- 修复范围与回归测试清单：
  - 真实 phase-dir scenario builder
  - upstream-only phase-dir 回归
  - missing green fixture fail-close 回归
- 非 FIXABLE 问题的后续处理动作：无。本轮问题均归类为 `FIXABLE`
