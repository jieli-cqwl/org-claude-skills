# AI Feature/Task Harness Engineering 调研报告

> 调研模式：analysis
> 呈现模式：understanding
> 调研时间：2026-04-12
> 预设读者：正在思考如何把 AI 从“会写一点”推进到“能持续执行具体 feature/task”的团队负责人、流程设计者、skill/contract 维护者

## 这是什么
- 当前对象/主题：面向具体 `feature / task` 执行的 `Harness Engineering`
- 一句话定义：它不是“再补几份文档”，而是围绕 AI 执行任务搭一层 `可读、可控、可验证、可回收` 的运行系统。
- 最容易混淆的相近对象：
  - 它不等于 `新人 onboarding`
  - 它不等于 `prompt engineering`
  - 它不等于 `纯文档治理`
  - 它也不等于 `再造一个 workflow 平台`

## 为什么值得关注
- 关键价值：真正要解决的是 AI 在多步任务中的 `断片、漂移、失真、不可接管、不可复盘`，不是让仓库“看起来更整齐”。
- 为什么现在值得看：你们仓库已经有很强的 `small-chain + tasks.md + verification + QA + acceptance` 骨架，最值得判断的是“还差哪一层就能变成真正可用的 Harness”，而不是继续局部补命名或补说明。
- 谁最需要理解它：
  - 设计 `skills / contracts / hooks / docs` 的人
  - 希望让 AI 持续推进任务、而不是每轮都重新解释背景的人
  - 想做团队级试点，但不想一上来就平台化过度建设的人

## 核心机制与关键差异
| 维度 | 内容 |
|------|------|
| 核心机制 | 用 `guides/feedforward` 限制 AI 起手方向，用 `state + trace + evidence + sensors` 让 AI 在执行中持续自纠、可接管、可复盘。 |
| 对 AI 真正有用的最小闭环 | `单真源状态 -> 执行记录 -> fresh 验证 -> 闭环结论 -> 失败回流` |
| 与 onboarding 的差异 | onboarding 只是让系统更可读；Harness 的目标是让 AI 自己能继续推进任务。 |
| 与 prompt engineering 的差异 | prompt 只解决“怎么说”，Harness 还解决“怎么知道现在到哪、做得对不对、偏了怎么纠正”。 |
| 与纯文档治理的差异 | 文档可以当地图，但不能单独充当控制系统；没有行为证据时，文档只是在讲故事。 |
| 与 workflow orchestration 的差异 | orchestration 解决“怎么派发/怎么跑”；Harness 还要解决“怎么保真、怎么观测、怎么回流、怎么收口”。 |
| 最容易被误解的点 | 不是状态文件越多越好；不是先造平台；不是把 `status/记录/文档` 全都写成真源。 |

## 适用边界
- 适用场景：
  - AI 要执行的是 `多步、跨轮次、可中断恢复` 的任务
  - 同类任务会重复发生，值得把失败经验固化成状态/验证/回流机制
  - 团队希望把人工注意力放在裁决和例外，而不是每轮补背景
- 不适用场景：
  - 任务一次性强、低频、强探索，几乎没有复用
  - 人始终在线主导，AI 只是局部辅助
  - 任务没有稳定验收路径，成功与否主要靠口头解释
- 需要保留的前提：
  - 必须有真实验证入口，不能拿 Mock 或自述替代
  - 必须接受“单真源 + 派生视图”，不能平行维护第二套真实状态
  - 必须能持续清理漂移，否则 Harness 很快会腐烂

## 如果只记住三件事
- 你们真正要做的不是“新人更好上手”，而是“AI 能持续接住并推进一个具体 task”。
- 你们现在已经有很强的 `gate`，但还缺 `runtime state + trace + takeover`。
- 第一版最值得做的不是新平台，而是在现有 `small-chain` 上补最小可恢复执行层，并用真实任务结果证明它值不值得继续投。

## 拆解对象概览
- 对象类型：工程实践 / 任务执行控制系统
- 原始观点：为了让 AI 在具体 `feature / task` 上持续感知状态、积累记录、维护文档并推进交付，需要打造一套真正可用的 Harness Engineering。
- 需要回答的问题：
  - 这个主张到底成立到什么程度
  - 你们当前仓库已经有什么，还缺什么
  - 第一版最小闭环应该长什么样
  - 哪些方向看起来合理，但其实会把系统做重

## 核心判断依据

### 论点一：对你们来说，Harness 的目标不是 onboarding，而是 AI 任务执行的稳定性与可恢复性
- 最强支持证据：
  - OpenAI 将 agents 描述为会 `plan, call tools, collaborate across specialists, and keep enough state to complete multi-step work` 的应用，说明“保持足够状态完成多步工作”是核心能力，而不是附带效果。  
    来源：OpenAI Agents SDK 概览（[developers.openai.com](https://developers.openai.com/api/docs/guides/agents)）
  - Anthropic 明确指出，prompt engineering 的前提是你已经有清晰成功标准和实证测试；并非所有问题都适合靠 prompt engineering 解决。  
    来源：Anthropic Prompt engineering overview（[platform.claude.com](https://platform.claude.com/docs/en/docs/prompt-engineering)）
  - Martin Fowler 将 harness 拆成 `guides + sensors`，强调它的作用是提升首次成功率并让 agent 在人接手前先自我修正。  
    来源：[Harness engineering for coding agent users](https://martinfowler.com/articles/harness-engineering.html)
- 最强反方挑战：
  - 这听起来像“prompt + tests + docs”的重新包装，可能只是术语升级。
- 当前判定：成立。
- 结论稳健性：高。
- 失效边界：如果任务本身是单轮、低风险、低变异，Harness 的边际价值会很低。

### 论点二：你们仓库已经有很强的静态 Harness，但还没有完整的运行时 Harness
- 最强支持证据：
  - 仓库已明确 `tasks.md` 是进度/完成状态真源，`plan.md` 只保留 task-id 映射，不持有 checkbox 状态。  
    来源：[README.md](../../README.md)
  - `contracts/small-chain.yaml` 已经把 `tasks-progress -> verification-before-completion -> verify-change` 串成线性收口链。  
    来源：[contracts/small-chain.yaml](../../contracts/small-chain.yaml)
  - `developer-report-template.md`、`dev-report-template.md`、`qa-report-template.md`、`acceptance-summary-template.md` 已经能产出 RED/GREEN/fresh proof、QAR、release recommendation、签收等交付证据。  
    来源：`shared/skills/**/references/templates/*.md`
  - OpenAI 在 Harness 文章里强调，真正拉开差距的是让 `UI、logs、metrics、traces` 对 agent 直接可见，而不是只靠 repo 说明文档。  
    来源：[openai.com/index/harness-engineering](https://openai.com/index/harness-engineering/)
- 最强反方挑战：
  - 也许你们已经做得足够多，再补 Harness 只会把维护成本继续抬高。
- 当前判定：部分成立。
- 结论稳健性：高。
- 失效边界：如果仓库外已经有成熟的状态层、trace、eval registry、runtime observability，则“缺运行时 Harness”需要下调。

### 论点三：当前最大缺口不是更多门禁，而是 AI 可持续消费的状态层、trace 和 takeover
- 最强支持证据：
  - 现有流程已经把“先验证再宣称完成”卡得很严，但状态仍主要散落在 `tasks.md / dev-report / qa-report / acceptance-summary` 的组合里，没有一个统一的运行态对象来回答“现在在哪、为什么卡住、下一步是什么、谁来接手”。
  - OpenAI 在结果与观测的指南中把 `results and state`、`integrations and observability`、`evaluate agent workflows` 直接作为 agent app 的核心路径，而不是附录。  
    来源：OpenAI Agents SDK 导航页（[developers.openai.com](https://developers.openai.com/api/docs/guides/agents)）
  - Anthropic 对 agent loop 的表达是 `gather context -> take action -> verify work -> repeat`，本质上也要求上下文和验证能跨轮持续。  
    来源：[Building agents with the Claude Agent SDK](https://claude.com/blog/building-agents-with-the-claude-agent-sdk)
- 最强反方挑战：
  - 很多“AI 推不下去”其实是任务状态机本身太弱，不一定需要上升到 Harness 设计。
- 当前判定：成立，但应收窄成“先补最小可恢复状态层”。
- 结论稳健性：中高。
- 失效边界：如果状态机、阻塞表达、验收边界都还没清楚，先做 Harness 会变成包装混乱。

### 论点四：单真源是硬约束；新增对象只能是派生视图或追加日志，不能和现有真源争夺解释权
- 最强支持证据：
  - 仓库已有明确真源：`tasks.md` 负责完成状态，`plan.md` 负责映射，`qa-report.md` 负责质量判断，`acceptance-summary.md` 负责签收收口。
  - OpenAI 明确写到 “one big AGENTS.md” 会因为上下文稀缺、指导失焦、快速腐烂、难以机械校验而失败，因此要把 `AGENTS.md` 降成目录，把结构化知识库当系统真源。  
    来源：[openai.com/index/harness-engineering](https://openai.com/index/harness-engineering/)
  - 架构 challenger 指出：只要 `状态 / 记录 / 文档` 都能回答“现在做到哪了”，就已经变成多真源，后面一定出现对账成本。
- 最强反方挑战：
  - 没有一个统一 runtime object，AI 跨轮恢复就还是很难。
- 当前判定：成立。
- 结论稳健性：高。
- 失效边界：如果未来引入新的状态对象，它只能是派生视图或 append-only 日志，不能取代既有真源边界。

### 论点五：这件事只有在绑定真实行为证据和结果指标时才有价值；否则只是更完整的叙事层
- 最强支持证据：
  - QA 契约已经要求真实服务、真实路径以及命中 `browser_required` 时必须提供浏览器证据。  
    来源：[shared/skills/qa/SKILL.md](../../shared/skills/qa/SKILL.md) 与 [qa-report-template.md](../../shared/skills/qa/references/templates/qa-report-template.md)
  - Anthropic 文档强调，在做 prompt engineering 之前需要先定义成功标准并建立实证评估。  
    来源：[platform.claude.com/docs/en/docs/prompt-engineering](https://platform.claude.com/docs/en/docs/prompt-engineering)
  - DORA 报告只把高质量内部文档视为基础能力之一，不把“文档更多”直接等同于交付更好。  
    来源：[DORA 2021 report](https://dora.dev/research/2021/dora-report/)
  - METR 的研究提醒：在某些熟手、熟仓库、真实任务场景中，AI 不一定天然提升效率，主观体感可能和真实结果相反。  
    来源：[arXiv:2507.09089](https://arxiv.org/abs/2507.09089)
- 最强反方挑战：
  - 即便结果指标一时没提升，可追溯性和交接体验仍然可能有价值。
- 当前判定：成立，但必须区分“可读性价值”和“交付价值”。
- 结论稳健性：中高。
- 失效边界：如果你们只追求交接可读性，不追求交付效率/稳定性提升，那么这一论点需要降级。

## 吸收建议

### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 保留 `tasks.md` 作为完成状态唯一真源 | 现有 single-source 约束继续成立 | 不新增并行状态表，任何新对象只能引用 `task_id` 并派生展示 |
| 把 `plan.md` 固定为任务映射和执行路径层 | 当前约束已明确 plan 不持有状态 | 禁止把 `plan.md` 改成状态仪表盘 |
| 把 `fresh proof / QA / acceptance` 当行为证据链 | 有真实验证入口 | 任何 `done/blocked` 结论都必须指向证据锚点 |
| 优先补 `trace / runtime state / takeover` | 已有 gate 较强 | 下一阶段聚焦状态、trace、takeover，而不是继续加说明文档 |

### 改写后吸收
| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| “做一套状态、记录、文档体系” | 做“单真源状态 + append-only 运行账本 + closeout 结论” | 避免状态/记录/文档三者都变真源 |
| “打造真正的 Harness Engineering” | 先做“最小可恢复执行层”试点 | 避免一上来平台化建设 |
| “让 AI 有状态、有记录、有文档” | 让 AI 在任意时刻都能回答：现在到哪、为什么这么判断、下一步是什么、证据在哪 | 从抽象口号收敛到可验证行为 |
| “先做进展感知” | 先做 `runtime card + takeover packet + evidence refs` | 进展感知本身不是目标，持续推进才是目标 |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 先建 dashboard / 状态数据库 / 新平台 | 太早，且极易与现有真源冲突 |
| 把 onboarding 当主目标 | 会误导设计方向，削弱 AI 执行闭环视角 |
| 新增“进度文档”作为新品类 | 很可能与 `tasks.md / plan.md / reports` 打架 |
| 只补更多规范和说明文档 | 会加强静态治理，不会自动补齐运行态缺口 |

## 落地行动项
- [P0] 先定义一份最小 `runtime card` 草案，只保留：`task_id / current_state / next_step / blocker / evidence_ref / last_decision / last_verified / takeover_summary`
- [P0] 明确它的写入边界：它不是第二状态真源，只是对 `tasks.md + evidence refs` 的可恢复执行视图
- [P0] 选 1 类高频、低不确定性的真实任务，连续跑 `6-10` 个 task 做试点
- [P0] 先记录 baseline：首次验收通过率、返工率、暂停后恢复时间、人工救火次数、工件维护时间占比
- [P0] 写死 kill criteria：通过率无提升、返工上升、维护成本超标、无证据完成、状态与事实分叉即停止
- [P1] 增加 append-only 的决策/阻塞 trace，只记录关键选择、重试依据、replan 原因、证据指针
- [P1] 设计一页 `takeover packet`，确保不找原作者也能复原当前任务现场
- [P1] 为 1-2 类高频失败模式建立最小 eval/trace 回流表，不追求全量
- [P2] 若试点证明有效，再考虑把日志、metrics、traces 更直接暴露给 agent，而不是先上大平台

## 审计附录

### 论点挑战总表
| 论点 | 最强支持证据 | 最强反方挑战 | 当前判定 | 对我们的启示 |
|------|-------------|-------------|---------|-------------|
| Harness 的目标是 AI 持续执行，不是 onboarding | OpenAI/Anthropic/Fowler 都把状态、反馈、验证放在核心位置 | 术语有包装嫌疑 | 成立 | 目标层要改口，不再以新人为中心 |
| 仓库已有静态 Harness，但缺运行时 Harness | 本地已有强 gate 和证据模板；外部最佳实践强调 observability/traces | 也许再补只会增维护成本 | 部分成立 | 先补 runtime state/trace，不先补平台 |
| 单真源是硬约束 | README、contracts、模板边界已很明确；OpenAI 反对 monolithic AGENTS | 没有统一 runtime object 又难恢复 | 成立 | 新对象只能是派生视图或日志 |
| 状态/记录/文档只有绑定行为证据才有价值 | QA/browser/fresh proof 已是本地硬门；Anthropic 要求 eval；DORA/METR 提醒别迷信体感 | 可读性本身也有价值 | 成立 | 试点必须用结果指标衡量，不凭感觉决策 |

### 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| 会不会把系统做得过重 | 如果把任务分解、执行状态、审计证据、持续推进一起设计，容易变成第二套元流程 | 接受。结论收窄为“先补最小可恢复执行层”，不做全量任务操作系统 | 是 |
| 会不会制造多个真源 | 只要 `状态 / 记录 / 文档` 都能回答当前进度，就会产生对账成本 | 接受。报告明确要求单真源，新增对象只能是派生视图或 append-only 日志 | 是 |
| 会不会只是可读性提升，不是真正交付价值提升 | 没有真实行为证据和结果指标，Harness 只是叙事层 | 接受。把 ROI 和行为证据门槛前置到试点准入条件 | 是 |
| 会不会把状态机问题误当成 Harness 问题 | 很多断片来自任务状态机太弱，而不是缺 Harness | 接受。把 `runtime card` 收缩为最小状态机 + 证据指针，而不是抽象大平台 | 是 |

### 检索路径与覆盖证明
- 名称归一化：
  - `Harness Engineering`
  - `harness engineering`
  - `AI task harness`
  - `runtime state`
  - `trace grading`
  - `stateful agents`
- 已查对象类型：
  - 官方工程文章
  - 官方 API/SDK 文档
  - 学术/实证研究
  - 社区/行业方法文章
  - 本仓库 contracts / templates / reports / skills
- 已查 discovery 入口：
  - OpenAI 官方文章与开发文档
  - Anthropic 官方文档与工程博客
  - Martin Fowler / Thoughtworks
  - DORA / METR
  - 仓库 `README.md`、`contracts/`、`shared/skills/**/templates`、`docs/` 历史研究材料
- 已排除候选：
  - “新人 onboarding 体系”作为主目标：会把目标从 AI 执行闭环带偏
  - “纯命名统一工程”：只能改善可读性，不能单独解决运行时缺口
  - “先建平台/数据库/dashboard”：不满足最小试点原则
  - `OpenSpec` 作为本次运行时依赖：最多可作参考语义，不是当前结论的前提
- 剩余盲区：
  - 还没有拿你们自己的真实任务数据做 baseline/after 对照
  - 还没有定义试点任务族与失败样本集
  - 还没有验证 `runtime card` 会不会与现有工件形成新的维护债

### 项目上下文
- 技术栈：
  - 这是一个以 `skills / rules / reference / hooks / agents / contracts` 为核心的流程仓库，不是普通业务应用仓库。
- 已有相关实现：
  - `small-chain` 已定义从 entry 到 verify 再到 archive 的工件链
  - `tasks.md` 已被明确设为完成状态真源
  - `plan.md` 已被明确设为 task-id 映射层
  - `developer / qa / project-manager` 模板已经能产出较强交付证据
  - `project-manager-role` 与既有 `Harness Engineering` 调研文档已指出当前更缺 runtime observability、goal closure、drift cleanup
- 约束条件：
  - 现有体系偏强治理、强门禁、强文档追溯
  - 因此新增能力必须优先满足“单真源、不抢权、可机检、可回收”

### 证据索引
- [E1] OpenAI Agents SDK overview  
  https://developers.openai.com/api/docs/guides/agents
- [E2] OpenAI, `Harness engineering: leveraging Codex in an agent-first world`, 2026-02-11  
  https://openai.com/index/harness-engineering/
- [E3] OpenAI, `A practical guide to building agents`  
  https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
- [E4] Anthropic, `Prompt engineering overview`  
  https://platform.claude.com/docs/en/docs/prompt-engineering
- [E5] Anthropic, `Define success criteria and build evaluations`  
  https://platform.claude.com/docs/en/docs/empirical-performance-evaluations
- [E6] Anthropic, `Building agents with the Claude Agent SDK`  
  https://claude.com/blog/building-agents-with-the-claude-agent-sdk
- [E7] Martin Fowler / Thoughtworks, `Harness engineering for coding agent users`, 2026-04-02  
  https://martinfowler.com/articles/harness-engineering.html
- [E8] METR, `Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity`  
  https://arxiv.org/abs/2507.09089
- [E9] DORA, `Accelerate State of DevOps Report 2021`  
  https://dora.dev/research/2021/dora-report/
- [E10] 本仓库 [README.md](../../README.md)
- [E11] 本仓库 [contracts/small-chain.yaml](../../contracts/small-chain.yaml)
- [E12] 本仓库 [docs/harness-engineering-20260411/research-report.md](../harness-engineering-20260411/research-report.md)
- [E13] 本仓库 [docs/project-manager-role-20260411/role-definition-gap.md](../project-manager-role-20260411/role-definition-gap.md)
- [E14] 本仓库 [shared/skills/developer/references/templates/developer-report-template.md](../../shared/skills/developer/references/templates/developer-report-template.md)
- [E15] 本仓库 [shared/skills/project-manager/references/templates/dev-report-template.md](../../shared/skills/project-manager/references/templates/dev-report-template.md)
- [E16] 本仓库 [shared/skills/qa/references/templates/qa-report-template.md](../../shared/skills/qa/references/templates/qa-report-template.md)
- [E17] 本仓库 [shared/skills/project-manager/references/templates/acceptance-summary-template.md](../../shared/skills/project-manager/references/templates/acceptance-summary-template.md)
- [E18] 本仓库 [shared/skills/project-manager/references/phase3-dispatch.md](../../shared/skills/project-manager/references/phase3-dispatch.md)
