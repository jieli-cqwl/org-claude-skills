# 复杂链路主 Agent 降噪调研报告

> 调研模式：[analysis]
> 呈现模式：audit

## 当前判断
- 这次要回答的问题：在 `/product → /design → /test-design → /tech-lead → /delivery-owner` 这条复杂链路里，哪些地方必须引入 `sub agent` 才能减少主 Agent 噪音并改善交付质量。
- 当前结论：部分成立。
- 一句话判断：这条链路里没有任何一个完整节点可以整体下放，真正值得补的是“只读采集、独立假设、矩阵/映射草稿、单 Task 执行与独立验证”这类高读写、低裁决步骤；高频长链噪音更集中在 `product / design / test-design / tech-lead`，其中 `tech-lead` 是追踪字段最密的热区，`delivery-owner` 更像收口放大器而不是首要根因。
- 最大风险：把前半段必要共创误杀成噪音，或把工件/合同缺陷误诊成“缺少 sub agent”。
- 下一步动作：条件采纳。先定义“可下放工序 contract”，小范围试点 4 类插点，不对任何完整阶段整体下放。

## 关键论点挑战表
| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| 主噪音主要在 `/product`、`/design` 的共创问答 | 这些阶段有大量暂停、确认、回退、文档落盘 | 共创步骤的主要作用是前置降噪，删掉会把歧义推迟到下游；真正的高频噪音是长暂停链与 `tech-lead` 追踪字段负担 | 不成立 | 中 |
| 主噪音主要在 `/tech-lead`、`/delivery-owner` 的追踪、证据、门禁编排 | `tech-lead` 要维护覆盖追踪链、Task 证据包；`delivery-owner` 再承接验证与签收报告栈 | `delivery-owner` 更像收口和放大节点，不应被高估为首要根因；真正的高频长暂停链在 `product/design/test-design/tech-lead` | 部分成立 | 高 |
| 前半段复杂链路应普遍引入 sub agent | `product/design/tech-lead` 都存在高读写、强结构化、可形成候选草稿的工作 | 若把完整共创步骤交给 sub agent，只会制造更多待确认文本和回收负担 | 部分成立 | 中 |
| 没有任何完整节点可以整体下放 | `contracts/skill-chain.yaml` 把 5 个阶段都定义为 `position: main`，且每一环输出都是下一环必需输入 | 局部工序可以下放，不能把“整节点不可下放”误读成“一点都不能拆” | 成立 | 高 |
| 工件改进优先于盲目加 agent | `brief/design/test-cases/plan` 的回收件、追踪链、证据锚点不完整时，下游会重复追问和补台账 | 即便工件更好，独立 challenge、worktree 隔离、真实环境验证仍然需要 sub agent | 成立 | 高 |

## 覆盖证明摘要
- 已查入口摘要：`product/design/test-design/tech-lead/delivery-owner` 5 个主流程 skill，`contracts/skill-chain.yaml`，`shared/reference/影响范围分析.md`，`shared/reference/agent-team-patterns.md`，`delivery-owner/references/dispatch-guide.md`，`delivery-owner/references/phase3-dispatch.md`，`tech-lead/references/templates/plan-template.md`，`delivery-owner/references/templates/dev-report-template.md`，`docs/rules-reference-rollout-readiness-20260411/review-summary.md`。
- 最大剩余盲区：本次是流程合同级调研，没有引入真实会话日志、实际 token 消耗统计、线上失败样本，因此结论回答的是“设计上哪里容易形成主 Agent 噪音”，不是“生产中已经量化验证的噪音强度”。
- 为什么当前仍可判断：你的问题聚焦“复杂链路流程 design 是否缺 sub agent”，而仓库里的技能合同、阶段硬门槛和工件模板就是这条链路的单一真源，足以判断职责边界、噪音热区和适合下放的工序。

## 拆解对象概览
- 对象类型：项目方法 / 流程 skill 链
- 原始观点：从“减少主 Agent 噪音、提升交付质量”的目标倒推，评估复杂链路里哪些地方该补 `sub agent`
- 需要回答的问题：哪些噪音点找对了；哪些应该先修工件；哪些工序适合下放；哪些 Gate 必须保留在主 Agent

## 核心判断依据

## 论点一：主噪音不是单点，而是“中前段长暂停链 + tech-lead 追踪字段热区”；`delivery-owner` 更像收口放大器

### 核心机制
- `/product`、`/design`、`/test-design`、`/tech-lead` 都有长暂停链、三视角审查或强追溯字段，会持续占用主 Agent 注意力。
- 其中 `tech-lead` 把负担推到最密：覆盖追踪链、Task 证据包、并行策略、审查收敛都要在一个阶段里完成。
- `/delivery-owner` 也很重，但它更像收口节点和放大器，主要承接前面已经冻结的计划与证据，而不是最早制造噪音的根因。
- 因此，复杂链路中的噪音不是“某个单一阶段太重”，而是“长暂停链 + 同一事实被重复转码和重复回收”。

### 证据分层
- A 级证据：
  - `product` 的共创与确认硬门槛：[shared/skills/product/SKILL.md:136-219](/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md:136)
  - `design` 的逐决策共创与最终确认：[shared/skills/design/SKILL.md:145-200](/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md:145)
  - `test-design` 的 AC 三态覆盖、QA 交接契约、专项展开与审查：[shared/skills/test-design/SKILL.md:46-87](/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md:46)
  - `tech-lead` 的追踪链与 Task 证据包：[shared/skills/tech-lead/SKILL.md:78-124](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md:78)
  - `delivery-owner` 的 preflight / proving / Phase 3 报告栈：[shared/skills/delivery-owner/SKILL.md:125-169](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md:125)
  - 上下文预算复盘指向 `design / product / tech-lead`：[docs/rules-reference-rollout-readiness-20260411/review-summary.md:251-257](/Users/lijieli/org-claude-skills/docs/rules-reference-rollout-readiness-20260411/review-summary.md:251)
- B 级证据：无
- 证据冲突：一部分后半段步骤也是必要质量控制，因此不能把“热区”直接等同于“都该删”

### 正反论证
- 最强支持证据：`tech-lead` 明确要求 `UNIT -> AC -> scope_item_id -> MOD -> Task -> test_ref` 追踪链、`impact_files`、`proving_command`、`real_dependency_note`、`evidence_target`、`mock_boundary_note`；同时 `product/design/test-design` 也都存在长暂停链和三视角审查，这些都会持续拉长主 Agent 路径。
- 最强反方挑战：`delivery-owner` 常被感知为“最重阶段”，但它的职责更偏交付编排、质量门禁和签收推进。
- 反例/失败案例：如果把前半段共创和 `test-design` 义务直接删掉，噪音不会消失，只会变成更晚暴露的返工和错验收。

### 项目适配评估
- 最匹配的点：仓库本身已经承认“上下文窗口盲区”和“Sub Agent 信息碎片化”，并通过工件链管理上下文；同时内部复盘已经点名 `design / product / tech-lead` 的上下文预算偏高。
- 最不匹配的点：目前缺少真实执行日志，无法量化每个热区的 token 或轮次成本。
- 采纳成本：中。主要是梳理和重写技能合同，不一定需要重构整条链。
- 退出成本：低。即使判断偏差，也可以先从局部工序试点，不必改掉主流程。

### 当前判断
- 判定：成立
- 结论稳健性：高。多条独立分析与挑战都指向同一热区。
- 失效边界：如果真实执行数据证明 `delivery-owner` 的门禁编排才是绝对主因，或前半段暂停链并未造成显著等待成本，这个判断需要重估。
- 待验证项：采集真实复杂链路的回合数、重复回写次数、失败回退位置。

## 论点二：没有任何完整阶段可以整体下放，能下放的是可回收工序

### 核心机制
- `contracts/skill-chain.yaml` 把 5 个阶段都定义成 `position: main`，每个阶段的产物都被后续阶段直接消费。
- 所以完整节点的责任不是“做很多事”，而是承担阶段性的确认、裁决、Gate 判定、签收和回退。
- 能被 `sub agent` 吃掉的，只能是“先做候选事实、草稿、矩阵、单 Task 执行”，然后回收给主 Agent 定案。

### 证据分层
- A 级证据：
  - 主链合同：[contracts/skill-chain.yaml:4-56](/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml:4)
  - `product` 的显式交付确认与共创强约束：[shared/skills/product/SKILL.md:15-42](/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md:15)
  - `design` 的最终确认与隐式继承限制：[shared/skills/design/SKILL.md:16-47](/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md:16)
  - `tech-lead` 的 `DESIGN_OK`、计划模式、用户确认：[shared/skills/tech-lead/SKILL.md:18-29](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md:18)
  - `delivery-owner` 的 sign-off 和主干提交门槛：[shared/skills/delivery-owner/SKILL.md:15-34](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md:15)
- B 级证据：无
- 证据冲突：无实质冲突，分歧主要发生在“局部工序可拆到什么程度”

### 正反论证
- 最强支持证据：各阶段都把“用户确认、最终确认、FAIL 阻断、sign-off”写成不可绕过的硬门槛。
- 最强反方挑战：前半段仍然存在大量模板化工作，如果不拆，主 Agent 仍会被噪音拖慢。
- 反例/失败案例：如果把完整阶段整体下放，主 Agent 仍然要承担回收、冲突仲裁和对用户解释，往往会增加而不是减少噪音。

### 项目适配评估
- 最匹配的点：这条链是强合同驱动，不是自由流对话；因此“工序下放、责任不下放”非常适配。
- 最不匹配的点：若未来把复杂链路改造成 agent-native pipeline，这个判断会松动。
- 采纳成本：低。它更像一条边界原则。
- 退出成本：低。

### 当前判断
- 判定：成立
- 结论稳健性：高
- 失效边界：只有当主链合同允许节点自治、无需用户确认时，整节点下放才可能成立。
- 待验证项：无

## 论点三：前半段不是不能加 sub agent，而是只能补“读多、比多、抽多”的可回收工序

### 核心机制
- 前半段的根问题确认、架构裁决、`DESIGN-GAP(EQ)` 判定、计划冻结，本质上是单点责任，不能分散。
- 但这些阶段内部仍有大量候选事实生成工作，例如静默预扫描、运行时采证、备选方案草稿、AC 到测试用例映射、覆盖矩阵和 Task 草稿。
- 因此，前半段的正确补法不是“再造一个并行主脑”，而是“给主 Agent 提供更干净的候选输入”。

### 证据分层
- A 级证据：
  - `product` 的 `S1 静默信息收集`：[shared/skills/product/SKILL.md:132-135](/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md:132)
  - `design` 的代码/依赖/运行时扫描：[shared/skills/design/SKILL.md:127-133](/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md:127)
  - `test-design` 的 AC→用例、QA 交接契约、专项展开：[shared/skills/test-design/SKILL.md:46-87](/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md:46)
  - `tech-lead` 的覆盖矩阵、Task 草稿和并行策略：[shared/skills/tech-lead/SKILL.md:78-124](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md:78)
  - agent 模式参考：[shared/reference/agent-team-patterns.md:8-35](/Users/lijieli/org-claude-skills/shared/reference/agent-team-patterns.md:8)
- B 级证据：无
- 证据冲突：有一条 challenger 明确反对在前四段继续加 sub agent，认为大多会“只是搬家”

### 正反论证
- 最强支持证据：`product/design/tech-lead` 当前偏向“主 Agent 先产出，再由 reviewer 兜底”，独立假设生成不足；而 `test-design/tech-lead` 的矩阵、映射、草稿明显是高读写低裁决工作。
- 最强反方挑战：前四段都带用户确认和 Gate，稍微扩张 `sub agent` 都可能增加回收和冲突成本。
- 反例/失败案例：若让 sub agent 代替用户共创、设计裁决、计划冻结，最后只会制造更多 ADR/边界/测试草稿待合并。

### 项目适配评估
- 最匹配的点：可以给这些工序定义固定回收件，比如“候选事实表、方案对比表、覆盖矩阵草稿、Task 草稿”，让主 Agent 只处理裁决。
- 最不匹配的点：如果回收件不标准，前半段反而会变成“看更多草稿”。
- 采纳成本：中
- 退出成本：低到中

### 当前判断
- 判定：部分成立
- 结论稳健性：中
- 失效边界：若试点后发现主 Agent 需要读更多子稿、回收轮次增加，则这一做法不成立。
- 待验证项：为每类工序设定固定输入、固定输出、固定最大 agent 数后做一次试点。

## 吸收建议

### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 不把任何完整阶段整体下放 | 全部复杂链路 | 在流程合同中明确“节点责任不下放，工序可下放” |
| 保留主 Agent 的 Gate 与签收职责 | 全部复杂链路 | 把“确认、裁决、回退、sign-off”列为不可下放职责 |
| 工件改进优先于盲目加 agent | 任何准备加 sub agent 的阶段 | 先检查回收件、追踪链、证据锚点是否已经足够清晰 |

### 改写后吸收
| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| 前半段应该普遍加 sub agent | 只在前半段增加“候选事实/候选方案/候选矩阵”型 sub agent | 保留共创与裁决单点责任，避免变成草稿洪水 |
| 多加 reviewer 就能降噪 | reviewer 保持现状，优先补 `竞争假设`、只读扫描、矩阵草稿 | 当前链路“评审强、独立假设弱” |
| `delivery-owner` 再加协调层 | 仅在任务量很大时增加状态/证据汇总工序，不增加常驻管理者 | 避免把收口节点变成“管理管理者”的噪音放大器 |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 对 `/product`、`/design`、`/test-design` 做整节点 sub agent 化 | 会稀释共创和最终裁决责任 |
| 用 sub agent 替代 `DESIGN-GAP(EQ)`、`DESIGN_OK`、sign-off 这类 Gate 判定 | 与现有硬门槛冲突 |
| 在 `delivery-owner` 继续叠加额外协调者/审查者 | 已有 developer/verifier/review/qa，多加只会放大门禁编排成本 |

## 落地行动项
- [P0] 产出一张“主 Agent / sub agent 职责矩阵”，把不可下放职责与可下放工序写成合同。
- [P0] 在 `product/design/tech-lead` 试点 `竞争假设` 子代理，但只允许输出候选问题/候选方案/候选模式判断，不允许代替用户共创与最终裁决。
- [P0] 在 `design/test-design/tech-lead` 试点 3 类读写分离工序：现状扫描、覆盖矩阵草稿、Task 草稿。
- [P1] 为 `test-design/tech-lead/delivery-owner` 统一一套可复用的证据锚点和回收件格式，减少同一事实被重复编码进多份工件。
- [P1] 为每个试点定义降噪判据：主 Agent 需维护的字段数是否下降、重复回写次数是否下降、跨阶段重复解释次数是否下降、未解决漂移是否上升。
- [P1] 单独验证 `delivery-owner`：区分“收口成本”与“主噪音根因”，不要把 warning 级和增强级门禁误算成首要治理目标。

## 审计附录

### 论点挑战总表
| 论点 | 最强支持证据 | 最强反方挑战 | 当前判定 | 对我们的启示 |
|------|-------------|-------------|---------|-------------|
| 前半段共创是主噪音源 | 暂停、确认、回退确实很多 | 这些步骤主要在过滤歧义，不是主因 | 不成立 | 不要把“重”直接等同于“噪音” |
| 后半段追踪/证据/门禁编排是主噪音热区 | 多份矩阵、证据包、报告栈在 `tech-lead/delivery-owner` 叠加 | `delivery-owner` 更像放大器，真正的高频长链还在 `product/design/test-design/tech-lead` | 部分成立 | 优先治理 `tech-lead` 的追踪字段和前半段长暂停链 |
| 前半段完全不该加 sub agent | 整节点下放会制造更多回收负担 | 局部读写型工序仍适合拆出候选草稿 | 部分成立 | 只拆工序，不拆节点责任 |
| 工件改进比加 agent 更优先 | 回收件、追踪链、证据锚点缺失会导致返工 | 独立 challenge、worktree 隔离、真实验证仍需 agent | 成立 | 先补工件，再决定加哪里 |

### 证据索引
- [E1] [contracts/skill-chain.yaml](/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml)
- [E2] [shared/skills/product/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md)
- [E3] [shared/skills/design/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md)
- [E4] [shared/skills/test-design/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md)
- [E5] [shared/skills/tech-lead/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md)
- [E6] [shared/skills/delivery-owner/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md)
- [E7] [shared/reference/影响范围分析.md](/Users/lijieli/org-claude-skills/shared/reference/影响范围分析.md)
- [E8] [shared/reference/agent-team-patterns.md](/Users/lijieli/org-claude-skills/shared/reference/agent-team-patterns.md)
- [E9] [shared/skills/delivery-owner/references/dispatch-guide.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md)
- [E10] [shared/skills/delivery-owner/references/phase3-dispatch.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/phase3-dispatch.md)
- [E11] [shared/skills/tech-lead/references/templates/plan-template.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/templates/plan-template.md)
- [E12] [shared/skills/delivery-owner/references/templates/dev-report-template.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/templates/dev-report-template.md)
- [E13] [docs/rules-reference-rollout-readiness-20260411/review-summary.md](/Users/lijieli/org-claude-skills/docs/rules-reference-rollout-readiness-20260411/review-summary.md)

## 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| 噪音点找没找对 | 不要把 `/product`、`/design` 的共创问答误判成主噪音源，真正热区更偏长暂停链与追踪字段 | 接受。将主噪音热区从“前后段均匀分布”调整为“中前段长暂停链 + `tech-lead` 追踪字段热区，`delivery-owner` 为放大器” | 是 |
| 补 sub agent 是否真能降噪 | 前四段大部分插点只是搬家，不是降噪 | 部分接受。否定整节点加法，保留局部工序试点 | 是 |
| 是否误把工件问题诊断成 agent 问题 | 很多噪音其实来自工件没把边界、回收件、证据路径写死 | 接受。把“工件改进优先”提升为结论级判断 | 是 |
| 是否高估了 `delivery-owner` | `delivery-owner` 更像收口节点，warning 级 `preflight-evidence` 和增强级 `REVIEW_C` 不应被算成主噪音 | 接受。把 `delivery-owner` 从“首要根因”下调为“收口放大器” | 是 |

## 检索路径与覆盖证明
- 名称归一化：`product / design / test-design / tech-lead / delivery-owner / skill-chain / impact-files / shared_files / sub agent / reviewer / verifier / qa`
- 已查对象类型：`skill` / `contract` / `reference` / `template`
- 已查 discovery 入口：主流程 skill、合同文件、共享 reference、阶段调度 reference、模板文件
- 已排除候选：small-chain 的 `subagent-driven-development` 未纳入主分析对象，只作为反方证据使用，因为本次范围只聚焦复杂链路；`delivery-owner` 下的 `preflight-evidence` 与 `REVIEW_C` 未被视为主噪音候选，因为一个是 warning 级，一个是增强项
- 剩余盲区：真实运行日志、历史失败台账、token/轮次统计、用户会话回放

## 项目上下文
- 技术栈：以 Markdown skill 合同、Shell 测试与 hook、YAML 合同、TOML agent 定义为主的流程仓库。
- 已有相关实现：
  - `product/design/test-design/tech-lead` 已有固定三视角审查模式。
  - `delivery-owner` 已有 developer / verifier / review / qa / fixer 的执行与验收链。
  - small-chain 中已有 `subagent-driven-development`，但定位在执行段，不是复杂链路前四段的默认能力。
- 额外观察：
  - 仓库内部复盘已点名 `design / product / tech-lead` 的上下文预算偏高。
  - `delivery-owner` 的 `preflight-evidence` 当前仍是 warning 级，`REVIEW_C` 仍是增强项，不宜被高估为首要噪音源。
- 约束条件：
  - 5 个阶段都属于主链责任节点。
  - 多处存在显式用户确认、FAIL 阻断、sign-off、回退 Gate。
  - `delivery-owner` 明确禁止 `Worker 数量 > 5`，说明过度多 agent 本身已被视为风险。
