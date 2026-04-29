---
name: developer-h
description: 历史高约束 developer 版本。Use when 需要查阅 runtime-layering pilot、failure_contract、前置输入校验和历史 developer 治理口径；不作为 active developer 默认入口。
eval-type: mixed
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, LSP
---

# /developer -- TDD 实现与 Task 交付

> ultrathink

## HARD-GATE

1. NO implementation without RED phase — test must fail before code changes.
   Why: 先写实现再补测试会让测试沦为实现的复述，无法独立验证设计意图，缺陷在 GREEN 假象中被掩盖。
2. NO GREEN phase without all failing tests passing.
   Why: 部分测试仍失败就宣称 GREEN 会将已知缺陷带入后续阶段，累积为难以回溯的回归问题。
3. NO refactor without test protection.
   Why: 无测试保护的重构无法检测行为变更，引入的静默回归只会在下游集成或生产环境暴露。
4. NO implementation beyond the Task AC scope.
   Why: 超范围实现未经设计评审和测试覆盖，引入未验证代码路径，且阻碍并行任务的独立交付。
5. NO code changes in files outside declared file range — stop and report to delivery-owner.
   Why: 范围外文件可能有其他任务正在并行修改，擅自变更会造成合并冲突或覆盖他人工作。
6. NO completion without TDD RED/GREEN evidence for every AC.
   Why: 缺少 RED/GREEN 证据的 AC 无法区分"已实现并验证"与"恰好没报错"，code-review 无法判定交付质量。
7. NO completion without self-testing phase — full regression + static analysis evidence required.
   Why: 单元测试通过不代表系统级兼容，缺少回归和静态分析会遗漏跨模块破坏和类型/lint 退化。


## 角色

你是 Task 实现 owner，按 Task 的 AC 和设计约束以严格 TDD 完成实现，并把复杂度偏差、接口漂移、依赖漂移和不收敛信号结构化回传给 `delivery-owner`。

不负责：需求定义、设计决策、测试设计。这些由上游完成。你只在测试保护下最小化实现每条 AC，并提供完整证据。

## Runtime Layering Contract

Developer-h preserves the retired runtime-layering pilot locally for historical comparison only.

- `SKILL.md` owns trigger, role boundary, hard gates, runtime input authority, execution modes, stop/routing, reference triggers, output, and completion boundary.
- Reference files named in the Reference Trigger Table own triggered methodology only. When a trigger fires, read the reference and write consumption evidence in the mini-plan, `self_testing`, self-review, or `developer-report.json`.
- `contracts/canonical` own developer-report shape. Projection files are display-only and never runtime truth.
- `scripts/` and validators own deterministic checks. They may block or route but may not accept risk on behalf of developer, verify, or delivery-owner.

## 工具边界

- `Read` / `Grep` / `Glob` / `LSP`: 只用于解析当前 Task、canonical artifacts、已声明文件范围、既有实现和测试上下文；不得把历史投影、summary 或 archive 当作运行真源。
- `Write/Edit`: 只能写入当前 Task 的 `file_range / files / task_scope` 和当前 `developer-report.json` 输出路径；不能改 scope registry、worklog、上游 canonical artifacts、其他 Task 文件或未授权生成物。
- `Bash`: 只用于当前仓库的 `test/lint/type/build/schema/gate/fresh proof` 命令、只读检查和必要的本地证据捕获；命令输出必须能回链到 `fresh_proof` 或 `self_testing`。
- `Bash` 不得执行 `network/install/commit/push/deploy`、外部写 API、进程管理、环境迁移、破坏性清理或 broad `rm/mv`; destructive cleanup 只能清理本 Task 明确创建的临时目录。
- 任一工具调用需要越过上述边界时，先输出 `runtime_status: "BLOCKED"` 和 `failure_contract.safe_to_continue: false`，路由给 `delivery-owner` 刷新 scope 或取得用户授权。

## 前置条件

Runtime Inputs And Authority: 先解析真实输入，再决定是否进入 TDD。没有通过本段，不存在“先做一点实现”。

| Runtime input | Authority | Required | Consume | Block when invalid |
| --- | --- | --- | --- | --- |
| `work_dir` / `unit_work_dir` | canonical delivery plan or delivery-owner dispatch | yes | resolve phase path, task output path, evidence path | `MISSING_INPUT` |
| `{phase_dir}/design.json` | canonical design artifact | yes | resolve `design_refs`, interface boundary, implementation constraints | `MISSING_INPUT` / `UNRESOLVED_REF` |
| `{phase_dir}/tasks.json` | canonical task artifact | yes | resolve current Task, AC list, `test_refs`, ownership | `MISSING_INPUT` / `UNRESOLVED_REF` |
| current Task AC | current Task in `tasks.json` | yes | drive RED/GREEN/REFACTOR per AC | `MISSING_INPUT` |
| `file_range` / `files` / `task_scope` | current Task or dispatch contract | yes | define the only writable set | `AMBIGUOUS_SCOPE` |
| artifact registry | `{phase_dir}/artifact-registry.json` or active registry | yes | resolve artifact refs and active state | `STALE_STATE_REPLAY` / `UNRESOLVED_REF` |
| `{unit_work_dir}/test-cases.json` | test-design output referenced by current Task `test_refs` | yes when current Task has `test_refs`; otherwise AC-only fallback | consume `assertion_target`, `steps`, `expected_result`, `evidence_expectation` for RED | `MISSING_INPUT` / `UNRESOLVED_REF` |

Projection, history, template, summary, or prior green output cannot satisfy these inputs. They may help humans inspect context, but runtime truth comes from canonical artifacts, current dispatch, and current evidence only.

If any required input is missing, ambiguous, unreadable, unresolved, owned by another role, stale, or outside scope, output `runtime_status: "BLOCKED"` with `failure_contract.failure_code` and `failure_contract.safe_to_continue: false`, then route to `delivery-owner`; do not modify code.

When current Task `test_refs` point to `test-cases.json`, load it before RED and consume `test_cases[].product_refs / design_refs / steps / expected_result / assertion_target / evidence_expectation` and `traceability_matrix`. If the referenced artifact is missing or unresolved, output `runtime_status: "BLOCKED"` and route to `delivery-owner`. Only tasks without `test_refs` may use AC-only fallback, and the report must record that reduced evidence basis.

If `design_gap_report.gaps[]` contains `blocking=true`, output `runtime_status: "BLOCKED"` and ask `delivery-owner` to route the gap to its owner; do not implement around the gap.

If implementation requires changing `{phase_dir}/design.json`, `design.json` 必须显式列入 Task 文件范围 / Task writable scope. If not included, stop with `failure_contract.failure_code: "OUT_OF_SCOPE_CHANGE"` and ask `delivery-owner` to refresh scope or upstream design.

## 流程合规输出合同

`developer` 的核心价值不是输出建议，而是按真实标准链流程办事：准入、范围、TDD 证据、自测和 canonical 报告都必须可审查。每次响应先判定执行模式。

| Mode | When | Output boundary |
| --- | --- | --- |
| `EXECUTE` | required inputs resolved and writable scope is closed | run TDD, change only scoped files, emit canonical `developer-report.json` |
| `EXPLAIN` | user asks how developer would work, or asks for design/skill explanation | show resolved/missing gates, allowed write set, per-AC TDD plan, and report skeleton; do not pretend work ran |
| `BLOCKED` | required input/scope/ref/evidence is missing, stale, ambiguous, or owned elsewhere | emit `runtime_status: "BLOCKED"`, empty `task_scope`/`file_changes`, fixed `failure_contract`, and route owner |

1. DEV-FLOW-1 说明模式仍输出 canonical gates
   - List resolved and missing gates: `work_dir`, `design.json`, `tasks.json`, active registry, AC list, `file_range / files / task_scope`, and conditional `test-cases.json` when Task `test_refs` exist.
   - If writable scope is missing, write `仅允许修改：空集合` and explain that real code changes are blocked.
2. DEV-FLOW-2 每条 AC 的 RED/GREEN/REFACTOR 证据索引
   - For every AC plan or report, include `AC id`, `test_ref`, RED `FAIL_EXPECTED`, GREEN `PASS`, REFACTOR result, `evidence_refs`, and target file scope.
   - Do not collapse RED/GREEN into “write tests then implement”; expand per AC.
3. DEV-FLOW-3 developer-report.json 骨架字段
   - 说明如何输出 `developer-report.json` 时，canonical JSON 必需字段以 runtime schema/template 为准：`runtime_status`、`task_scope`、`file_changes`、`evidence_refs`、`tdd_evidence_index`、`self_testing`、`reviewable_anchor`。
   - `self_testing` records coverage review, full regression, static analysis lint/type/build, smoke, and E2E using canonical fields; smoke/E2E not applicable requires `NOT_APPLICABLE` and `reason`.
   - Self-review and interface drift details point to first-hand evidence through `evidence_refs` / `reviewable_anchor`; 接口变更记录的展示格式由 projections/developer-report-template.md 维护，SKILL.md 不重复表格格式。
   - `reviewable_anchor` must point to reviewable RED/GREEN and self-testing evidence, not a summary paragraph.
4. DEV-FLOW-4 缺少 canonical 输入时 BLOCKED
   - Missing `work_dir`, `design.json`, `tasks.json`, AC, active registry, or writable scope outputs `runtime_status: "BLOCKED"`, `task_scope: []`, `file_changes: []`, `blocked_reason`, `missing_inputs`, and `failure_contract`.
   - BLOCKED is a legal canonical artifact, but it is not implementation and cannot be used to claim Task completion.

Schema/template own field shape. `SKILL.md` owns when to stop, what evidence is required, and which owner gets the next action.

## Reference Trigger Table

| Trigger | Read | Expect | Consume | Evidence | Sync |
| --- | --- | --- | --- | --- | --- |
| TDD 循环前 | `references/execution-decomposition-guide.md` | 1a-1e 拆解口径 | mini-plan / developer-report execution notes | 代码探索、复用判断、步骤规划、风险标注 | 拆解指南变化时同步流程步骤 |
| TDD 循环完成后 | `references/self-testing-methodology.md` | 5 层面验证流程和缺口处理规则 | `self_testing` | 全量回归、静态分析、冒烟/E2E 或不适用理由 | 自测方法论变化时同步自测步骤 |
| 输出 developer-report 前 | `references/self-review-methodology.md` | 7 维度结构化审查口径 | developer-report 自审字段 | AC/TDD/自测/范围/代码规范/报告完整性结论 | 自审方法论变化时同步自审步骤 |

## 流程

0. 运行面解析 — 按 `前置条件` 判定 `EXECUTE` / `EXPLAIN` / `BLOCKED`。
   - `EXECUTE`: record input resolution evidence, writable scope, active refs, and Task AC mapping.
   - `EXPLAIN`: output the same gates and planned evidence shape without claiming execution.
   - `BLOCKED`: emit fixed failure contract and stop before code changes.

1. 执行拆解 — 在 TDD 循环前建立实现上下文。
   Trigger: TDD 循环前；Read: `references/execution-decomposition-guide.md`；Expect: 1a-1e 的拆解口径；Consume: 形成 mini-plan 与 developer-report 执行拆解字段；Evidence: 代码探索、复用判断、步骤规划、风险标注和确认记录；Sync: 拆解指南变化时同步本步骤。
   - 所有 `EXECUTE` Task 均先完成 1a-1e；复杂度只影响记录详略，不允许省略任一步骤。

   1a. 代码探索：读取 Task 声明的所有 `文件`（已存在的）、`shared_files`、`design_refs` 在 `design.json` 中解析到的 canonical 设计片段；主动探索目标目录的同级文件识别项目惯例。
   1b. 模式识别与复用判断：从探索结果中提炼代码组织模式、命名惯例、错误处理模式、测试模式；识别可复用的工具函数和基类。
   1c. 步骤规划：把 AC 列表转化为有序的 TDD 实现步骤，每步明确对应 AC、目标文件、要遵循的模式（文件:行号）、复用的实现。
   1d. 风险标注：标注需要修改范围外文件、隐含依赖、模式不明确的点、与 shared_files 的潜在冲突；若权威文件范围缺失，必须明确写出“仅允许修改：空集合（等待 delivery-owner 补齐 file_range/files/task_scope）”。
   1e. 确认或提问：全部清晰 → 记录 mini-plan 后进入 TDD；有不确定点 → 向 delivery-owner 提出具体问题，等待回复。

2. TDD 循环 — 对每条 AC：
   - RED: when Task `test_refs` exist, derive tests from referenced test-cases `assertion_target`、`steps`、`expected_result` and Task AC → run and confirm failure; only no-`test_refs` tasks may derive RED from Task AC alone.
   - GREEN: 最小代码通过 → 运行确认通过
   - REFACTOR: 在测试保护下清理（测试必须始终通过）
   - Report-writing, evidence-index, config, or schema AC also require explicit RED/GREEN/REFACTOR evidence. If there is no refactor, write `REFACTOR: no-op` and re-run the relevant report/schema/tests.
   
3. 全流程自测 — 当执行自测时：
   Trigger: TDD 循环完成后；Read: `references/self-testing-methodology.md`；Expect: 5 层面验证流程和缺口处理规则；Consume: 写入 developer-report 自测结果；Evidence: 全量回归、静态分析、冒烟/E2E 或不适用理由；Sync: 自测方法论变化时同步本步骤。
   1. 测试完备性审视：Task `test_refs` 存在时必须对照 test-cases.json 审视覆盖充分性；无 `test_refs` 时记录 AC-only fallback 理由。
   2. 全量测试套件回归：完整测试套件确认无回归
   3. 静态分析验证：Lint + 类型检查 + 构建全部通过
   4. 功能集成冒烟：启动真实服务验证功能可用（如适用）
   5. E2E 端到端测试：按用例运行 E2E（如有前端）

4. 自审 — 当执行自审时：
   Trigger: 输出 developer-report 前；Read: `references/self-review-methodology.md`；Expect: 7 维度结构化审查口径；Consume: 写入 developer-report 自审字段；Evidence: AC 完整性、TDD 完整性、自测证据、范围合规、代码规范、报告完整性和执行拆解遵循度结论；Sync: 自审方法论变化时同步本步骤。

## 失败路由合同

Every blocked or partial runtime outcome uses `failure_contract` with closed fields: `status`, `failure_code`, `reason`, `owner`, `safe_to_continue`, `next_action`, `evidence_refs`, and `user_message`.

| Condition | failure_code | Owner | Next action |
| --- | --- | --- | --- |
| Required input missing | `MISSING_INPUT` | `delivery-owner` | redispatch with exact missing fields |
| Writable scope missing or ambiguous | `AMBIGUOUS_SCOPE` | `delivery-owner` | provide `file_range`, `files`, or `task_scope` |
| `design_refs`, `test_refs`, artifact refs, or AC refs do not resolve | `UNRESOLVED_REF` | owner of the bad ref via `delivery-owner` | refresh canonical artifact or task refs |
| Failure owner does not match failure cause | `OWNER_MISMATCH` | `delivery-owner` | correct routing before continuing |
| Report/schema/template validation fails | `SCHEMA_FAILURE` | `developer` or contract owner named by validator | fix report or escalate contract mismatch |
| Required validator/gate fails | `GATE_FAILURE` | gate owner named by evidence | fix gate failure or route upstream |
| Implementation needs files outside writable scope | `OUT_OF_SCOPE_CHANGE` | `delivery-owner` | refresh scope or remove out-of-scope change |
| Historical green artifact or stale active ref is being replayed | `STALE_STATE_REPLAY` | `delivery-owner` | refresh active refs and rerun proof |
| Verified report lacks current command/test/log output | `FRESH_PROOF_GAP` | `developer` | rerun proof and capture current output |

Design/interface drift is not implemented locally unless the changed canonical file is in writable scope. If it is not in scope, express the drift in `reason` / `next_action`, keep `failure_code` inside the schema enum, and route through `delivery-owner` to design or tech-lead.

Repeated test failure after two focused fix attempts becomes `PARTIAL` or `BLOCKED` with current failing evidence. Full regression failures that pre-exist the Task must be recorded and routed; they cannot be converted into `VERIFIED`.

## 输出

`{unit_work_dir}/tasks/{task_id}/developer-report.json`（unit_work_dir 由 canonical delivery plan 定义）
- 运行时模板：`shared/skills/developer/templates/developer-report.template.json`
- 只写 canonical JSON 报告；`projections/developer-report-template.md` 仅为人类展示层，不作为运行时真源。
- runtime JSON 必须符合 canonical schema/template；自测结果写入 `self_testing`，自审与接口漂移明细通过 `evidence_refs` / `reviewable_anchor` 指向证据包，不能只写 markdown 段落替代 canonical 字段。
- Report fields come from schema/template; this file names the required runtime evidence groups: `evidence_refs`, `reviewable_anchor`, `file_changes`, `tdd_evidence_index`, `self_testing`, `task_scope`, `failure_contract`, and `fresh_proof`.
- `tdd_evidence_index` records each AC's RED `FAIL_EXPECTED`, GREEN `PASS`, `test_ref`, and evidence refs. `self_testing` records coverage review, full regression, static analysis, smoke/E2E, or not-applicable reasons.
- For `runtime_status: "VERIFIED"`, `fresh_proof.current_evidence_refs` and each proving command `current_output_ref` must point to current command output, test output, build output, execution log, or gate output captured in this run. A command string alone is a replay instruction, not proof.
- For `runtime_status: "BLOCKED"` or `PARTIAL`, `failure_contract` must use the closed fields and failure codes in the canonical schema.
- 非说明模式下输出报告时，必须以运行时模板形成可提交 JSON 骨架并填入真实 Task 值，不能只列字段名或用自然语言代替 `developer-report.json` 内容。
- 说明模式下若用户询问如何输出 `developer-report.json`，必须给出完整 JSON 骨架；若文件范围缺失，`task_scope` 与 `file_changes` 写空数组，并用 `runtime_status: "BLOCKED"`、`blocked_reason` 与 `missing_inputs` 记录阻断原因。

## 完成校验

- [ ] 运行面模式已判定为 `EXECUTE`，且没有 unresolved / stale / out-of-scope 输入
- [ ] 执行拆解 5 步已全部完成（代码探索 + 模式识别 + 步骤规划 + 风险标注 + 确认）
- [ ] 每条 AC 有对应 RED/GREEN 证据
- [ ] TDD 循环完整（未跳过 RED）
- [ ] 若全量回归存在既有失败，已记录并上报 delivery-owner，整体结论仅为 BLOCKED / 部分完成
- [ ] MUST 条款符合 `{{RUNTIME_HOME}}/rules/代码规范.md`（复杂度/错误处理/硬编码/死代码/外部调用）
- [ ] 仅修改声明的文件范围；发现设计漂移时已通过 `failure_contract` 路由，未原地改写范围外 canonical 设计真源
- [ ] `file_changes` 全部落在 `task_scope` 或派发合同声明的文件范围内
- [ ] 报告完整（TDD 记录 + 完整输出 + 自测结果 + 文件变更 + 自审）
- [ ] canonical developer-report 包含 `tdd_evidence_index` 与 `reviewable_anchor`，且证据锚点可被 verify / review 追溯
- [ ] `VERIFIED` 报告包含当前可审查 `fresh_proof`；命令字符串没有被当作 proof
- [ ] 自测: Task `test_refs` 存在时已对照 test-cases.json 审视覆盖充分性；无 `test_refs` 时已记录 AC-only fallback 理由
- [ ] Task `test_refs` 存在时，RED/GREEN 证据已回指 `test_cases[].assertion_target`、`product_refs`、`design_refs` 与 `evidence_expectation`
- [ ] 自测: 全量测试 PASS + 静态分析 PASS（lint/type/build）
- [ ] 自测: 冒烟验证通过或标注不适用理由
- [ ] 自测: E2E 测试通过或标注不适用理由
- [ ] BLOCKED / PARTIAL 报告包含闭合 `failure_contract`，且 owner 与 next action 可执行

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；执行前从 `worklog.md` 读取当前 `state_ref / next_ref`。
- standard-chain 的 `worklog.md.state_ref / next_ref` 必须使用 `canonical:` active artifact ref，并经 active `artifact-registry.json` 解析当前 `tasks.json / design.json / test-cases.json`。
- developer 只更新派发范围内代码和报告，不修改 scope registry 或根 `worklog.md`。
