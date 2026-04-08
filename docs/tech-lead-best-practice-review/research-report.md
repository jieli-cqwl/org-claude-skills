# tech-lead 角色定义最佳实践调研报告

## 一页判断
- 当前结论：条件推荐
- 是否符合当前目标：高
- 一句话判断：把 `tech-lead` 定义为“评审设计，并将其拆成可执行、可并行、可验证的实施计划”不是通用最佳实践，但对当前仓库这种“上游设计工件明确、下游 agent/LLM 需要字面可执行计划”的工作流是高价值做法，前提是限制其中心化程度并保留反馈回路。
- 最大收益：把 `design -> execution` 的信息损失降到最低，形成可追踪、可验证、可回滚的交接包。
- 最大风险：把“技术协调与约束整合”滑向“单点中心化总规划”，制造计划幻觉、角色瓶颈和团队自治下降。
- 不适用场景：探索性强、需求高频变化、小改动低风险、实施者已具备完整上下文且团队高度自治的场景。
- 结论翻转条件：如果当前仓库不再以下游 agent/LLM 按字面执行计划为重要约束，或者实证显示重流程造成的摩擦显著高于返工损失，则该定义应进一步轻量化。

## 关键论点挑战表
| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| 设计应先经评审，再进入实施拆分 | SEI ATAM 强调通过多方 stakeholder 参与、业务驱动和 scenario 分析，尽早识别架构风险并改进文档与决策依据 | 评审如果变成单人拍板或重文档轻反馈，会沦为形式主义 | 成立 | 高 |
| 实施计划应可执行、可追踪、可验证 | NASA 要求设计到代码双向追踪；NASA Technical Planning 强调 WBS、依赖、验证计划、living plan | 过度字段化和过度计划化会吞掉讨论空间，并不总比团队直接协作更优 | 条件成立 | 高 |
| `tech-lead` 适合承担设计评审 + 计划翻译职责 | 当前仓库下游是 `project-manager`/`developer`/LLM，`tech-lead` 作为“证据化交接层”能显著降低歧义 | Scrum/Agile 强调 self-managing teams；若 `tech-lead` 变成总规划者，会压制自治并制造单点瓶颈 | 条件成立 | 中高 |
| “可并行”应作为默认优化目标 | 对跨模块、跨前后端、多依赖任务，显式依赖和并行边界能提升吞吐和降低冲突 | challenger 指出复杂系统中的“并行”常是幻觉，错误边界只会放大返工和同步损耗 | 部分成立 | 中 |
| 完整计划越细越好 | 细计划对 agent/LLM 执行尤其友好 | Agile + DORA + planning fallacy 都提示：未知很多时，过细计划会伪装不确定性、抑制学习与反馈 | 不成立 | 高 |

## 优缺点速览
| 对象/论点 | 核心优势 | 核心短板 | 适用场景 | 不适用场景 |
|-----------|---------|---------|---------|-----------|
| 设计评审前置 | 风险前移，减少错误设计被放大 | 若缺少多方参与，可能变成权威背书 | 中大型、跨模块、高风险改动 | 快速探索、一次性小改动 |
| 可执行计划拆分 | 降低交接歧义，适合下游按字面执行 | 容易过度模板化、过度承诺 | 多角色协作、agent 化执行 | 实施者已具备全上下文的高自治团队 |
| 强追踪与验证门禁 | 方便验收、回滚、审计和复盘 | 维护成本高，局部小任务收益不足 | 需要高可靠、高可验证性的项目 | 低风险、短链路任务 |
| `tech-lead` 集中承担计划翻译 | 提供清晰 owner 和统一技术口径 | 易演化为单点瓶颈和角色越界 | 角色边界清晰、设计已收口的工作流 | 需求未收敛、需要团队共创学习的环境 |

## 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| 计划是否被过度神化 | 精益/敏捷视角认为“可执行、可并行、可验证”优化的是执行效率，不是发现正确性，可能把未知切碎而不是解决未知 | 采纳。最终结论从“推荐”下调为“条件推荐”，并明确对高不确定性工作应使用分段承诺、探索任务和停止条件 | 是 |
| 中心化角色是否伤害复杂系统流动 | DevOps/复杂系统视角认为中心化规划会忽视运行反馈、制造知识瓶颈和假并行 | 采纳。最终建议把 `tech-lead` 改写为“证据化交接与约束整合者”，而不是“总计划师” | 是 |
| 角色是否与 PM/开发者职责冲突 | 组织设计视角认为若边界不清，`tech-lead` 会吞掉 `project-manager` 的节奏管理和 `developers` 的任务内自治 | 采纳。报告中给出职责边界改写建议 | 是 |

## 采纳速览
- 现在该做什么：改写后采纳
- 采纳前必须补的验证：在 2 到 3 个真实任务上对比“完整 tech-lead 流程”和“轻量模式”带来的返工率、等待时间、计划变更次数
- 最匹配的点：当前仓库明确把 `tech-lead` 放在 `design -> test-design -> tech-lead -> project-manager` 链路中，并假设下游会按计划字面执行
- 最不匹配的点：当前定义对“高不确定性任务如何降级”和“哪些情况不该进入厚流程”约束不够显式

## 调研背景
- 调研触发：用户质疑 `tech-lead` 当前定义是否属于最佳实践，希望结合软件工程、项目管理等视角做系统分析，并要求并行研究和反方挑战
- 决策目标：判断当前 `tech-lead` 定义该保留、改写还是降级，并明确适用边界
- 关键约束：不迷信权威；必须有一手证据、本地仓库扫描、最强反方挑战和失效条件；调研对象是角色定义本身，而不是某个 feature 的实施计划

## 检索路径与覆盖证明
- 名称归一化：`tech-lead` / `tech lead` / `technical lead` / `implementation planning` / `design review` / `task decomposition` / `traceability` / `self-managing teams`
- 已查对象类型：仓库内 skill/agent/contract；官方/一手方法论文档；项目管理与敏捷/DevOps 官方资料
- 已查 discovery 入口：本地仓库 `shared/`、`contracts/`、`README.md`；SEI、NASA、Scrum Guides、Agile Manifesto、DORA、PMI
- 已排除候选：纯二手经验帖、只讲职位 title 不讲职责边界的招聘文案、无一手出处的“最佳实践清单”
- 剩余盲区：缺少当前仓库真实历史数据来量化“厚流程 vs 轻流程”的收益差；暂未纳入更多实证团队案例

## 项目上下文
- 技术栈：本仓库是 `skills / reference / contracts / agents` 体系，核心目标是统一 Claude Code 与 Codex CLI 运行时行为，[README.md](/Users/lijieli/org-claude-skills/README.md)
- 已有相关实现：`tech-lead` 被定义为流程链中的评审与计划节点，[shared/skills/tech-lead/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md)；其输入输出契约见 [contracts/skill-chain.yaml](/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml)
- 约束条件：当前 `tech-lead` 明确假设下游 LLM 会按字面执行计划，因此强调 traceability、依赖、验收、独立审查与用户确认；这是比普通人类团队更强的结构化约束

## 拆解对象概览
- 对象类型：项目方法 / 角色定义
- 原始观点：`tech-lead` 定义的是“你是技术负责人。负责评审设计，并将其拆成可执行、可并行、可验证的实施计划。”
- 需要回答的问题：这一定义是否属于最佳实践；哪些部分应保留；哪些部分需要降级、加边界或改写

## 核心论点拆解

### 论点 1：设计评审前置，是强最佳实践
结论：成立。

支持证据：
- SEI 的 ATAM 将架构评估定义为一项系统化活动，通常需要评估团队、架构师和多类 stakeholder 参与，收益包括澄清质量属性需求、改进架构文档、记录架构决策依据、尽早识别风险、增强 stakeholder 沟通。
- SEI 的 ARID 指出，对尚未完全细化的 intermediate design 进行主动评审，可以在设计被“制度化”为细规格之前，尽早暴露问题并吸收用户社区反馈。

反方挑战：
- “评审”本身不是目标。若评审退化为单点权威把关，只会把偏差更早固化。

判定：
- 保留“先评审，再拆计划”。
- 但评审应被定义为多证据、多视角的质量门禁，而不是 `tech-lead` 的个人裁决。

### 论点 2：实施计划应可执行、可追踪、可验证
结论：成立，但属于条件性强实践。

支持证据：
- NASA 要求从软件设计到代码保持双向追踪，理由是这能确保设计元素被落实到代码，也能避免开发超出设计范围的功能。
- NASA Technical Planning 指出，WBS、schedule、budget、verification plan 之间是相互依赖的；技术计划是 living document，需要随着项目推进持续更新。
- 当前仓库的 `tech-lead` 定义把这种思想进一步细化成 `design_ref`、`scope_item_ref`、`api_ref`、`test_ref`、依赖和可验证 AC，明显是在做“面向 agent 的可执行合同”。

反方挑战：
- 这些字段对 agent/LLM 很友好，但并不是所有人类团队都需要；模板过重会带来维护成本。

判定：
- 对当前仓库成立，因为这里的主要矛盾是“如何把人类设计稳定传给下游 agent/LLM”。
- 对一般团队，只保留必要追踪和验证字段即可，不必默认上满。

### 论点 3：`tech-lead` 作为“设计评审 + 计划翻译层”合理
结论：条件成立。

支持证据：
- 当前仓库已经把 `tech-lead` 与 `design`、`test-design`、`project-manager` 拆开，说明其目标不是包办一切，而是做设计到执行之间的技术交接层。
- `tech-lead` 的硬门禁强调不改需求、不写实现，只做设计评审与计划制定；这是相对克制的角色边界。

反方挑战：
- Scrum Guide 强调 Developers 是自管理的，自己制定交付 Sprint Goal 所需的计划；Agile Manifesto 也强调最佳架构、需求和设计来自 self-organizing teams。
- 如果 `tech-lead` 连任务级“怎么做”都替团队决定，就会与 self-managing team 原则冲突。

判定：
- 应保留 `tech-lead` 作为“技术交接 owner”。
- 但要明确：`tech-lead` 负责计划质量与约束整合，不替代 `developers` 的任务内实现决策，不替代 `project-manager` 的节奏推进，不替代 `product` 的优先级判断。

### 论点 4：高不确定性工作不应被强行完整计划化
结论：成立。

支持证据：
- Agile 原则强调欢迎变化，即使在开发后期也如此；最佳架构、需求和设计来自自组织团队。
- DORA 研究长期强调小批量、稳健测试和实验式产品开发的重要性；2024 报告也指出，AI 或流程改进不是灵药，基本功仍然是 small batch sizes 和 robust testing。
- 挑战 agent 从精益/敏捷与复杂系统视角一致指出：在高不确定性场景里，把计划做得更细，往往是在伪装未知，而不是降低未知。

反方挑战：
- 若完全不计划，就会把依赖、验证和回滚风险推迟到实现与联调阶段，造成代价更高的返工。

判定：
- 不是不要计划，而是要把“完整静态计划”改成“分段承诺 + 持续更新 + 探索任务优先”。

## 论点挑战总表
| 论点 | 最强支持证据 | 最强反方挑战 | 当前判定 | 对我们的启示 |
|------|-------------|-------------|---------|-------------|
| 设计先评审再拆计划 | SEI ATAM / ARID | 单点评审会固化偏差 | 成立 | 保留 5-Gate 思想，但强调多视角证据 |
| 计划应可执行可验证可追踪 | NASA traceability + Technical Planning | 模板过重、局部任务收益不足 | 条件成立 | 对 agent 工作流高价值，对普通团队应分级 |
| `tech-lead` 应承担这项工作 | 当前仓库角色链清晰，且下游需要字面可执行计划 | self-managing teams 反对中心化总规划 | 条件成立 | 保留 role，但把定位改成“交接与约束整合层” |
| 可并行是默认优化目标 | 依赖显式化有助吞吐 | 错误并行会制造假接口和返工 | 部分成立 | 从“追求并行”改为“识别真并行、显式标注不可并行” |
| 计划越细越好 | 对 agent 执行友好 | planning fallacy、探索性工作不适配 | 不成立 | 引入轻量模式和探索模式 |

## 吸收建议

### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 先做设计评审再做实施拆分 | 设计已成文，存在跨模块风险 | 保留 `DESIGN_OK` 前不得进入计划拆分 |
| 强调 traceability、依赖、前置验证、回滚约束 | 下游需要按计划字面执行，或交付风险较高 | 保留 `coverage matrix`、`depends_on`、`api_ref`、可验证 AC |
| 独立审查和用户确认 | 计划会被多人或 agent 执行 | 保留 plan reviewer 和用户确认记录 |

### 改写后吸收
| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| `tech-lead` 负责评审设计，并将其拆成可执行、可并行、可验证的实施计划 | `tech-lead` 负责对已收口设计做独立评审，并在不改变设计目标的前提下，将其转换为带追踪链、前置验证、依赖关系、并行边界和回滚约束的实施包；对高不确定性工作采用分段承诺与持续更新，对低风险小改动采用轻量审查。 | 把“总计划师”降级为“证据化交接与约束整合者”，补上轻重分级和反馈回路 |
| 可并行 | 可识别真并行、显式标注不可并行 | 避免把并行当成默认 KPI |
| 完整计划化 | 标准模式 + 轻量模式 + 探索模式 | 避免厚流程吞掉价值 |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 把 `tech-lead` 视为普适最佳实践角色 | 缺乏跨上下文通用性，和高自治/高探索环境冲突 |
| 默认所有任务都走完整厚流程 | 对小改动、低风险任务收益不足 |
| 把计划看成静态承诺而不是临时协调假设 | 与复杂系统和探索性工作不匹配 |

## 落地行动项
- P0：改写 `tech-lead` 的角色定义，把“实施计划”改为“实施包/协调假设”，并显式加入“高不确定性分段承诺、低风险轻量模式”
- P0：在 `tech-lead` 或其引用方法论里补充“何时不适用完整流程”的触发条件
- P1：补一份角色边界说明，明确 `tech-lead`、`project-manager`、`developers`、`product`、`design` 的职责边界
- P1：把“并行策略”从默认目标改成条件判断，强调识别真并行和显式不可并行
- P1：在计划模板中加入“反馈点/再计划触发条件/停止条件”，避免静态计划幻觉
- P2：挑选 2 到 3 个真实任务做 A/B 对比，评估厚流程与轻流程的返工率、等待时间、变更次数

## 证据索引
1. 本地仓库 `[shared/skills/tech-lead/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md)`：当前 `tech-lead` 的硬门禁、角色边界、计划拆分要求
2. 本地仓库 `[shared/agents/tech-lead.md](/Users/lijieli/org-claude-skills/shared/agents/tech-lead.md)`：agent 合同说明 `tech-lead` 的输入输出角色
3. 本地仓库 `[contracts/skill-chain.yaml](/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml)`：`tech-lead` 在角色链中的位置与消费者
4. SEI ATAM factsheet，https://www.sei.cmu.edu/library/file_redirect/2011_015_001_28266.pdf/ ，访问日期 2026-04-08：支持“设计评审前置、风险早识别、stakeholder 沟通、文档与决策改进”
5. SEI ARID，https://www.sei.cmu.edu/library/active-reviews-for-intermediate-designs/ ，访问日期 2026-04-08：支持“对 intermediate design 进行主动评审，提前获得反馈”
6. NASA SWE-064，https://swehb.nasa.gov/spaces/SWEHBVB/pages/32604529/SWE-064+-+Bidirectional+Traceability+Between+Software+Design+and+Software+Code ，访问日期 2026-04-08：支持“设计到代码双向追踪”
7. NASA Technical Planning，https://www.nasa.gov/reference/6-1-technical-planning/ ，访问日期 2026-04-08：支持“WBS/计划/验证计划是 living process，需和项目经理及技术团队持续协调”
8. Scrum Guide 2020，https://scrumguides.org/docs/scrumguide/v2020/2020-Scrum-Guide-US.pdf ，访问日期 2026-04-08：支持“Developers self-managing，自己制定实现 Sprint Goal 所需的计划”
9. Agile Manifesto Principles，https://agilemanifesto.org/principles ，访问日期 2026-04-08：支持“欢迎变化、最佳架构/需求/设计来自 self-organizing teams”
10. DORA Research 2016，https://dora.dev/research/2016/ ，访问日期 2026-04-08：支持“小批量、实验式产品开发、把质量融入每个阶段”
11. Google Cloud Blog, 2024 DORA report，https://cloud.google.com/blog/products/devops-sre/announcing-the-2024-dora-report ，访问日期 2026-04-08：支持“small batch sizes + robust testing 仍是基本功”
12. Buehler, Griffin, Ross. The Planning Fallacy, 1994，https://web.mit.edu/curhan/www/docs/Articles/biases/67_J_Personality_and_Social_Psychology_366%2C_1994.pdf ，访问日期 2026-04-08：支持“过度乐观规划是稳定偏差”
