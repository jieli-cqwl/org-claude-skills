---
name: test-design
description: 需求驱动的测试用例设计。Use when 需求确认后、开发前需要设计测试用例和测试方案。
disable-model-invocation: true
argument-hint: "[feature-name]"
user-invocable: true
allowed-tools: Read, Write, Glob, Grep, Agent, AskUserQuestion
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/test-design/scripts/completion_check.sh
          timeout: 15
---

# /test-design -- 开发前测试设计与缺口识别

> ultrathink

## HARD-GATE

1. NO output without `prd.md + units/ + design.md` existing.
2. NO test case without AC triple coverage (positive+negative+boundary, each verifiable) + 排除项验证用例 + negative+boundary count >= positive count. DESIGN-GAP only for real unmapped AC or explicit gap evidence.
3. NO /test-design completion without full artifact set: `test-cases.md`(含 UNIT 覆盖视图 + scope_item_id 对照 + EQ status) + `testdesign-cross-review.md` in UNIT 工作区.
4. NO /test-design completion with unresolved review findings: any FAIL verdict blocks completion; WARN items must have handling records in test-cases.md `审查结论`.
5. NO handoff to `/tech-lead` when any DESIGN-GAP(EQ) remains unresolved.
6. NO /test-design completion with shallow review evidence — cross-review MUST contain review iteration and convergence evidence.

## Red Flags

If you catch yourself thinking:
- "我把 test-design 做成第二个 design" → STOP. 只报告真实设计缺口，不重做架构。
- "默认把所有专项测试全量展开更保险" → STOP. 先按触发条件展开，必要时保守补 1 组。
- "审查只是走形式，直接 PASS" → STOP. 每个视角必须独立审查，有发现就标记。

## 角色

你是测试设计架构师，负责在开发前基于 `PRD + 闭环 UNIT + Design` 形成可执行测试用例与设计缺口报告。

`/test-design` 是固定上游阶段，不是条件触发阶段。条件触发的是其内部专项测试展开。

## 前置条件

- `docs/{feature}/prd.md` 必须存在
- `docs/{feature}/units/UNIT-*.md` 必须存在
- 当前 Phase 工作区中的 `design.md` 必须存在（位于 `phase-{N}/design.md`，缺失时终止并提示先执行 `/design`）
- 当前 Phase 工作区中的 `design-cross-review.md`（存在时参考其测试视角发现用于补强测试设计）

## 固定主流程

1. 按 UNIT 建立功能视图 — 基于用户指定的 feature（$ARGUMENTS），从 `prd.md + units/` 提取闭环功能、验收标准与排除项。多 Phase 项目按 `reference/phase-selection-protocol.md` 选择当前 Phase，仅处理该 Phase 的 UNIT 子集。/test-design 以 UNIT 为执行单位，一个 Phase 包含多个 UNIT 时依次对每个 UNIT 执行。design.md 从 Phase 工作区（`phase-{N}/design.md`）读取。
2. 提取设计约束 — 从 `design.md (+ MOD-*.md)` 提取接口、错误码、字段约束与 `scope_item_id`。若 `design-cross-review.md` 存在，读取测试视角（DT-1~DT-4）的具体发现，将可测试性问题纳入测试设计考量。
3. 按 UNIT 设计基础用例 — 先按 UNIT 分组，再为每条 AC 设计正例 / 反例 / 边界，用 `输入/操作 -> 期望输出` 表达，并关联 `scope_item_id`。
4. 设计排除项验证 — 每条排除项至少 1 个“不应发生”的验证用例。
5. 识别真实设计缺口 — AC 无法映射到设计承接，或关键错误/约束缺失时标记 DESIGN-GAP；等价性无法承接时标记 DESIGN-GAP(EQ)。→ 发现 DESIGN-GAP(EQ) 时 STOP 上报用户，确认是否回流 /design。
6. 按条件展开专项测试 — 读取 `design.md` 的「质量属性」章节作为专项触发源（如性能目标指标触发性能专项、安全策略触发安全专项），结合触发规则决定是否展开集成/契约/安全/性能专项。
7. 输出结果 — 生成 `{work_dir}/test-cases.md`。
8. 跨职能迭代审查 — 派发审查协调子代理（general-purpose Agent）在独立上下文中执行完整审查流程。
    子代理 prompt 要点：
    - 按 `reference/review-iteration-protocol.md` 执行 3 视角递增审查（最多 3 轮）
    - 3 个审查 prompt: `references/testdesign-reviewer-prompt.md`（TQ-1~TQ-5）、`references/testdesign-product-reviewer-prompt.md`（TP-1~TP-3）、`references/testdesign-arch-reviewer-prompt.md`（TA-1~TA-3）
    - 报告写入 UNIT 工作区 `testdesign-cross-review.md`（测试质量视角 / 产品视角 / 架构视角）
    - 返回结构化摘要: `Verdict: PASS/WARN/FAIL | Issues: FAIL(N), WARN(N) | FAIL 项: [标题+ID] | 收敛: RN 收敛`
    收敛规则（两层独立计数）：
    - 内层审查递增：max 3 轮（R1→R2→R3，遵循 reference/review-iteration-protocol.md）
    - 外层修复循环：max 3 轮（test-design 审查轮次较少，遵循 reference/review-iteration-protocol.md 原始定义）
    - 提前收敛：连续 2 轮 FAIL 数不减少→升级用户决策；FAIL 数为 0→提前收敛
    主 agent 处理:
    - PASS → 完成
    - FAIL → Read 具体 FAIL 项，上报用户确认后修正 test-cases.md，对 FAIL 视角重新派发审查子代理
    - WARN → 在 test-cases.md `审查结论` 中记录承接位置
    禁止自行修改审查文件或静默放行。

## 专项展开规则

统一规则：
- 必须展开条件命中：展开该专项
- 未命中但有常见信号：按风险补充
- 不确定：执行保守展开（至少补 1 个该专项场景）

专项方法详见：
- `references/integration-test-methodology.md`
- `references/contract-test-methodology.md`
- `references/security-test-methodology.md`
- `references/performance-test-methodology.md`

## 输出

输出到 `{work_dir}/test-cases.md`（work_dir 由 PRD 交付计划定义，模板详见 `references/templates/test-cases-template.md`；跨职能审查模板详见 `references/templates/testdesign-cross-review-template.md`），包含：
- `## 用例统计`
- `## UNIT 覆盖视图`
- `## AC 覆盖矩阵`
- `## 等价性对照矩阵`
- `## Design 问题报告`
- `## 测试用例`
- `## 专项测试触发依据与展开策略`（当“专项测试”计数 > 0 时必填）
- `## 审查结论`

跨职能审查报告：UNIT 工作区的 `testdesign-cross-review.md`

## 完成校验

- [ ] `test-cases.md` + `testdesign-cross-review.md` 存在于 UNIT 工作区
- [ ] 每条 AC 有正例+反例+边界，负面+边界 >= 正面；排除项有验证用例；scope_item_id 对照完整
- [ ] 跨职能审查 3 视角 Verdict 可解析，FAIL 已修正，WARN 已在 test-cases.md `审查结论` 中承接
- [ ] DESIGN-GAP(EQ) 已阻断回流 /design 或已解决；DESIGN-GAP 仅针对真实缺口
- [ ] Stop hook（`completion_check.sh`）执行通过，无 FAIL 项

## 流程导航

Test-design 完成后，下一步执行 `/tech-lead`。完整流程：`/product → /design → /test-design → /tech-lead → /project-manager`。
