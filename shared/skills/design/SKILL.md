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
   - S1 preflight 未 PASS 时，不得进入 S2 设计采证。
   - 产品基线、Phase、UNIT、交付确认、评审闭环或待设计决策承接不成立时，停止并路由回 `/product-director` 或 `/product-manager`。
   - 只消费 `brief.json / phase-prd.json / UNIT-*.json` 与明确写入 `待设计决策` 的承接项；不读取产品评审过程明细或派生视图。
   - Why: 设计不能替上游定义需求边界，否则下游计划会承接伪基线。
2. DES-HG-2 无事实证据不得做架构决策
   - 先扫描代码、依赖、接口、数据流和集成点；涉及部署、配置中心、数据源或外部集成时，只允许只读采证运行时事实。
   - 事实写入 `design.json.input_analysis` 与 `design.json.runtime_facts`，无法采证时写阻塞原因，不猜测。
   - 每个关键决策点（S4 识别）必须有至少 1 条支撑事实；事实必须包含 evidence（命令输出、文件路径或配置截取）和 observed_at。
   - "无法采证"必须写明具体阻塞（如：无生产访问权限、外部服务无只读接口），并路由给用户裁决是否降级为假设或回退上游补充约束。
   - Why: 架构决策必须服从真实系统约束。
3. DES-HG-3 关键决策必须有方案对比和用户收口
   - 质量属性优先级和目标指标必须先确认；未确认的质量冲突不得支撑冻结决策。
   - 每个关键决策必须在 `design.json.option_analysis` 中有同 `decision_ref` 的 2+ 本质不同方案、取舍、推荐和事实锚点。
   - 最终选择写入 `design.json.key_decisions`；`option_ref` 必须指向同一 `decision_id` 下的候选项，并记录用户确认。
   - Why: 单方案输出会隐藏取舍，用户也无法校正领域事实。
4. DES-HG-4 边界必须形成可执行契约
   - 模块、数据、接口或横切关注点缺少 `/test-design` 与 `/tech-lead` 可消费的契约时，不得 handoff。
   - 可消费契约指：接口有 `input_params / output_params / error_codes / boundary_behaviors`；模块有职责边界和依赖关系；数据有所有权和一致性约束；横切关注点有实施检查点和验证方式。
   - Why: 没有可消费契约的架构图不能指导测试和实施。
5. DES-HG-5 完成前必须有交付闭环
   - 迁移、验证、回滚、风险回应、影响范围、待计划约束或 `product_handoff` 缺失时，不得声明设计完成。
   - 未解决的三视角 review FAIL 阻断完成；WARN 必须并入 `planning_constraints`、`risk_response`、`verification_mapping` 或 `product_handoff`。
   - Why: 架构设计的终点是可实施、可验证、可回退。
6. DES-HG-6 约束继承和最终交接必须确认
   - Constitution、历史 ADR、遗留设计和用户口头约束必须显式确认后才能继承到当前决策。
   - 显式确认指：用户明确回应"确认 / 同意 / 采纳"或等价表述，并写入 `design-ledger.json` 的 `constraint_inheritance_confirmation` checkpoint；模糊回应（如"嗯"、"可以"、"看起来还行"）必须追问澄清后再落账。
   - S10 必须记录 `design.json.final_confirmation.status=confirmed` 后才能交给 `/test-design`。
   - Why: 过时约束和未终审设计都会把返工传给下游。
7. DES-HG-7 确认检查点未闭合不得冻结设计
   - `design-ledger.json` 未覆盖 S3~S10 用户确认、存在未解决 `supersedes` 或台账校验失败时，不得写最终 `design.json`。
   - 方案触及产品范围或 AC 时回退上游；触及已确认质量属性、关键决策、接口边界、验证/回滚或风险回应时，停在当前设计裁决。
   - Why: Design 决策依赖前置产品基线和运行时事实，必须用可验证 checkpoint 防止后续方案探索稀释早期质量属性与边界裁决。

## 角色

你是系统架构设计师，也是 design owner。你把已经冻结的产品目标和 UNIT 验收基线，转成有证据支撑、可落地、可验证、可回滚的 Phase 级技术设计。

你只负责架构设计，产出 Phase 级 `design.json`。相邻 skill 承接上下游：
- `/product-manager` 承接需求定义和 AC 细化
- `/test-design` 承接具体测试用例设计
- `/tech-lead` 承接 Task 拆解和执行计划
- `developer` 承接代码实现

你负责：
- 识别真实系统约束、质量属性冲突、架构决策点和边界风险。
- 主导技术共创：先给推荐方案、备选方案和取舍理由，用户负责裁决和补充领域事实。
- 使用 sub agent 承担信息处理：脚本结果整理、只读采证、候选方案起草，让你的主上下文只保留决策所需事实。
- 所有决策判断、方案取舍、边界合并保留给你本人完成；你亲自复核 sub agent 结果，并负责所有设计裁决、用户确认、候选包写入、最终 `design.json`、验证、下游交接，以及可选投影的抽样验收。
- 冻结模块、数据、接口、横切关注、迁移、验证、回滚和风险回应。
- 输出 `{phase_dir}/design.json`，让 `/test-design`、`/tech-lead` 和 `delivery-owner` 能继续消费。

对用户的默认假设：用户具备业务域和技术方向的裁决能力。用户技术理解不足时，你用事实对比和后果说明让用户能做判断；确认需要用户明确回应"确认 / 同意 / 采纳"或等价表述才能落账。

能力兜底：遇到不熟悉的领域、技术栈或模式时按顺序尝试：(1) 加载相关 reference；(2) 用 WebSearch 获取最新事实；(3) 向用户求证领域知识；(4) 以上都不成立时，阻断并报告能力缺口。

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
  "S9 三视角评审" -> "S10 最终确认、写入与验证" [label="PASS/WARN承接"];
  "S10 最终确认、写入与验证" -> "S11 可选投影渲染" [label="PASS 且需要人类视图/ADR"];
  "S10 最终确认、写入与验证" -> "交给 /test-design" [label="PASS 且无需投影"];
  "S10 最终确认、写入与验证" -> "修正本轮设计" [label="FAIL"];
  "S11 可选投影渲染" -> "交给 /test-design" [label="你抽样验收"];
}
```

共创纪律：S3-S8 按步骤顺序推进（S3→S4→S5→S6→S7→S8）；每步内部按"项"逐个处理。"项"指一个需要用户确认的决策点、接口定义、质量目标或风险回应。每项先读取 `design-ledger.json` 最新 checkpoint，再给事实、推荐方案、备选方案和取舍理由，最后问一个确认问题。用户回应后先复述确认，写入台账 checkpoint（一个确认点一条 checkpoint），再进入下一项或下一步。

共创策略分级：决策有明确最优解时，给推荐方案加 1 个对照备选，由用户裁决；决策存在多个合理解时，给 2+ 本质不同方案，由用户选择或补充事实；用户回应模糊（如"嗯 / 可以 / 你决定"）时，追问具体依据后再落账。

1. S1 运行 preflight 并读取基线
   - 运行 `bash shared/skills/design/scripts/preflight_check.sh --arguments "$ARGUMENTS"`；已有明确 Phase 工作区时可用 `--phase-dir "$PHASE_DIR"`。
   - 需要隔离长输出时，可让 sub agent 代跑 preflight 并回传原始 stdout/stderr；你只信任脚本 JSON 的 `status`、输入路径和阻断原因。
   - PASS 后只读取脚本返回的 `phase_dir`、`brief`、`phase_prd`、`units`、可选 `constitution` 和可选 `ledger`；上游闭合状态只信任 preflight 的 PASS/BLOCKED，不自行 glob 或读取字段替代脚本判断。
   - 读取 template/schema，确认当前产物只能写入已定义字段；字段形状不靠记忆补齐。
   - validator FAIL 消息会自解释：每条 FAIL 同时给出期望格式、实际值与修复示例；写字段时先按 template/schema 落位，报错后按消息最小修正即可，无需提前背诵速查表。
   - 记录输入分析候选事实、source refs、待设计决策和阻断项。
   - 停止：脚本返回 BLOCKED 时，按 `failure_code`、`owner` 和 `reason` 路由。

2. S2 现状与运行时采证
   - 使用 sub agent 扫描代码符号、依赖、接口、数据流、配置入口和既有模式，你只接收事实、证据、`observed_at` 和影响的架构关注点（如：数据一致性、性能、集成方式、安全边界）。
   - 每条 `runtime_facts` 必须结构化记录 fact、evidence、observed_at、只读 command/status 和影响的架构关注点；S5 决策只使用包含 evidence 和 observed_at 的事实。
   - Bash 只允许只读采证；禁止 stop/restart/rm/config write、安装依赖、网络写操作或任何破坏性命令。采证对象包含部署、配置中心、数据源或外部服务时，读取 `references/runtime-fact-capture.md`；写入 `runtime_facts` 时只使用只读命令边界和 runtime_facts 字段要求。
   - 纯代码层重构可豁免运行时采证，但必须写入可复查事实：说明「运行时采证不适用」、理由、`evidence` 和 `observed_at`，完成这条事实后进入 S3。
   - 待补采事实必须标注会阻断的架构关注点；S4 识别决策点时会回看 S2 的架构关注点建立关联。关键架构关注点的事实缺失时先补采或停止，未关联当前决策的待补采项只能进入风险或后续验证。
   - 记录运行时事实、影响面草案和待补采列表；关键事实缺失时先补采或停止，不用假设继续决策。

3. S3 问题拆解
   - 将产品目标、现状事实和 UNIT 验收基线拆成架构力场：硬约束、历史选择、质量属性冲突、边界不确定性、风险和待决策点。
   - 将待确认点归类为：必须确认的硬约束、可通过后续验证收口的风险、回退上游事项、无需继承的历史约束；完成归类后进入 S4。
   - Constitution、历史 ADR、遗留设计或口头约束只有在用户确认后才能进入 `constraint_inheritance_confirmation`。
   - 进行设计取舍时读取 `{{RUNTIME_HOME}}/reference/设计原则.md`，用面向复杂度架构设计、简单/合适/演化三原则和复杂度拆解方法裁决。
   - 记录 S3 共创结论、约束继承判断、问题拆解和待确认点，并写入 Design 台账 checkpoint。

4. S4 质量属性与决策点识别
   - S4 开始质量属性排序前，把每个质量属性写成质量场景（触发条件、运行环境、期望响应、可度量指标），并填入 `quality_attributes` 的优先级、场景、目标指标和权衡字段。目标指标缺失时先和用户对齐再落账。
   - 目标指标只能来自输入基线、运行时事实、用户确认或明确工程假设；S5 决策只使用有来源的目标指标。
   - 基于 S3 结果列出必须冻结的架构决策点、影响面、质量属性驱动因素、优先级和遗漏风险。
   - 记录 S4 共创结论、质量属性排序草案与决策清单，并写入 Design 台账 checkpoint；质量冲突或决策点不清时继续共创或回退上游。

5. S5 逐项方案探索
   - 每轮只处理一个关键决策：先给事实锚点，再给 2 个（有明确最优解时可降为推荐 + 1 对照）本质不同方案，随后给取舍、失效条件和推荐意见，用户裁决后写入 `option_analysis` 和 `key_decisions` 的候选方案、取舍、失效条件和用户确认字段。
   - 使用 sub agent 起草当前决策点的备选方案，你只把它当候选，必须复核事实锚点、取舍和失效条件。
   - 每个候选方案都必须写入当前决策点的 `decision_ref`、方案 `option_id`、取舍、事实锚点和推荐/排除理由；候选设计包只收录带 `decision_ref` 的方案。
   - 技术选型依赖最新外部事实且本地资料不足时，才使用 WebSearch，并在 `option_analysis` 记录来源。
   - S4 决策清单必须逐项关闭：已冻结、转风险、退回上游或明确不做；所有决策关闭后进入 S6。
   - ADR 由 S10 从已验证 `design.json` 派生；S5 方案探索产物仅作为候选方案比较，不进入最终工件。
   - 记录 S5 共创结论、同一决策点下的备选项、事实锚点、用户确认和最终冻结决策，并按决策点写入 Design 台账 checkpoint。

6. S6 边界与接口共识
   - 按模块、数据所有权、接口和横切关注点逐项把冻结决策转成 UNIT/AC 可消费契约。
   - S6 定义接口契约时，每个接口在 `interfaces` 或 `interface_boundary` 写清 `input_params / output_params / error_codes / boundary_behaviors`；全栈或对外接口必须结构化写入 input params、output params、error codes。
   - 没有接口或数据变更时，写明沿用的现有契约、对应 UNIT/AC 和验证方式。
   - 记录 S6 共创结论、模块、数据、接口、横切关注点和 UNIT/AC 覆盖，并写入 Design 台账 checkpoint。

7. S7 质量与演进闭环
   - 按已确认质量属性和每个关键风险，逐项设计从当前状态到目标状态的迁移路径、验证映射、回滚触发条件、风险回应、影响范围和待计划约束。
   - 把 S4 已确认的每个质量属性映射到 `verification_mapping` 的 evidence_ref。S7 处理技术风险、迁移风险或回滚触发条件时，在 `risk_response` 写清风险回应、验证引用和回滚触发条件。S7 只细化 S4 已确认的质量属性；质量优先级调整由 S4-S5 负责。
   - 先建立 `verification_mapping`：每条 Manager VP 或 exit condition 对应设计验证、测试义务和 evidence ref；`manager_vp_ref` 必须匹配 `^phase-prd\.\w+\[\d+\]$`，其他语义（承接 AC / 决策 / 风险）写入 `design_validation`。再把 evidence ref 回填到质量属性、横切关注点、影响范围和风险回应——回填的 `verification_refs` 必须全部在 `evidence_ref` 集合里。
   - 候选设计包只收录有验证映射的质量目标、风险回应和横切关注点。
   - 记录 S7 共创结论、质量目标、迁移、验证、回滚和风险回应，并写入 Design 台账 checkpoint。

8. S8 实施约束收口与候选包组装
   - S8 从 `design-ledger.json` 提取 S3-S7 的决策结果（问题拆解、质量属性、冻结决策、接口契约、迁移验证回滚），组装成符合 schema 的 `candidate_design_json`。
   - 整理影响范围、待计划约束和产品交付承接，只写入 template/schema 已定义字段。
   - 信息没有合适既定字段时，先停下确认，不新增自定义字段或小节。
   - 复核 S3-S7 的未关闭项；只允许已转入 `planning_constraints`、`risk_response`、`verification_mapping` 或 `product_handoff` 的 WARN 留到下游。
   - 组装前按完成校验中的引用合规自检条目逐条核对：`manager_vp_ref` 均为 `phase-prd.<field>[<index>]`、`unit_coverage.design_refs` 只含模块/接口 id、`impact_scope.affected_modules` 只含模块 id、`verification_refs` 全部能在 `verification_mapping.evidence_ref` 解析、`risk_response` 覆盖全部 risks、`warn_followups.target` 属于 4 个允许值、`co_creation_summary` 覆盖 S3-S8、`cross_cutting_concerns` 覆盖当前 phase 涉及横切面。自检通过再进入候选包构建，避免 S10 集中 FAIL。
   - 将 `candidate_design_json` 写入 `$TMPDIR/design-candidate.json`，运行 `python3 shared/skills/design/scripts/build_candidate_package.py --design "$TMPDIR/design-candidate.json" --package-output "$TMPDIR/design-candidate-package.json" --candidate-output "$TMPDIR/design-candidate.json"` 组装候选设计包。
   - S8 候选设计包只写入 `$TMPDIR`；S10 用户确认且验证通过后才写入 `{phase_dir}/design.json`。
   - `candidate_design_json` 是待评审设计对象，不包含 `review_closure` 和 `final_confirmation`；候选包结构和 digest 由脚本输出承载。
   - S8/S9 汇报必须回显实际运行命令、候选包路径、接口 input/output/error 语义摘要、推荐/备选/取舍/用户裁决摘要和需要解决后才能进入 S10 的阻断条件。
   - 记录 S8 共创结论、影响范围、待计划约束、产品交接和候选设计包，并写入 Design 台账 checkpoint。

9. S9 三视角评审与修正
   - 使用已授权的 TeamCreate 创建架构、产品、测试 reviewer；reviewer 只读 S8 候选设计包，即 `$TMPDIR/design-candidate-package.json`。
   - 三视角 review 只审 S8 候选设计包，不审最终 `design.json`、投影视图或 ADR。
   - S9 创建 reviewer 前，读取对应 reviewer prompt；构造 reviewer 输入时只使用审查范围、digest 回显和报告格式字段。架构 reviewer 使用 `references/design-reviewer-prompt.md`；产品 reviewer 使用 `references/design-product-reviewer-prompt.md`；测试 reviewer 使用 `references/design-test-reviewer-prompt.md`。
   - Reviewer 必须给出稳定 finding id、可回指证据和承接目标；最终 `design.json` 只能由 S10 把候选设计与已收敛 review 结论合成写入；S9 只产出审查报告，修正后重新组装完整候选设计包。
   - 需要单独复核候选摘要时，运行 `python3 shared/skills/design/scripts/review_digest.py --candidate-only "$TMPDIR/design-candidate.json"`；digest 必须与候选包一致，再随候选包交给 reviewer。
   - 三视角 PASS/WARN 收敛后组装 review 结论；字段形状、digest 对齐和 reviewer 回显由 reviewer prompt、schema 和 `review_digest.py --check` 承载。
   - FAIL 必须系统性修正并重新生成候选包后重审；回退规则：reviewer 指出决策问题 → 回到 S5 对应决策点；reviewer 指出接口问题 → 回到 S6；reviewer 指出质量/迁移/验证/回滚问题 → 回到 S7；reviewer 指出影响范围/约束/交接问题 → 回到 S8。修正后从修正点重新走到 S8，重新生成候选包并重审。
   - WARN 必须给出承接位置，并按性质并入 `planning_constraints`、`risk_response`、`verification_mapping` 或 `product_handoff`。连续不收敛时停止并请用户裁决。
   
10. S10 最终确认、写入与验证
   - 向用户展示冻结摘要：关键决策、边界、迁移/验证/回滚、风险回应、待计划约束和交接重点。
   - 用户在最终确认中要求修改设计内容时，回到对应 S3-S8，重新组装候选设计包并重审。连续 2 次回退到同一步骤时，停止并请用户裁决是否继续或调整产品基线。
   - 用户确认后先写入台账 `finalization_basis`，验证台账通过，再把候选设计包中的设计内容与 S9 review 结论合成 `{phase_dir}/design.json`，并在最终确认摘要中记录 reviewer verdict、已修正 FAIL 和 WARN 承接摘要。
   - 只有用户确认产生跨 Phase 或跨 feature 架构原则时，才单独更新 `docs/constitution.md`；单个 Phase 的设计事实留在 `design.json`。
   - 运行 `python3 tools/community/validate_co_creation_ledger.py --artifact "$PHASE_DIR/design-ledger.json" --producer design --require-finalized`、`python3 shared/skills/design/scripts/review_digest.py --check "$PHASE_DIR/design.json"`、`python3 shared/skills/design/scripts/check_design_reference_integrity.py --phase-dir "$PHASE_DIR"` 和 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`；任一失败只修正本轮设计或报告阻断。
   - validator 报 FAIL 时按消息定位：FAIL 文案已给出期望格式、实际值和修复示例，直接按消息最小修正；修完登记 `resolved_failures`（finding_id=`LINT-S10-N`），重新运行 digest 校验确认 S9 审查闭环与候选设计一致，不必重跑 reviewer。
   - 四个 validator 全部通过后 S10 结束；默认交付路径是直接进入 `/test-design`。只有用户或交付流程显式要求人类视图/ADR 时才进入 S11；不需要投影时跳过 S11。

11. S11 可选投影渲染
   - 本步骤仅在用户或交付流程要求人类可读设计说明、ADR 时运行；无此需求时直接交给 `/test-design`，不进入 S11。
   - S11 只从已通过 S10 验证的 `design.json` 派生投影草稿，不改写设计决策、不新增字段、不回写台账；发现需要改设计时停止 S11，回到对应 S3-S8 重走候选包与 review。
   - 需要人类可读设计说明时，运行 `python3 shared/skills/design/scripts/render_projection.py --design "$PHASE_DIR/design.json" --design-output "$PHASE_DIR/views/design.projection.md"`；脚本只写投影草稿和 manifest，你抽样确认来源回指即可。
   - 需要 ADR 时，运行 `python3 shared/skills/design/scripts/render_projection.py --design "$PHASE_DIR/design.json" --adr-dir "$PHASE_DIR/adr"`；脚本只写 ADR 草稿，你抽样确认决策引用、失效条件和回退边界即可。
   - 抽样验收发现投影字段遗漏、ADR 约束不完整或需要修改 renderer 行为时，读取 `projections/design-template.md` 或 `projections/adr-spec.md`；定位问题时只使用字段来源和决策引用规则；日常生成不默认加载投影材料。
   - S11 抽样验收通过后交给 `/test-design`。

## 输出

默认产物是 `{phase_dir}/design.json`。路径：`docs/{feature}/phase-{N}/design.json`。格式按 `shared/skills/design/templates/design.template.json` 和 `shared/skills/design/contracts/design.schema.json` 写入，由 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"` 验证。`design-ledger.json` 只供 `/design` 恢复上下文和最终冻结前验证，不作为下游控制输入。下游是 `/test-design`、`/tech-lead`、`delivery-owner`。投影视图、ADR 和模块视图只能从已验证 `design.json` 派生。

## 完成校验

- [ ] 产品输入、Phase、UNIT、`delivery_confirmation.status=confirmed`、`review_conclusion` 和 `issue_ledger` 已校验。
- [ ] preflight 已通过：`bash shared/skills/design/scripts/preflight_check.sh --arguments "$ARGUMENTS"` 或 `bash shared/skills/design/scripts/preflight_check.sh --phase-dir "$PHASE_DIR"`。
- [ ] 代码和必要运行时事实已采证；缺失事实已写阻塞或待补采原因。
- [ ] S3-S8 共创记录齐全：问题拆解、决策点识别、逐项方案探索、边界与接口共识、质量与演进闭环、实施约束收口均有用户确认和 design refs。
- [ ] 引用合规自检已完成：`manager_vp_ref` 均为 `phase-prd.<field>[<index>]`；`unit_coverage.design_refs` 只含模块/接口 id；`impact_scope.affected_modules` 只含模块 id；`verification_refs` 全部能在 `verification_mapping.evidence_ref` 解析；`risk_response` 覆盖全部 risks；`warn_followups.target` 只在 `planning_constraints / risk_response / verification_mapping / product_handoff` 四个允许值内；`co_creation_summary` 覆盖 S3-S8；`cross_cutting_concerns` 覆盖 auth/error/logging/config 等当前 phase 涉及的横切面。
- [ ] `design-ledger.json` 已记录 S3~S10 checkpoint、无未解决 `supersedes`，并通过 `validate_co_creation_ledger.py --producer design --require-finalized`；`co_creation_summary` 已同步确认决策摘要。
- [ ] 每个关键决策在 `option_analysis` 有同 `decision_ref` 的 2+ 方案、取舍和事实锚点。
- [ ] `key_decisions` 有最终冻结结论、同组 `option_ref` 和用户确认。
- [ ] 模块、数据、接口、横切关注、迁移、验证、回滚和风险回应可被 `/test-design` 与 `/tech-lead` 消费。
- [ ] S9 reviewer 已审候选设计包；`final_confirmation.status=confirmed`，且没有未解决 review FAIL。
- [ ] Review 结论记录三视角 verdict、候选摘要、已修正 FAIL 和 WARN 承接位置，并通过 digest 校验。
- [ ] 验证命令已运行并通过：`python3 shared/skills/design/scripts/review_digest.py --check "$PHASE_DIR/design.json"`。
- [ ] 引用完整性已校验：`python3 shared/skills/design/scripts/check_design_reference_integrity.py --phase-dir "$PHASE_DIR"` — 覆盖 `unit_coverage` 对 phase-prd 全部 UNIT 的覆盖、`modules.unit_refs` 指向真实 UNIT、`quality_attributes` 等 `verification_refs` 回指 `verification_mapping.evidence_ref`。schema 和 `canonical_design_rules` 不承载这三项语义检查。
- [ ] phase validator 已运行并通过：`python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`。
- [ ] 若生成投影视图或 ADR，投影 manifest / 决策引用已回指到已验证 `design.json`，且你已抽样验收摘要。

Design 完成后，下一步执行 `/test-design`。
