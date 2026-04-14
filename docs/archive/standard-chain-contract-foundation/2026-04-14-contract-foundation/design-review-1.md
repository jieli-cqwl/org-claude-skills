## 输入分析

REVIEW: DESIGN_ISSUE

本轮是进入 `writing-plans` 前的 design 出闸评审，不是正式 `/tech-lead`。

评审输入：
- `docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md`
- Agent Team 四个视角并行复核：架构分层、对抗式契约、实施可落地性、验收与回放闭环

当前阻断上下文：
- 当前 feature 目录只有 `design.md`
- 缺少 `brief.md / phase prd / units / test-cases`
- 因此前置追踪链无法按标准链完整闭合，本轮只能做 design 出闸评审，不能直接进入正式计划拆分

## Design 评审结论

### 评审摘要

这份设计的主方向是成立的：`canonical JSON + evidence refs + HTML` 的三层分离、`fail-closed`、旧 `process md` 退出运行时主链路，这些核心判断是清晰的。

当前不建议进入 `writing-plans`。原因不是“方向错了”，而是 foundation contract 还有几处会把设计决策偷渡到计划与实现阶段的硬缺口；如果现在进入计划拆分，后续暴露的问题应归因于 design 未收口，而不是实施阶段执行不力。

### Issues

1. `artifact-registry.json` 已经是 cutover、resolver、quarantine 的核心控制工件，但没有冻结 owner 和操作权限。
   证据：`design.md:375-408`、`design.md:597-616`、`design.md:1023-1030`、`design.md:1042-1060`
   问题：`Artifact Ownership` 和 `Operation Matrix` 都没有给 `artifact-registry.json` 定义 create / update / finalize / quarantine authority，也没有说明它是派生产物还是控制真源。
   风险：实现阶段会把 registry 写进隐式脚本逻辑，导致 `active_for_consumption`、`QUARANTINED -> 恢复`、active discovery 失去单一真源。
   建议：补齐 `artifact-registry.json` 的 ownership、authority、并发更新规则，以及同一 `(artifact_type, phase/unit)` 唯一 active 不变式。

2. `user-decision writer` 是 readiness gate，但 authority proof 仍是口头要求，不是可验证契约。
   证据：`design.md:280-289`、`design.md:459-479`、`design.md:481-495`、`design.md:497-527`、`design.md:996-1005`
   问题：文档要求 `user-decision writer` 做 authority 证明，但没有冻结 proof object、attestation source、用户身份绑定规则；`sign_off_status` 还被使用了，但枚举体系没有一起冻结。
   风险：录入通道或自动脚本可以伪装成真实用户决定，导致 `CLOSED` 被错误推进，且 replay 无法证明签收是否可信。
   建议：补最小 authority proof 契约，明确 proof 字段、真源引用、认证/重认证规则，并把 `sign_off_status / business_risk_acceptance_status` 的枚举冻结到 registry。

3. `BLOCKED` 恢复与 replay oracle 还不能稳定重放，关键场景会依赖实现脑补。
   证据：`design.md:194-201`、`design.md:703-746`、`design.md:905-943`
   问题：状态机只规定 `BLOCKED` 可恢复到“原前置阶段”，但没有 `blocked_from_stage / resume_stage / unblock_condition_ref` 之类的显式字段；同时 replay oracle 用一张全局 `must_match` 字段表覆盖异构 artifacts。
   风险：`BLOCKED -> 恢复`、`PARTIAL`、`CONDITIONAL_ALLOW`、authority conflict 等关键分支无法机器重放；不同实现会各自推断恢复目标和比对字段。
   建议：补 `BLOCKED` 恢复契约，并把 replay oracle 改成按 `artifact_type` 或场景 profile 定义的比对规则。

4. `plan_version_ref / tasks_version_ref` 混用了静态基线绑定和 runtime active baseline 语义。
   证据：`design.md:169-172`、`design.md:297-316`、`design.md:318-334`、`design.md:643-673`
   问题：`tasks.json` 作为静态注册表携带 `plan_version_ref`，但版本矩阵又把这两个字段定义成“当前运行时消费基线”，责任人还是 runtime producer。
   风险：`REPLAN`、mixed-version 校验和 replay 会出现双重解释，静态基线与运行时状态边界被打穿。
   建议：拆分“静态绑定字段”和“运行时 active 字段”，或按 artifact 类型明确同名字段的语义边界。

5. runtime artifacts 定义了 finalize，但缺少完整 runtime lifecycle contract。
   证据：`design.md:396-408`、`design.md:418-439`
   问题：`Operation Matrix` 给 `developer-report / verify-result / qa-result / delivery-state / user-decision` 等 runtime artifacts 定义了 finalize，但后文只为规划真源定义了 `DRAFT / FINALIZED / SUPERSEDED` 生命周期。
   风险：实现阶段会各自决定 runtime artifact 是原地改、追加快照还是新版本替换，registry active 标记、oracle 和 replay 无法统一。
   建议：补一张 runtime lifecycle contract，区分 append-only snapshot 和 mutable current state，并冻结 finalize、supersede、registry 状态迁移规则。

6. 计划交接面还没冻结，`writing-plans` 现在进入会被迫替 design 做关键拍板。
   证据：`design.md:783-839`、`design.md:968-1015`、`design.md:1038-1104`
   问题：文档定义了 validator stack、cutover strategy、V1 freeze 和 golden pilot path，但没有冻结 `Implementation Workstreams`、repo-level implementation topology、旧 `md` 消费者替换矩阵、V1 stop-line。
   风险：计划阶段会被迫决定代码落点、工作流切片、`user-decision writer` v1 实现形态、旧链路替换顺序，这些都属于设计冻结面，不应留给 `writing-plans` 兜底。
   建议：补 `Implementation Workstreams`、`Repo Topology`、`Current Consumer -> New Source` 替换表，以及分阶段 milestone freeze。

## Gate 检查明细

| Gate | 结论 | 关键证据 | 阻断项 |
|------|------|----------|--------|
| 需求语义一致性 Gate | FAIL | 当前 feature 目录仅有 `design.md`，无 `brief/prd/test-cases` 可用于 `AC -> Design` 语义映射；同时设计文档内也没有可供 `writing-plans` 直接消费的上游追踪矩阵 | 无法证明这份设计已完整承接目标、范围与 AC，标准链前置追踪链未闭合 |
| 决策充分性 Gate | FAIL | `artifact-registry` owner、`user-decision writer` authority proof、runtime lifecycle、V1 cut 方式仍是开放决策 | 这些都是 foundation contract 的关键拍板点，不能留给计划阶段或实现阶段临场决定 |
| 边界与契约完整性 Gate | FAIL | `artifact-registry.json` 缺 ownership/operation authority；`BLOCKED` 恢复字段缺失；replay oracle 对异构 artifact 统一硬套字段；部分状态字段枚举未冻结 | 核心控制边界仍留白，validator / resolver / replay 会各自补语义 |
| 演进可实施性 Gate | FAIL | `BLOCKED / REPLAN / quarantine / authority conflict` 的恢复与验证闭环未冻结；V1 范围过宽，缺 stop-line | 设计还不能稳定支撑“可实施、可验证、可回退”的落地路径 |
| 计划交接就绪 Gate | FAIL | 缺 workstream 拆分、repo-level topology、consumer replacement matrix、milestone freeze | 现在进入 `writing-plans` 会让计划阶段替 design 兜底关键结构决策 |

## 三原则裁决

| 原则 | 裁决 | 依据 |
|------|------|------|
| 简单 | FAIL | 三层主结构是简洁的，但 V1 范围、`user-decision writer` 多实现形态、未冻结的 cutover 切片会把本该在 design 决定的复杂度下沉到计划和实现阶段 |
| 合适 | PASS | `canonical-only`、`fail-closed`、authority/replay/quarantine 的关注点都保留了问题域真正需要的复杂度，没有把关键风险错误简化掉 |
| 演化 | FAIL | 还没有把可逆性、恢复路径、负路径验收和阶段性 stop-line 冻结成可执行契约，难以支撑渐进迁移与安全回退 |

## 交接项

- 结论：回退 design 修正后重新评审，不进入 `writing-plans`
- 建议修正顺序：
  1. 先补 `artifact-registry` ownership/authority 与 runtime lifecycle
  2. 再补 `user-decision writer` authority proof 和状态枚举 registry
  3. 再补 `BLOCKED` 恢复契约与 replay profile
  4. 最后冻结 `Implementation Workstreams`、repo topology、consumer replacement matrix、V1 milestone
- 复审维度保持不变：
  - 架构分层
  - 对抗式契约
  - 实施可落地性
  - 验收与回放闭环
