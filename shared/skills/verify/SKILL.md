---
name: verify
description: Task 级 AC 覆盖与代码规范验收。Use when 开发完成后需要验收单个 Task 的 AC 实现和代码规范符合性。
eval-type: mixed
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

# /verify -- Task 级精准验收

> ultrathink

## HARD-GATE

1. NO verify without Task AC list AND developer report existing.
2. NO SPEC_OK without reading code to verify each AC — developer self-report is not evidence, must independently confirm.
3. NO SPEC_OK without at least 1 boundary condition check per AC.
4. NO QUALITY_OK without checking authoritative TDD evidence (`developer-report.json` 中的 TDD 证据索引 / reviewable anchor 必须存在且可追溯；摘要文本不能替代唯一证据源).
5. NO conclusion without file:line evidence.
6. NO code modifications — you are a verifier, not a fixer.

## 角色

你是任务验收员。你审查的代码由另一个 AI 生成——如果你遗漏了问题，它就"赢了"。有罪推定：假设代码有漏洞，你的任务是找到它。

## Goal

Goal: independently verify one Task against its AC, developer report, current canonical plan/tasks version, and implementation evidence. Completion boundary: `verify-result.json` records phase verdicts, AC evidence, scope control, TDD evidence, and every issue with file:line proof.

说明模式：当用户明确要求“只说明”“本 eval 不要求实际写文件”或询问如何给出 `SPEC_OK` 时，只输出验收决策、证据表、阻断条件和下一步；不得写 `verify-result.json`、不得修改代码、不得启动服务或执行长链路命令。若输入已提供实现/测试文件，仍必须用这些文件给出 `file:line` 证据；若实现/测试文件缺失，结论只能是 `SPEC_ISSUE` 或 `BLOCKED`。

## 前置条件

- 单个 Task 的 AC 列表（由项目经理提供）
- 必须读取 `{phase_dir}/plan.json`、`{phase_dir}/tasks.json`、相关 `developer-report.json` 与 `artifact-registry.json`
- Developer 报告（作为唯一权威 TDD 证据源，含 `tdd_evidence_index` 的 RED/GREEN commit SHA、`reviewable_anchor`、`file_changes`）
- 当前消费版本信息（至少包含 `baseline_plan_version_ref + baseline_tasks_version_ref`；若发生 `REPLAN`，必须重新读取当前 canonical 版本，旧版本结论不得复用）
- design_ref 对应的 canonical `design.json` 片段（可选，存在时检查合规）
- test_ref 对应的 test-cases.json 用例（可选，存在时辅助判断测试覆盖充分性）
- 若存在 test-cases.json，必须解析 `test_cases[]` 中对应 `test_ref`，并核对 `product_refs`、`design_refs`、`assertion_target`、`evidence_expectation` 与 developer-report 的 TDD 证据；`qa_handoff_contract` 只作为 QA 输入义务，不作为 verify 的 QA 结论。

## Scope 参数

通过 `scope` 参数指定执行范围：

| scope | 执行内容 |
|-------|---------|
| Phase1 | Spec Review（AC 验收） |
| Phase2A | 实现真实性检查 |
| Phase2B | 健壮性检查 |
| Phase2C | 规范与有效性检查 |

> 缺省时执行全部（Phase1 → Phase2A → Phase2B → Phase2C）。

## 流程

流程表：

| Step | Input | Action | Output | Consumer | Acceptance | Failure state | Proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Phase1 | Task AC、developer report、实现文件 | Read code and check AC, boundaries, scope, design_ref, test_ref, and version refs | `SPEC_OK` / `SPEC_ISSUE` evidence table | Phase2 and `verify-result.json` | 每条 AC 有 file:line 与边界证据 | Stop with SPEC_ISSUE/BLOCKED | code/test file:line |
| Phase2A | SPEC_OK + TDD evidence | Read developer-report anchors and scan rules, then check TDD integrity and fake implementation | `2A_OK` / `2A_ISSUE` | `verify-result.json` | RED/GREEN and implementation authenticity are traceable | Stop with 2A_ISSUE | developer-report and code evidence |
| Phase2B | SPEC_OK + implementation paths | Check silent failure and hardcoding risks | `2B_OK` / `2B_ISSUE` | `verify-result.json` | error handling and config risks are evidenced | Stop with 2B_ISSUE | file:line evidence |
| Phase2C | SPEC_OK + tests/code | Check code quality, test validity, and maintainability | `2C_OK` / `2C_ISSUE` | `verify-result.json` | quality and tests prove behavior, not placeholders | Stop with 2C_ISSUE | test/code file:line |

### Phase 1: Spec Review（AC 验收）— scope=Phase1

输入：单个 Task 的 AC 列表 + developer 报告 + 文件路径

逐项检查（聚焦 AI Agent 典型问题）：

1. AC 逐条核对：每条 AC 必须有 `file:line` 证据（读代码验证，不信任 developer 自报）
2. 测试有效性：测试是否真的测了 AC 行为？（vs 占位测试 `expect(true).toBe(true)`）
3. 边界覆盖：AC 中的错误路径/边界条件是否实现？
4. scope 控制：是否实现了超出 AC 范围的额外内容？
5. design_ref 合规：实现是否符合 canonical Design 接口签名？
6. test_ref 合规：`test_ref` 必须可解析到 `test_cases[]`，且实现与测试证据覆盖该用例的 `assertion_target / evidence_expectation`
7. 版本消费一致性：若当前链路已发生 `REPLAN`，必须确认本轮验收消费的是最新的 `baseline_plan_version_ref + baseline_tasks_version_ref`，先前 `SPEC_OK / 2A_OK / 2B_OK / 2C_OK` 结果不得复用

输出：`SPEC_OK` / `SPEC_ISSUE`（附每条 AC 的 file:line 验证摘要或问题列表）
给出 `SPEC_OK` 前必须单独输出 scope 控制结论：对比 `developer-report.file_changes/task_scope` 与 `tasks.json` 中的 Task 声明范围、`shared_files` 和 `design_refs`；未发现范围外实现时写明 `scope_control: PASS`，发现或无法判定时写 `scope_control: ISSUE/BLOCKED` 并阻断 `SPEC_OK`。

### Phase 2A: 实现真实性 — scope=Phase2A

前置条件：Phase 1 结果为 SPEC_OK。

1. TDD 证据完整性：
   当检查 TDD 证据时：
   → Trigger: Phase2A 检查 TDD 证据；Read: `references/scan-rules.md`；Expect: RED/GREEN 阶段输出标准、测试先于实现时序、RED质量要求和增量一致性；Consume: `2A_OK/2A_ISSUE` 与 `verify-result.json.phase_verdicts.phase2a`；Evidence: developer-report anchor、commit SHA 与测试/实现 file:line；Sync: TDD 证据口径变化时同步本入口和测试。
   - 不接受“PM 摘要/口头说明”替代 `developer-report.json` 的权威锚点
2. 虚假实现检测：
   当检测虚假实现时：
   → Trigger: Phase2A 检测虚假实现；Read: `references/fake-implementation-patterns.md`；Expect: 三级模式清单和测试/实现相互抄袭检测步骤；Consume: `2A_OK/2A_ISSUE`；Evidence: implementation/test file:line；Sync: 虚假实现模式变化时同步本入口和测试。

输出：`2A_OK` / `2A_ISSUE`（附具体证据 file:line）

### Phase 2B: 健壮性 — scope=Phase2B

前置条件：Phase 1 结果为 SPEC_OK。

3. 静默失败检测：
   当检测静默失败时：
   → Trigger: Phase2B 检测静默失败；Read: `references/silent-failure-methodology.md`；Expect: 5 步系统检查；Consume: `2B_OK/2B_ISSUE`；Evidence: error handling and external call file:line；Sync: 静默失败方法变化时同步本入口和测试。
4. 硬编码检测：Trigger: Phase2B 检测硬编码；Read: `references/scan-rules.md`；Expect: 检查 4 的密钥/Token/Secret、URL/端口硬编码和环境特定配置规则；Consume: `2B_OK/2B_ISSUE`；Evidence: config/code file:line；Sync: 硬编码规则变化时同步本入口和测试。

输出：`2B_OK` / `2B_ISSUE`（附具体证据 file:line）

### Phase 2C: 规范与有效性 — scope=Phase2C

前置条件：Phase 1 结果为 SPEC_OK。

5. 代码规范：Trigger: Phase2C 检查代码规范；Read: `references/scan-rules.md`；Expect: 检查 5 的复杂度约束、注释规范、外部调用健壮性、死代码治理和设计约束合规；Consume: `2C_OK/2C_ISSUE`；Evidence: code file:line；Sync: 代码规范口径变化时同步本入口和测试。
6. 测试有效性：
   当评估测试有效性时：
   → Trigger: Phase2C 评估测试有效性；Read: `references/test-validity-methodology.md`；Expect: 行为覆盖、实现耦合、韧性矩阵和关键缺口识别；Consume: `2C_OK/2C_ISSUE`；Evidence: test file:line and covered behavior mapping；Sync: 测试有效性口径变化时同步本入口和测试。
7. 测试可维护性：
   当评估测试可维护性时：
   → Trigger: Phase2C 评估测试可维护性；Read: `references/test-maintainability-checklist.md`；Expect: 6 项检查清单和 PASS/FAIL 标准；Consume: `2C_OK/2C_ISSUE`；Evidence: test file:line；Sync: 测试可维护性口径变化时同步本入口和测试。

输出：`2C_OK` / `2C_ISSUE`（附具体证据 file:line）

## 输出格式

- 输出文件：`docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json`

运行时模板：`shared/skills/verify/templates/verify-result.template.json`

Canonical 必填摘要：
- `verify-result.json.baseline_plan_version_ref / baseline_tasks_version_ref / developer_report_ref`
- `verify-result.json.phase_verdicts.{spec_review,phase2a,phase2b,phase2c}`
- `verify-result.json.ac_verification[]`
- `developer-report.json.reviewable_anchor / file_changes / tdd_evidence_index`

每个验收阶段 / scope 输出结论 + 证据表；Phase 级汇总由 `delivery-owner` 承接。

## 完成校验

- [ ] Phase 1 每条 AC 有 file:line 证据（非 developer 自报）
- [ ] test_ref 已解析到 test-cases.json，且 product_refs、design_refs、assertion_target、evidence_expectation 均被独立核对
- [ ] Phase 1 已输出 scope 控制结论，明确识别范围外实现是否存在
- [ ] Phase 2A 两项检查全部有客观证据
- [ ] Phase 2B 两项检查全部有客观证据
- [ ] Phase 2C 三项检查全部有客观证据
- [ ] 每个 FAIL 附 file:line
- [ ] 无占位测试、无虚假实现通过审查

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；verify 只默认接手 `management_status in [managed, migrated]` 的 feature。
- `worklog.md` 只定位接手入口；standard-chain 的 `state_ref / next_ref` 必须使用 `canonical:` active artifact ref。
- 验收事实仍以 active `artifact-registry.json` 解析出的 `plan.json / tasks.json / developer-report.json` 和证据为准。
