# 1人+agent 产品研发交付团队整体架构设计图

评审主入口请打开：[`2026-05-25--one-human-agent-product-delivery-team--architecture-diagram.html`](./2026-05-25--one-human-agent-product-delivery-team--architecture-diagram.html)。

本 Markdown 文件是可编辑源稿，依赖支持内嵌 HTML/CSS 的 Markdown Viewer 才能完整渲染。普通浏览器直接打开 `.md` 会显示成文本或弱渲染，不作为评审展示入口。

面向产品、研发、测试和交付角色评审对齐。本图是目标架构蓝图，用于对比现有流程查漏补缺；它不是当前流程现状图，也不是工程实施计划。

## 读图顺序

1. 先看整体架构图：确认五层组织、主链、执行池、支撑接口和工程保障的位置是否成立。
2. 再看产物流图：确认每个阶段冻结什么、交给谁消费。
3. 最后用查漏补缺矩阵对照现有流程：标出缺角色、缺产物、缺门禁、缺证据或职责错位。

## 整体架构图

<div style="width: 1200px; box-sizing: border-box; position: relative; background: #fafbfc; padding: 20px; border-radius: 6px; border: 1px solid #e5e7eb; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;">
<style scoped>.arch-wrapper{display:flex;gap:12px}.arch-sidebar{width:190px;flex-shrink:0}.arch-main{flex:1;min-width:0}.arch-title{text-align:center;font-size:22px;font-weight:700;color:#111827;margin-bottom:6px}.arch-subtitle{text-align:center;font-size:12px;color:#6b7280;margin-bottom:16px}.arch-layer{margin:8px 0;padding:14px;border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.04)}.arch-layer-title{font-size:13px;font-weight:700;margin-bottom:10px;text-align:center}.arch-grid{display:grid;gap:8px}.arch-grid-2{grid-template-columns:repeat(2,1fr)}.arch-grid-3{grid-template-columns:repeat(3,1fr)}.arch-grid-4{grid-template-columns:repeat(4,1fr)}.arch-grid-6{grid-template-columns:repeat(6,1fr)}.arch-box{border-radius:4px;padding:9px;text-align:center;font-size:11px;font-weight:650;line-height:1.35;color:#1f2937;background:#fff;border:1px solid #e5e7eb}.arch-box small{display:block;margin-top:3px;font-size:9px;font-weight:500;color:#6b7280}.arch-box.highlight{background:#f3f4f6;border:2px solid #6b7280}.arch-box.warn{border:2px solid #d97706;background:#fffbeb}.arch-layer.user{background:linear-gradient(135deg,#eff6ff 0%,#dbeafe 100%);border:2px solid #3b82f6}.arch-layer.user .arch-layer-title{color:#1d4ed8}.arch-layer.application{background:linear-gradient(135deg,#fffbeb 0%,#fef3c7 100%);border:2px solid #d97706}.arch-layer.application .arch-layer-title{color:#92400e}.arch-layer.ai{background:linear-gradient(135deg,#f0fdf4 0%,#dcfce7 100%);border:2px solid #16a34a}.arch-layer.ai .arch-layer-title{color:#15803d}.arch-layer.data{background:linear-gradient(135deg,#fdf2f8 0%,#fce7f3 100%);border:2px solid #db2777}.arch-layer.data .arch-layer-title{color:#9d174d}.arch-layer.infra{background:linear-gradient(135deg,#f3f4f6 0%,#e5e7eb 100%);border:2px solid #6b7280}.arch-layer.infra .arch-layer-title{color:#374151}.arch-sidebar-panel{border-radius:6px;padding:10px;background:linear-gradient(135deg,#f3f4f6 0%,#e5e7eb 100%);border:1px solid #d1d5db;margin-bottom:8px}.arch-sidebar-title{font-size:12px;font-weight:700;text-align:center;color:#1f2937;margin-bottom:6px}.arch-sidebar-item{font-size:10px;text-align:center;color:#374151;background:#fff;padding:6px;border-radius:3px;margin:4px 0;border:1px solid #e5e7eb;line-height:1.3}.arch-sidebar-item.metric{background:#f3f4f6;border:1px solid #9ca3af;color:#1f2937;font-weight:700}.arch-note{font-size:10px;color:#6b7280;text-align:center;margin-top:10px}.arch-inline-pipeline{display:flex;gap:0;align-items:stretch}.arch-inline-stage{flex:1;padding:8px;border:1px solid #e5e7eb;border-radius:4px;background:#fff;text-align:center;font-size:11px;font-weight:650;color:#1f2937;line-height:1.3}.arch-inline-stage small{display:block;margin-top:3px;font-size:9px;font-weight:500;color:#6b7280}.arch-inline-arrow{display:flex;align-items:center;justify-content:center;width:24px;flex-shrink:0;font-size:14px;color:#6b7280}</style>
<div class="arch-title">1人+agent 产品研发交付团队目标架构</div>
<div class="arch-subtitle">用户最终决策 · 核心定义链逐层冻结 · 执行 agent 池闭环 · 工程保障脊柱贯穿 · 支撑接口输入演化</div>
<div class="arch-wrapper">
<div class="arch-sidebar">
<div class="arch-sidebar-panel"><div class="arch-sidebar-title">L4 支撑接口</div><div class="arch-sidebar-item metric">Input-only by default</div><div class="arch-sidebar-item">research<br>事实与外部材料</div><div class="arch-sidebar-item">knowledge / memory<br>历史上下文</div><div class="arch-sidebar-item">skill production<br>能力沉淀</div><div class="arch-sidebar-item">eval<br>流程质量信号</div><div class="arch-sidebar-item">feedback<br>改进输入</div><div class="arch-sidebar-item">ops / growth<br>运营增长输入</div></div>
<div class="arch-sidebar-panel"><div class="arch-sidebar-title">进入主链规则</div><div class="arch-sidebar-item">只能作为 cited evidence / decision input / backlog suggestion</div><div class="arch-sidebar-item">必须被对应 L1 owner 显式接收</div><div class="arch-sidebar-item">不能直接改 canonical baseline</div></div>
</div>
<div class="arch-main">
<div class="arch-layer user"><div class="arch-layer-title">L0 Human Control Tower</div><div class="arch-grid arch-grid-4"><div class="arch-box highlight">用户<br><small>最终方向 owner</small></div><div class="arch-box">范围与投入取舍<br><small>scope / cost / priority</small></div><div class="arch-box">风险接受<br><small>risk acceptance</small></div><div class="arch-box">最终签收<br><small>acceptance / commit auth</small></div></div></div>
<div class="arch-layer application"><div class="arch-layer-title">L1 Core Definition Chain：WHAT / HOW / TEST / PLAN / RUN 逐层冻结</div><div class="arch-inline-pipeline"><div class="arch-inline-stage">product-director<small>WHY / Phase<br>brief.json / phase-prd.json</small></div><div class="arch-inline-arrow">→</div><div class="arch-inline-stage">product-manager<small>WHAT / UNIT / AC<br>UNIT-*.json</small></div><div class="arch-inline-arrow">→</div><div class="arch-inline-stage">design<small>HOW contract<br>design.json</small></div><div class="arch-inline-arrow">→</div><div class="arch-inline-stage">test-design<small>TEST contract<br>test-cases.json</small></div><div class="arch-inline-arrow">→</div><div class="arch-inline-stage">tech-lead<small>PLAN architecture<br>plan.json / tasks.json</small></div><div class="arch-inline-arrow">→</div><div class="arch-inline-stage">delivery-owner<small>RUN state<br>delivery-state / signoff package</small></div></div></div>
<div class="arch-layer ai"><div class="arch-layer-title">L2 Execution Agent Pool：delivery-owner 调度的执行闭环</div><div class="arch-grid arch-grid-6"><div class="arch-box">developer<small>单 Task 最小实现</small></div><div class="arch-box">verify<small>AC-by-AC 验证</small></div><div class="arch-box">review<small>代码/架构/风险审查</small></div><div class="arch-box">qa<small>用户路径验收证据</small></div><div class="arch-box">fix<small>明确 FAIL 最小修复</small></div><div class="arch-box">consistency-auditor<small>跨工件一致性审计</small></div></div></div>
<div class="arch-layer data"><div class="arch-layer-title">RUN / SIGNOFF Evidence Loop</div><div class="arch-grid arch-grid-4"><div class="arch-box">developer-report<small>进入 verify</small></div><div class="arch-box">verify-result<small>驱动 task state</small></div><div class="arch-box">qa / review / audit result<small>进入 readiness evidence</small></div><div class="arch-box warn">signoff-package<small>readiness，不是用户签收</small></div></div></div>
<div class="arch-layer infra"><div class="arch-layer-title">L3 Assurance Spine：贯穿全链路的确定性保障</div><div class="arch-grid arch-grid-4"><div class="arch-box">schema / template<small>artifact 结构约束</small></div><div class="arch-box">preflight / validator<small>确定性门禁</small></div><div class="arch-box">traceability / registry<small>active refs 与追踪</small></div><div class="arch-box">evidence provenance<small>fact / assumption / recommendation</small></div><div class="arch-box">bounded loop<small>max rounds / no progress</small></div><div class="arch-box">recovery state<small>blocked / resume point</small></div><div class="arch-box">risk ledger<small>风险与 owner</small></div><div class="arch-box">signoff boundary<small>readiness vs acceptance</small></div></div></div>
</div>
<div class="arch-sidebar">
<div class="arch-sidebar-panel"><div class="arch-sidebar-title">硬边界</div><div class="arch-sidebar-item metric">用户最终签收</div><div class="arch-sidebar-item">PM 不改 Director baseline</div><div class="arch-sidebar-item">design 不改 WHAT / AC</div><div class="arch-sidebar-item">test-design 不替 QA 签收</div><div class="arch-sidebar-item">tech-lead 定 PLAN</div><div class="arch-sidebar-item">delivery-owner 只在 frozen plan_version 内调度</div></div>
<div class="arch-sidebar-panel"><div class="arch-sidebar-title">失败回派</div><div class="arch-sidebar-item">requirement / AC → PM / director</div><div class="arch-sidebar-item">design gap → design</div><div class="arch-sidebar-item">plan gap → tech-lead</div><div class="arch-sidebar-item">implementation gap → fix</div><div class="arch-sidebar-item">risk / scope / auth → user</div></div>
</div>
</div>
<div class="arch-note">读法：中间是主链和执行闭环，左侧是支撑输入，右侧是越权红线与失败路由，底部是贯穿所有阶段的工程保障。</div>
</div>

## 产物流架构图

<div style="width: 1200px; box-sizing: border-box; position: relative; background: #fafbfc; padding: 20px; border-radius: 6px; border: 1px solid #e5e7eb; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;">
<style scoped>.flow-title{text-align:center;font-size:20px;font-weight:700;color:#111827;margin-bottom:14px}.flow-row{display:flex;gap:0;align-items:stretch;margin-bottom:10px}.flow-stage{flex:1;padding:10px;border:2px solid #d97706;border-radius:6px;background:#fffbeb;text-align:center;font-size:11px;font-weight:700;color:#1f2937;line-height:1.35}.flow-stage small{display:block;margin-top:4px;font-size:9px;font-weight:500;color:#6b7280}.flow-arrow{display:flex;align-items:center;justify-content:center;width:24px;flex-shrink:0;color:#6b7280}.flow-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}.flow-box{border-radius:4px;padding:9px;background:#fff;border:1px solid #e5e7eb;text-align:center;font-size:10px;line-height:1.35;color:#374151}.flow-box strong{display:block;color:#111827;margin-bottom:3px}.flow-box.warn{border:2px solid #d97706;background:#fffbeb}.flow-box.ok{border:2px solid #16a34a;background:#f0fdf4}.flow-box.stop{border:2px solid #db2777;background:#fdf2f8}</style>
<div class="flow-title">Canonical Artifact Flow：从业务意图到签收准备包</div>
<div class="flow-row"><div class="flow-stage">用户意图<small>目标 / 约束 / 风险偏好</small></div><div class="flow-arrow">→</div><div class="flow-stage">brief.json<br>phase-prd.json<small>product-director 冻结 WHY / Phase</small></div><div class="flow-arrow">→</div><div class="flow-stage">UNIT-*.json<small>product-manager 冻结 WHAT / AC</small></div><div class="flow-arrow">→</div><div class="flow-stage">design.json<small>design 冻结 HOW</small></div><div class="flow-arrow">→</div><div class="flow-stage">test-cases.json<small>test-design 冻结 TEST</small></div></div>
<div class="flow-row"><div class="flow-stage">plan.json<br>tasks.json<small>tech-lead 冻结 PLAN / Task Packet</small></div><div class="flow-arrow">→</div><div class="flow-stage">developer-report<small>实现证据</small></div><div class="flow-arrow">→</div><div class="flow-stage">verify-result<br>qa-result<br>review-result<br>audit-report<small>验证、验收、审查、审计证据</small></div><div class="flow-arrow">→</div><div class="flow-stage">delivery-state.json<br>artifact-registry.json<small>delivery-owner 管理 RUN 事实</small></div><div class="flow-arrow">→</div><div class="flow-stage">signoff-package.json<small>readiness package，等待用户签收</small></div></div>
<div class="flow-grid"><div class="flow-box ok"><strong>冻结规则</strong>下游只消费 active refs；stale / archived refs 不作为当前事实。</div><div class="flow-box"><strong>冲突规则</strong>冲突按 conflict_precedence 找 canonical owner 或升级裁决。</div><div class="flow-box warn"><strong>回派规则</strong>输入缺口回对应 owner；风险、授权、范围回用户。</div><div class="flow-box stop"><strong>签收规则</strong>signoff-package 只表示准备就绪；用户才拥有 acceptance / risk acceptance / commit authorization。</div></div>
</div>

## 目标架构 vs 现有流程差距矩阵 v1

对照证据以当前可执行真源为准：`contracts/standard-chain.yaml`、`contracts/product-artifacts.yaml`、各核心 skill 的 `SKILL.md / contracts / templates / scripts`，以及 `delivery-owner` 的 runtime state、signoff 和 registry 契约。

| 对照维度 | 目标架构要求 | 现有流程证据 | 差距判定 | 建议 owner / 下一步 |
|---|---|---|---|---|
| 层级模型 | L0-L4 分层清楚，主链、执行池、保障脊柱、支撑接口不混写 | `standard-chain.yaml` 只有 `position: main / sidecar`，未显式表达 L0-L4；支撑接口未统一建模 | 部分缺口：组织蓝图清楚，机器真源缺层级语义 | tech-lead / contracts：增加 layer / authority / support-interface 元数据 |
| Director / PM 边界 | product-director 拥有 `brief.json / phase-prd.json`；PM 只产出 UNIT / AC 和 delta request | `standard-chain.yaml` 中 product-manager 对 `brief.json`、`phase-prd.json` 仍是 `operation: refine` | 关键缺口：可执行契约仍允许 PM 改 Director baseline | product-director + product-manager：把 PM refine 改成 delta request / derived view |
| WHAT / HOW / TEST / PLAN 真源 | 每层有唯一 canonical artifact，下游只消费 active refs | product-manager、design、test-design、tech-lead 均已有 schema/template/script；artifact paths 已在 `artifact_contract` 注册 | 基本具备：需继续收紧 active refs 和 owner mutation | contracts：把 allowed mutation / active refs 纳入 validator |
| 执行 agent 池 | developer / verify / review / qa / fix / auditor 是 delivery-owner 调度池，不拥有主链决策权 | `delivery-owner/SKILL.md` 已调度执行池；但 `standard-chain.yaml` 仍把 developer / review / verify / qa 标为 `position: main` | 结构漂移：skill 行为像执行池，chain 模型像主链角色 | delivery-owner + standard-chain：把执行角色改为 execution_pool / sidecar 分类 |
| Delivery staged gates | RUN 阶段应有 DO-S1..DO-S8 staged gates，可验证、可暂停、可恢复 | delivery-owner skill 已定义 hard-gate 和 DO-S1..S8；`standard-chain.yaml` 只声明最终输入输出 | 工程缺口：流程纪律在 skill 文本中，chain/schema 尚不能完整门禁 | delivery-owner：把 staged gates 落成 contract / validator |
| Active Context Pack | 接手包必须含 active_refs、stale_refs、conflict_precedence、open_gaps、resume_point 等 | `delivery-state.schema.json` 有 kickoff、tasks、blocker refs；`artifact-registry` 有 active revision | 部分缺口：有 runtime 状态雏形，缺完整接手上下文包 | delivery-owner + registry：新增 active-context / resume packet schema |
| Bounded loop | 10 轮上限、同 gap 连续 2 轮无进展暂停，gap taxonomy 可追踪 | delivery-owner skill 明确 10 轮和 2 轮规则；schema 未强制 `max_rounds / no_progress / gap_taxonomy / pause_states` | 工程缺口：规则可读但不可机器验证 | delivery-owner：在 delivery-state 和 completion gate 中固化 loop protocol |
| Evidence provenance | evidence 必须区分 fact / assumption / recommendation，并记录 source、owner、observed_at、confidence、canonical_impact | 现有 artifact 多为 `evidence_refs / decision_basis_refs`，未见统一 provenance 字段 | 关键缺口：证据引用存在，但事实/假设/建议边界不够硬 | L3 assurance：新增 evidence provenance contract 并接入各 gate |
| Signoff boundary | `signoff-package` 只表示 readiness；acceptance、risk acceptance、commit auth 只能来自用户 | `signoff-package.schema.json` 有 `sign_off_status`、`business_risk_acceptance_status`，但描述仍偏 phase-level signoff，缺 `requires_user_signoff / authorization_ref / accepted_risks` | 部分缺口：字段已有雏形，readiness vs acceptance 语义需收紧 | delivery-owner：增强 signoff-package schema 和 completion gate |
| 支撑接口 | research / memory / skill production / eval / feedback / ops-growth 默认 input-only，由 L1 owner 显式接收 | 当前有 research、eval、feedback 等 skill/测试材料，但未在 chain 中统一声明 input-only 和接收规则 | 缺口：支撑能力存在，进入主链规则未工程化 | contracts：新增 support interface contract / provenance routing |
| 工程保障脊柱 | schema、template、preflight、validator、traceability、registry 贯穿全链路 | 各核心 skill 已有 schema/template/preflight/completion；`artifact-registry` 已存在 | 部分具备：保障能力分散，缺统一 spine 视图和跨阶段 coverage gate | L3 assurance：收敛 validator stack、coverage、registry 和 traceability |

## 评审结论记录位

| 评审项 | 结论 | 缺口 | owner | 下一步 |
|---|---|---|---|---|
| 五层组织是否成立 |  |  |  |  |
| 核心角色边界是否成立 |  |  |  |  |
| 执行 agent 池是否完整 |  |  |  |  |
| 产物流是否可消费 |  |  |  |  |
| 工程保障是否放对位置 |  |  |  |  |
| 现有流程最大缺口 |  |  |  |  |
