# skill-harness 标准流程 Harness 治理设计

## 背景

本设计冻结 `skill-harness` 的下一阶段方向：它不再只被定义为单个 Skill 的运行合同审计器，而是作为标准流程的 Harness 治理入口。用户在使用 `skill-harness` 审计某个 Skill 时，目标不是给该 Skill 做泛化评分，而是按照严格的 Harness 合同治理它在标准流程中的职责、主内容、状态流转、证据链、权限边界和工程化控制能力。

旧 `skill-audit` 的核心优势是信息全。它已经沉淀了触发、加载、决策、执行、验证、演化六段链路，也沉淀了 reference contract、runtime noise contract、permission/script contract、hook adapter contract、SubAgent handoff contract、schemas、field consumers、evals、examples、templates 和 renderer 等完整能力。

当前 `skill-harness` 的核心优势是经过一轮可执行清洗。它保留了 read-first、consumer-first、evidence-first、JSON 按消费者触发、retired name 去噪、Darwin 候选独立裁决等轻量运行边界。

本设计的目标是把两者合并为一套可执行的最佳实践：用旧 `skill-audit` 补全能力视野，用当前 `skill-harness` 控制默认路径重量，用标准流程场景验证治理能力。

## 定位

`skill-harness` 的一句话定位：

```text
skill-harness 是标准流程的 Harness 治理入口：它规定 LLM 在被治理 Skill 中负责什么，SKILL.md 如何承载这些职责，工程机制如何控制状态、证据、权限、验证和演化。
```

它治理的是被指定的 Skill，而不是让 LLM 成为标准流程治理者。LLM 是运行时语义执行单元；治理责任属于 `skill-harness` 定义的合同和工程机制。

使用方式接近 `darwin-skill`：用户指定一个目标 Skill，`skill-harness` 按治理合同审计该 Skill 是否符合标准流程最佳实践。

## 治理对象

`skill-harness` 的治理对象包含两类：

| 对象 | 治理重点 |
| --- | --- |
| 单个 Skill | LLM 职责边界、主内容结构、资源路由、权限、证据、验证、演化噪音 |
| 标准流程链路中的 Skill | 所属阶段、上游输入、下游输出、状态转移、hard gate、消费者、禁止越权行为 |

标准流程链路定义为：

```text
product-director
-> product-manager
-> design
-> tech-lead
-> test-design
-> delivery-owner
-> developer
-> verify / review / qa
-> sign-off / archive
```

`delivery-owner` 是关键校准样本，因为它最容易同时暴露三类问题：正确闭环变重、流程编排噪音、工程状态真源不稳。

## 三层治理模型

### 第一层：LLM 职责层

这一层回答：当某个 Skill 被 `skill-harness` 治理后，LLM 在该 Skill 中负责什么，禁止负责什么。

LLM 负责：

| 职责 | 含义 |
| --- | --- |
| 触发判断 | 判断用户请求是否匹配该 Skill，识别相邻 Skill 冲突 |
| 目标理解 | 理解用户目标、约束、完成边界和验收口径 |
| 语义裁决 | 判断当前情况属于哪个流程分支、风险类型或异常状态 |
| 流程编排 | 决定下一步读取哪个 reference、调用哪个 script、派发哪个 agent、触发哪个 gate |
| 证据解释 | 解释工程产物、验证输出和风险边界对用户的意义 |
| 风险升级 | 在越权、证据不足、状态不一致、验证失败时停止推进并升级 |
| 人类对齐 | 写入、删除、提交、签收、风险接受、外部副作用前请求用户确认 |

LLM 禁止负责：

| 禁止项 | 原因 |
| --- | --- |
| 状态真源 | 状态需要由 artifact、validator、hook 或脚本维护 |
| 状态授权 | 状态变化需要工程门禁或用户确认授权 |
| 自证完成 | 完成需要 fresh proving command、真实证据或用户确认支撑 |
| 代替用户签收 | 业务风险接受只属于用户 |
| 绕过工程门禁 | 失败后只能诊断和修复，不能静默降级继续 |
| 把 Markdown 当机器事实源 | 机器消费者需要读取结构化 artifact |
| 凭记忆承接跨轮状态 | 跨轮状态需要落到可读事实源 |

### 第二层：Skill 主内容层

这一层回答：为了让 LLM 正确履行职责，`SKILL.md` 主内容需要放什么，哪些内容属于运行时噪音。

`SKILL.md` 的定义：

```text
SKILL.md 是 LLM 的运行时入口和路由器，不是知识库、历史档案、schema 手册或全量流程百科。
```

主内容保留：

| 内容 | 用途 |
| --- | --- |
| frontmatter | 描述触发、权限、自动/手动调用属性 |
| 一句话定位 | 让 LLM 识别角色和相邻边界 |
| HARD-GATE | 放置最高优先级运行规则 |
| LLM 职责边界 | 明确可做、禁止做、需要升级的行为 |
| 默认流程 | 描述高频路径和关键分支 |
| reference 路由 | 指向低频方法、示例、模板、规则和工程合同 |
| 输出合同 | 规定人类输出或机器 artifact 的最低字段 |
| 停止条件 | 定义何时阻断、等待用户、触发 replan 或退出 |
| 完成校验 | 声称完成前需要的证据类型和验证命令 |

主内容去噪规则：

| 噪音类型 | 去向 |
| --- | --- |
| 历史迁移说明、旧版本对比、退役入口解释 | `docs/archive/` 或迁移报告 |
| 长篇方法论、调研材料、agent team review 过程 | `references/` 或研究文档 |
| schema 全字段说明、validator 实现细节 | `schemas/`、`scripts/` 或 runtime blueprint |
| 完整 examples/evals 数据集 | `examples/`、`evals/` |
| 无消费者目录说明 | 删除或保留在 archive |
| 过期 alias、兼容入口、旧命令名 | 删除；仅保留负例 fixture |
| 低频异常路径长说明 | 按触发条件路由到 reference |

主内容顺序需要保护 LLM 加载路径：

```text
frontmatter -> 定位 -> HARD-GATE -> 职责边界 -> 默认流程 -> 分支路由 -> 输出合同 -> 完成校验 -> references
```

### 第三层：工程化控制层

这一层回答：哪些事情不能依赖 LLM，需要由工程机制控制。

工程机制负责：

| 能力 | 责任 |
| --- | --- |
| JSON fact source | 只有机器消费者、跨轮状态、hook、validator、runner、Darwin gate、发布验证需要时启用 |
| schema validation | 校验结构、类型、枚举和必填字段 |
| semantic validation | 校验证据、状态、流转、消费者、权限和失败语义 |
| field consumers | 每个 runtime 字段需要声明消费者、用途、验证方式和删除条件 |
| scripts manifest | 命令需要声明 path、allowed args、denied args、timeout、输出根、失败语义和验证命令 |
| examples | 校准 LLM 对正例、反例、边界例的判断 |
| evals | 固化触发、非触发、权限、handoff、噪音、链路集成和失败路径样例 |
| templates | 承载稳定人类视图，不反向定义事实 |
| renderer | 从 JSON 派生 Markdown/HTML，并记录 provenance |
| hook adapter | 消费已验证 artifact，阻断非法状态流转 |
| SubAgent handoff | 约束 fork 输入、输出、证据、不确定点、消费者和下一步 |
| runtime noise checks | 识别无消费者、退役、迁移、临时和历史内容 |

核心原则：

```text
LLM can propose; engineering must authorize.
```

这条原则只作用于状态、证据、权限、验证和副作用，不把 LLM 误设为标准流程治理者。

## 目录能力模型

目录存在的前提是有消费者、验证路径和失败边界。目录本身不是质量证明。

| 目录 | 职责 | 创建条件 |
| --- | --- | --- |
| `references/` | 方法细节、审计合同、低频流程、handoff、runtime noise、hook adapter | 被 `SKILL.md` 契约式路由 |
| `schemas/` | runtime artifact schema、state vocabulary、field consumers | 存在机器事实源消费者 |
| `scripts/` | 确定性校验、validator、renderer、artifact builder | 有 manifest、测试、timeout 和输出边界 |
| `examples/` | 正例、反例、边界例、校准样本 | 被 eval、人类审计或 reference 消费 |
| `evals/` | seed dataset、触发/非触发、权限、handoff、链路失败样例 | 有可复跑命令和结果校验 |
| `templates/` | Markdown/HTML 或结构化报告模板 | 被 renderer 消费，且只是派生视图 |
| `agents/` | 平台暴露、SubAgent 角色边界 | 被运行时入口消费 |
| `rules/` | skill-local 权限或行为规则 | 与全局 rules 不同且有消费者 |
| `hooks/` | 局部 hook adapter 入口 | validator 稳定且接入范围被用户确认 |

## 旧 skill-audit 资产归位

| 旧资产 | 新治理位置 | 裁决 |
| --- | --- | --- |
| 六段链路：触发、加载、决策、执行、验证、演化 | LLM 职责层与主内容层的审计主轴 | 保留 |
| `runtime-noise-contract` | 主内容去噪核心规则 | 升级为核心能力 |
| `reference-contract` | 资源路由与同步义务 | 保留 |
| `permission-script-contract` | 工程化控制层的权限与脚本规则 | 保留 |
| `hook-adapter-contract` | 状态阻断和 lifecycle 控制 | 按消费者触发 |
| `subagent-handoff-contract` | LLM 编排边界和 agent 交接合同 | 保留 |
| `field-consumers.json` | JSON 准入和字段消费者校验 | 保留并泛化 |
| schemas | 机器事实源合同 | 按消费者触发 |
| evals | 边界样例和回归验证 | 保留，不冒充真实质量收益 |
| examples | LLM 判断校准 | 保留 |
| templates / renderer | 派生视图 | 保留但不能做事实源 |
| `optimization-plan.json` | 接受 findings 后的实施阶段 artifact | 不进入默认审计路径 |
| `verification-result.json` | 发布或机器复验阶段 artifact | 按验证消费者触发 |

旧 `skill-auditor` 名称不恢复为 active runtime。它只作为 archive、fixture、历史证据和迁移审计输入。

## 标准流程集成合同

当 `skill-harness` 审计标准流程中的某个 Skill 时，需要按以下合同判断该 Skill 是否正确嵌入链路：

| 字段 | 含义 |
| --- | --- |
| `role` | 该 Skill 在标准流程中的职责 |
| `input` | 必须读取的上游真源 |
| `output` | 必须产出的下游工件 |
| `state_transition` | 允许推动的状态变化 |
| `hard_gate` | 不得绕过的门禁 |
| `evidence` | 结论可复验的证据 |
| `consumer` | 谁消费该 Skill 的输出 |
| `forbidden` | 该 Skill 禁止承担的职责 |

示例裁决：

| Skill | 正确职责 | 禁止越权 |
| --- | --- | --- |
| `product-director` | 冻结根问题、目标、范围和 Phase 边界 | 替代执行期交付、签收或 QA |
| `tech-lead` | 冻结 plan、scope、task、gate matrix | 替代 developer 实现或 delivery-owner 调度 |
| `delivery-owner` | 执行期编排、偏差治理、动态 gate 升级、目标级收口 | 反向定义需求、发明技术方案、替代 QA、单方接受业务风险 |
| `qa` | 独立质量判断、release recommendation、residual risk | 替代用户签收 |

## 审计输出模型

默认输出为结构化 Markdown。字段为：

```text
overall_verdict
finding_severity
dimension
file:line
evidence
impact
recommendation
proof_command
```

JSON 只在存在机器消费者时启用。启用前需要记录：

```text
consumer
read_purpose
validation_command
drop_condition
```

JSON 启用后成为唯一机器事实源。Markdown/HTML 只能从 JSON 派生，不能反向定义事实。

## 审计维度

`skill-harness` 的审计维度采用运行链路加三层治理模型组合：

| 维度 | 审计问题 |
| --- | --- |
| Trigger | 触发、非触发、相邻 Skill 冲突是否清楚 |
| Loading | 主内容是否干净，低频知识是否按需路由 |
| Decision | LLM 分支判断是否有规则、证据和停止条件 |
| Execution | 权限、脚本、agent handoff 和副作用边界是否受控 |
| Verification | fresh proof、schema、semantic、eval、消费者校验是否支撑结论 |
| Evolution | 迁移、retired name、runtime noise、Darwin 候选和回退边界是否清楚 |
| Chain Integration | 该 Skill 是否正确嵌入标准流程 |
| Engineering Control | 状态、证据、权限和验证是否交给工程机制 |

## 非目标

`skill-harness` 不做以下事情：

- 不恢复 `skill-auditor` 为 active Skill 名称。
- 不把所有审计默认 JSON 化。
- 不把 schema、validator、renderer、hook adapter 全部放进默认路径。
- 不把 LLM 定位为标准流程治理者。
- 不替代 `delivery-owner` 推进交付。
- 不替代 `darwin-skill` 生成候选。
- 不替代 `skill-creator` 创建新 Skill。
- 不把 Markdown 与 JSON 并列为机器事实源。
- 不用目录数量证明 Skill 质量。

## 成功标准

本设计达成后，`skill-harness` 的最佳实践需要满足：

| 标准 | 达成口径 |
| --- | --- |
| LLM 职责清楚 | 每个被治理 Skill 能说清 LLM 可做、禁止做、需要升级的行为 |
| 主内容可执行 | `SKILL.md` 只承载运行时高频规则和路由，低频内容按需加载 |
| 噪音可识别 | 历史、迁移、旧名、无消费者字段和低频长说明能被分类处理 |
| 工程控制接住状态 | 状态、证据、权限、验证和副作用不依赖 LLM 记忆或自证 |
| 复杂度有消费者 | 每个 JSON、schema、script、eval、example、template、hook 都能说明消费者和失败边界 |
| 标准链路可审计 | 从 `product-director` 到 `delivery-owner` 再到 `sign-off` 的角色、输入、输出、状态和证据能被审计 |
| 旧资产被归位 | 旧 `skill-audit` 的完整能力被吸收为触发式能力，不回到默认重量 |
| 当前轻量边界保留 | 默认审计仍是 read-first、structured Markdown、evidence-first、consumer-first |

## 风险与裁决

| 风险 | 裁决 |
| --- | --- |
| 旧资产全量恢复导致 `skill-harness` 变重 | 按消费者触发，默认路径只保留最小审计合同 |
| 只做轻量审计导致标准流程治理能力不足 | 新增 Chain Integration、Main Content Noise、Directory Capability 三类审计 |
| LLM 职责被误解成 LLM 治理标准流程 | 明确 LLM 只是语义执行单元，治理权属于合同和工程机制 |
| JSON 重新变成仪式化产物 | JSON 由机器消费者触发，不由审计存在触发 |
| `delivery-owner` 被当成全能 owner | 标准流程集成合同明确 role/input/output/forbidden |
| examples/evals 被误当成真实质量收益 | eval 证明边界样例稳定，质量收益需要真实案例和 fresh proof 支撑 |

## 实施范围边界

本设计允许进入实施计划的能力范围限定为：

| 能力 | 设计边界 |
| --- | --- |
| LLM responsibility contract | 定义 LLM 在被治理 Skill 中的职责、禁区、升级条件和人类确认点 |
| main-content-noise audit | 审计 `SKILL.md` 主内容是否只承载高频运行规则和路由 |
| directory-capability audit | 审计目录是否有消费者、验证路径和失败边界 |
| standard-chain integration audit | 审计目标 Skill 是否正确嵌入标准流程 |
| field-consumer gate | 阻断无消费者 runtime 字段进入机器事实源 |
| retained `skill-audit` asset mapping | 将旧资产按职责归入新治理模型，不恢复旧运行入口 |

任务拆分、执行顺序、文件范围和验证命令由 `tasks.md` 与 `plan.md` 承担，不写入本设计文档。
