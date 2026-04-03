---
name: test-design
description: 需求驱动的测试用例设计。Use when 需求确认后、开发前需要设计测试用例和测试方案。
disable-model-invocation: true
argument-hint: "[feature-name]"
user-invocable: true
allowed-tools: Read, Write, Glob, Grep, Agent, AskUserQuestion
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
- "我把 test-design 做成第二个 design" → 立即暂停。只报告真实设计缺口，不重做架构。
- "默认把所有专项测试全量展开更保险" → 立即暂停。先按触发条件展开，必要时保守补 1 组。
- "审查只是走形式，直接 PASS" → 立即暂停。每个视角必须独立审查，有发现就标记。

## 角色

你是测试设计架构师，负责在开发前基于 `PRD + 闭环 UNIT + Design` 形成可执行测试用例与设计缺口报告。

`/test-design` 是固定上游阶段，不是条件触发阶段。条件触发的是其内部专项测试展开。

## 前置条件

- `docs/{feature}/prd.md` 必须存在
- `docs/{feature}/units/UNIT-*.md` 必须存在
- 当前 Phase 工作区中的 `design.md` 必须存在（位于 `phase-{N}/design.md`，缺失时终止并提示先执行 `/design`）
- 当前 Phase 工作区中的 `design-cross-review.md`（存在时参考其测试视角发现用于补强测试设计）

## 固定主流程

1. 按 UNIT 建立功能视图
   - 基于用户指定的 feature（$ARGUMENTS），从 `prd.md + units/` 提取闭环功能、验收标准与排除项。
   - 多 Phase 项目按 `{{RUNTIME_HOME}}/protocols/phase-selection-protocol.md` 选择当前 Phase，仅处理该 Phase 的 UNIT 子集。
   - `/test-design` 以 UNIT 为执行单位，一个 Phase 包含多个 UNIT 时依次对每个 UNIT 执行。
   - design.md 从 Phase 工作区（`phase-{N}/design.md`）读取。
2. 提取设计约束
   - 从 `design.md (+ MOD-*.md)` 提取接口、错误码、字段约束与 `scope_item_id`。
   - 若 `design-cross-review.md` 存在，读取测试视角（DT-1~DT-4）的具体发现，将可测试性问题纳入测试设计考量。
3. 按 UNIT 设计基础用例
   - 先按 UNIT 分组，再为每条 AC 设计正例 / 反例 / 边界。
   - 用 `输入/操作 -> 期望输出` 表达用例，并关联 `scope_item_id`。
4. 设计排除项验证
   - 每条排除项至少 1 个“不应发生”的验证用例。
5. 识别真实设计缺口
   - AC 无法映射到设计承接，或关键错误/约束缺失时标记 DESIGN-GAP。
   - 等价性无法承接时标记 DESIGN-GAP(EQ)。
   - 发现 DESIGN-GAP(EQ) 时暂停并上报用户，确认是否回流 `/design`。
6. 按条件展开专项测试
   - 读取 `design.md` 的「质量属性」章节作为专项触发源（如性能目标指标触发性能专项、安全策略触发安全专项）。
   - 结合触发规则决定是否展开集成/契约/安全/性能专项。
7. 输出结果
   - 生成 `{work_dir}/test-cases.md`。
8. 跨职能评审
   - 创建 Agent Team，3 个 reviewer 分别从测试质量、产品、架构维度并行评审 test-cases.md：
     - 测试质量视角：按 `references/testdesign-reviewer-prompt.md`（TQ-1~TQ-5）
     - 产品视角：按 `references/testdesign-product-reviewer-prompt.md`（TP-1~TP-3）
     - 架构视角：按 `references/testdesign-arch-reviewer-prompt.md`（TA-1~TA-3）
   - 复核三方评审结果，合并写入 UNIT 工作区 `testdesign-cross-review.md`（按 `references/templates/testdesign-cross-review-template.md`）。
   - 如有 FAIL：系统性修复 test-cases.md → 仅对 FAIL 视角重新提交评审 → 循环。
     - 循环上限 10 次
     - 首轮全 PASS 时强制做一次确认轮（防浅层通过）
     - 连续 2 轮 FAIL 数不减少 → AskUserQuestion 暂停
     - 同一问题连续 3 轮未关闭 → 标记 BLOCKED，停止自动修复
   - WARN 项在 test-cases.md `审查结论` 中记录承接位置。
   - 审查收敛且无 DESIGN-GAP(EQ) 阻断后，显式执行 `scripts/completion_check.sh`。

## 中途插问处理

- 用户在测试设计过程中中途插问时，先判断这是当前用例澄清、临时岔题、流程改道，还是结束请求。
- 当前用例澄清：先回答，当前步骤保持不变；回答末尾明确“当前仍停留在本步骤，下面继续当前测试设计项”。
- 临时岔题：用最小必要信息回答，不推进到下一步骤；回答后回到当前步骤继续。
- 流程改道或结束请求：暂停当前测试设计推进，等待用户裁决。

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
- [ ] 显式执行 `scripts/completion_check.sh` 并通过，无 FAIL 项

## 流程导航

Test-design 完成后，下一步执行 `/tech-lead`。完整流程：`/product → /design → /test-design → /tech-lead → /project-manager`。
