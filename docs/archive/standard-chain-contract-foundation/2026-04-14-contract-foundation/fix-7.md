# Fix-7

## 输入分析
- 输入来源清单：用户要求继续按 Agent Team 系统性 review 收口；本轮承接二轮 review 后仍存在的 P1/P2 风险。
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：6 组。

差异说明（N > 1 时 REQUIRED）:
- `fix-1` 至 `fix-3` 主要收紧 readiness / validator / QA gate 的早期缺口。
- `fix-4` 至 `fix-5` 主要处理 canonical runtime dispatcher、signoff、review/verify/developer-report 运行时合同。
- `fix-6` 处理 merge-main 后 `product-director / product-manager` 拆分与 canonical runtime 控制面的统一。
- 本轮不再扩大流程目标，而是沿 Agent Team 复审发现的系统性缺口做 fail-closed 收紧：模板字段、安装 runtime root、产品 WARN 空壳、readiness 语义闭环、developer TDD 证据、QA/skill-chain/eval 假阳性。

## 诊断阶段

### 环境快照
- 当前分支：`codex/standard-chain-contract-foundation`
- 工作树状态：存在多文件 feature diff，集中在 `contracts/canonical/`、`shared/skills/`、`tools/community/`、`tools/eval/`、`tests/` 与 golden fixtures。
- 最近基线：merge-main 后的 standard-chain canonical runtime 控制面。

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | 产品 WARN issue ledger 可空壳通过 | 将 `brief.json` / `phase-prd.json` 的 `review_conclusion.verdict` 设为 `WARN`，并只保留 `issue_id/status` | 修复前 product closure / readiness 可接受缺少 severity/evidence/handoff 的 WARN。 |
| 2 | readiness 签收闭环未覆盖 phase goal / waiver scope / developer runtime 状态 | 删除 phase goal closure、伪造 waiver scope，或把 task `developer-report.runtime_status` 改为 `IN_PROGRESS` | 修复前 readiness 只覆盖 brief goals，未绑定 phase-prd goal，也未对 task 状态做语义一致性校验。 |
| 3 | 安装后的 product/delivery gate runtime root 解析错误 | 在临时 `$HOME/.codex` / `$HOME/.claude` 安装后运行 completion gate | 修复前脚本可能把 runtime root 解析到 `$HOME/tools` 而不是 `$HOME/.codex/tools` 或 `$HOME/.claude/tools`。 |
| 4 | developer canonical report TDD 证据可伪造 | 把 RED 结果改为 `PASS` 或使用不存在的 `commit_sha` | 修复前 canonical developer gate 只看 RED/GREEN phase，未验证 RED 结果语义和 commit 真实性。 |
| 5 | QA/skill-chain/template 字段漂移 | `qa` required inputs 缺 UNIT definition，QA skill 缺 `issue_ledger_anchor`，template authoritative_fields 未跟 key_fields 同步 | 修复前部分测试绿灯不能证明模板、gate、skill-chain 三方一致。 |
| 6 | product split benchmark 可被长关键词空壳文本骗过 | 使用较长关键词堆砌文本，覆盖 rubric 词但声明“无判断/无证据/无可执行内容” | 修复前 pass_rate 可被关键词命中抬高。 |

当前环境复现结论:
- 可复现：是。已为上述问题补入 RED 回归，修复前对应测试失败或 review 提供的复现路径成立。
- 不可复现时环境差异证据：无。

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | WARN 空壳 | schema 已经强制完整 ledger 字段 | 检查 `contracts/canonical/schemas/planning/brief.schema.json`、`phase-prd.schema.json` 与 `tools/community/validate_product_closure.py` | 排除。修复前 closure 层未要求 severity/evidence/handoff。 |
| 2 | readiness 漂移 | phase validator 已足够覆盖 signoff 语义 | 静态追踪 `validate_standard_chain_readiness.py -> validate_readiness_contract.py` | 排除。schema 只能验证结构，无法证明 phase goal、waiver scope 和 delivery-state 状态一致。 |
| 3 | 安装 root | completion gate 使用 `$REPO_ROOT` 足够 | 在非 git 临时安装目录运行 installed gate | 排除。安装后 `$REPO_ROOT` 是用户 workspace，不是 runtime package root。 |
| 4 | developer 证据 | schema enum 已经保证 TDD 真实 | 修改 `.tdd_evidence_index[0].result` 和 `commit_sha` 运行 gate | 排除。schema 不知道 RED 必须 `FAIL_EXPECTED`，也不能验证 git commit 存在。 |
| 5 | 字段漂移 | registry/key_fields 测试已覆盖所有模板字段 | 增加 skill-chain key_fields 与 template authoritative_fields 子集校验 | 确认遗漏。修复前 `brief` 等模板缺少 key_fields。 |
| 6 | eval 空壳 | 关键词 smoke 足以挡住差输出 | 用长关键词 hollow response 跑 `tests/test-product-split-benchmark-contract.sh` | 排除。修复前关键词命中仍可能给高分。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | 产品 WARN issue ledger 可空壳通过 | `tools/community/validate_product_closure.py:21-76` | product closure 旧逻辑只要求 `WARN` 有 ledger 且 status closed，没有要求 closed issue 携带 severity/dimension/finding/evidence/handoff_target。 | `product-director/product-manager` completion gate 调用 product closure；readiness 再消费 finalized product artifacts，因此 closure 是 WARN 语义的运行时入口。 |
| 2 | readiness 签收闭环和 task 状态漂移 | `tools/community/validate_readiness_contract.py:94-115,140-195` | readiness 旧逻辑只校验 task artifact identity 和 brief goals，没有把 `developer-report.runtime_status` 绑定到 `delivery-state`，也没有把 `phase-prd#phase-goal` 与 waiver scope 纳入闭环。 | `validate_standard_chain_readiness.py` 调用 `assert_task_runtime_identity()` 和 `assert_signoff_closure()`；这两个函数直接决定 closeout 是否放行。 |
| 3 | installed runtime root 解析错误 | `shared/hooks/lib/common.sh:78-89` 及 product/director/developer/delivery-owner completion scripts | installed gate 需要从脚本位置解析 runtime package root；单用 `$REPO_ROOT` 会指向用户 workspace，导致找不到 `$HOME/.codex/tools/community`。 | product-manager/product-director/developer/delivery-owner gates 均 source `common.sh`，新增 `resolve_runtime_root()` 后统一解析 repo worktree 与 installed runtime。 |
| 4 | developer TDD 证据可伪造 | `shared/skills/developer/scripts/completion_check.sh:127-145` | 旧 gate 只要求存在 RED/GREEN phase，没有验证 RED result 必须是 `FAIL_EXPECTED`、GREEN result 必须是 `PASS`，也未验证 commit SHA 在 git 中存在。 | `developer` completion gate 直接消费 canonical `developer-report.json`；新增负例在同 gate 中验证假 commit 和 RED=PASS 均失败。 |
| 5 | QA/skill-chain/template 字段漂移 | `contracts/skill-chain.yaml:100-107`、`shared/skills/qa/SKILL.md:125-158`、canonical templates | skill-chain、skill 文案、template authoritative_fields、fixture 之间缺少同源闭环，导致模板字段新增/删减可能不被 gate/test 消费。 | `tests/test-standard-chain-foundation-registry.sh` 新增 key_fields 子集校验；`tests/test-qa-browser-gate-contract.sh` 直接检查 QA skill/template/check 三处一致。 |
| 6 | product split benchmark 可被空壳文本骗过 | `tools/eval/scripts/product_split_benchmark_scoring.py:47-95` | 旧 rubric 只按关键词覆盖计分，长关键词堆砌文本可绕过 outcome quality。 | `run_product_split_benchmark.py` 读取 scoring helper 生成 grading；新增 hollow markers 和最小长度/非空壳约束后，hollow fixture 不再过线。 |

## 处置阶段

### 决策
处置策略：
1. 不改变 T1-T6 目标、不提前做新的 cutover；只收紧已进入 canonical runtime 控制面的 gate/test/template。
2. 对 P1 走 fail-closed：缺字段、错锚点、假 commit、runtime status 漂移、安装 runtime 依赖缺失均必须失败。
3. 对 P2 字段漂移同步 template / schema / fixture / tests，避免“文档改了、工程门禁没消费”。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | WARN 空壳 | FIXABLE | 补 product closure 和 planning schema required 字段，并补 readiness 负例。 |
| 2 | readiness 语义漂移 | FIXABLE | 扩展 signoff/task semantic checks，并补 phase goal、waiver scope、runtime status 负例。 |
| 3 | installed runtime root | FIXABLE | 在 common hook lib 增加 runtime root resolver，product/director/developer/delivery-owner gate 统一使用。 |
| 4 | developer TDD 证据伪造 | FIXABLE | gate 校验 RED/GREEN result 和 git commit SHA 存在性。 |
| 5 | QA/skill-chain/template 漂移 | FIXABLE | 同步 skill-chain、QA skill、canonical templates、registry tests。 |
| 6 | product split hollow eval | FIXABLE | scoring helper 增加 hollow markers 和非空壳约束，补 benchmark 负例。 |

## RED/GREEN 证据

RED:
- `bash tests/test-standard-chain-foundation-registry.sh` 修复前失败：`skill-chain key_fields missing from brief template authoritative_fields: ['non_functional_requirements']`
- `bash tests/test-standard-chain-readiness-gate.sh` 修复前失败：`readiness gate should reject product WARN issue_ledger entries without evidence and handoff fields`
- `bash tests/test-qa-browser-gate-contract.sh` 修复前失败：`missing pattern in shared/skills/qa/SKILL.md: issue_ledger_anchor`
- `bash tests/test-developer-contract-alignment.sh` 新增负例覆盖 fake commit 与 RED=PASS。
- `bash tests/test-product-split-benchmark-contract.sh` 新增 hollow response 覆盖关键词空壳。
- `bash tests/test-install-systematic.sh` 新增 installed gate 与缺失 `authority_proof.py` 修复覆盖。

GREEN:
- `python3 - <<'PY' ... json.load(...) ... PY`：`json ok: 16 files`
- `bash -n install.sh shared/skills/developer/scripts/completion_check.sh shared/skills/product-manager/scripts/completion_check.sh shared/skills/product-director/scripts/completion_check.sh shared/skills/delivery-owner/scripts/completion_check.sh tests/test-install-systematic.sh tests/test-standard-chain-readiness-gate.sh tests/test-developer-contract-alignment.sh tests/test-product-split-benchmark-contract.sh tests/test-qa-browser-gate-contract.sh tests/test-standard-chain-foundation-registry.sh`
- `python3 -m py_compile tools/community/validate_readiness_contract.py tools/community/validate_standard_chain_readiness.py tools/community/validate_product_closure.py tools/eval/scripts/product_split_benchmark_scoring.py tools/community/validate_canonical_schema.py tools/community/normalize_canonical_artifact.py tools/community/resolve_evidence_refs.py tools/community/validate_projection_manifest.py tools/eval/scripts/product_split_benchmark_core.py`
- `bash tests/test-standard-chain-foundation-registry.sh` → `[PASS] standard chain foundation registry`
- `bash tests/test-qa-browser-gate-contract.sh` → `[PASS] qa browser gate contract`
- `bash tests/test-developer-contract-alignment.sh` → `PASS: 23  FAIL: 0`
- `bash tests/test-standard-chain-readiness-gate.sh` → `[PASS] standard chain readiness gate`
- `bash tests/test-product-split-benchmark-contract.sh` → `[PASS] product split benchmark contract`
- `bash tests/test-install-systematic.sh` → `Systematic tests passed: 20, skipped: 0`
- `bash tests/test-skill-output-and-gate-contract.sh` → `[PASS] skill output/gate contract`
- `bash tests/test-standard-chain-validator-stack.sh` → `[PASS] standard chain validator stack`
- `bash tests/test-install-smoke.sh` → `[PASS] install/uninstall smoke`
- `bash tools/dev/validate-contracts.sh` → `OK: all checks passed`
- `bash tests/test-standard-chain-runtime-state.sh` → `[PASS] standard chain runtime state`
- `bash tests/test-standard-chain-user-decision.sh` → `[PASS] standard chain user decision`
- `bash tests/test-standard-chain-projection-replay.sh` → `[PASS] standard chain projection replay`
- `bash tests/test-standard-chain-cutover.sh` → `[PASS] standard chain cutover`
- `bash tests/test-chain-completeness.sh` → `[PASS] chain completeness`
- `bash tests/test-runtime-integrity.sh` → `[PASS] runtime integrity`
- `bash tests/test-phase-context-resolution.sh` → `[PASS] phase context resolution`
- `bash tests/test-delivery-owner-phase3-contract.sh` → `[PASS] delivery-owner phase3 contract`
- `bash tests/test-constraint-closure-contract.sh` → `[PASS] constraint closure contract`
- `bash tests/test-review-convergence-gates.sh` → `[PASS] review convergence gates`
- `bash tests/test-delivery-owner-source-anchor-contract.sh` → `[PASS] delivery-owner source anchor contract`
- `bash tests/test-product-eval-contract.sh` → `[PASS] product eval contract`
- `git diff --check`

## 修复四问
| # | 问题 | 根因是什么？ | 修复是否完整？ | 是否引入新问题？ | 是否补测试？ |
|---|------|--------------|----------------|------------------|--------------|
| 1 | WARN 空壳 | closure/schema 未要求 closed issue 携带证据和 handoff 字段 | 已同时收紧 schema、validator、readiness 负例 | 收紧后旧空壳 WARN 会失败，这是预期 fail-closed | 是 |
| 2 | readiness 语义漂移 | closeout 只做结构存在，不做 phase goal / waiver / task status 语义绑定 | 已绑定 phase goal、waiver scope、developer runtime status 与 delivery-state | 可能暴露旧 fixture 状态不一致，已同步 golden pilot | 是 |
| 3 | installed runtime root | installed gate 把 workspace 当 runtime root | 已统一 `resolve_runtime_root()`，并在 install systematic 中真实运行 installed gates | repo worktree 与 installed runtime 双路径均被覆盖 | 是 |
| 4 | developer TDD 证据伪造 | gate 只看 phase，不看 RED/GREEN result 与 commit 存在性 | 已检查 RED=`FAIL_EXPECTED`、GREEN=`PASS`、commit 在 git 中存在 | 非 git 环境会 fail-closed，符合 canonical report 证据要求 | 是 |
| 5 | 字段漂移 | skill-chain/template/skill/gate 缺少自动一致性约束 | 已补 authoritative_fields、QA skill、skill-chain required input 与 registry test | 对旧模板残缺会失败，符合任务目标 | 是 |
| 6 | hollow eval | 关键词 smoke 可被长空壳文本绕过 | 已加入 hollow markers 与非空壳约束 | 可能压低空泛回答得分，这是预期 | 是 |

## 产出

### 修复清单
| # | 范围 | 主要文件 |
|---|------|----------|
| 1 | product WARN closure | `tools/community/validate_product_closure.py`、`contracts/canonical/schemas/planning/{brief,phase-prd}.schema.json` |
| 2 | readiness semantic closeout | `tools/community/validate_readiness_contract.py`、`tools/community/validate_standard_chain_readiness.py`、golden signoff/developer fixtures |
| 3 | installed runtime root | `shared/hooks/lib/common.sh`、product/director/developer/delivery-owner completion scripts、`install.sh` |
| 4 | developer canonical TDD gate | `shared/skills/developer/scripts/completion_check.sh`、`tests/test-developer-contract-alignment.sh` |
| 5 | template / field / QA alignment | `contracts/skill-chain.yaml`、canonical templates、`shared/skills/qa/SKILL.md`、registry/QA tests |
| 6 | product split eval | `tools/eval/scripts/product_split_benchmark_scoring.py`、`tests/test-product-split-benchmark-contract.sh` |

### 交接项清单
- 根因分析结论与定位文件:行号：见“根因结论”表。
- 非 FIXABLE 问题的后续处理动作：无。本轮所有问题均归类为 `FIXABLE`。
- 当前 review 闭环状态：等待本轮确认 review。
