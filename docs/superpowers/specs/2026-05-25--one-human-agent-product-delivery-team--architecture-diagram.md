# 1 人 + 智能代理产品研发交付组织系统目标架构

评审主入口请打开：[`2026-05-25--one-human-agent-product-delivery-team--architecture-diagram.html`](./2026-05-25--one-human-agent-product-delivery-team--architecture-diagram.html)。

本 Markdown 文件是可编辑源稿；HTML 是评审展示入口。普通浏览器直接打开 Markdown 不作为评审展示口径。

## 架构基准

本文件定义 1 人 + 智能代理产品研发交付组织系统的架构基准，作为团队评审、角色分工、协作边界、产物冻结、WBS 任务拆解、交付调度、能力保障和后续工程化建设的统一依据。

| 基准项 | 定义 |
|---|---|
| 基准性质 | 组织系统架构定义 |
| 评审对象 | 产品 / 研发 / 测试 / 交付 |
| 定义范围 | 组织层级、角色权责、运行机制 |
| 使用方式 | 按层级、契约、门禁、闭环评审 |

基本约束：

- 组织边界：用户保留方向、范围、投入、风险接受、最终签收和提交授权；智能代理承接被授权的专业能力与执行任务。
- 权责边界：定义权、任务拆解权、执行权、质量判断权、审计权和签收权分离；每类权责由明确角色承担，并通过冻结产物交接。
- 产出边界：核心产物按阶段冻结并被下游消费；支撑输入层的材料进入主流程前必须转化为证据、建议、风险、待办或变更请求。
- 角色能力责任位：角色代表组织必须长期具备的能力，不等同于单个 agent 或一次性任务。
- 冻结交接：上游冻结定义，下游消费当前有效版本；冲突回到拥有该定义的角色。
- 受控执行：执行与质量代理层只按交付负责人派发包行动；QA 只给质量判断，旁路审计只给 advisory findings，不修改需求、架构、测试、WBS 任务拆解或签收基线。
- 能力保障：角色能力通过契约、模板、schema、脚本、eval、review、证据和复盘持续证明。

## 组织系统总览

主图定义组织系统的决策、冻结、调度、验证、回派和签收关系。

| 边界 | 图上位置 | 职责 |
|---|---|---|
| 用户决策与签收层 | 顶部 | 决定方向、范围、投入、风险接受、最终签收和提交授权 |
| 定义冻结主流程 | 中部主流程 | 从产品方向到 WBS 任务拆解逐层冻结定义；交付调度只消费冻结任务拆解和有效证据 |
| 执行与质量代理层 | 主流程下方 | 按交付负责人派发包执行开发、验证、代码审查、QA、修复和一致性审计；结果只以证据回流 |
| 工程保障层 | 底部并贯穿主流程 | 提供契约、模板、门禁、追踪、证据、恢复状态、风险台账和能力治理 |
| 支撑输入层 | 左侧 | 提供调研、历史知识、能力沉淀、质量评估、反馈和运营输入 |

箭头语义：

| 箭头 | 含义 |
|---|---|
| 金色实线 | 冻结交接：上游确认后，下游只消费当前版本 |
| 绿色实线 | 调度与证据：交付调度派发执行与质量代理层，结果回流为证据 |
| 红色虚线 | 缺口回派：缺口回到拥有对应产物的角色或用户 |
| 灰色虚线 | 工程保障层与支撑输入层：只能作为校验、证据、建议或待办进入主流程 |

## 评审顺序

1. 架构基准：确认组织边界、权责边界、产出边界和能力保障原则。
2. 组织系统总览：确认用户决策与签收层、定义冻结主流程、执行与质量代理层、工程保障层和支撑输入层。
3. 角色与运行机制：确认角色能力契约、产物流冻结门禁、能力保障闭环和评审结论。

## 产物流与冻结门禁

| 阶段 | 责任角色 | 冻结或汇总内容 | 主要产物 |
|---|---|---|---|
| 产品方向冻结 | 产品总监 | 问题、目标、阶段边界和业务风险 | `brief.json`、`phase-prd.json` |
| 产品需求冻结 | 产品经理 | 需求单元、规则、验收标准和排除项 | `UNIT-*.json` |
| 架构方案冻结 | 架构师 | 模块边界、接口、数据归属、风险应对和回滚约束 | `design.json` |
| 测试设计冻结 | 测试设计师 | 测试策略、验收证据、测试层级、负向路径和回归义务 | `test-cases.json` |
| WBS 任务拆解冻结 | 技术负责人（Tech Lead） | 工作包拆分、关键路径、依赖拓扑、并行批次、Task 合同、证明命令和风险/投入信号 | `plan.json`、`tasks.json` |
| 执行与质量证据汇总 | 执行与质量代理层 | 实现证据、验证结果、代码审查、QA 建议、修复记录和一致性审计发现 | `developer-report.json`、`verify-result.json`、`code-review-result.json`、`qa-result.json`、`fix-result.json`、`consistency-audit-result.json` |
| 交付事实汇总 | 交付负责人 | 当前运行状态、证据闭环、残余风险和待用户签收事实 | `delivery-state.json`、`artifact-registry.json`、`signoff-package.json`、`user-decision.json` |

门禁规则：

- 冻结规则：下游只消费当前有效引用；过期或归档引用不作为当前事实。
- 冲突规则：冲突回到对应定义负责人；不能由下游自行改口径。
- 回派规则：需求、设计、测试、WBS 任务拆解、实现、质量和审计缺口各回对应负责人；WBS 任务拆解缺口回技术负责人，风险授权和最终签收只回用户。
- 签收规则：交付包只表示准备就绪；最终签收、风险接受和提交授权只来自用户。

## 角色能力与产出契约

下表定义组织系统中的角色能力责任位、决策权限、越权边界、输入输出、保障机制和缺口回派关系。

| 角色 | 解决的复杂度 | 必备能力 | 决策权 | 越权边界 | 输入 | 输出 | 能力保障 | 缺口回派 |
|---|---|---|---|---|---|---|---|---|
| 用户决策者 | 方向、投入、风险和最终接受 | 业务判断、优先级取舍、风险接受 | 方向、范围、投入、风险接受、最终签收、提交授权 | 不替专业角色产出需求、架构、测试、WBS 或执行证据；只做裁决和授权 | 签收包、风险台账、变更请求、验收证据 | 裁决、授权、接受或退回意见 | 签收清单、风险确认、人工决策记录 | 信息不足回交付负责人补证据 |
| 产品总监 | 问题定义和阶段边界漂移 | 问题建模、目标拆解、阶段策略、业务风险识别 | 产品方向和阶段基线 | 不改需求单元、架构方案、测试设计、WBS 任务拆解或执行证据 | 用户目标、调研证据、业务约束 | `brief.json`、`phase-prd.json` | 方向模板、目标检查、风险清单、评审门禁 | 目标不清回用户裁决 |
| 产品经理 | 需求规则、验收口径和排除项漂移 | 需求单元拆分、规则表达、验收标准定义 | 需求单元和变更建议 | 不改产品方向、架构方案、测试设计、WBS 任务拆解或执行证据 | 阶段 PRD、用户反馈、约束和证据 | `UNIT-*.json`、变更请求 | 需求 schema、验收清单、边界检查、需求评审 | 范围冲突回产品总监 |
| 架构师 | 模块边界、接口、数据归属和演化风险 | 复杂度拆解、边界设计、接口契约、风险与回滚设计 | 架构方案和技术边界 | 不改产品方向、需求验收口径、测试设计、WBS 任务拆解或执行证据 | 冻结需求、约束、证据和风险 | `design.json`、架构决策、风险应对 | 设计原则、架构评审、接口检查、影响分析 | 需求缺口回产品；风险授权回用户 |
| 测试设计师 | 验收证据、负向路径和回归义务缺失 | 测试分层、证据设计、边界路径和失败路径识别 | 测试策略和验收证据口径 | 不改产品需求、架构方案、WBS 任务拆解、实现证据或签收结论 | 需求单元、架构方案、风险清单 | `test-cases.json`、证明命令建议 | 测试规范、覆盖矩阵、负向路径清单、证据门禁 | 不可测需求回产品或架构 |
| 技术负责人（Tech Lead） | 技术负责人把冻结需求、架构和测试义务拆成 AI 可执行 WBS | WBS、工作包拆分、关键路径、依赖拓扑、并行批次、Task 合同、证据路径、投入/风险判断 | WBS 任务拆解、任务边界、依赖顺序、并行批次和版本 | 不改产品、架构、测试、执行证据或签收基线 | 冻结需求、`design.json`、`test-cases.json`、约束和风险 | `plan.json`、`tasks.json` | planning preflight、plan/tasks schema、任务合同校验、用户确认 | 产品、架构、测试缺口回对应负责人；资源或风险授权回用户；WBS 任务拆解不可执行回技术负责人修正 |
| 交付负责人 | 执行调度、状态恢复、证据闭环、循环收敛和风险暂停 | WBS 任务拆解消费、agent 调度、阻塞处理、证据验收、状态治理、签收包整理 | 执行策略、派发顺序、批次调度、运行节奏、暂停和回派 | 不改 WBS 任务拆解、不替 QA 判断、不替用户签收 | 冻结 `plan.json`、`tasks.json`、设计、测试、执行/质量证据和运行状态 | `delivery-state.json`、`artifact-registry.json`、`signoff-package.json`、`user-decision.json` | 前置校验、状态机、恢复协议、签收包模板、风险台账 | WBS 任务拆解缺口回技术负责人；证据不足回执行或 QA；定义缺口回对应负责人；授权缺口回用户 |
| 执行代理组 | 实现、验证、代码审查和最小修复 | 按任务包执行、产出证据、独立验证、缺陷定位、最小修复 | 派发包内实现、验证、审查和最小修复 | 不改定义基线、不扩大范围、不签收、不自行改派发顺序 | 任务包、目标文件、证明命令、失败边界 | 代码变更、`developer-report.json`、`verify-result.json`、`code-review-result.json`、`fix-result.json` | 任务合同、证明命令、review、verifier、fix report | 任务不充分回交付负责人；WBS 任务拆解不可执行回技术负责人；定义冲突回主流程角色 |
| 质量验收（QA） | 用户路径质量判断、残余风险和发布建议 | 验收执行、证据比对、负向路径确认、残余风险识别、条件发布判断 | 质量判断和 release recommendation | 不替用户签收、不接受业务风险、不改定义或 WBS 任务拆解 | 冻结需求、架构、WBS 任务拆解、测试、开发报告、验证报告、审查报告 | `qa-result.json` | QA handoff、测试证据、质量门禁、残余风险清单 | 质量证据不足回交付负责人补证据；需求、设计或测试缺口回对应负责人 |
| 旁路一致性审计 | 冻结工件漂移、遗漏、矛盾和追踪断链 | 跨工件只读检查、引用可达性检查、漂移识别 | advisory_only | 只读检查；不改基线、不裁决质量、不签收、不发起修复 | active refs、冻结产物、运行状态和签收包 | `consistency-audit-result.json` | audit schema、blocked/skipped layers、tool warning、required owner action | 漂移回产物 owner；需要重冻结时回主流程对应角色 |
| 能力治理 | 角色能力退化和组织学习断链 | 缺口模式分析、skill/template/schema/eval/gate 演化 | 能力契约和保障机制改进建议 | 不直接改业务基线、不改当前冻结产物、不替 owner 裁决 | 交付复盘、审查缺陷、验收缺口、运行数据 | 能力改进项、eval 更新建议、门禁优化建议 | 能力评估、回归 eval、postmortem、规则同步 | 组织规则冲突回用户或架构评审 |

能力保障要求：

- 能力定义：每个角色必须说明它消除哪类复杂度、能做什么判断、不能越过哪条边界。
- 产出证明：每个角色输出都要有结构、证据和门禁；没有证据的结论只能是建议或待裁决风险。
- 退化修复：当角色反复漏判、越权或产出不可验时，改进对象是契约、模板、eval、脚本或角色边界。

## 持续能力保障闭环

本机制定义角色能力从契约、执行、证据、门禁到组织学习的持续保障方式。

1. 能力契约：定义角色存在原因、决策权、输入、输出和缺口回派。
2. 执行约束：用模板、schema、任务合同和范围边界降低随意发挥。
3. 产出证据：每个结论、改动和状态都要能回到可复验材料。
4. 质量门禁：通过 review、verify、QA、audit、eval、脚本和 diff 阻断退化。
5. 组织学习：缺口确认后改契约、模板、eval、脚本或角色边界，让系统下次自动变强。

缺口分类必须进入复盘：角色能力问题、契约问题、工具问题、流程边界问题。

## 工程化承载差距矩阵

本矩阵把架构基准映射到当前仓库事实，用于确定后续 contracts、schema、skills、scripts、eval 和运行状态的工程化顺序；它不表示本文件已经完成下列承载物改造。

| 架构要求 | 当前承载 | 差距或风险 | 处理方式 | 验证方式 |
|---|---|---|---|---|
| 角色权责、层级和越权边界可校验 | `contracts/standard-chain.yaml`、`contracts/standard-chain-field-consumption.yaml` 和 `contracts/skill-runtime-surface.json` 承载链路、字段消费和 skill runtime surface；各 `shared/skills/*/SKILL.md` 定义角色职责和 HARD-GATE | 决策权、越权边界和可写产物仍分散在 skill 文本和架构文档中，尚未形成统一机器可消费 role contract | 建立角色元数据或 authority contract 扩展，先覆盖产品、架构、测试、Tech Lead、Delivery Owner、QA、审计和用户签收边界 | contract validator 校验 role owner、可写产物、可消费产物和越权边界 |
| WBS 任务拆解由 Tech Lead 冻结 | `shared/skills/tech-lead/SKILL.md`、`shared/skills/tech-lead/contracts/plan.schema.json`、`shared/skills/tech-lead/contracts/tasks.schema.json`、`shared/skills/tech-lead/scripts/planning_preflight.py` 和 `tools/community/validate_standard_chain_phase.py` 承载计划与任务拆解 | `tech-lead` skill 局部仍有“实施计划”旧口径；WBS owner、冻结状态、版本确认和下游消费约束需要继续用 schema/gate 锁定 | 第一批清理 Tech Lead 旧命名，并把 WBS owner、冻结状态、用户确认和版本引用写入 schema/gate | `rg` 旧口径检查、tasks/plan schema 校验、`validate_standard_chain_phase.py` |
| 交付调度只能消费冻结 WBS | `shared/skills/delivery-owner/SKILL.md` 和 `shared/skills/delivery-owner/contracts/*.schema.json` 定义 intake preflight、baseline audit、dispatch packet、delivery-state、artifact-registry、signoff-package 和 user-decision | 交付调度规则较完整，但 dispatch packet、owner action、状态迁移和签收包之间的跨文件一致性还需要更强门禁 | 把派发包、owner action、状态迁移和签收包纳入统一 validator，阻断未冻结 plan/tasks 被消费 | delivery-owner preflight、task packet check、delivery-state / artifact-registry / signoff schema 校验 |
| QA、审计和用户签收边界不可混用 | `shared/skills/qa/SKILL.md` 输出 `qa-result.json`；`shared/skills/consistency-audit/SKILL.md` 输出 advisory finding；delivery-owner 只整理 signoff-package 和 user-decision | QA release recommendation、审计 advisory 和用户 acceptance / risk acceptance / commit authorization 的语义需要在 schema 与 eval 中持续锁定 | 明确 readiness、quality recommendation、advisory finding、acceptance、risk acceptance、commit authorization 的字段和门禁 | qa-result、consistency-audit-result、signoff-package、user-decision schema 与 eval 覆盖 |
| 缺口回派必须回到产物 owner | delivery-owner 流程、consistency-auditor owner action、`contracts/standard-chain.yaml` 和角色矩阵共同定义回派路径 | gap 分类、owner action 字段和回派闭环目前跨 skill、报告和状态文件分散，容易出现“发现问题但 owner 不明确” | 建立统一 typed gap / owner action 字段，覆盖需求、设计、测试、WBS、实现、质量、审计和授权缺口 | standard-chain validator、audit report contract、delivery-state gap 状态校验 |
| 产物冻结、注册和恢复状态一致 | active refs、`shared/skills/delivery-owner/contracts/artifact-registry.schema.json`、`shared/skills/delivery-owner/contracts/delivery-state.schema.json`、worklog 导航和 context contract 承载当前事实定位 | 角色能力契约尚未和 artifact registry、active refs、恢复协议形成完整可达性检查 | 把角色输出产物、冻结版本、active refs 和恢复状态纳入同一引用可达性检查 | `validate_context_contract.py`、`recover_context.py`、artifact-registry schema、context contract |
| 能力退化能回流到 eval/gate | 各 skill eval、lifecycle-review、`tools/community/validate_canonical_schema.py`、`tools/community/validate_episode_package.py`、`tests/test-standard-chain-validator-stack.sh` 和 quick/full test suite 提供质量反馈入口 | “角色能力问题 / 契约问题 / 工具问题 / 流程边界问题”尚未统一映射到 eval 更新或 gate 优化流程 | 建立 postmortem 到 eval/gate 的改进记录模板，先覆盖高频越权、漏判、证据不足和回派错误 | lifecycle-review、eval contracts、quick/full suite 和新增能力回归 eval |
| 支撑输入只能作为证据、建议或变更请求进入主流程 | 架构基准定义支撑输入层，现有 research/design/review 等 skill 可产出调研、评估和建议 | 支撑输入如何转成 typed evidence、risk、todo 或 change request 还缺统一入口和字段 | 定义支撑输入入站 contract，禁止支撑材料直接改写冻结基线 | 入站 contract 校验、active refs 检查、变更请求 schema 或记录校验 |

## 工程化建设原则

后续 contracts、schema、skills、scripts、eval 和运行状态均按以下原则对齐本架构基准。

| 维度 | 架构要求 | 工程化承载 | 门禁要求 | 评审关注 |
|---|---|---|---|---|
| 层级模型 | 组织系统按用户决策与签收层、定义冻结主流程、执行与质量代理层、工程保障层、支撑输入层分层。 | 流程契约、角色元数据、调度权限、支撑接口。 | 角色层级、可写范围和可消费产物可被机器校验。 | 是否存在越层修改、旁路执行或双重真源。 |
| 角色边界 | 产品、架构、测试、WBS 任务拆解、交付、执行、QA、审计和签收职责分离。 | skill contract、任务包、artifact schema、review checklist。 | 定义角色冻结口径，执行与质量角色只消费冻结版本。 | 是否有角色既定义又执行、既验证又签收，或把 QA/审计判断当用户签收。 |
| 产物冻结 | 阶段产物冻结后才进入下游；冲突回到拥有该定义的角色。 | canonical artifact、active refs、状态文件、恢复协议。 | 过期、归档或未冻结引用不能作为当前事实。 | 冻结顺序、引用可达性和变更入口是否清楚。 |
| WBS 任务拆解 | 技术负责人把冻结需求、架构和测试输入转成 AI 可执行 WBS 任务拆解。 | `plan.json`、`tasks.json`、planning preflight、任务合同校验。 | 任务拆解必须包含任务边界、依赖拓扑、并行批次、证明命令、报告路径和风险信号。 | WBS 任务拆解 owner 是否是技术负责人，交付负责人是否只消费冻结任务拆解。 |
| 交付调度 | 交付负责人基于冻结 WBS 任务拆解调度执行与质量代理层，结果以证据回流。 | dispatch contract、developer/verify/review/fix/qa/audit reports、delivery-state。 | 派发包必须引用冻结 plan/tasks；执行结果必须回写证据，缺口按 owner 回派。 | 并行边界、缺口回派、修复权限和状态恢复是否受控。 |
| 质量与审计 | QA 给质量判断和发布建议；一致性审计只读检查冻结工件漂移。 | `qa-result.json`、`consistency-audit-result.json`、质量记录、审计报告。 | QA 不替用户签收；审计为 advisory_only；质量和审计发现必须可追踪到 owner action。 | 是否把 review/verify/QA/audit 任一结论误当最终签收或业务风险接受。 |
| 能力保障 | 角色能力通过契约、模板、schema、脚本、eval、review、QA、audit 和复盘持续证明。 | 模板库、校验脚本、eval 集、审查报告、质量记录。 | 角色产出必须可结构化检查、可证据追踪、可复盘改进。 | 能力退化是否能被发现并沉淀为系统改进。 |
| 签收边界 | 交付包表示准备就绪；最终签收、风险接受和提交授权只来自用户。 | signoff-package、风险台账、用户裁决记录。 | readiness、acceptance、risk acceptance、commit authorization 语义分离。 | 是否把测试通过、交付就绪或 agent 判断误当用户签收。 |

## 评审结论记录位

| 评审项 | 结论 | 缺口 | 负责人 | 下一步 |
|---|---|---|---|---|
| 架构基准是否成立 |  |  |  |  |
| 组织层级是否清楚 |  |  |  |  |
| 角色权责是否完整 |  |  |  |  |
| WBS 任务拆解 owner 是否明确 |  |  |  |  |
| WBS 任务拆解与交付调度是否分离 |  |  |  |  |
| 产物流和冻结门禁是否明确 |  |  |  |  |
| 执行与质量代理层调度是否受控 |  |  |  |  |
| QA、审计和用户签收边界是否清楚 |  |  |  |  |
| 能力保障闭环是否成立 |  |  |  |  |
| 缺口回派和签收边界是否清楚 |  |  |  |  |
| 工程化建设原则是否可执行 |  |  |  |  |

评审通过后，本文件作为组织系统架构基准进入后续 contracts、schema、skills、scripts、eval 和交付流程建设。
