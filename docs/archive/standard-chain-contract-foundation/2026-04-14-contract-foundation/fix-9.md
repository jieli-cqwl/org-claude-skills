# Fix-9

## 输入分析

- 输入来源清单：用户要求继续推进，不达到最终目标不要停；本轮承接 Agent Team 第二轮系统性 review 的 P1/P2/P3 发现。
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：9 组。

差异说明（N > 1 时 REQUIRED）:
- `fix-8` 已处理首轮 readiness artifact set、template/fixture/key_fields、installed runtime 与 product split eval hollow 的主要缺口。
- 本轮在其基础上继续处理第二轮 review 暴露的阻断项：task coverage、code-review 语义、verify-result task binding、Director lock、UNIT 空壳、completion_check/schema 分叉、signoff 精确闭包、legacy extras 与 marker-free keyword stuffing。

## 诊断阶段

### 环境快照

- 当前分支：`codex/standard-chain-contract-foundation`
- 当前工作树：大规模 staged feature diff，新增本轮未 staged 修改集中在 `validate_readiness_contract.py`、`validate_product_closure.py`、canonical schemas/templates、golden fixture、`completion_check.sh`、benchmark scoring 与回归测试。
- 已确认阻断项来源：Agent Team reviewers `contract correctness`、`template/field completeness`、`verification credibility`、`merge risk`、`chain compatibility`。

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `delivery-state.tasks` 可遗漏 `tasks.json` 的任务 | 删除 golden 中 T2 的 delivery-state runtime row | 修复前 readiness 返回 0。 |
| 2 | `code-review-result` 失败语义未被 closeout 阻断 | 设置 `gate_result=FAIL`、`review_conclusion=REQUEST_CHANGES` | 修复前 readiness 返回 0。 |
| 3 | `verify-result.goal_closure` 可为空 | 设置 task verify `goal_closure=[]` | 修复前 readiness 返回 0 或只靠非语义路径。 |
| 4 | `verify-result.developer_report_ref` 可指向别的 task | 将 T1 verify 指向 T2 developer-report | 修复前 readiness 返回 0。 |
| 5 | Director-owned 字段可被 Manager 阶段漂移 | 写入原始 locked digest 后修改 `brief.root_problem` / `phase_prd.phase_goal` | 修复前 product closure/readiness 返回 0。 |
| 6 | UNIT schema 允许空壳 | 构造空 `closure_definition`、空 AC、无 priority/dependencies | 修复前 canonical schema 可通过。 |
| 7 | design/qa completion_check 与 canonical schema 分叉 | design 只写四个局部字段；qa 删除 `current_stage/issue_ledger` | 修复前 skill gate 可放行非法 canonical envelope。 |
| 8 | signoff closure 非精确 | `goal_ref` 与 `goal_source_ref` 漂移，或追加 extra goal closure row | 修复前 readiness 未精确拦截。 |
| 9 | marker-free keyword stuffing 仍可得满分 | 构造带因果词和重复 rubric term 的空泛 response | 修复前 product split scoring 得到 perfect score。 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 |
|---|------|---------|-----------|
| 1 | task coverage 不完整 | `tools/community/validate_readiness_contract.py::assert_task_runtime_identity` | 只校验已有 task runtime artifact 身份，没有把 `tasks.json.tasks` 与 `delivery-state.tasks` 做 exact coverage。 |
| 2 | review 失败语义漏挡 | `validate_standard_chain_readiness.py` 缺少 code-review semantic gate | required file 存在不等于 review approve；closeout 必须消费 `gate_result/review_conclusion/dimension_verdicts`。 |
| 3 | verify 空闭包 | `verify-result.schema.json` 与 readiness semantic check | schema 未要求 minItems，readiness 空数组迭代自然通过。 |
| 4 | verify/developer task 绑定弱 | `assert_task_runtime_identity` | 验证 task_id/artifact_id 还不足以证明 `developer_report_ref` 指向同 task 的 developer-report。 |
| 5 | Director lock 不可执行 | `validate_product_closure.py` 与 planning schemas | `director_confirmation` 只有 status/time，没有字段 digest，Manager 可改 Director-owned fields。 |
| 6 | UNIT 空壳 | `unit-definition.schema.json` | schema 只要求字段存在，没有 `minLength/minItems`，且缺 `priority/priority_basis/dependencies`。 |
| 7 | completion_check/schema 分叉 | `design/scripts/completion_check.sh`、`qa/scripts/completion_check.sh` | 局部 jq 检查绕开 `validate_canonical_schema.py`，导致缺 shared-core envelope 也能通过。 |
| 8 | signoff 非精确闭包 | `assert_signoff_closure`、`assert_authority_proof` | 只检查 required refs 出现一次，不拒绝 extra rows；authority proof 只验证第一条 ref。 |
| 9 | eval hollow | `product_split_benchmark_scoring.py` | 关键词命中与行动词命中仍无法排除重复堆砌。 |

## 处置阶段

### 决策

处置策略：
1. 所有 P1 进入 fail-closed readiness / schema / hook gate，不用文档约定替代工程门禁。
2. 对模板字段遗漏按硬门禁处理：schema、template、fixture、skill-chain key_fields、registry tests 同步。
3. P2/P3 中低成本且与目标一致的漂移也一并收口，避免下一轮 review 重复发现。

失败分类:

| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1-9 | 本轮全部 findings | FIXABLE | 已修复并补 RED/GREEN 回归。 |

## RED/GREEN 证据

RED:
- `bash tests/test-standard-chain-readiness-gate.sh` 修复前在 Director lock drift 负例处失败，证明 readiness 未挡住 Director-owned 字段漂移。
- `bash tests/test-product-split-benchmark-contract.sh` 修复前输出 `marker-free keyword stuffing must not receive a perfect outcome score`。
- `bash tests/test-standard-chain-foundation-registry.sh` 修复前先暴露 qa/signoff key_fields drift，随后暴露 UNIT hollow schema 缺口。
- `bash tests/test-standard-chain-validator-stack.sh` 修复前输出 `rule validator should reject legacy extra fields even when schemas allow forward-compatible extensions`。

GREEN:
- `python3 -m py_compile ...` 覆盖本轮修改的 community/eval Python 脚本，exit 0。
- `bash -n ...` 覆盖本轮修改的 completion_check 与测试脚本，exit 0。
- `git diff --check && git diff --cached --check`，exit 0。
- `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md` -> `[PASS] tasks-plan consistency (6 tasks, 40 plan steps)`。
- `bash tests/test-standard-chain-readiness-gate.sh` -> `[PASS] standard chain readiness gate`。
- `bash tests/test-standard-chain-validator-stack.sh` -> `[PASS] standard chain validator stack`。
- `bash tests/test-standard-chain-projection-replay.sh` -> `[PASS] standard chain projection replay`。
- `bash tests/test-standard-chain-foundation-registry.sh` -> `[PASS] standard chain foundation registry`。
- `bash tests/test-skill-output-and-gate-contract.sh` -> `[PASS] skill output/gate contract`。
- `bash tests/test-standard-chain-runtime-state.sh` -> `[PASS] standard chain runtime state`。
- `bash tests/test-standard-chain-user-decision.sh` -> `[PASS] standard chain user decision`。
- `bash tests/test-standard-chain-cutover.sh` -> `[PASS] standard chain cutover`。
- `bash tests/test-chain-completeness.sh` -> `[PASS] chain completeness`。
- `bash tests/test-runtime-integrity.sh` -> `[PASS] runtime integrity`。
- `bash tests/test-qa-browser-gate-contract.sh` -> `[PASS] qa browser gate contract`。
- `bash tests/test-developer-contract-alignment.sh` -> `PASS: 23  FAIL: 0`。
- `bash tests/test-delivery-owner-phase3-contract.sh` -> `[PASS] delivery-owner phase3 contract`。
- `bash tests/test-delivery-owner-source-anchor-contract.sh` -> `[PASS] delivery-owner source anchor contract`。
- `bash tests/test-product-eval-contract.sh` -> `[PASS] product eval contract`。
- `bash tests/test-constraint-closure-contract.sh` -> `[PASS] constraint closure contract`。
- `bash tests/test-review-convergence-gates.sh` -> `[PASS] review convergence gates`。
- `bash tools/dev/validate-contracts.sh` -> `OK: all checks passed`。
- `bash tests/test-product-split-benchmark-contract.sh` -> `[PASS] product split benchmark contract`。
- `bash tests/test-install-smoke.sh` -> `[PASS] install/uninstall smoke`。
- `bash tests/test-install-systematic.sh` -> `Systematic tests passed: 20, skipped: 0`。
- `bash tests/test-product-role-split-contract.sh` -> `[PASS] product role split contract`。
- `bash tests/test-product-artifact-contract.sh` -> `[PASS] product artifact contract`。
- `bash tests/test-product-output-contract-reference.sh` -> `[PASS] product output contract reference`。
- `bash tests/test-product-inherited-capability-parity.sh` -> `[PASS] product inherited capability parity`。
- `bash tests/test-product-context-signal-quality.sh` -> `[PASS] product context signal quality contract`。
- `bash tests/test-phase-context-resolution.sh` -> `[PASS] phase context resolution`。
- `bash tests/test-subagent-context-contract.sh` -> `[PASS] subagent context contract`。
- `HOME="$PWD/tests/fixtures/standard-chain-foundation/clean-home" python3 tools/community/validate_canonical_schema.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1` -> exit 0。
- `HOME="$PWD/tests/fixtures/standard-chain-foundation/clean-home" python3 tools/community/validate_standard_chain_readiness.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1 --catalog shared/runtime/standard-chain-catalog.json --profiles shared/runtime/replay-profiles.json` -> exit 0。
- `python3 tools/community/build_standard_chain_catalog.py --check` -> exit 0。

## 修复四问

| # | 问题 | 根因是什么？ | 修复是否完整？ | 是否引入新问题？ | 是否补测试？ |
|---|------|--------------|----------------|------------------|--------------|
| 1 | readiness task/review/verify/signoff/authority 漏挡 | closeout contract 没有消费全语义 | 已补 exact coverage、PASS semantics、task ref binding、exact closure、all proof refs | 收紧后旧半成品会失败，符合目标 | 是 |
| 2 | Director lock 不可执行 | 缺 field digest | 已补 `locked_field_digest` schema/template/fixture 与 product closure 校验 | Manager 修改 Director-owned fields 会被挡住 | 是 |
| 3 | UNIT 空壳 | schema 缺执行性字段和非空约束 | 已补 `priority/priority_basis/dependencies` 与 min constraints | 旧空壳 UNIT 会失败，符合目标 | 是 |
| 4 | completion_check/schema 分叉 | design/qa 只做局部 jq | 已统一调用 canonical schema validator，再做角色特定语义检查 | hook 更严格；合法 golden 已通过 | 是 |
| 5 | eval keyword stuffing | 重复关键词可伪装成质量 | 已加入 keyword stuffing 检测 | 空泛输出降分，符合 eval 目标 | 是 |

## 产出

### 修复清单

| # | 范围 | 主要文件 |
|---|------|----------|
| 1 | readiness closeout | `tools/community/validate_readiness_contract.py`、`tools/community/validate_standard_chain_readiness.py` |
| 2 | product lock | `tools/community/validate_product_closure.py`、`contracts/canonical/schemas/planning/{brief,phase-prd}.schema.json`、golden fixtures |
| 3 | UNIT contract | `contracts/canonical/schemas/planning/unit-definition.schema.json`、`contracts/canonical/templates/planning/unit-definition.template.json`、`contracts/skill-chain.yaml` |
| 4 | hook/schema convergence | `shared/skills/design/scripts/completion_check.sh`、`shared/skills/qa/scripts/completion_check.sh` |
| 5 | validator/eval hardening | `tools/community/simple_json_schema.py`、`tools/community/validate_canonical_rules.py`、`tools/eval/scripts/product_split_benchmark_scoring.py` |
| 6 | tests/fixtures/docs | readiness/registry/validator/skill-output/product-split tests、golden pilot、`qa/SKILL.md`、test-design reviewer prompt |

### 交接项清单

- 非 FIXABLE 问题的后续处理动作：无。
- 当前状态：阻断项已修复，fresh proving commands 已通过；等待 Agent Team 复审闭环。
