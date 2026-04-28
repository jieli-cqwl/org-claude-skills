# Standard Chain Runtime Layering Redesign

## Problem Statement

`standard-chain` 的核心问题不是某个节点说明不够细，而是运行面分层失控。`SKILL.md`、`references/`、canonical schema、canonical template、script、validator、gate、projection、history 的职责边界不清，导致 AI agent 在执行时无法稳定区分：

- 该读什么。
- 该信什么。
- 该做什么。
- 该停在哪。
- 该用什么 fresh proof 证明完成。

这不是文本长度本身的问题，而是确定性校验、角色判断、低频方法论、模板样例、历史说明和验收口径混在同一条运行路径里，造成上下文负担、source-of-truth 漂移、角色越权和完成证据失真。

旧 `2026-04-27-preflight-noise-regression/design.md` 和后续研究材料只作为问题线索与反例来源，不作为本设计的方案结构来源。

## Goals And Success Criteria

本设计通过工程化、单一职责、去噪音、渐进式披露、单一真源和可验收闭环，重构 standard-chain 的运行面边界。

优先级如下：

1. AI agent 运行时正确性。
2. 交付接手与验收可恢复。
3. Skill 维护便利性。

成功不是 `SKILL.md` 变短，而是能证明 AI 在标准链节点中更稳定地读对、信对、做对、停对、证对。

成功标准：

- 读对：主上下文和 reference 触发条件清楚；方法论按需加载，触发时必须读取并产生消费证据。
- 信对：每类运行事实有唯一权威裁决源；projection、history、template 不能反向定义 runtime truth。
- 做对：LLM 只处理角色判断、风险解释、方案取舍和必要用户对齐；确定性事实交给 script、validator、gate。
- 停对：缺输入、范围不明、ref 不可解析、owner 不匹配、schema/gate 失败时返回 BLOCKED 或明确路由，不继续下游。
- 证对：完成声明必须对应当前成功标准、canonical artifact、fresh proving command、gate、eval 或可复验记录；历史绿灯和自然语言总结不能替代完成证据。

## Approach

### Main Runtime Layer

| Layer | Responsibility | Non-Responsibility |
| --- | --- | --- |
| `SKILL.md` | 触发、角色职责、主流程、硬门禁、输入输出、停机/路由、reference 触发条件 | 长方法论、历史背景、模板正文、机械校验逻辑 |
| `references/` | 按需方法论、判断框架、复杂场景指南 | 隐藏 hard gate、定义 runtime truth、承载当前状态 |
| canonical schema | artifact shape、必填字段、枚举、基础结构约束 | 证明语义真实、证明 fresh proof 真的发生 |
| canonical template | artifact 初始骨架 | 字段语义真源、状态流转裁决、完成判定 |
| script | 稳定命令入口、参数解析、调用 validator/gate | 业务判断、设计判断、用户确认 |
| validator | schema、ref、字段、范围、证据结构等确定性校验 | 风险接受、业务取舍、设计方案裁决 |
| gate | 根据校验结果放行、阻断、路由 owner | 静默修复、替角色做决定 |
| projection/report template | 从 canonical artifact 派生的人类展示 | runtime truth、机器状态源、反向规则定义 |
| archive/history | 历史追溯 | 当前执行输入，除非 active registry 或恢复流程明确引用 |

### Runtime Integration Layer

| Layer | Responsibility | Boundary |
| --- | --- | --- |
| hooks | 在运行时拦截或提示风险 | 不定义新规则；只调用 adapter/checker/gate |
| adapters | 把 runtime payload 转成 checker 参数 | 不包含独立业务规则 |
| runtime catalog | 暴露可用 skill、hook、script 和 contract 入口 | 不覆盖 canonical contract |
| install exposure | 控制 skill 是否进入目标 runtime | 不替代 lifecycle-review 或运行质量审计 |

### Governance And Evidence Layer

| Layer | Responsibility |
| --- | --- |
| `evals/` | 证明 AI 行为更稳定，覆盖正例、反例、缺参、误触发和失败路径 |
| `examples/` | 提供正反例、触发样例、失败样例，服务 eval 或文档解释 |
| `evals/lifecycle-review.json` | 记录 retain / optimize / retire 证据；不替代运行质量审计 |
| migration audit | 记录规范性内容的删除、移动、改写和验证方式 |
| regression pilot | 证明改造没有破坏既有 standard-chain 消费路径 |

## Core Principles

### Engineering

工程化是把可机械验证的事实交给 script、validator、gate，例如文件存在、schema、ref、字段、范围、证据结构。它不是把业务判断、设计判断、风险接受或用户确认交给脚本。

### Single Responsibility

每层必须有明确 owner、消费者、输出和验证方式。单一职责不是所有内容只能出现一次，也不是为了目录对称硬拆文件；同一事实可以被引用、摘要或投影，但权威裁决源只能有一个。

### Noise Reduction

噪音包括无消费者内容、过期历史、重复真源、跨角色越权、隐藏 MUST、模板正文或脚本逻辑塞进主流程。去噪音不是压缩字数，不得删除 hard gate、失败路径、完成边界或安全约束。

### Progressive Disclosure

`SKILL.md` 提供主执行骨架和 reference 路由。reference 是按触发条件加载的执行资源；触发条件必须可观察，读取后必须有消费产物或证据。无条件生效的 hard gate、字段合同、状态流转和完成判定不能藏在 reference，必须进入 `SKILL.md`、canonical contract、schema、validator 或 gate。

### Single Source Of Truth

每类运行事实只有一个权威裁决源。其他材料可以引用、派生、投影或生成骨架，但不能反向定义规则。

### Acceptance Loop

每个完成声明必须能回放到成功标准、产物、命令、eval、gate 或消费者。单个脚本绿灯、历史通过记录、自然语言总结不能独立证明完成。

## Developer Pilot Boundary

`developer` 是验证样本，不是本次需求主线。试点验证运行面分层框架能否在一个高风险节点上落地。

The pilot must verify:

- Preflight 在未写代码前阻断缺输入、范围不明、ref 不可解析、owner 不匹配。
- AI 能按阶段触发读取 reference，并产出 mini-plan、`self_testing`、自审证据等消费结果。
- Completion gate 能验证 `developer-report.json`、TDD evidence、`self_testing`、fresh proof 结构。
- 缺输入、范围外、schema/gate 失败时 developer 返回 BLOCKED，并由 delivery-owner 按 owner matrix 分派；developer 不直接改上游真源。
- 试点结束输出两类结果：developer 节点闭环改造结果，以及可推广规则 vs developer 特例清单。

The pilot does not prove every standard-chain node has been redesigned. It must not rewrite `test-design`、`qa`、`delivery-owner` or redefine product/design/QA responsibility.

Main pilot: a minimal developer-only fixture covering normal execution, missing-input block, out-of-scope block, and completion gate validation.

Regression sample: `login-homepage-pilot` only proves existing standard-chain pilot consumption remains intact. It does not define the new design.

## Migration And Noise Strategy

Every normative segment removed, moved, or materially rewritten from `SKILL.md` must be audited. Normative content includes hard gate, MUST, inputs/outputs, failure routing, completion condition, field semantics, and lifecycle/status semantics.

Minimum migration audit fields:

| Field | Meaning |
| --- | --- |
| `source_ref` | Original file and anchor or line reference |
| `content_type` | hard_gate, protocol, reference_methodology, schema_shape, template_skeleton, script_check, projection_display, history, obsolete |
| `action` | keep, move, rewrite, archive, delete |
| `destination_ref` | Target layer/file or `none` for deletion |
| `consumer` | Runtime, agent, validator, gate, human reviewer, eval, or none |
| `verification_ref` | Command, test, eval, review, or audit proof |
| `reason` | Why this action is valid |
| `owner` | Owner responsible for the migrated rule |

Rules:

- If no target layer is clear, keep the content in `SKILL.md` and mark it for design decision; do not force-move it.
- Role-crossing content moves to the owner role or becomes a BLOCKED route.
- If schema can express shape but not semantics, add semantic validator, gate, eval, or reviewable evidence.
- If reference contains unconditional MUST, promote it to `SKILL.md` or canonical contract.
- If projection is consumed by runtime, change the runtime consumer to canonical artifact and keep projection as display only.
- Pure background can be deleted only when it has no current consumer or has been archived.

## Fresh Proof Boundary

Completion gate may validate fresh proof structure, required fields, and evidence reference shape. It does not automatically prove the command really ran in the current execution.

Fresh proof authenticity must come from at least one current, reviewable source:

- Current command output captured in the task session.
- Current test or build result.
- Current execution log linked by evidence ref.
- A reproducible proving command that can be re-run.

JSON that merely states a command passed is not sufficient by itself.

## Alternatives Considered

### Option A: Full-chain principles only

This would define common layering rules before touching any node. It avoids local overfitting, but risks producing an abstract standard that does not prove AI can execute the design.

### Option B: Developer-only redesign

This would create a fast, concrete pilot. It risks turning the whole requirement into a local developer cleanup and losing the standard-chain-wide problem definition.

### Option C: Runtime layering framework plus developer pilot

This is the chosen option. It first defines the standard-chain runtime layering framework, then uses `developer` as a bounded pilot to prove feasibility. The pilot feeds back into reusable rules and a developer-specific exception list.

## Change Scope

This design proposes a new small-chain workset:

`docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign`

It does not change `contracts/active-doc-scope.yaml` in this design step because the current registry points to `2026-04-28-test-design-governance`, which appears to be an active parallel workset. Registry cutover requires separate user confirmation.

Potential implementation surface after approval:

- Standard-chain runtime layering documentation.
- Developer `SKILL.md` and its references, scripts, validators, gates, templates, evals, examples, and tests.
- Migration audit artifact for developer pilot.
- Regression command for existing pilot.
- Worklog handoff entry for this proposed workset.

Out of scope:

- Full rewrite of all standard-chain nodes.
- `test-design` mainline changes.
- Product/design/QA responsibility redesign.
- Replacing canonical JSON with Markdown.
- Using projection/history/template as runtime truth.

## Invariants

- Correctness is more important than shorter files.
- `SKILL.md` must retain hard gates, failure paths, completion boundary, and reference routing needed for execution.
- Reference files are not second-class rules; they are triggered execution resources.
- Scripts, validators, gates, hooks, and adapters must fail closed when required inputs are missing or ambiguous.
- Developer may not modify upstream canonical truth outside declared task scope.
- Existing active workset must not be overwritten by this proposed design.

## Downstream Impact

- AI agent should get a smaller and clearer active path, without losing required methodology.
- Delivery owners should get clearer BLOCKED routes and owner assignment.
- Maintainers should get auditable migration records instead of silent text deletion.
- Validators and gates may need new fixtures for missing-input, out-of-scope, and fresh proof authenticity cases.
- Existing regression pilot must still pass after any implementation.

## Risks

| Risk | Mitigation |
| --- | --- |
| The design becomes a developer-only optimization | Require reusable rules vs developer exceptions as a pilot output |
| Noise reduction deletes real constraints | Require migration audit for normative content and prohibit untracked deletion |
| Progressive disclosure hides hard gates | Require unconditional MUST to live in `SKILL.md` or canonical contract |
| Script/gate over-automates judgment | Limit scripts to deterministic checks and route human/role decisions |
| Registry cutover conflicts with parallel test-design work | Write proposed workset first; do not change registry until explicitly approved |
| Fresh proof becomes self-reported JSON | Require current command output, execution log, test result, or reproducible command |

## Contract-Grade Preflight

This design triggers contract-grade preflight because it affects source-of-truth boundaries, validator/gate behavior, runtime hooks/adapters, migration audit, and handoff recovery.

### C1 Current Vs Target

Current HEAD already has `contracts/standard-chain.yaml`, canonical schemas/templates, existing skill bodies, completion gates, hooks, and standard-chain pilot fixtures. Target phase introduces a runtime layering framework and a developer pilot without cutting over all standard-chain roles.

Migration phase: proposed design workset first; implementation planning after user review; registry cutover only after explicit approval.

Cutover owner: standard-chain runtime owner.

### C2 Source Of Truth Matrix

| Fact Type | Source Of Truth | Conflict Priority |
| --- | --- | --- |
| Standard-chain role input/output contract | `contracts/standard-chain.yaml` plus canonical schemas | contract/schema over skill prose |
| Artifact shape | canonical schema | schema over template/projection |
| Artifact initial skeleton | canonical template | schema/validator over template |
| Runtime execution protocol | role `SKILL.md` | hard gate/contract over reference |
| Methodology | triggered `references/` | `SKILL.md` route controls when loaded |
| Mechanical validation | validator/gate/script | contract/schema over script-local prose |
| Human display | projection/report template | canonical artifact over projection |
| Current handoff | scope registry + `worklog.md` + active artifact | active registry/worklog over archive |
| Historical evidence | archive/history | not runtime truth unless recovery flow cites it |
| Completion proof | current command/test/log/evidence + gate | current proof over historical green artifact |

### C3 Closed Vocabulary / Grammar

Migration actions: `keep`, `move`, `rewrite`, `archive`, `delete`.

Pilot statuses: `PASS`, `BLOCKED`, `PARTIAL`, `FAIL`.

Runtime failure shape must include reason, owner, safe-to-continue, and next action. Exact JSON schema may be introduced during implementation planning if existing gates cannot express it.

State refs for managed handoff continue to use the existing standard-chain grammar in `contracts/standard-chain.yaml` when the feature is in standard-chain mode. This proposed design workset remains small-chain until registry cutover is approved.

### C4 Ownership / Waiver

| Artifact/Layer | Writer | Consumer | Waiver Approver | Mechanical Check |
| --- | --- | --- | --- | --- |
| `SKILL.md` runtime protocol | skill owner | AI agent/runtime | standard-chain runtime owner | skill quality/eval checks |
| canonical schema/template | contract owner | validator/gate/artifact producers | contract owner | schema/template validation |
| validator/gate/script | runtime owner | hooks/CI/agent | runtime owner | targeted tests |
| references | skill owner | AI agent | skill owner | trigger/eval checks |
| projection | renderer/report owner | human reviewer | renderer owner | projection manifest/source trace |
| migration audit | migration owner | reviewer/planner | standard-chain runtime owner | audit completeness check |

### C5 Failure Contract

Missing input, ambiguous scope, unresolved ref, owner mismatch, schema failure, gate failure, or fresh proof authenticity gap must produce BLOCKED or a fixed failure output. The agent must not infer current state from archive/history or projection.

### C6 Implementation Surface

Allowed future implementation surface is limited to the runtime-layering workset, developer pilot files, related developer tests/evals/scripts/templates, migration audit artifact, and regression proof commands. `test-design` mainline and active registry pointer are excluded until separately approved.

### C7 Proving Categories

| Success Criterion | Proof Category |
| --- | --- |
| Read correctly | developer eval covering triggered vs untriggered references |
| Trust correct truth source | source-of-truth matrix review and fixture assertions |
| Deterministic checks are scripted | preflight/completion tests |
| Stop correctly | missing-input/out-of-scope negative fixtures |
| Prove completion | current command/test/log evidence plus completion gate |
| Do not break existing chain | `bash tests/test-standard-chain-login-homepage-pilot.sh` or successor regression command |

### C8 Existing Contract Diff

Before implementation planning, compare this design against:

- `contracts/standard-chain.yaml`
- `contracts/active-doc-scope.yaml`
- `shared/skills/developer/SKILL.md`
- developer references, scripts, projections, evals, and tests
- hook manifests and runtime catalog entries
- existing standard-chain pilot tests and fixtures

Any conflict must be resolved in design or planning before implementation.

