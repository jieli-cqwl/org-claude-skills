# Harness Engineering 调研报告

> 调研模式：analysis
> 呈现模式：understanding
> 调研时间：2026-04-11
> 预设读者：已经在使用 AI 编码/Agent 流程，但对 `Harness Engineering` 仍停留在“听过、没想透”的团队成员

## 这是什么
- 当前对象/主题：`Harness Engineering`
- 一句话定义：它不是单独一条提示词技巧，而是围绕 AI agent 搭建“可读环境 + 可执行约束 + 可验证反馈 + 可持续改进回路”的工程实践。
- 最容易混淆的相近对象：
  - 它不等于 `Prompt Engineering`。Prompt 只是 harness 的一部分。
  - 它不等于 `Context Engineering`。Context 更偏“给模型看什么”；Harness 更偏“如何把引导、检查、反馈、修正组织成系统”。
  - 它也不等于“加几个 eval”。Eval 是 feedback 传感器，不是全部 harness。

## 为什么值得关注
- 关键价值：在 agent 自主度提高时，把“人盯人”改成“系统盯系统”，降低返工、误改、漂移和人工 review/QA 压力。
- 为什么现在值得看：`Harness Engineering` 作为术语在 2026 年初明显升温。OpenAI 于 2026-02-11 发布同名工程文章，LangChain 于 2026-02-17 发布基于 harness 调优提升 agent 基准成绩的案例，Thoughtworks / Martin Fowler 于 2026-02-05 和 2026-04-02 连续把它与 `context engineering`、`guides + sensors` 框架做了系统化阐释。
- 谁最需要理解它：
  - 已经开始让 AI 参与编码、测试、评审、调试的人
  - 想把 AI 从“辅助写代码”推进到“可控执行任务”的团队
  - 被“AI 一开始很惊艳，随后越来越不稳”困扰的负责人

## 核心机制与关键差异
| 维度 | 内容 |
|------|------|
| 核心机制 | 用 `feedforward`（规则、技能、文档、脚本、模板、拓扑）提升首次成功率；用 `feedback`（测试、lint、trace、grader、review、runtime signals）让 agent 在交付前自我修正。 |
| 业务目标 | 不是让模型“更聪明”，而是让团队在既定成本、时延和风险约束下，获得更高的任务通过率、吞吐量和稳定性。 |
| 和 Prompt Engineering 的差异 | Prompt 关注“怎么说”；Harness 关注“除了怎么说，还给它什么工具、约束、环境、验证和回路”。 |
| 和 Context Engineering 的差异 | Context 更像“内容供给”；Harness 更像“控制系统设计”。Context engineering 是 harness engineering 的重要组成，但不是全部。 |
| 和 Eval-first 的差异 | Eval 主要回答“结果好不好”；Harness 还回答“如何让 agent 在执行过程中更少走歪、能自纠、能复盘、能持续调优”。 |
| 和传统软件流程的差异 | 传统流程假设“人写代码，系统验代码”；Harness 时代更像“人设计约束与反馈系统，agent 在系统内产出代码”。 |
| 最容易被误解的点 | 不是越复杂越好；也不是先堆技能、MCP、hooks。核心不是组件多少，而是失败模式能否被提前约束、及时发现、自动修正。 |

## 适用边界
- 适用场景：
  - 你们已经在做多步 agent 任务，不再只是问答或一次性生成
  - 任务有重复模式，值得把经验固化成规则、脚本、模板和检查
  - 你们希望把人工注意力集中到裁决、异常、边界判断，而不是机械巡检
- 不适用场景：
  - AI 只偶尔帮忙写几个函数，整体仍是人工主导
  - 任务变化极快、尚无稳定标准，做重型 harness 的收益不足
  - 团队还没有基本测试、文档、代码规范，直接上复杂 harness 只会放大混乱
- 需要保留的前提：
  - 要有真实验证路径，而不是只靠 agent 自评
  - 要有可回收的失败信号，最好能积累 trace / logs / cases
  - 要接受“先做最小 harness，再按失败模式迭代”，而不是一开始就设计大而全平台

## 如果只记住三件事
- `Harness Engineering = 给 agent 搭操作系统，不只是给它一段提示词。`
- 它最直接解决的是“AI 能干活，但不稳定、不好复盘、越用越乱”的问题。
- 对大多数团队，最佳做法不是“全面上 harness”，而是先补最小闭环：规则地图、强制验证、trace/eval、持续清理。

## 拆解对象概览
- 对象类型：方法论 / 工程实践
- 原始观点：与其把注意力放在“模型再变聪明一点”，不如把更多工程投入放在让 agent 更易被引导、被观察、被验证和被校正的系统上。
- 需要回答的问题：
  - 这个概念到底成立到什么程度
  - 它和你们当前流程差在哪里
  - 你们是否值得引入，以及应从哪里开始

## 核心判断依据

### 论点一：`Harness Engineering` 是一个新兴但尚未完全标准化的 umbrella term
- 最强支持证据：
  - OpenAI 把核心挑战明确表述为“设计环境、反馈回路和控制系统”，并展示了从代码仓库结构、AGENTS、文档、worktree、浏览器控制到可观测性栈的一整套实践。
  - LangChain 直接把 harness 定义为围绕模型的系统设计，包含 system prompt、tools、middleware、skills、sub-agent delegation、memory 等“旋钮”。
  - Thoughtworks / Martin Fowler 明确提出：在 coding agent 语境下，harness 可以理解为一组 `guides + sensors`，目标是减少监督、增加信心。
- 最强反方挑战：
  - 术语边界还在演化，不同社区把它与 `context engineering`、`agent orchestration`、`eval engineering` 的划分并不完全一致。
- 当前判定：成立。
- 结论稳健性：中高。
- 失效边界：如果未来社区对术语重新收敛，它的定义可能会变窄，但“围绕 agent 建控制系统”的核心思想大概率保留。

### 论点二：它的业务目标不是“让模型更强”，而是“在可控成本下提高自主执行质量与吞吐”
- 最强支持证据：
  - OpenAI 公开案例显示，其内部产品在“人不手写代码”的极端实验下，靠设计环境和反馈回路把三人小团队推到了高吞吐交付。
  - LangChain 公布了“模型不变、只改 harness，Terminal Bench 2.0 从 `52.8` 提升到 `66.5`”的结果，说明 harness 可以直接影响任务表现。
  - OpenAI 官方 eval 文档把 traces、graders、datasets、eval runs 组织成持续改进飞轮，说明最佳实践已从“调 prompt”转向“系统性迭代代理工作流”。
- 最强反方挑战：
  - 这些案例都在特定任务、特定组织、特定投入条件下成立，不能直接等价成“任何团队都该重投 harness”。
- 当前判定：成立。
- 结论稳健性：高。
- 失效边界：如果你的任务量很小、失败代价低、团队并不追求 agent autonomy，那么 harness 的 ROI 会显著下降。

### 论点三：和你们现有流程相比，你们已经做了不少 harness，但主要集中在“可维护性 harness”，还没有把“运行时反馈 + eval flywheel”做重
- 最强支持证据：
  - 你们已有很强的 `feedforward`：`AGENTS.md`、`rules/`、`skills/`、`contracts/small-chain.yaml`、`design.md / tasks.md / plan.md` 共同构成了渐进式披露和流程约束。
  - 你们已有很强的 `feedback`：`verification-before-completion`、`verify-change`、`qa`、`review`、`fix`、托管 hooks、completion gates 都在做交付前校验。
  - 你们已有初步的 orchestration：`subagent-driven-development`、`delivery-owner`、`phase3-dispatch` 等说明你们不是单 agent 单轮次流程。
- 最强反方挑战：
  - 你们并不缺流程，继续加更多规则、更多 skill，可能只会把维护成本抬高。
- 当前判定：部分成立。
- 结论稳健性：高。
- 失效边界：如果仓库外其实已经有成熟的 trace、runtime observability、benchmark 数据集和自动化反馈闭环，那“还没做重”这个判断需要下调。

### 论点四：你们不需要“为了概念而上 Harness Engineering”，但值得把它当作审视现有流程的 lens
- 最强支持证据：
  - 你们当前流程已经有明显的 harness 骨架，继续收益最大的不是重造框架，而是补齐缺口。
  - Martin Fowler 的划分很适合你们：`maintainability harness` 你们已经强，`architecture fitness harness` 部分具备，`behaviour harness` 和 `trace-driven steering loop` 仍有提升空间。
- 最强反方挑战：
  - 如果团队现在最缺的是需求稳定性、测试基线或工程纪律，谈 harness 可能过早。
- 当前判定：成立，但应轻量采纳。
- 结论稳健性：高。
- 失效边界：如果近期组织目标不是提升 agent autonomy，而只是稳定手工开发流程，则优先级应下调。

## 你们当前流程与 Harness Engineering 的差异
| 维度 | 你们当前更像什么 | Harness Engineering 强调补什么 |
|------|------------------|-------------------------------|
| 规则输入 | `AGENTS + rules + skills + docs` 的前置约束很强 | 保持，但继续做“地图化”和最小上下文，而不是越写越厚 |
| 流程编排 | `small-chain + subagent-driven-development + phase dispatch` 很明确 | 补“为什么 agent 在运行中失败”的 trace 视角，而不只看阶段产物是否齐全 |
| 验证方式 | 以 fresh proving command、review、qa、verify-change 为主 | 再增加 traces、datasets、graders、benchmark/eval runs 的持续改进飞轮 |
| 运行时可观测性 | 仓库内已能验证静态产物和流程状态 | 补 agent 可直接消费的 UI/log/metric/trace/runtime context |
| 漂移治理 | 已有 hooks、rules、scan、completion gate | 增加常态化“垃圾回收/ janitor”机制，持续处理 AI 生成漂移 |
| 最终目标 | 强治理、强验收、强文档追溯 | 在保持治理的同时，提高 agent 的自治度和单位人工注意力产出 |

## 吸收建议

### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 用 `guides + sensors` 视角盘点现有流程 | 你们已经有 rules / skills / hooks / verify | 把现有能力按 `feedforward / feedback / steering loop` 重画一遍，找重复和缺口 |
| 把“验证前禁止宣称完成”当作 harness 核心原则 | 你们已经有对应 skill | 继续保持，并把失败样本回流为新规则/新检查 |
| 用渐进式披露替代超长总说明 | 你们已有 `AGENTS + docs + skills` | 控制入口文档长度，优先索引化、地图化 |

### 改写后吸收
| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| “先把所有 skill / MCP / hooks 都配上” | 先围绕高频失败模式补最小 harness | 组件堆叠不等于效果，容易造成维护债 |
| “Harness 就是更强的 prompt engineering” | 把 prompt 放回系统设计的一层 | 便于团队理解投资对象不是单一提示词 |
| “有测试和 review 就算 harness 完成了” | 把 traces、runtime signals、drift cleanup 也纳入 | 只看结果不过问过程，改进会变慢 |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 现在就新建一套宏大的 harness 平台 | 你们已有大量可复用流程资产，先补薄弱环节更划算 |
| 为了“agent 自主”而弱化人工裁决 | 你们当前流程的价值正在于关键裁决点清晰，应该保留 |
| 把 Harness Engineering 理解成某个单独产品或框架采购项 | 它本质上更像方法论和工程体系，不是单个工具能替代 |

## 落地行动项
- [P0] 做一次现状映射：把现有 `rules / skills / hooks / tests / review / qa / verify-change` 归类到 `feedforward / feedback / steering loop`。
- [P0] 增加高信号 trace 视角：至少让关键 agent 任务保留可复盘的执行轨迹、失败点和验证证据，而不是只保留最终报告。
- [P0] 为 1 到 2 类高频任务建立最小 eval 集：输入样本、期望输出、失败标准、回归门槛。
- [P1] 给 agent 增加更可消费的运行时上下文：例如启动方式、目录地图、关键脚本探针、错误日志入口、浏览器/页面证据。
- [P1] 建立“失败样本 → 新 rule / 新 hook / 新 skill / 新 grader”的固定回流机制。
- [P2] 试点“垃圾回收 / janitor”任务，定期找文档漂移、过时规则、重复技能和失效检查。

## 结论
- 你听到的 `Harness Engineering`，本质上是在说：随着 AI agent 越来越能干，工程团队最值钱的工作会从“亲自写每一行代码”转向“设计 agent 的工作环境、约束系统和反馈闭环”。
- 对你们来说，这不是从零到一的新范式切换，而更像是一次框架升级：
  - 你们已经有很强的流程型 harness
  - 现在更值得补的是 `trace/eval/runtime observability/drift cleanup`
- 所以我的建议不是“全面上 Harness Engineering”，而是“把它当成诊断你们现有 AI 流程的框架”，按最小闭环逐步增强。

## 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| 这个概念会不会只是新瓶装旧酒 | 确实和 context engineering、eval engineering 有重叠 | 接受。报告中明确把它定位为 umbrella term，而非边界严丝合缝的标准概念 | 是 |
| 你们是不是已经做得够多了，不需要再谈 harness | 现有流程已很强，继续上复杂度可能适得其反 | 接受。结论改为“轻量采纳，用它做流程诊断 lens”，而不是“全面新建体系” | 是 |
| 是否高估了 trace / eval 的必要性 | 部分团队靠强 review + 强测试也能跑起来 | 部分接受。把它们降级为“下一阶段最值得补”的能力，而不是“现在不做就不行” | 是 |
| 是否低估了行为验证难度 | 功能正确性仍然最难，不能因为 maintainability harness 强就误判整体稳定 | 接受。报告明确指出 behaviour harness 仍是难点，不能只靠 agent 自测 | 是 |

## 检索路径与覆盖证明
- 名称归一化：
  - `Harness Engineering`
  - `harness engineering`
  - 用户原始词条中的 `Harness Enginering`
  - `agent harness`
  - `evaluation harness`
  - `context engineering`
- 已查对象类型：
  - 官方工程文章
  - 官方开发文档
  - 社区技术博客
  - 项目本地流程合同 / skills / hooks
- 已查 discovery 入口：
  - OpenAI 官网工程文章与开发文档
  - LangChain 官方博客
  - Martin Fowler / Thoughtworks 文章
  - 本仓库 `README.md`、`contracts/`、`shared/hooks/`、`community/superpowers/skills/`
- 已排除候选：
  - 线束工程（传统工业领域 `harness engineering`）与本次 AI 语境无关
  - SaaS 厂商 `Harness` 品牌相关页面，与本次术语讨论无关
  - 纯 `evaluation harness` 属于更窄子集，不能代表完整概念
- 剩余盲区：
  - 尚未纳入更多一线团队的私有内部实践
  - 还没有拿你们真实执行日志去量化“最常见失败模式”
  - 术语边界未来数月内仍可能继续演化

## 项目上下文
- 技术栈：
  - 这是一个以 `skills / rules / reference / hooks / agents / contracts` 为核心的流程仓库，而不是普通业务应用仓库。
- 已有相关实现：
  - `README.md` 已定义 `small-chain` 为默认轻量链。
  - `contracts/small-chain.yaml` 明确了从 `using-superpowers` 到 `verify-change` 再到 `archive` 的完整工件链。
  - `community/superpowers/skills/subagent-driven-development/SKILL.md` 说明你们已在执行层引入 subagent orchestration。
  - `community/superpowers/skills/verification-before-completion/SKILL.md` 与 `verify-change/SKILL.md` 说明你们已经把强验证作为硬门槛。
  - `shared/hooks/registry.json` 与 `shared/hooks/managed/codex_stop_dispatch.py` 说明你们已把部分约束下沉到 runtime hooks / completion gates。
- 约束条件：
  - 当前工作区已有大量未提交改动，本次调研未触碰这些文件，只新增独立调研文档。
  - 现有体系偏强治理、强文档、强门禁，因此不适合再无差别叠加新流程。

## 证据索引
- [E1] OpenAI，`工程技术：在智能体优先的世界中利用 Codex`，2026-02-11  
  https://openai.com/zh-Hans-CN/index/harness-engineering/
- [E2] LangChain，`Improving Deep Agents with harness engineering`，2026-02-17  
  https://blog.langchain.com/improving-deep-agents-with-harness-engineering/
- [E3] OpenAI Docs，`Evaluate agent workflows`，当前在线文档  
  https://developers.openai.com/api/docs/guides/agent-evals
- [E4] OpenAI Docs，`Evaluation best practices`，当前在线文档  
  https://developers.openai.com/api/docs/guides/evaluation-best-practices
- [E5] Martin Fowler / Thoughtworks，`Context Engineering for Coding Agents`，2026-02-05  
  https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html
- [E6] Martin Fowler / Thoughtworks，`Harness engineering for coding agent users`，2026-04-02  
  https://martinfowler.com/articles/harness-engineering.html
- [E7] 本仓库 `README.md`
- [E8] 本仓库 `contracts/small-chain.yaml`
- [E9] 本仓库 `community/superpowers/skills/subagent-driven-development/SKILL.md`
- [E10] 本仓库 `community/superpowers/skills/verification-before-completion/SKILL.md`
- [E11] 本仓库 `community/superpowers/skills/verify-change/SKILL.md`
- [E12] 本仓库 `shared/hooks/registry.json`
- [E13] 本仓库 `shared/hooks/managed/codex_stop_dispatch.py`
