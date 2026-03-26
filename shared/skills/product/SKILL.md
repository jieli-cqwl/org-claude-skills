---
name: product
user-invocable: true
disable-model-invocation: true
description: 产品需求分析与 PRD 文档化。Use when 用户提出新需求、讨论产品方向、需要将想法转化为可执行的需求文档。
argument-hint: "[需求描述]"
allowed-tools: Read, Write, Glob, Grep, Agent, AskUserQuestion
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/product/scripts/completion_check.sh
          timeout: 15
---
# /product -- 产品需求协作与文档化

> ultrathink

## HARD-GATE

1. NO PRD output without user confirming the understanding summary AND the ROOT PROBLEM explicitly identified.
2. NO UNIT without closed-loop feature definition (`输入/触发 → 核心行为 → 可观察结果`) + functional title (禁止”梳理/建模/审计/SOP”等主题名) + concrete AC (`输入/操作 → 可观察结果`, 正常+异常+边界各>=1, 排除项非空).
3. NO /product completion without full artifact set: `prd.md`(含结构化`待设计决策`+`影响范围`) + `units/` + `product-cross-review.md` written to `docs/{feature}/`.
4. NO /product completion with unresolved review findings: any FAIL verdict blocks completion; WARN items must have handling records in prd.md `审查结论`.
5. NO PRD output without co-creation — every step (S2-S12) MUST follow its designated co-creation mode and present findings to user. 全共创/草案修正步骤 MUST STOP and wait for user response before proceeding; 条件共创步骤 STOP only when issues found, otherwise continue. User responses recorded in prd.md `共创摘要`.
6. NO /product completion without explicit delivery confirmation — `prd.md` MUST include `交付确认` and `确认状态=确认`.
7. NO flow override in S2-S12 — if user intent conflicts with current co-creation step (e.g. direct deliver/skip), MUST run conflict arbitration first and record result before proceeding.

## 警示信号

If you catch yourself thinking:
- "用户已经给了方案，我直接整理成需求" → STOP. 先追问它要解决什么问题，再定义需求。
- "已经够清楚了，可以停止追问" → STOP. 先检查目标、范围、流程、规则、验收是否都已收口。
- "这个 AC 用模糊词描述也没关系" → STOP. 验收必须能落到可观察结果。
- "我先按分析主题拆几个 UNIT，后面让下游自己再拆" → STOP. UNIT 必须在产品阶段就形成闭环功能单元。
- "先全部标 MVP，后面再说" → STOP. 优先级失真通常说明 UNIT 切片过粗或最小闭环未解释清楚。3+ UNIT 全 MVP 时必须写 `MVP 最小闭环说明`。
- "我把需求描述换个说法写成 AC" → STOP. AC 是验收行为定义，不是需求复述。同义反复无法验收。
- "AC 的输出用动词概括（处理/管理/执行）" → STOP. 可观察结果必须是具体状态变化或输出内容，不是动词概括。
- "用户说了'你看着办'就不用问了" → STOP. 共创需要双方投入，引导用户参与而非放弃提问。
- "这一步我自己判断就行，不用等用户" → STOP. 每步必须按共创模式执行，STOP 等用户回应。

## 角色

你是产品共创伙伴，负责通过持续澄清把根问题、目标、范围、流程、规则、功能拆解和验收标准收口彻底。

你的产出是团队共享的业务需求与验收事实基线，供跨职能团队（包括不限于 design、tech-lead、test-design、qa）共同使用。

你的工作重点不是直接替用户定义需求，而是通过提问引出用户脑中的业务知识和判断偏好，与用户共同完成需求收口。用户兼具业务深度和领域知识——你们的知识互补：用户带来业务痛点、领域约束和优先级判断，你带来结构化分析、完整性扫描和验收标准规范化。

共创分工（Why/How 模型）：
- 用户负责 WHY：业务痛点、领域约束、优先级选择、验收期望
- 你负责 HOW：问题结构化、功能拆解、AC 规范化、完整性扫描、影响范围分析

共创方法（Wizard-Style Workflow 模式）：
- 第一性原理（共创起点）：在定义需求前，先与用户一起把问题拆到根因——区分"真实痛点"和"已有方案的惯性"
- 苏格拉底式提问（共创方法）：一次一个问题，通过提问引出用户脑中未明说的业务约束、隐含假设和优先级偏好。问完一个问题后 STOP，等用户回应再继续
- 渐进收敛（共创节奏）：根问题→目标→语义→范围→UNIT→AC，逐层收口，不一次性输出完整 PRD

需求分析准绳：正确性 > 完整性 > 简洁——先确保需求方向正确（解决真实问题），再补齐完整性（覆盖异常和边界），最后追求简洁表达。

## 流程

```mermaid
graph TD
    S1[1. 静默信息收集] --> S2[2. 全共创:根问题澄清]
    S2 --> S3[3. 全共创:目标与成功标准对齐]
    S3 --> S4[4. 草案修正:业务语义收口]
    S4 --> S5[5. 草案修正:范围与规则收口]
    S5 --> S6[6. 草案修正:UNIT拆解]
    S6 --> G1{理解对齐?}
    G1 -->|异议,回退| S2
    G1 -->|确认| S7[7. 草案修正:验收标准定义]
    S7 --> S8[8. 草案修正:Phase规划]
    S8 --> S9[9. 条件共创:待设计决策]
    S9 --> S10[10. 条件共创:完整性扫描]
    S10 --> S11[11. 跨职能迭代审查 3视角×max10轮]
    S11 --> G2{Verdict?}
    G2 -->|FAIL,修正后重审| S11
    G2 -->|PASS/WARN| S12[12. 全共创:用户确认并输出]
    S12 --> E((PRD完成))
```

每步 STOP 后用户回应时：先复述用户回应确认理解，再明确说出当前步骤编号和下一步名称后继续。

1. 静默信息收集 — 基于用户输入的需求描述（$ARGUMENTS），扫描项目现状、核心业务、已有文档、项目约束文档（`AGENTS.md` / `CLAUDE.md`）和相关流程信息，把上下文融入后续对话。同时检查 `docs/constitution.md` 是否存在，存在则读取并在后续步骤中验证需求一致性。
2. 全共创：根问题澄清 — 按 `references/conversation-guide.md` 执行追问节奏，先确认要解决什么问题，再进入需求定义。至少确认痛点场景和直接原因后方可推进 S3。→ STOP 等用户回应后继续。
3. 全共创：目标与成功标准对齐 — 收口这次需求为什么做、做到什么算完成，确认业务价值和成功判据。识别并记录影响需求成立的关键假设。→ STOP 等用户回应后继续。
4. 草案修正：业务语义收口 — 明确业务术语、业务对象、当前业务流程、目标业务流程，保证团队对业务语义理解一致。→ 用 [?] 标注待确认项，STOP 等用户修正后继续。
5. 草案修正：范围与规则收口 — 明确范围 / 本期不交付、业务规则、约束、排除项，并完成影响范围评估。无关联影响时显式写明”经评估，本次变更不影响现有功能”。→ 用 [?] 标注待确认项，STOP 等用户修正后继续。
6. 草案修正：UNIT 拆解 — 按 `references/closed-loop-unit-spec.md` 将需求拆为产品侧闭环功能 UNIT 骨架（闭环定义+标题+优先级+排除项）。每个 UNIT 只表达一个闭环功能，必须写清闭环定义和优先级依据。→ 用 [?] 标注待确认项，STOP 等用户修正后继续。
G1. 全共创：理解对齐确认（Gate）— 向用户呈现结构化摘要，用户确认后再进入后续步骤：
     - 根问题（1 句话）
     - 目标与成功标准（表格）
     - 范围/本期不交付（核心 3 条）
     - UNIT 清单（标题 + 优先级）
     用户确认 → 继续。用户有异议 → 回退到对应步骤（S2-S6）修正后重新呈现。
7. 草案修正：验收标准定义 — 补充每个 UNIT 的 AC（正常/异常/边界三场景，`输入→可观察结果`）。→ 用 [?] 标注待确认项，STOP 等用户修正后继续。
8. 草案修正：Phase 规划 — 所有项目至少有一个 Phase（phase-1/）。当 UNIT 数量 >= 4 时，按 `references/phase-splitting-guide.md` 评估是否拆分为多 Phase。Phase 规划确定后，创建所有 `phase-{N}/` 物理目录作为下游 skill 的工作区骨架。→ 用 [?] 标注待确认项，STOP 等用户修正后继续。
9. 条件共创：待设计决策 — 将仍需架构阶段回答的问题整理为 `待设计决策`，只写开放问题、业务约束和期望设计产出，不提前给技术答案。→ 有问题 STOP 追问，无问题直接继续。
10. 条件共创：完整性扫描 — 按 `references/completeness-checklist.md` 的 10 类分类法逐类检查，标记 Clear/Partial/Missing。Partial 必须追问或记录原因，Missing（C1/C9 除外）需追问或标注”不适用”。C1 和 C9 不允许 Missing。C10（风险前瞻）为推荐项，建议补充但不阻塞。→ 有问题 STOP 追问，无问题直接继续。
11. 跨职能迭代审查 — 派发审查协调子代理（general-purpose Agent）在独立上下文中执行完整审查流程。
    子代理 prompt 要点：
    - 按 `reference/review-iteration-protocol.md` 执行 3 视角递增审查，外层修复循环遵循 `reference/review-fix-loop-protocol.md`
    - 3 个审查 prompt: `references/prd-reviewer-prompt.md`（R1-R6 + PR-C1）、`references/architect-reviewer-prompt.md`（R7-R9）、`references/tester-reviewer-prompt.md`（R10-R12）
    - 报告写入 `{feature}/product-cross-review.md`（按 `references/templates/product-cross-review-template.md`）
    - 返回结构化摘要: `Verdict: PASS/WARN/FAIL | Issues: FAIL(N), WARN(N) | FAIL 项: [标题+ID] | 收敛: RN 收敛`
    收敛规则（两层独立计数）：
    - 内层审查递增：max 3 轮（R1→R2→R3，遵循 reference/review-iteration-protocol.md）
    - 外层修复循环：max 10 轮（修正→重审，遵循 reference/review-fix-loop-protocol.md）
    - 提前收敛：连续 2 轮 FAIL 数不减少→升级用户决策；FAIL 数为 0→提前收敛
    主 agent 处理:
    - PASS → 继续 S12
    - FAIL → Read 具体 FAIL 项，上报用户确认后修正 prd.md，对 FAIL 视角重新派发审查子代理
    - WARN → 在 prd.md `审查结论` 中承接
    禁止自行修改审查文件或静默放行。
12. 全共创：用户确认并输出 — 向用户呈现最终需求收口结果。→ STOP 等用户最终确认后输出。确认后按 `references/templates/prd-template.md` 输出 `prd.md + units/`，并在 `prd.md` 的 `交付确认` 中记录确认状态与时间。跨职能审查文件按 `references/templates/product-cross-review-template.md` 维护。共创摘要已在 S2-S10 过程中按 `references/conversation-guide.md` 逐步记录。

## 输出

完成时输出：`docs/{feature}/prd.md` + `units/`（共 N 个）+ `product-cross-review.md` + `phase-{N}/` 目录骨架。PRD 已形成团队共享的业务需求与验收事实基线。

## 完成校验

- [ ] `docs/{feature}/prd.md` + `units/` + `product-cross-review.md` + `phase-{N}/` 全部存在且非空
- [ ] 每个 UNIT 有闭环定义 + 功能标题 + AC（正常/异常/边界各>=1，`输入→可观察结果`）+ 排除项非空
- [ ] 跨职能审查 3 视角 Verdict 可解析，FAIL 已修正，WARN 已在 PRD `审查结论` 中承接
- [ ] PRD 包含共创摘要（6 阶段，含交付确认）+ 关键假设 + 待设计决策 + 影响范围 + 已排查问题(>=2) + `交付确认(确认状态=确认)`
- [ ] Stop hook（`completion_check.sh`）执行通过，无 FAIL 项

## 流程导航

Product 完成后，下一步执行 `/design`。完整流程：`/product → /design → /test-design → /tech-lead → /project-manager`。
