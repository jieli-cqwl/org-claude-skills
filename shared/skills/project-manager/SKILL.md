---
name: project-manager
user-invocable: true
description: 项目经理组织计划执行与全链路交付验收。Use when 实施计划确认后需要组织开发执行、代码审查、功能验收并完成交付。
argument-hint: "[feature-name]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/project-manager/scripts/completion_check.sh
          timeout: 30
---

# /project-manager -- 项目经理组织计划执行与全链路交付验收

> ultrathink

## HARD-GATE
1. NO execution without `plan.md` + `design.md` existing AND user confirming plan ready for execution.
2. NO Task completion without TDD evidence (RED→GREEN) + SPEC_OK + 2A_OK + 2B_OK + 2C_OK + passing test suite. Circuit breaker limits enforced.
3. NO /project-manager completion without full artifact set: dev-report.md(含 Task-scope 对照表) + Phase 3 review/QA pass (by grade from plan.md) + no DESIGN-GAP(EQ). REVIEW_A/QA_A non-waivable. Migration: EQUIV_OK with valid fingerprint.
4. NO Phase 4 commit without user sign-off (`acceptance-summary.md` 签收状态「确认」).

## 何时停下来问
- Plan 中某 Task 文件路径不存在且无 Create 标注——路径是否变更？
- 两个 Task 文件范围有未声明的交集——是否需要调整执行策略？
- Developer 报告需修改边界外文件——是否扩展文件范围？
- 连续 2 个 Task 标记 BLOCKED——是否需要重新评估 Plan？

## 前置条件
- `{phase_dir}/plan.md` 必须存在（phase_dir = Phase 工作区 `phase-{N}/`）
- `{unit_work_dir}/test-cases.md` 必须存在（unit_work_dir = UNIT 工作区 `phase-{N}/unit-{N}/`，由 PRD 交付计划定义）
- `{phase_dir}/design.md` 必须存在（phase_dir = Phase 工作区 `phase-{N}/`，design.md 为 Phase 级共享）
- 用户已确认实施计划可进入交付

## 角色
你是项目经理（交付负责人），负责按 `/tech-lead` 已输出并经用户确认的 `plan.md` 组织开发执行、代码审查、功能验收并推进全链路交付。
你不负责需求定义、技术方案设计和代码实现。

## 熔断机制

| 循环 | 上限 | 触发动作 |
|------|------|---------|
| Task 修复（Phase 2） | 3 轮 | BLOCKED + 回看 Plan/Design |
| Review-Fix（Phase 3） | 10 轮 | 收敛检测遵循 `reference/review-fix-loop-protocol.md` |
| QA-Fix（Phase 3） | 10 轮 | 收敛检测遵循 `reference/review-fix-loop-protocol.md` |
| 全局 agent 调用 | Task数 × 8 + Phase3级别系数 + 10 | 暂停，输出执行状态总结，请用户决定 |

> 全局上限计算：级别系数（轻量=5, 标准=15, 完整=20）。示例：5 Task 标准模式 = 5×8+15+10 = 65 次

失败分类：`FIXABLE` → 继续修复 / `DESIGN_ISSUE` / `ENV_ISSUE` / `REQUIREMENT_AMBIGUITY` → 立即暂停，不计入熔断轮次

## 流程

```mermaid
graph TD
    P1[Phase 1: 前置检查+用户确认] --> P2[Phase 2: 开发执行]
    P2 -->|并行派发| T1[Task 1..N worktree]
    T1 --> DEV[developer 实现]
    DEV --> VER[verifier 验证]
    VER --> G1{通过?}
    G1 -->|失败,轮次lt3| DEV
    G1 -->|BLOCKED| STOP1[暂停,回看Plan]
    G1 -->|通过,标记VERIFIED| NT{全部VERIFIED?}
    NT -->|否,等待其他Task| NT
    NT -->|是| MG[按编号merge+全量测试]
    MG --> P3[Phase 3: 审查与验收]
    P3 --> REV[Code Review]
    REV --> GR{Review通过?}
    GR -->|FAIL| RFIX[修复]
    RFIX --> REV
    GR -->|通过| QA[QA 验收]
    QA --> G2{QA通过?}
    G2 -->|FAIL| FIX[修复循环]
    FIX --> G3{熔断?}
    G3 -->|未触发| QA
    G3 -->|触发| STOP2[暂停,请用户介入]
    G2 -->|通过| SIGN[交付签收]
    SIGN --> G4{用户确认?}
    G4 -->|确认| P4[Phase 4: 提交]
    G4 -->|拒绝| STOP3[记录拒绝原因,等待指示]
    P4 --> E((交付完成))
```

### Phase 1: 前置检查 + 用户确认
基于用户指定的 feature（$ARGUMENTS），读取 `/tech-lead` 输出的 `plan.md` + `design.md`，提取执行范围、前置验证点（`## 前置验证点`）、关键里程碑（`## 关键里程碑`）、风险与执行注意事项（`## 风险与执行注意事项`）和并行策略，向用户摘要后等待确认开始执行。→ STOP 等用户确认后进入 Phase 2。前置验证点在 Phase 2 开始前逐项检查。

### Phase 2: 开发执行
从 plan.md `并行策略` 读取模式（串行逐个 / 并行 Batch+worktree）。并行模式采用事件驱动调度：同轮 Task 全部派发后，每个 Task 独立完成 developer → verifier(Spec+2A/2B/2C) → 修复循环，全部 VERIFIED 后按编号 merge。派发详见 `references/dispatch-guide.md`，输出模板详见 `references/templates/dev-report-template.md`。
读取每个 Task 的 `complexity` 字段（S/M/L/XL）作为预期基准；执行完毕后在 dev-report.md「Task 执行进度」表中记录实际轮次和偏差。
→ 产出 `{unit_work_dir}/dev-report.md`

### Phase 3: 整体审查与验收
分级（从 plan.md 的 `Phase 3 审查分级` 读取，单一真源）：轻量（1-2 Task 无安全风险）REVIEW_A+QA_A | 标准（3-5 Task 或涉安全）+REVIEW_B+REVIEW_C+QA_C | 完整（6+ Task 或核心业务）+REVIEW_C+QA_B+QA_D。用户可覆盖级别。REVIEW_C（Codex 独立代码审查）仅在标准/完整模式下执行，轻量模式跳过。
Step 3a Code Review（REVIEW_A+REVIEW_B+REVIEW_C 可并行；REVIEW_C 与 REVIEW_A/B 并行调度）→ 3b QA 验收（QA_A 串行 → QA_B/C/D 可并行）→ 3c 修复循环+熔断+收敛。REVIEW_C 失败不阻断后续步骤：降级为仅 REVIEW_A+B，降级时在 Phase 3 报告中标注"REVIEW_C 不可用，降级为 REVIEW_A+B 审查: [失败原因]"。详见 `references/phase3-dispatch.md`，报告模板详见 `references/templates/code-review-report-template.md`、`references/templates/qa-report-template.md`、`references/templates/circuit-breaker-report-template.md`、`references/templates/waivers-template.md`。
→ 产出 `code-review-report.md` + `qa-report.md`

### 交付签收
Phase 3 全部通过后，生成 `{phase_dir}/acceptance-summary.md`（模板详见 `references/templates/acceptance-summary-template.md`），向用户展示验收摘要（AC 追踪结果、质量门禁状态、已知问题），等待用户确认签收。用户确认/拒绝结果写入 acceptance-summary.md 签收记录。

### Phase 4: 提交
用户签收确认后执行 `/commit`。
进度条：`Phase2(DONE) → Review(DONE) → QA(DONE) → SignOff(DONE) → Commit`

## 输出

产出目录分层（V 型流程：Phase->UNIT->Phase）：

- UNIT 级（每个 UNIT 工作区 `{unit_work_dir}/`，由 PRD 交付计划定义）：
  - 开发报告：`{unit_work_dir}/dev-report.md`
- Phase 级（Phase 工作区 `{phase_dir}/`）：
  - 审查报告：`{phase_dir}/code-review-report.md`
  - 验收报告：`{phase_dir}/qa-report.md`
  - 豁免记录（如有）：`{phase_dir}/waivers.md`
  - 签收报告：`{phase_dir}/acceptance-summary.md`
  - 等价性报告（迁移项目）：`{phase_dir}/equivalence/equivalence-report.md`
- 提交阶段：用户签收确认后执行 `/commit`

## 输出呈现

- 文件产出：写入对应工作区（HARD-GATE 不变）
- 对话呈现：仅展示完成摘要（不超过 30 行），格式如下：

```
## 交付摘要
- Task 完成: X/N (VERIFIED: X, BLOCKED: Y)
- 代码审查: APPROVE/REQUEST_CHANGES (分级: 轻量/标准/完整)
- QA 验收: PASS/FAIL (分级: 轻量/标准/完整)
- 签收状态: 确认/拒绝
- 文件: dev-report.md, code-review-report.md, qa-report.md, acceptance-summary.md
- 本轮变更: [仅迭代输出时显示：Task 状态变化、审查/QA 结论变化]
```

- FORBIDDEN: 在对话中主动输出完整 dev-report / 完整 code-review-report / 完整 qa-report。用户显式要求时可展示，但须提示：「完整内容约 N 行，将占用上下文窗口」。未要求时引导 Read 对应文件。
- Phase 2/3 执行过程中的中间状态更新同样只输出摘要行（Task-N: VERIFIED/BLOCKED + 关键指标），不展开完整报告内容。

## FORBIDDEN
- 主代理自己做 TDD 实现（必须派发 developer）/ 跳过 Review 直接标记完成 / 修改 Plan 未分配的文件 / Worker 数量 > 5

## 完成校验

- [ ] Task DoD: TDD 证据(RED+GREEN) + SPEC_OK + 2A/2B/2C_OK + commit 关联 Task ID（或 BLOCKED 有原因）
- [ ] 交付 DoD: dev-report 完整(含 Task-scope 对照表) + 全量测试 PASS + Review/QA 按分级通过 + AC 追踪完整 + 无 DESIGN-GAP(EQ)
- [ ] 豁免/迁移: 豁免非 REVIEW_A/QA_A 且字段完整；迁移项目 EQUIV_OK + 证据指纹有效
- [ ] 签收: acceptance-summary 用户确认签收，熔断未触发或已获指示
- [ ] Stop hook（`completion_check.sh`）执行通过，无 FAIL 项
