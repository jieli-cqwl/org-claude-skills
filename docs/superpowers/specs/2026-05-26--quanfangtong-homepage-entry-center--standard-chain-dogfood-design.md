# 全房通首页入口中心改造标准链路试跑设计

## 1. 目标

本设计定义一次 `standard-chain/v1` 上线前真实闭环试跑。试跑需求是基于 `https://www.quanfangtongvip.com/` 当前页面，把“全房通首页”改造成“专业入口中心”。

这不是普通小需求实现，也不是营销官网重做。核心目标是完整走完 `product-director -> product-manager -> design -> test-design -> tech-lead -> developer -> review -> verify -> qa -> consistency-auditor -> delivery-owner` 的每个环节，观察每个环节的真实产出能力、细节符合性、下游可消费性、阻塞与返修能力，判断标准链路是否可以投入团队使用。

## 2. 需求边界

### 2.1 需求命名

统一命名为：全房通首页入口中心改造。

命名中保留“首页”，因为用户入口来自当前首页；同时加入“入口中心”，避免被误解为营销型官网首页改版。

### 2.2 当前页面事实

试跑开始前必须保存当前页面 evidence pack，至少包括：

- 原始 URL：`https://www.quanfangtongvip.com/`
- 采集时间
- 桌面截图
- 移动截图
- 页面文本抓取
- 采集失败时的失败原因、重试记录和替代证据说明

已知页面事实包括：

- 页面品牌为“全房通公寓管理系统”。
- 页面包含到期提醒、自助续费、登录、忘记密码、解决办法、扫码登录、协议、客服联系、客户端下载和备案信息。
- 当前页本质是登录、续费、下载、客服和公告类入口聚合页，不是传统营销首页。

Evidence pack 固定保存到：`docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/`。

文件清单：

- `capture-manifest.json`：证据索引和 metadata。
- `desktop-homepage.png`：桌面截图。
- `mobile-homepage.png`：移动截图。
- `page-text.md`：页面文本抓取。
- `capture-failure-log.md`：采集失败、重试和替代证据记录；无失败时写明 `N_A`。

`capture-manifest.json` 中每个 entry 至少包含：`entry_id`、`source_type`、`source_ref`、`captured_at`、`status`、`supports`；截图 entry 还必须包含 `screenshot_ref`、`viewport`；文本 entry 必须包含 `observed_text_ref`；采集失败 entry 必须包含 `failure_log_ref`、`gap_reason`、`required_evidence` 和 `blocks_fields`。

`entry_id` 使用稳定前缀：`QFT-ASIS-001`、`QFT-ASIS-002`。PM 写 AS-IS fact、`evidence_sources[]`、`as_is_flows[].evidence_refs` 时只能引用 manifest 中已存在的 `entry_id`。没有 entry 支撑的当前态判断只能写 `ASSUMPTION`；如果影响 AC、用户路径、业务规则、真实依赖或验收结论，`blocks_fields` 必须非空，并阻塞依赖该字段的后续阶段。

### 2.3 交付边界

本次没有真实全房通代码仓库。developer 阶段只能在本仓产出可运行轻交互原型，用于验证标准链路闭环和产品/设计/测试/交付产物质量。

原型包含：

- 登录方式切换：密码登录、验证码登录、扫码登录。
- 续费提示收起或确认。
- 下载入口展示与点击反馈。
- 客服入口展示与点击反馈。
- 公告或提示入口的基础展示。
- 桌面和移动视口的基础响应式效果。

原型不包含：

- 真实登录。
- 真实续费支付。
- 真实客户端下载。
- 真实客服系统接入。
- 真实后端接口、埋点、鉴权、发布和线上回滚。

PM、AC、QA 和 signoff 中凡涉及真实登录、真实续费、真实下载、真实客服、真实后端、埋点、鉴权、发布或回滚的条目，必须显式标记 `not_integrated` 或 `prototype_only`。任何未集成真实能力的条目不得作为线上发布能力通过，也不得进入“可投入团队使用”的无条件依据。

## 3. 试跑真实性边界

真实反馈指每个角色基于真实输入、真实 artifact、真实约束和真实验证结果做判断，并把判断写入标准链路原生产物或观察报告。

真实性不等于线上发布能力。本次可以证明：

- 标准链路是否能驱动一个真实页面改造需求从方向定义走到可验收原型。
- 每个角色是否能产出可被下游消费的 artifact。
- 工件之间是否能保持追踪、一致、可审计。
- delivery-owner 是否能形成可签收事实包和团队投入判断。

本次不能证明：

- 全房通线上系统可发布。
- 真实登录、续费、下载、客服链路已集成。
- 真实生产环境性能、安全、合规和运维能力达标。

## 4. 成功标准

试跑成功必须逐项有证据支持：

1. 每个标准链路角色都真实执行，且产出对应 canonical artifact 或明确阻塞记录。
2. 每个下游角色显式消费上游 artifact，并能指出输入是否充足、是否漂移、是否可继续。
3. 每个环节都有站内验收，覆盖输入门禁、产出能力、细节符合性、下游可消费性、阻塞与返修。
4. PM 阶段使用 evidence pack，`phase-prd.json.evidence_sources[]` 能引用截图、页面描述或用户裁决等证据；缺证据必须写 `ASSUMPTION`、`gap_reason`、`required_evidence` 和 `blocks_fields`。
5. developer 阶段产出本仓可运行轻交互原型和 `developer-report.json`，报告逐条对应 AC、变更文件和 fresh proving evidence。
6. review、verify、qa、consistency-auditor 和 delivery-owner 分别做独立判断，不互相替代。
7. QA 使用真实浏览器路径验证原型，留下桌面和移动证据；无法验证时记录阻塞，不用弱证据代替通过。
8. delivery-owner 产出 `delivery-state.json`、`artifact-registry.json`、`signoff-package.json` 和人类可读观察报告。
9. 最终结论明确判定标准链路为“可投入团队使用 / 有条件投入团队使用 / 不可投入团队使用”之一，并列出依据、阻塞和下一步。

每个角色的站内验收记录至少包含：`input_gate`、`artifact_schema`、`contract_boundary`、`downstream_intake`、`blocking_status`、`rework_route` 和 `evidence_refs`。缺少任一最低记录项时，该角色不得判定为通过。

## 5. 执行策略

采用阶段门禁式 live dogfood。

曾比较过三种方式：

- 直接执行全链路：速度快，但容易掩盖中间角色产物问题。
- 离线 fixture 演练：成本低，但无法证明真实协作与反馈闭环。
- 阶段门禁式 live dogfood：成本最高，但最能暴露产出能力、下游消费和返修问题。

本次选择阶段门禁式 live dogfood。原因是用户目标不是快速做一个原型，而是投入团队使用前确认整条标准链路可靠。

## 6. 运行上下文

正式执行前建立 feature context：

- Feature 目录：`docs/feature--quanfangtong-homepage-entry-center/`
- Worklog：`docs/feature--quanfangtong-homepage-entry-center/worklog.md`
- 观察报告：`docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`
- active scope：在 `contracts/active-doc-scope.yaml` 登记本 feature。

`worklog.md` 只记录导航字段，不复制 PRD、设计、任务或验收全文。standard-chain 状态真源仍是 canonical JSON。

### 6.1 Artifact 路径表

本次固定为 `phase-1`、`UNIT-1`。canonical artifact 路径按 catalog 实例化；support/recovery artifact 显式标注，不能作为 control input。

| Artifact | Path | Boundary |
|---|---|---|
| product-director ledger | `docs/feature--quanfangtong-homepage-entry-center/product-director-ledger.json` | support/recovery；producer=`product-director`；`control_input=false` |
| brief | `docs/feature--quanfangtong-homepage-entry-center/brief.json` | canonical catalog/control handoff |
| phase-prd | `docs/feature--quanfangtong-homepage-entry-center/phase-1/phase-prd.json` | canonical catalog/control handoff |
| unit-definition | `docs/feature--quanfangtong-homepage-entry-center/phase-1/units/UNIT-1.json` | canonical catalog/control handoff |
| design | `docs/feature--quanfangtong-homepage-entry-center/phase-1/design.json` | canonical catalog/control handoff |
| test-cases | `docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/test-cases.json` | canonical catalog/control handoff |
| plan | `docs/feature--quanfangtong-homepage-entry-center/phase-1/plan.json` | canonical catalog/control handoff |
| tasks | `docs/feature--quanfangtong-homepage-entry-center/phase-1/tasks.json` | canonical catalog/control handoff |
| developer-report | `docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/tasks/{task_id}/developer-report.json` | canonical catalog/control handoff |
| verify-result | `docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/tasks/{task_id}/verify-result.json` | canonical catalog/control handoff |
| code-review-result | `docs/feature--quanfangtong-homepage-entry-center/phase-1/code-review-result.json` | canonical catalog/control handoff |
| qa-result | `docs/feature--quanfangtong-homepage-entry-center/phase-1/qa-result.json` | canonical catalog/control handoff |
| consistency-audit-result | `docs/feature--quanfangtong-homepage-entry-center/phase-1/consistency-audit-result.json` | canonical catalog/control handoff |
| fix-result | `docs/feature--quanfangtong-homepage-entry-center/phase-1/fix-result.json` | canonical sidecar result；consumers=`delivery-owner`,`review`,`verify`,`qa` |
| delivery-state | `docs/feature--quanfangtong-homepage-entry-center/phase-1/delivery-state.json` | canonical catalog/control handoff |
| artifact-registry | `docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json` | canonical catalog/control handoff |
| signoff-package | `docs/feature--quanfangtong-homepage-entry-center/phase-1/signoff-package.json` | canonical catalog/control handoff |
| user-decision | `docs/feature--quanfangtong-homepage-entry-center/phase-1/user-decision.json` | canonical catalog/control handoff |
| projection-manifest | `docs/feature--quanfangtong-homepage-entry-center/phase-1/views/phase-operational.projection-manifest.json` | canonical catalog/control handoff |

观察报告是 supplemental report，路径为 `docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`。它不是 canonical artifact，不是 control input；最终判定必须引用 canonical artifacts、schema/validator 结果和真实证据。

### 6.2 原型承载与验证路径

轻交互原型默认承载路径：`docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype/`。

原型至少包含：`index.html`、`styles.css`、`app.js`。如后续计划选择项目既有前端技术栈，必须先证明该技术栈存在且可运行；否则使用静态原型，避免引入无关依赖。

默认本地预览命令：`python3 -m http.server 4173 --directory docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype`。如果端口不可用，必须记录实际端口和原因。

浏览器证据输出目录：`docs/feature--quanfangtong-homepage-entry-center/phase-1/evidence/prototype-qa/`。QA 至少产出桌面截图、移动截图和步骤记录；可用工具支持时同时产出 trace 或 video。

## 7. 角色运行方式

正式执行时，必须先确认当前可用运行方式：

- 有可用 subagent 的角色，按角色 subagent 派发。
- 无可用 subagent 但有 installed/shared skill 的角色，由主会话加载对应 skill 并按合同执行。
- 无可用 skill 的环节，由主会话按 `contracts/standard-chain.yaml`、schema、template 和角色边界执行，并在观察报告记录运行方式缺口。

运行方式差异本身属于链路投入风险，必须被记录，不能静默等价为“角色能力已完整可用”。

正式执行前必须形成 runtime matrix：

| Role | Preferred runner | Fallback runner | Discovery source | Gap rule |
|---|---|---|---|---|
| product-director | shared/installed `product-director` skill | main session + contract/schema/template | skill list, `shared/skills/product-director` | skill 缺失为 observable gap；contract/schema/template 缺失为 blocking |
| product-manager | shared/installed `product-manager` skill | main session + contract/schema/template | skill list, `shared/skills/product-manager` | skill 缺失为 observable gap；schema/template 缺失为 blocking |
| design | shared/installed `design` skill | main session + contract/schema/template | skill list, `shared/skills/design` | skill 缺失为 observable gap；schema/template 缺失为 blocking |
| test-design | shared/installed `test-design` skill | main session + contract/schema/template | skill list, `shared/skills/test-design` | skill 缺失为 observable gap；schema/template 缺失为 blocking |
| tech-lead | shared/installed `tech-lead` skill | main session + contract/schema/template | skill list, `shared/skills/tech-lead` | skill 缺失为 observable gap；plan/tasks schema 缺失为 blocking |
| developer | `developer` subagent | main session with task packet | agent list, task packet | subagent 缺失为 observable gap；task packet 不完整为 blocking |
| review | shared/installed `review` skill | main session + review contract | skill list, `shared/skills/review` | skill 缺失为 observable gap；review contract 缺失为 blocking |
| verify | `verifier` subagent | main session + verify contract | agent list, `shared/skills/verify` | subagent 缺失为 observable gap；verify schema 缺失为 blocking |
| qa | `qa` subagent | main session + QA contract/browser tools | agent list, `shared/skills/qa`, browser tool availability | subagent 缺失为 observable gap；浏览器证据能力缺失为 blocking |
| consistency-auditor | `consistency-auditor` subagent | main session + audit contract | agent list, `shared/skills/consistency-audit` | subagent 缺失为 observable gap；audit schema 缺失为 blocking |
| delivery-owner | shared/installed `delivery-owner` skill | main session + contract/schema/template | skill list, `shared/skills/delivery-owner` | skill 缺失为 observable gap；registry/signoff schema 缺失为 blocking |
| fix | `fixer` subagent or shared/installed `fix` skill | main session + fix contract | agent list, `shared/skills/fix` | runner 缺失为 observable gap；`fix-result.json` schema 缺失为 blocking |

主会话按合同/schema/template 执行某角色时，可以算作该角色真实执行；但必须在观察报告记录 runner gap，并通过 artifact schema、下游 intake 和 evidence_refs 证明结果可消费。缺少角色合同、schema 或模板时，不得把主会话自由发挥等价为角色执行。

## 8. 逐环节验收矩阵

每个角色完成后必须做站内验收和下游 intake check。验收不看“重点”，而是看全量细节是否满足该角色合同。

### 8.1 product-director

产出：`brief.json`、`phase-prd.json`、`product-director-ledger.json`。

验收：

- 问题空间、用户画像、业务目标、投入边界、non-goals、风险和 Phase 规划清楚。
- ledger 保留共创 checkpoint，且 finalization basis 能解释为什么可以冻结。
- 不提前写 HOW、UNIT、AC 或实现方案。
- 下游 PM 能消费 Director baseline，并能区分事实、假设和用户裁决。

### 8.2 product-manager

产出：refined `brief.json`、refined `phase-prd.json`、`UNIT-*.json`。

验收：

- 不漂移 Director baseline。
- AS-IS/TO-BE、用户路径、业务规则、AC、scope/exclusion、dependency、technical evidence、delivery confirmation 完整。
- `evidence_sources[]` 引用 evidence pack；截图证据使用 `screenshot_ref`、`captured_at`、`entry_ref`。
- 缺证据不硬写事实，必须按 schema 写假设、证据缺口和阻塞字段；凡影响 AC、用户路径、业务规则、真实依赖或验收结论的缺证据假设，`blocks_fields` 必须非空，并阻塞依赖阶段。
- AC、UNIT、QA handoff 和 delivery confirmation 中涉及未集成真实能力的条目必须标记 `prototype_only` 或 `not_integrated`。
- 每个 UNIT 可设计、可测试、可验收。
- design、test-design、qa 和 delivery-owner 能直接消费 refined brief、UNIT、AC 和证据关系。

### 8.3 design

产出：`design.json`。

验收：

- 继承 WHAT，不改产品范围和 AC。
- 至少比较两个可行方案，解释取舍、代价和失效条件。
- 明确 runtime facts、接口边界、无后端接口边界、质量属性、模块、数据结构、横切关注点、风险响应、迁移/回滚和验证映射。
- review closure 和 final confirmation 明确。
- tech-lead 能据此拆任务；test-design 能据此设计验证义务。

### 8.4 test-design

产出：`test-cases.json`。

验收：

- AC、设计风险和用户路径都有 traceability。
- 等价类、正常路径、异常路径、响应式、浏览器证据、QA handoff 和 typed gap 完整。
- 对无法验证的真实后端能力明确标记不适用或后续前置条件。
- 不用 Mock 证明真实集成完成。
- tech-lead 和 QA 能消费测试义务和证据目标。

### 8.5 tech-lead

产出：`plan.json`、`tasks.json`。

验收：

- WBS、依赖关系、顺序/并行边界、proving command、real dependency、evidence target 和 mock boundary 清楚。
- 每个 task 都有单一边界、AC、允许修改范围、验证命令和报告路径。
- blocking gap 不冻结为可执行任务。
- delivery-owner 能直接派发 task packet。

### 8.6 developer

产出：代码变更、`developer-report.json`。

验收：

- 只做 task 边界内最小实现。
- 每条 AC 都有 RED/GREEN 或等价 fresh proof。
- 报告包含 changed files、验证命令、证据、未覆盖项和阻塞。
- 原型真实可运行，轻交互覆盖约定范围。
- 不把日志、占位、Mock 后端或静态截图当成功实现。

### 8.7 review

产出：`code-review-result.json`。

验收：从行为、架构、范围、安全、测试、可维护性、证据、契约、用户路径和回归风险审查；finding 有文件/行、严重级别、证据、影响和 owner action；PASS 只代表 review 未发现阻塞，不等于 QA 通过或用户签收。

若 review blocking 或后续 `fix` 涉及代码、原型、验证逻辑变更，必须重新产出或追加 `code-review-result.json` revision 后再进入 verify/QA；若 `fix` 仅补证据且不改实现，必须记录免重审依据和 `decision_ref`。

### 8.8 verify

产出：`verify-result.json`。

验收：

- Task 级逐 AC 验证。
- 明确 `SPEC_OK`、`2A_OK`、`2B_OK`、`2C_OK` 或对应失败原因。
- 验证 developer report 中的 proof 是否真实、当前、可复验。
- FAIL 时给出最小 owner route，不自行改实现。

### 8.9 qa

产出：`qa-result.json`。

验收：

- 使用真实浏览器验证用户路径。
- 覆盖桌面、移动、登录方式切换、续费提示、下载入口、客服入口、异常/乱序操作。
- 输出 QA_A/B/C/D、obligation_results、QAR triage 和 release recommendation。
- QA PASS 是 signoff readiness input，不是最终签收。

`qa-result.json` 中每条 `obligation_results[]` 至少包含：`obligation_id`、`source_ac_ref`、`status`、`criticality`、`release_gate`、`browser_name`、`browser_version`、`viewport`、`environment`、`steps`、`expected_result`、`actual_result`、`timestamp`、`evidence_refs` 和 `blocker_owner`。`evidence_refs` 至少绑定 `screenshot_ref`；工具支持时补充 `video_ref` 或 `trace_ref`。没有 evidence ref 的 obligation 不得判定 PASS。

关键 QA obligation 采用可枚举规则生成：凡映射到核心 AC、登录方式切换、续费提示、下载入口、客服入口、桌面/移动响应式、证据真实性、原型边界声明或 signoff readiness 的 obligation，`criticality` 必须为 `critical`，`release_gate` 必须为 `true`。最终三档投入判定必须逐条引用这些 critical obligation 的 `obligation_id` 和状态。

### 8.10 consistency-auditor

产出：`consistency-audit-result.json`。

验收：

- 只读检查，不改 artifact。
- 覆盖 L1-L7：范围、需求、设计、测试、计划、执行、验收、签收链路的一致性和追踪性。
- 每个问题带 `json_pointer`、content evidence、owner action。
- PASS 不等于签收，只是 consistency evidence。

### 8.11 delivery-owner

产出：`delivery-state.json`、`artifact-registry.json`、`signoff-package.json`、`user-decision.json`、观察报告。

验收：

- preflight 检查 active refs、artifact 完整性、运行方式和证据状态。
- 执行 baseline audit 和 final audit。
- 调度 task packet，记录循环、返修、阻塞和恢复点。
- artifact registry 能追到所有 canonical artifact、证据和状态。
- signoff package 区分 readiness、residual risk、authorization basis 和 user acceptance。
- 明确原型边界，不把本仓原型说成线上发布就绪。

`signoff-package.json` 最低字段必须覆盖 standard-chain 合同 key_fields：`baseline_tasks_version_ref`、`active_tasks_version_ref`、`current_stage`、`release_recommendation`、`goal_closure`、`waiver_entries`、`sign_off_status`、`business_risk_acceptance_status`、`last_observed_at`、`runtime_snapshot`、`active_blocker`、`blocker_owner`、`takeover_note`、`decision_basis_refs`。在此基础上可追加 readiness / authorization / acceptance 映射字段：`readiness.status`、`readiness.evidence_refs`、`residual_risks[]`、`authorization_basis.decision`、`authorization_basis.approver`、`authorization_basis.decision_ref`、`acceptance.status`、`acceptance.user_decision_ref`、`prototype_boundary_statement`。`authorization_basis` 只能记录授权依据，不能替代用户 acceptance。

## 9. 审计时机

consistency audit 分两次：

1. baseline audit：在 `tech-lead` 冻结计划前执行，检查 Director/PM/design/test-design 之间是否存在漂移、断链或缺字段。
2. final audit：在 QA 后、delivery-owner signoff 前执行，检查全链路 artifact、验证证据、返修记录和签收包是否一致。

如 baseline audit 发现阻塞级问题，必须回对应 owner 修复后再进入计划冻结。

baseline audit 是 pre-plan sidecar，不等同于最终线性 `consistency-auditor` 阶段。baseline audit 前必须由 `artifact-registry-writer` 创建 canonical `docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json` bootstrap revision，至少枚举当前 active refs、已存在 canonical artifacts、evidence pack refs 和缺口；delivery-owner 后续只能 append revision。baseline audit 消费该 registry 的 bootstrap revision；final audit 消费 delivery-owner append 后的 active revision，以及完整 QA、review、verify、developer、fix 和 signoff readiness 证据；若本轮存在 `fix-result.json`，delivery-owner append revision 和 signoff basis 必须引用 active fix-result。该 bootstrap 只服务 pre-plan trace check，不代表 `delivery-state` 已进入 RUN，也不代表 signoff readiness 已完成。

## 10. 阻塞与返修规则

以下情况必须停止推进依赖该前提的后续步骤：

- 缺少 required input、证据或用户裁决。
- PM/Design/Test/Plan 任一阶段存在 blocking typed gap。
- developer 没有可运行原型、fresh proof 或逐 AC 报告。
- review/verify/qa 出现阻塞失败。
- QA 缺真实浏览器证据。
- consistency audit 发现断链、漂移或 artifact 缺失。
- delivery-owner 无法形成 artifact registry 或 signoff package。

返修按 owner route 回派：

- requirement / AC gap -> product-manager 或 product-director。
- design gap -> design。
- test gap -> test-design。
- plan gap -> tech-lead。
- implementation gap -> developer 或 `fix` sidecar；`fix` 输出 `fix-result.json`，修复后必须回 review/verify/QA 复验。
- verification / QA evidence gap -> verify 或 qa。
- risk / scope / authorization gap -> 用户裁决。

## 11. 观察报告

观察报告路径为：`docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`。

观察报告记录三类问题：

- 需求问题：全房通入口中心需求自身的目标、范围、证据或验收问题。
- 链路问题：角色合同、artifact、schema、模板、handoff、validator、sidecar 或 delivery-owner 调度问题。
- 环境问题：工具、浏览器、网络、subagent/skill 可用性、真实代码仓库缺失等执行条件问题。

每条观察至少记录：阶段、现象、证据、影响、归类、severity、status、owner、owner_route、是否阻塞、artifact_ref、json_pointer、建议下一步、closed_evidence。

## 12. 可投入团队使用判定

最终只允许三档结论：

- 可投入团队使用：open blocking = 0，open major = 0；所有 canonical artifact 通过对应 schema/contract 检查；QA 关键 obligation 全部 PASS；final audit 无阻塞或重大断链；只存在不影响当前团队试用的 minor，且每条都有 owner 和后续处理方式。
- 有条件投入团队使用：open blocking = 0；存在未关闭 major，但 major 不破坏主链闭环、证据链、QA 关键路径或 signoff package，且每条都有使用条件、owner、补强计划和风险接受依据；或存在 runner gap、环境 gap 等会影响推广方式但不影响本次闭环事实的问题。
- 不可投入团队使用：open blocking > 0；或存在破坏 canonical trace、关键 QA obligation、证据真实性、返修闭环、artifact registry、signoff package 的未关闭 major；或继续推进需要改变成功标准、放宽证据口径、跳过真实浏览器验证、把原型等同线上发布。

判定必须逐项引用角色产物、验证记录、QA 证据、audit 结果和观察报告，不能用主观总结替代。

## 13. 风险与待验证项

- 当前无真实业务代码仓库，developer 原型只能证明链路和轻交互实现能力，不能证明线上集成能力。
- 截图采集可能受浏览器环境限制；失败时必须记录真实失败原因，不能用页面文本替代截图通过 PM 截图证据要求。
- 角色运行方式可能不完全等同目标团队配置；差异必须进入观察报告。
- 当前仓库存在既有 hook/lint/复杂度提示，若阻断本次 proving command，需要按目标内外分类处理，不得静默绕过。
- `standard-chain.yaml` 与 schema/field consumption 之间可能存在字段漂移风险，正式试跑中必须作为 consistency audit 观察项核验。

## 14. 下一步

用户 review 本设计文档后，如确认无修改，进入 implementation planning。下一阶段应创建执行计划，明确 feature context 创建、证据采集、角色执行顺序、artifact 路径、验证命令和阻塞裁决点。

Planning 完成判据：feature context 已建；active scope 已登记且满足 required fields；evidence pack 已完成或形成阻塞裁决；runtime matrix 已完成；artifact path table 已落到计划；projection manifest 的 materialize/validate 责任已分配；prototype path、启动命令、浏览器验证方式、证据输出目录、review/fix/re-review loop 已冻结；`plan.json` 和 `tasks.json` 可直接派发，且每个 task 都有 allowed paths、AC、proving command、report path 和阻塞条件。
