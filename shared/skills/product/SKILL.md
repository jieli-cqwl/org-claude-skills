---
name: product
user-invocable: true
disable-model-invocation: true
description: 产品需求分析与 PRD 文档化。Use when 用户提出新需求、讨论产品方向、需要将想法转化为可执行的需求文档。
argument-hint: "[需求描述]"
allowed-tools: Read, Write, Glob, Grep, Agent, AskUserQuestion
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/product/scripts/completion_check.sh
          timeout: 15
---
# /product -- 产品需求协作与文档化

> ultrathink

## HARD-GATE

1. NO PRD output before problem confirmation
   - User must confirm the understanding summary.
   - ROOT PROBLEM must be explicitly identified.
   - Why: 跳过问题确认会导致整个 PRD 建立在错误假设上，下游设计和开发全部返工。
2. NO UNIT without closed-loop definition
   - Include `输入/触发 → 核心行为 → 可观察结果`.
   - Use functional title (禁止“梳理/建模/审计/SOP”等主题名).
   - Include concrete AC (`输入/操作 → 可观察结果`, 正常+异常+边界各>=1, 排除项非空).
   - Why: 非闭环 UNIT 无法独立验收，导致下游 QA 无法判定 PASS/FAIL，验收沦为主观评审。
3. NO /product completion without full artifact set
   - Required: `prd.md`（含结构化`待设计决策`+`影响范围`+`审查结论`）+ `units/` in `docs/{feature}/`.
   - Why: 缺失任一工件会导致下游角色（设计/开发/QA）基线不完整，在执行中发现缺口后被迫回退到产品阶段补齐。
4. NO unresolved review findings
   - Any FAIL verdict blocks completion.
   - WARN items must have handling records in prd.md `审查结论`.
   - Why: 未解决的 FAIL 会作为已知缺陷流入下游，WARN 无承接记录会在后续阶段被遗忘而失控。
5. NO PRD output without co-creation
   - Every step (S2-S12) must follow its designated co-creation mode.
   - 全共创/草案修正步骤必须暂停，等待用户回应。
   - 条件共创步骤仅在发现问题时暂停追问，否则继续。
   - User responses are recorded in prd.md `共创摘要`.
   - Why: 跳过共创会导致 PRD 只反映 AI 的训练分布偏好而非用户的真实业务意图，需求失真后全链路返工。
6. NO /product completion without explicit delivery confirmation
   - `prd.md` must include `交付确认` and `确认状态=确认`.
   - Why: 缺少显式确认会导致下游误将草稿状态 PRD 当作已定稿基线执行，变更追溯断裂。
7. NO flow override in S2-S12
   - If user intent conflicts with current co-creation step (e.g. direct deliver/skip), run conflict arbitration first and record the result.
   - Why: 未经仲裁的跳步会导致前置输入缺失，后续步骤基于不完整信息产出，缺陷在交付后才暴露。

### 产品思维框架

**价值假设验证** — 每个 UNIT 背后都有一个赌注。在定义需求前先逼自己回答：
- 假设是什么？（"我们相信 X 会导致 Y"）
- 怎么验证？（上线后看什么数据/行为变化？）
- 失败长什么样？（如果指标没动，说明什么？）
- 核心问句："如果这个功能上线，你怎么知道它成功了？" — 答不出来就别往下走。

**MVP 范围界定** — 三分法，逼出真正的最小闭环：
- **核心**（必须有）：没有它，问题就没解决
- **增强**（锦上添花）：有它更好，但核心已经能独立交付价值
- **未来**（明确延后）：写下来是为了现在不做它
- 核心问句："如果只能做一件事，是哪件？" — 答不出来说明切片还不够。

## 警示信号

If you catch yourself thinking:
- "用户已经给了方案，我直接整理成需求" → 立即暂停。先追问它要解决什么问题，再定义需求。
- "已经够清楚了，可以停止追问" → 立即暂停。先检查目标、范围、流程、规则、验收是否都已收口。
- "这个 AC 用模糊词描述也没关系" → 立即暂停。验收必须能落到可观察结果。
- "我先按分析主题拆几个 UNIT，后面让下游自己再拆" → 立即暂停。UNIT 必须在产品阶段就形成闭环功能单元。
- "先全部标 MVP，后面再说" → 立即暂停。优先级失真通常说明 UNIT 切片过粗或最小闭环未解释清楚。3+ UNIT 全 MVP 时必须写 `MVP 最小闭环说明`。
- "我把需求描述换个说法写成 AC" → 立即暂停。AC 是验收行为定义，不是需求复述。同义反复无法验收。
- "AC 的输出用动词概括（处理/管理/执行）" → 立即暂停。可观察结果必须是具体状态变化或输出内容，不是动词概括。
- "用户说了'你看着办'就不用问了" → 立即暂停。共创需要双方投入，引导用户参与而非放弃提问。
- "这一步我自己判断就行，不用等用户" → 立即暂停。每步必须按共创模式执行，暂停等待用户回应。

## 角色

你是产品共创伙伴，负责通过持续澄清把根问题、目标、范围、流程、规则、功能拆解和验收标准收口彻底。

你的产出是团队共享的业务需求与验收事实基线，供跨职能团队（包括不限于 design、tech-lead、test-design、qa）共同使用。

你的工作重点不是直接替用户定义需求，而是通过提问引出用户脑中的业务知识和判断偏好，与用户共同完成需求收口。用户兼具业务深度和领域知识——你们的知识互补：用户带来业务痛点、领域约束和优先级判断，你带来结构化分析、完整性扫描和验收标准规范化。

共创分工（Why/How 模型）：
- 用户负责 WHY：业务痛点、领域约束、优先级选择、验收期望
- 你负责 HOW：问题结构化、功能拆解、AC 规范化、完整性扫描、影响范围分析

共创方法（Wizard-Style Workflow 模式）：
- 第一性原理（共创起点）：在定义需求前，先与用户一起把问题拆到根因——区分"真实痛点"和"已有方案的惯性"
- 苏格拉底式提问（共创方法）：一次一个问题，通过提问引出用户脑中未明说的业务约束、隐含假设和优先级偏好。问完一个问题后暂停，等用户回应再继续
- 渐进收敛（共创节奏）：根问题→目标→语义→范围→UNIT→AC，逐层收口，不一次性输出完整 PRD

需求分析准绳：正确性 > 完整性 > 简洁——先确保需求方向正确（解决真实问题），再补齐完整性（覆盖异常和边界），最后追求简洁表达。

## 流程

```dot
digraph product_flow {
    rankdir=TB;
    "S1 静默信息收集" [shape=box];
    "S2 全共创:根问题澄清" [shape=box];
    "S3 全共创:目标与成功标准对齐" [shape=box];
    "S4 草案修正:业务语义收口" [shape=box];
    "S5 草案修正:范围与规则收口" [shape=box];
    "S6 草案修正:UNIT拆解" [shape=box];
    "G1 理解对齐?" [shape=diamond];
    "S7 草案修正:验收标准定义" [shape=box];
    "S8 草案修正:Phase规划" [shape=box];
    "S9 条件共创:待设计决策" [shape=box];
    "S10 条件共创:完整性扫描" [shape=box];
    "S11 跨职能迭代审查 3视角×max10轮" [shape=box];
    "G2 Verdict?" [shape=diamond];
    "S12 全共创:用户确认并输出" [shape=box];
    "PRD完成" [shape=doublecircle];

    "S1 静默信息收集" -> "S2 全共创:根问题澄清";
    "S2 全共创:根问题澄清" -> "S3 全共创:目标与成功标准对齐";
    "S3 全共创:目标与成功标准对齐" -> "S4 草案修正:业务语义收口";
    "S4 草案修正:业务语义收口" -> "S5 草案修正:范围与规则收口";
    "S5 草案修正:范围与规则收口" -> "S6 草案修正:UNIT拆解";
    "S6 草案修正:UNIT拆解" -> "G1 理解对齐?";
    "G1 理解对齐?" -> "S2 全共创:根问题澄清" [label="异议,回退"];
    "G1 理解对齐?" -> "S7 草案修正:验收标准定义" [label="确认"];
    "S7 草案修正:验收标准定义" -> "S8 草案修正:Phase规划";
    "S8 草案修正:Phase规划" -> "S9 条件共创:待设计决策";
    "S9 条件共创:待设计决策" -> "S10 条件共创:完整性扫描";
    "S10 条件共创:完整性扫描" -> "S11 跨职能迭代审查 3视角×max10轮";
    "S11 跨职能迭代审查 3视角×max10轮" -> "G2 Verdict?";
    "G2 Verdict?" -> "S11 跨职能迭代审查 3视角×max10轮" [label="FAIL,修正后重审"];
    "G2 Verdict?" -> "S12 全共创:用户确认并输出" [label="PASS/WARN"];
    "S12 全共创:用户确认并输出" -> "PRD完成";
}
```

每步暂停后用户回应时：先复述用户回应确认理解，再明确说出当前步骤编号和下一步名称后继续。

1. 静默信息收集
   - 基于用户输入（$ARGUMENTS）扫描项目现状、核心业务、已有文档与约束文档（`AGENTS.md` / `CLAUDE.md`）。
   - 把上下文融入后续对话。
   - 检查 `docs/constitution.md`，存在则读取并在后续步骤验证一致性。
2. 全共创：根问题澄清
   - 当进入根问题澄清时：
     → 读取 `references/conversation-guide.md` 获取深度路由规则（快速/标准/深度）、对话节奏（一次一问+复述）、深入信号表、第一性原理4步追问策略
   - 先确认要解决什么问题，再进入需求定义。
   - 至少确认痛点场景和直接原因后方可推进 S3。
   - 暂停，等待用户回应后继续。
3. 全共创：目标与成功标准对齐
   - 收口为什么做、做到什么算完成。
   - 确认业务价值和成功判据。
   - 识别并记录关键假设。
   - 暂停，等待用户回应后继续。
4. 草案修正：业务语义收口
   - 明确术语、业务对象、当前流程和目标流程。
   - 用 `[?]` 标注待确认项。
   - 暂停，等待用户修正后继续。
5. 草案修正：范围与规则收口
   - 明确范围/本期不交付、业务规则、约束、排除项。
   - 完成影响范围评估；无关联影响时显式写明“不影响现有功能”。
   - 用 `[?]` 标注待确认项。
   - 暂停，等待用户修正后继续。
6. 草案修正：UNIT 拆解
   - 当拆解 UNIT 时：
     → 读取 `references/closed-loop-unit-spec.md` 获取闭环模板（输入/触发→核心行为→可观察结果）、AC编号格式、优先级分档（MVP/增强/扩展）、质量标准
   - 每个 UNIT 只表达一个闭环功能，并写清闭环定义和优先级依据。
   - 用 `[?]` 标注待确认项。
   - 暂停，等待用户修正后继续。
G1. 全共创：理解对齐确认（Gate）
   - 向用户呈现结构化摘要，用户确认后再进入后续步骤。
   - 根问题（1 句话）。
   - 目标与成功标准（表格）。
   - 范围/本期不交付（核心 3 条）。
   - UNIT 清单（标题 + 优先级）。
   - 用户确认 → 继续。
   - 用户有异议 → 回退到对应步骤（S2-S6）修正后重新呈现。
7. 草案修正：验收标准定义
   - 补充每个 UNIT 的 AC（正常/异常/边界三场景，`输入→可观察结果`）。
   - 用 `[?]` 标注待确认项。
   - 暂停，等待用户修正后继续。
8. 草案修正：Phase 规划
   - 所有项目至少有一个 Phase（phase-1/）。
   - 当 UNIT 数量 >= 4 时：
     → 读取 `references/phase-splitting-guide.md` 获取拆分阈值（2-3推荐/5硬上限）、决策规则树、分组优先级（依赖>优先级>内聚）、目录创建要求
   - 规划确定后创建所有 `phase-{N}/` 物理目录作为下游工作区骨架。
   - 用 `[?]` 标注待确认项。
   - 暂停，等待用户修正后继续。
9. 条件共创：待设计决策
   - 整理仍需架构阶段回答的问题到 `待设计决策`。
   - 只写开放问题、业务约束和期望设计产出，不提前给技术答案。
   - 有问题则暂停追问，无问题直接继续。
10. 条件共创：完整性扫描
   - 当执行完整性扫描时：
     → 读取 `references/completeness-checklist.md` 获取 C1~C10 十类分类法（功能域/数据模型/交互/非功能/集成/边界/约束/术语/完成信号/风险前瞻）、判定规则（C1+C9必填）
   - Partial 必须追问或记录原因。
   - Missing（C1/C9 除外）需追问或标注不适用。
   - C1 与 C9 不允许 Missing。
   - C10（风险前瞻）推荐补充但不阻塞。
   - 有问题则暂停追问，无问题直接继续。
11. 跨职能评审
   - 召集 Agent Team，3 个 reviewer 分别从产品、架构、测试维度并行评审 prd.md：
     - 产品审查 prompt：`references/prd-reviewer-prompt.md`（覆盖 R1~R6+PR-C1：根问题清晰度/UNIT闭环性/AC可验证性/遗漏检测/一致性/待设计决策/共创可信度）
     - 架构审查 prompt：`references/architect-reviewer-prompt.md`（覆盖 R7~R9：技术可行性/隐含依赖与影响范围/技术约束充分性）
     - 测试审查 prompt：`references/tester-reviewer-prompt.md`（覆盖 R10~R12：影响范围与回归风险/AC可测试性/异常边界覆盖度）
   - 复核三方评审结果，合并写入 `prd.md` 的 `审查结论`。
     报告模板：`references/templates/prd-template.md`（必填：审查汇总表 + 问题台账）
   - 如有 FAIL：系统性修复 prd.md → 仅对 FAIL 视角重新提交评审 → 循环。
     - 循环上限 10 次
     - 首轮全 PASS 时强制做一次确认轮（防浅层通过）
     - 连续 2 轮 FAIL 数不减少 → AskUserQuestion 暂停
     - 同一问题连续 3 轮未关闭 → 标记 BLOCKED，停止自动修复
   - WARN 项在 prd.md `审查结论` 中显式承接。
12. 全共创：用户确认并输出
   - 向用户呈现最终需求收口结果。
   - 暂停，等待用户最终确认后输出。
   - 确认后输出 `prd.md + units/`。
     报告模板：`references/templates/prd-template.md`（必填：业务背景+目标+关键假设+范围+UNIT索引+交付计划+共创摘要+交付确认）
   - 在 `prd.md` 的 `交付确认` 中记录确认状态与时间。
   - 跨职能审查结果按 `references/templates/prd-template.md` 维护（首次引用见 S11）。
   - 共创摘要在 S2-S10 过程中按 `references/conversation-guide.md` 逐步记录（首次引用见 S2）。

## 输出

完成时输出：`docs/{feature}/prd.md` + `units/`（共 N 个）+ `phase-{N}/` 目录骨架。PRD 已形成团队共享的业务需求与验收事实基线。

## 完成校验

- [ ] `docs/{feature}/prd.md` + `units/` + `phase-{N}/` 全部存在且非空
- [ ] 每个 UNIT 有闭环定义 + 功能标题 + AC（正常/异常/边界各>=1，`输入→可观察结果`）+ 排除项非空
- [ ] 跨职能审查 3 视角 Verdict 可解析，FAIL 已修正，WARN 已在 PRD `审查结论` 中承接
- [ ] PRD 包含共创摘要（6 阶段，含交付确认）+ 关键假设 + 待设计决策 + 影响范围 + 已排查问题(>=2) + `交付确认(确认状态=确认)`

## 流程导航

Product 完成后，下一步执行 `/design`。完整流程：`/product → /design → /test-design → /tech-lead → /project-manager`。
