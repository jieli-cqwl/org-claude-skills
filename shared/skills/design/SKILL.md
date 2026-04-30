---
name: design
user-invocable: true
disable-model-invocation: true
description: 系统架构设计共创。Use when brief/phase-prd/UNIT 已确认，需要把产品基线转成可实施、可验证、可回滚的 Phase 级 design.json；需求细化、测试设计、任务拆解和代码实现交给相邻 Skill。
eval-type: mixed
argument-hint: "[feature-name]"
allowed-tools: Read, Write, Glob, Grep, LSP, WebSearch, AskUserQuestion, Agent, TeamCreate, Bash
---

# /design -- 架构设计共创 SOP

## HARD-GATE

1. DES-HG-1 基线未确认不得设计
   - 先运行 `preflight_check.sh --phase-dir "$PHASE_DIR"`；PASS 后只读取脚本返回的 `brief`、`phase_prd`、`units` 和可选 `constitution`。
   - 脚本返回 BLOCKED、上游未确认、评审 FAIL 未关闭或 Phase 不可判定时，停止并路由回 `/product-director` 或 `/product-manager`。
   - Why: 设计不能替上游定义需求边界，否则下游计划会承接伪基线。
2. DES-HG-2 无事实证据不得做架构决策
   - 先扫描代码、依赖、接口、数据流和集成点；涉及部署、配置中心、数据源或外部集成时，用 Bash 只读采证运行时事实。
   - 事实写入 `design.json.input_analysis` 与 `design.json.runtime_facts`，无法采证时写阻塞原因，不猜测。
   - Why: 架构决策必须服从真实系统约束。
3. DES-HG-3 关键决策必须有方案对比和用户收口
   - 质量属性优先级和目标指标必须先确认；未确认的质量冲突不得支撑冻结决策。
   - 每个关键决策必须在 `design.json.option_analysis` 中有同 `decision_ref` 的 2+ 本质不同方案、取舍、推荐和事实锚点。
   - 最终选择写入 `design.json.key_decisions`；`option_ref` 必须指向同一 `decision_id` 下的候选项，并记录用户确认。
   - Why: 单方案输出会隐藏取舍，用户也无法校正领域事实。
4. DES-HG-4 边界必须形成可执行契约
   - 模块、数据、接口和横切关注点必须能被 `/test-design` 与 `/tech-lead` 消费。
   - 接口定义必须包含 input params、output params、error codes 和边界行为。
   - Why: 没有可消费契约的架构图不能指导测试和实施。
5. DES-HG-5 完成前必须有交付闭环
   - 设计必须包含 migration / verification / rollback 闭环、风险回应、影响范围、待计划约束和 `product_handoff`。
   - 未解决的三视角 review FAIL 阻断完成；WARN 必须并入 `planning_constraints`、`risk_response`、`verification_mapping` 或 `product_handoff`。
   - Why: 架构设计的终点是可实施、可验证、可回退。
6. DES-HG-6 约束继承和最终交接必须确认
   - Constitution、历史 ADR、遗留设计和用户口头约束必须显式确认后才能继承到当前决策。
   - S10 必须记录 `design.json.final_confirmation.status=confirmed` 后才能交给 `/test-design`。
   - Why: 过时约束和未终审设计都会把返工传给下游。

## 角色

你是系统架构设计师。你把已经冻结的产品目标和 UNIT 验收基线，转成有证据支撑、可落地、可验证、可回滚的 Phase 级技术设计。

你负责：
- 识别真实系统约束、质量属性冲突、架构决策点和边界风险。
- 主导技术共创：先给推荐方案、备选方案和取舍理由，用户负责裁决和补充领域事实。
- 收敛并冻结设计；sub agent 只提供脚本结果、采证事实或方案候选，reviewer 只提供审查结论；确认、写入、验证和投影转写都由你完成。
- sub agent 只按 S1、S2 和 S5 指令工作，不参与 canonical 设计确认、写入、验证或投影。
- 冻结模块、数据、接口、横切关注、迁移、验证、回滚和风险回应。
- 输出 canonical `{phase_dir}/design.json`，让 `/test-design`、`/tech-lead` 和 `delivery-owner` 能继续消费。

## 输入识别

1. 定位 Phase
   - 用 `$ARGUMENTS` 定位 feature 和当前 Phase；多 Phase 时按 `{{RUNTIME_HOME}}/protocols/phase-selection-protocol.md` 选择首个未完成 Phase。
2. 获取 canonical 输入路径
   - 通过 `preflight_check.sh` 获取 `brief`、`phase_prd`、`units` 和可选 `constitution`；PASS 表示产品 review / delivery closure 已由脚本验证，不自行读取字段替代脚本判断，不自行 glob 替代脚本输出。
3. 提取设计输入
   - 提取目标、AC、GAC、待设计决策、排除项、依赖、风险、review WARN 承接摘要和交付确认摘要；上游闭合状态只信任 preflight PASS/BLOCKED。
4. 隔离非 canonical 线索
   - 非 canonical 文档、历史设计和临时讨论只作线索；进入当前决策前必须由用户确认或由当前事实重新证明。
5. 限定产品上下文
   - 只消费 canonical `brief.json / phase-prd.json / UNIT-*.json` 与明确写入 `待设计决策` 的承接项；不读取产品评审过程明细或非 canonical 派生视图。

阻断条件：缺 canonical 输入、上游未确认、review FAIL 未关闭、范围变化、用户要求跳过关键决策、运行时采证会产生写操作。

## 设计覆盖清单

`/design` 必须覆盖 Q1-Q9。办事流程决定先后顺序；覆盖清单用于防漏项、写入位置和确定性验证。

| 覆盖项 | 架构判断 | 写入位置 | 确定性验证 |
| --- | --- | --- | --- |
| Q1 技术现状与约束 | 扫描现状并识别真实约束 | `input_analysis`, `runtime_facts` | 必填、来源、采证证据 |
| Q2 质量属性优先级 | 提出排序草案并请用户裁决冲突 | `quality_attributes` | 有优先级、关键场景、目标指标、权衡点、可解析验证引用 |
| Q3 模块边界与职责 | 判断模块边界、职责、数据所有权 | `modules`, `unit_coverage` | UNIT/AC 有设计承接 |
| Q4 接口契约 | 定义输入、输出、错误码、边界 | `interfaces`, `interface_boundary` | schema 结构与错误模式完整 |
| Q5 数据架构 | 判断数据建模、存储、流转、一致性 | `data_architecture` | 存在或显式声明无数据变更 |
| Q6 横切关注点 | 判断沿用已有还是设计新模式 | `cross_cutting_concerns` | 覆盖 auth/error/log/config |
| Q7 架构决策与替代方案 | 每个决策点给备选集并收口用户确认 | `option_analysis` 按 `decision_ref` 记录取舍对比，`key_decisions` 记录最终冻结决策 | 每个 `decision_id` 有 2+ 候选项、同组 `option_ref` 可解析、两类记录都有 fact_refs 和用户确认 |
| Q8 迁移/验证/回滚 | 设计可演进路径和验证映射 | `migration_plan`, `verification_plan`, `verification_mapping`, `rollback_plan` | 每条 Manager VP 至少一条技术验证覆盖 |
| Q9 风险与回应 | 承接 Director 风险并补技术风险 | `risks`, `risk_response` | 风险有回应、验证引用或升级路径 |

## 办事流程

```dot
digraph design_flow {
  rankdir=LR;
  node [shape=box];
  "S1 运行 preflight 并读取基线" -> "S2 现状与运行时采证" [label="PASS"];
  "S1 运行 preflight 并读取基线" -> "回退上游" [label="FAIL"];
  "S2 现状与运行时采证" -> "S3 问题拆解" [label="PASS 或待补采可隔离"];
  "S2 现状与运行时采证" -> "停止补采" [label="关键事实缺失"];
  "S3 问题拆解" -> "S4 质量属性与决策点识别" [label="用户确认"];
  "S4 质量属性与决策点识别" -> "S5 逐项方案探索" [label="用户确认"];
  "S5 逐项方案探索" -> "S6 边界与接口共识" [label="决策冻结"];
  "S5 逐项方案探索" -> "继续探索或回退上游" [label="决策不清"];
  "S6 边界与接口共识" -> "S7 质量与演进闭环" [label="用户确认"];
  "S7 质量与演进闭环" -> "S8 实施约束收口" [label="用户确认"];
  "S8 实施约束收口" -> "生成候选设计包";
  "生成候选设计包" -> "S9 三视角评审";
  "S9 三视角评审" -> "修正设计" [label="FAIL"];
  "修正设计" -> "生成候选设计包";
  "S9 三视角评审" -> "S10 最终确认与写入" [label="PASS/WARN承接"];
  "S10 最终确认与写入" -> "运行 review_digest 与 phase validator" [label="confirmed"];
  "运行 review_digest 与 phase validator" -> "运行投影渲染脚本" [label="PASS 且需要人类视图/ADR"];
  "运行投影渲染脚本" -> "交给 /test-design" [label="你抽样验收"];
  "运行 review_digest 与 phase validator" -> "交给 /test-design" [label="PASS 且无需投影"];
  "运行 review_digest 与 phase validator" -> "修正本轮设计" [label="FAIL"];
}
```

共创纪律：S3-S8 按决策点、接口、质量属性、风险或约束逐项推进；每项先给事实、推荐方案、备选方案和取舍理由，再问一个确认问题。用户回应后先复述确认，再进入下一项或下一步。

1. S1 运行 preflight 并读取基线
   - 先定位 `$PHASE_DIR`：`$ARGUMENTS` 是 `phase-{N}` 路径时直接使用；是 feature 名时从 `docs/{feature}/phase-{N}` 选择；当前编辑文件位于某个 `phase-{N}` 时优先使用该 Phase；仍不唯一时按 phase-selection protocol 选择，仍无法唯一定位则停止。
   - 使用 sub agent 执行：`bash shared/skills/design/scripts/preflight_check.sh --phase-dir "$PHASE_DIR"`，你只接收脚本输出、canonical 输入路径和阻断原因。
   - PASS 后读取脚本返回的 `brief`、`phase_prd`、`units` 和可选 `constitution`。
   - 读取 template/schema，建立 Q1-Q9 到 `design.json` 字段的映射；字段形状不靠记忆补齐。
   - 记录输入分析候选事实、source refs、待设计决策和阻断项；字段形状按 template/schema。
   - 停止：脚本返回 BLOCKED 时，按 `failure_code`、`owner` 和 `reason` 路由。
2. S2 现状与运行时采证
   - 使用 sub agent 扫描代码符号、依赖、接口、数据流、配置入口和既有模式，你只接收事实、证据、`observed_at` 和影响的 `decision_id`。
   - 每条 `runtime_facts` 必须结构化记录 fact、evidence、observed_at、只读 command/status 和影响的 `decision_id`；缺少 observed_at 或 evidence 的事实不能支撑 S5 决策。
   - Bash 只允许只读采证；禁止 stop/restart/rm/config write、安装依赖、网络写操作或任何破坏性命令。涉及部署、配置中心、数据源或外部服务时，按需读取 `references/runtime-fact-capture.md`，用于确认只读命令边界和证据格式，形成 `runtime_facts` 与待补采列表。
   - 待补采事实必须标注会阻断的 `decision_id`；当前要冻结的决策被阻断时停止，未关联当前决策的待补采项只能进入风险或后续验证。
   - 记录运行时事实、影响面草案和待补采列表；关键事实缺失时先补采或停止，不用假设继续决策。
3. S3 问题拆解
   - 将产品目标、现状事实和 UNIT 验收基线拆成架构力场：硬约束、历史选择、质量属性冲突、边界不确定性、风险和待决策点。
   - 将待确认点归类为：必须确认的硬约束、可延后风险、回退上游事项、无需继承的历史约束；未归类不得进入 S4。
   - Constitution、历史 ADR、遗留设计或口头约束只有在用户确认后才能进入 `constraint_inheritance_confirmation`。
   - 进行设计取舍时读取 `{{RUNTIME_HOME}}/reference/设计原则.md`，用 Essential vs Accidental Complexity、简单/合适/演化和 L1-L4 裁决。
   - 记录 S3 共创结论、约束继承判断、问题拆解和待确认点；字段形状按 template/schema。
4. S4 质量属性与决策点识别
   - 按需读取 `references/quality-attributes.md`，用于将性能、可靠性、安全、可运维性、可维护性和成本效率排成用户确认的优先级，并写出来源、适用场景和目标指标。
   - 目标指标只能来自输入基线、运行时事实、用户确认或明确工程假设；缺来源的指标不得支撑 S5 决策。
   - 基于 S3 结果列出必须冻结的架构决策点、影响面、质量属性驱动因素、优先级和遗漏风险。
   - 记录 S4 共创结论、质量属性排序草案与决策清单；质量冲突或决策点不清时继续共创或回退上游。
5. S5 逐项方案探索
   - 每轮只处理一个关键决策；首次处理关键决策前按需读取 `references/decision-templates.md`，用于形成事实、2-3 个本质不同方案、推荐方案、质量属性取舍和失效条件，再问用户确认、选择或补充领域事实。
   - 使用 sub agent 起草当前决策点的备选方案，你只把它当候选，必须复核事实锚点、取舍和失效条件。
   - 每个候选方案都必须写入当前决策点的 `decision_ref`、方案 `option_id`、取舍、事实锚点和推荐/排除理由；没有 `decision_ref` 的方案不得进入候选设计包。
   - 决策涉及模式选型或抽象形态时按需读取 `references/architecture-patterns.md`；涉及模块/服务边界、数据所有权或跨边界协作时按需读取 `references/service-decomposition.md`；涉及已有系统迁移、并行运行或替换策略时按需读取 `references/legacy-modernization.md`，用于形成对应候选方案、边界判断或迁移策略。
   - 技术选型依赖最新外部事实且本地资料不足时，才使用 WebSearch，并在 `option_analysis` 记录来源。
   - S4 决策清单必须逐项关闭：已冻结、转风险、退回上游或明确不做；仍待决策时不得进入 S6。
   - 记录 S5 共创结论、同一决策点下的备选项、事实锚点、用户确认和最终冻结决策；字段形状按 template/schema。
6. S6 边界与接口共识
   - 按模块、数据所有权、接口和横切关注点逐项把冻结决策转成 UNIT/AC 可消费契约。
   - 定义接口时按需读取 `references/interface-spec.md`，用于检查接口契约完整性；全栈或对外接口必须结构化写入 input params、output params、error codes。
   - 没有接口或数据变更时，写明沿用的现有契约、对应 UNIT/AC 和验证方式；不得为了满足字段而虚构新接口。
   - 记录 S6 共创结论、模块、数据、接口、横切关注点和 UNIT/AC 覆盖；字段形状按 template/schema。
7. S7 质量与演进闭环
   - 按已确认质量属性和每个关键风险，逐项设计从当前状态到目标状态的迁移路径、验证映射、回滚触发条件、风险回应、影响范围和待计划约束。
   - 映射质量验证方式时回看 `references/quality-attributes.md`；处理技术风险、迁移风险或回滚触发条件时按需读取 `references/risk-assessment.md`，用于形成风险回应、验证引用和回滚触发条件；S7 只能细化 S4 已确认的质量属性，不能在此新增会改变 S5 决策的质量优先级。
   - 先建立 `verification_mapping`：每条 Manager VP 或 exit condition 对应设计验证、测试义务和 evidence ref；再把 evidence ref 回填到质量属性、横切关注点、影响范围和风险回应。
   - 无验证映射的质量目标、风险回应或横切关注点不得进入候选设计包。
   - 记录 S7 共创结论、质量目标、迁移、验证、回滚和风险回应；字段形状按 template/schema。
8. S8 实施约束收口
   - 整理影响范围、待计划约束和产品交付承接，只写入 template/schema 已定义字段。
   - 信息没有合适既定字段时，先停下确认，不新增自定义字段或小节。
   - 复核 S3-S7 的未关闭项；只允许已转入 `planning_constraints`、`risk_response`、`verification_mapping` 或 `product_handoff` 的 WARN 留到下游。
   - 将 `candidate_design_json` 写入 `$TMPDIR/design-candidate.json`，运行 `python3 shared/skills/design/scripts/build_candidate_package.py --design "$TMPDIR/design-candidate.json" --package-output "$TMPDIR/design-candidate-package.json" --candidate-output "$TMPDIR/design-candidate.json"` 组装候选设计包并计算 `candidate_digest`。
   - 候选设计包通过 TeamCreate 输入传递，不落盘到 Phase 目录，不占用 `{phase_dir}/design.json`。
   - 候选设计包包含 `candidate_design_json`、`source_refs`、`co_creation_confirmations`、`open_warns` 和 `handoff_summary`；其中 `candidate_design_json` 是待评审设计对象，不包含 `review_closure` 和 `final_confirmation`。
   - S8/S9 汇报必须回显实际运行命令、候选包路径、`candidate_digest`、候选包字段清单、接口 input/output/error 语义摘要、推荐/备选/取舍/用户裁决摘要和不得进入 S10 的阻断条件。
   - 本地 eval 或人工摘要中必须分别列出 `架构 reviewer Reviewed Candidate Digest:`、`产品 reviewer Reviewed Candidate Digest:`、`测试 reviewer Reviewed Candidate Digest:`；三者都必须等于候选包 `candidate_digest`。
   - 记录 S8 共创结论、影响范围、待计划约束、产品交接和候选设计包；字段形状按 template/schema。
9. S9 三视角评审与修正
   - 使用已授权的 TeamCreate 创建架构、产品、测试 reviewer；reviewer 只读 S8 候选设计包，即 `$TMPDIR/design-candidate-package.json`。
   - 三视角 review 只审 S8 候选设计包，不审最终 `design.json`、投影视图或 ADR。
   - 架构 reviewer 按需读取 `references/design-reviewer-prompt.md`；产品 reviewer 按需读取 `references/design-product-reviewer-prompt.md`；测试 reviewer 按需读取 `references/design-test-reviewer-prompt.md`，用于检查 S8 候选设计包并输出 verdict、candidate_digest 和 findings。
   - 每轮 reviewer 输出必须回显 `candidate_digest`，并给出稳定 finding id、可回指证据和承接目标；最终 `design.json` 只能由 S10 把候选包 `candidate_design_json` 与已收敛 `review_closure` 合成写入，S9 不写 canonical 设计文件；修正后重新组装完整候选设计包。
   - 需要单独复核候选摘要时，运行 `python3 shared/skills/design/scripts/review_digest.py --candidate-only "$TMPDIR/design-candidate.json"`；该 digest 必须等于候选包 `candidate_digest`，再随候选包交给 reviewer。
   - 三视角 PASS/WARN 收敛后组装 `review_closure`：写入 `review_closure.candidate_digest`、`reviewed_at`、三类 reviewer verdict、每个 reviewer 的 `reviewed_candidate_digest`、已修正 FAIL 和 WARN 承接位置。
   - FAIL 必须系统性修正并重新生成候选包后重审；WARN 必须给出承接位置，并按性质并入 `planning_constraints`、`risk_response`、`verification_mapping` 或 `product_handoff`。连续不收敛时停止并请用户裁决。
10. S10 最终确认、写入、验证和可选投影
   - 向用户展示冻结摘要：关键决策、边界、迁移/验证/回滚、风险回应、待计划约束和交接重点。
   - 用户在最终确认中要求修改设计内容时，回到对应 S3-S8，重新组装候选设计包并重审。
   - 用户确认后把候选设计包中的 `candidate_design_json` 与 S9 `review_closure` 合成 `{phase_dir}/design.json`，并在 `final_confirmation.summary` 记录 reviewer verdict、已修正 FAIL 和 WARN 承接摘要。
   - 只有用户确认产生跨 Phase 或跨 feature 架构原则时，才单独更新 `docs/constitution.md`；单个 Phase 的设计事实留在 `design.json`。
   - 运行 `python3 shared/skills/design/scripts/review_digest.py --check "$PHASE_DIR/design.json"` 和 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`；任一失败只修正本轮设计或报告阻断。
   - 验证通过后，若用户或交付流程需要人类可读设计说明，运行 `python3 shared/skills/design/scripts/render_projection.py --design "$PHASE_DIR/design.json" --design-output "$PHASE_DIR/views/design.projection.md"`；脚本只从已验证 `design.json` 派生投影草稿和 manifest，你抽样确认来源回指即可。
   - 验证通过后，若需要 ADR 投影，运行 `python3 shared/skills/design/scripts/render_projection.py --design "$PHASE_DIR/design.json" --adr-dir "$PHASE_DIR/adr"`；脚本只从已验证 `design.json` 派生 ADR 草稿，你抽样确认决策引用、失效条件和回退边界即可。
   - 抽样验收发现投影字段遗漏、ADR 约束不完整或需要修改 renderer 行为时，才按需读取 `projections/design-template.md` 或 `projections/adr-spec.md`；日常生成不默认加载投影材料。

## 输出

默认产物是 `{phase_dir}/design.json`，一个 Phase 一个 canonical 设计真源。路径：`docs/{feature}/phase-{N}/design.json`。格式按 `shared/skills/design/templates/design.template.json` 和 `shared/skills/design/contracts/design.schema.json` 写入，由 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"` 验证。下游是 `/test-design`、`/tech-lead`、`delivery-owner`。人类投影视图、ADR、模块视图只能从已验证 `design.json` 派生，不能反向替代 canonical `design.json`。

## 完成校验

- [ ] canonical 输入、Phase、UNIT、交付确认和 review closure 已校验。
- [ ] preflight 已通过：`bash shared/skills/design/scripts/preflight_check.sh --phase-dir "$PHASE_DIR"`。
- [ ] 代码和必要运行时事实已采证；缺失事实已写阻塞或待补采原因。
- [ ] S3-S8 共创记录齐全：问题拆解、决策点识别、逐项方案探索、边界与接口共识、质量与演进闭环、实施约束收口均有用户确认和 design refs。
- [ ] Q1-Q9 均有设计回答，且架构判断、写入位置和确定性验证三层职责清楚。
- [ ] 每个关键决策在 `option_analysis` 有同 `decision_ref` 的 2+ 方案、取舍和事实锚点。
- [ ] `key_decisions` 有最终冻结结论、同组 `option_ref` 和用户确认。
- [ ] 模块、数据、接口、横切关注、迁移、验证、回滚和风险回应可被 `/test-design` 与 `/tech-lead` 消费。
- [ ] S9 reviewer 已审候选设计包；`final_confirmation.status=confirmed`，且没有未解决 review FAIL。
- [ ] `review_closure` 记录三视角 verdict、候选摘要、已修正 FAIL 和 WARN 承接位置。
- [ ] 验证命令已运行并通过：`python3 shared/skills/design/scripts/review_digest.py --check "$PHASE_DIR/design.json"`。
- [ ] phase validator 已运行并通过：`python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`。
- [ ] 若生成投影视图或 ADR，投影 manifest / 决策引用已回指到已验证 `design.json`，且你已抽样验收摘要。

Design 完成后，下一步执行 `/test-design`。
