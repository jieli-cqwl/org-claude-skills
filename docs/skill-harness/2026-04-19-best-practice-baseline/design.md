# skill-harness 最佳实践基线设计

## Problem Statement

现有 `skill-auditor` 已经引入 Harness Engineering 思路，但设计与实现边界偏重。它把审计、JSON 事实源、schema、validator、renderer、hook adapter 和迁移闭环放在同一个默认目标里，容易让 Skill 审计从“判断 Skill 是否正确”滑向“建立一套新平台”。

本设计冻结 `skill-harness` 的目标基线：它不是对 `skill-auditor` 的小修，也不是对 standard-chain 的复刻。它负责定义 Skill 的运行时合同、证据边界、验证方式和演化护栏，让 LLM 做语义判断，让工程机制承担状态、门禁和可复验事实。

参考证据来自三类来源：

| 来源 | 用途 |
| --- | --- |
| `shared/skills/skill-auditor/` | 当前 Harness 方向、权限、runtime noise、reference contract 和 manifest 现状 |
| `docs/skill-auditor/2026-04-16-course-derived-methodology/` | 历史设计、review 结论、runtime-blueprint 和过重风险 |
| `docs/archive/standard-chain-contract-foundation/2026-04-14-contract-foundation/` | standard-chain JSON 合同的历史证据，作为原则来源，不作为 `skill-harness` 默认运行时规范 |

## Positioning

`skill-harness` 的一句话定位：

```text
Skill 工程保障层：LLM 负责语义判断与编排意图，工程负责状态、门禁、证据、验证与可复验事实源。
```

它的职责是判断一个 Skill 是否具备正确的运行时合同：

- 触发边界清楚。
- 权限与写入范围可控。
- 证据能复验。
- 验证命令真实存在且能证明成功标准。
- 引用、脚本、JSON 字段和 runtime 规则有真实消费者。
- Darwin 或人工改造不会破坏内容顺序、权限边界和证据链。

它不替代 Darwin。Darwin 负责生成、优化和比较候选；`skill-harness` 负责裁决候选是否越界。

它不替代 delivery-owner。delivery-owner 面向交付闭环；`skill-harness` 面向 Skill 自身的工程合同。

它不替代 `skill-creator`。`skill-creator` 面向新 Skill 创建与评估；`skill-harness` 面向已有 Skill 或候选 Skill 的运行时保障。

## Goals And Success Criteria

`skill-harness` 的目标是建立一套“正确优先、最小充分、工程可验”的 Skill 保障基线。

成功标准如下：

| 标准 | 达成口径 |
| --- | --- |
| 语义与工程分工清楚 | LLM 只提出判断和转移动议；工程机制授权状态转移、写入、验证和阻断 |
| 复杂度有消费者 | 每个 JSON 字段、目录、脚本、reference、hook adapter 都能说明消费者、失败停止点和证据 |
| 默认路径轻量 | 普通审计输出结构化 Markdown，不落盘 JSON，不声明机器事实源 |
| JSON 触发清楚 | 只有机器消费者、跨轮状态、自动门禁、Darwin gate、发布验证或派生报告出现时，才升级 JSON fact source |
| 过重样本可识别 | `delivery-owner` 这类闭环正确但 LLM 状态负担过高的 Skill，被稳定判为 `Correctness PASS / Practice FAIL` |
| 漂移样本可阻断 | Darwin 尾部追加运行时规则、manifest 指向不存在命令、旧入口 runtime alias、无证据 FAIL 被稳定阻断 |
| standard-chain 经验被吸收 | 吸收 truth/control/display 分离、consumer-first、evidence refs 和 fail-closed 原则，不复制完整 canonical 交付链 |

## Non-goals

`skill-harness` 不做以下事情：

- 不作为泛化 Skill 评分器，不负责文风润色、表达优化或抽象质量打分。
- 不默认生成 `skill-audit.json`、`optimization-plan.json`、`verification-result.json` 三件套。
- 不默认引入 `artifact-registry.json`、`delivery-state.json`、`signoff-package.json`、`user-decision.json`。
- 不默认生成 HTML projection，不把 projection manifest 放进轻量审计路径。
- 不保留 `skill-auditor` 作为运行时兼容入口。旧名称只进入 archive、fixtures 或迁移说明。
- 不把 Markdown 与 JSON 同时作为事实源。
- 不让 LLM 手填状态、代签授权、跳过工程门禁。

## Core Principle

核心原则是：

```text
LLM can propose transitions; engineering must authorize transitions.
```

这条原则拆成三层：

| 层 | 归属 | 含义 |
| --- | --- | --- |
| 语义层 | LLM | 理解用户目标、识别风险、解释影响、提出下一步 |
| 合同层 | Skill 文档与 reference | 定义边界、权限、触发、证据、输出和非目标 |
| 门禁层 | 工程机制 | 校验证据、命令、字段消费者、内容顺序、runtime noise 和状态转移 |

复杂度裁决采用 Essential vs Accidental Complexity：

- 正确性、安全、授权、证据链属于 Essential Complexity，不因简化而删除。
- 无消费者字段、默认 JSON 三件套、全量状态机、双事实源属于 Accidental Complexity，默认不进入。
- 当真实机器消费者出现时，JSON、schema、validator 和 projection provenance 才成为 Essential Complexity。

## LLM Responsibilities

LLM 控制“理解与编排意图”，不控制状态事实。

| 能力 | 输出 |
| --- | --- |
| 触发判断 | 判断当前请求是否属于 Skill 审计、Harness 裁决、Darwin 候选验收或迁移对齐 |
| 范围裁决 | 界定目标 Skill、目标文件、非目标和本轮审计深度 |
| 语义审计 | 判断触发、加载、决策、执行、验证、演化链路中的缺口 |
| 风险识别 | 标注权限放宽、无证据 FAIL、状态自填、JSON 仪式化、旧入口噪音 |
| 用户对齐 | 在写入、迁移、发布、风险接受前要求用户明确确认 |
| 编排建议 | 提出下一步是只读审计、候选验收、文档收口、实现计划还是停止 |
| 结果解释 | 用人能理解的方式说明 verdict、影响、证据和修复边界 |

LLM 不持有这些权力：

- 不授权写入。
- 不证明命令存在。
- 不把 Markdown 声明为机器事实源。
- 不接受缺证据 FAIL。
- 不让 Darwin 候选自证通过。
- 不代替 hook、validator、manifest checker 或 fresh proving command。

## Engineering Responsibilities

工程机制控制“事实、门禁和阻断”。

默认工程能力包括：

| 能力 | 裁决对象 |
| --- | --- |
| 权限边界 | `allowed-tools`、写范围、危险动作、commit/push/delete 等动作授权 |
| 证据合同 | FAIL 是否有 `file:line`、证据、影响、验证方式 |
| fresh command | 声称通过前，命令是否真实运行并支撑成功标准 |
| manifest command-id | 脚本是否在 manifest 中声明、参数是否受控、命令目标是否存在 |
| runtime noise | 旧名、迁移残留、无消费者 compatibility alias 是否进入运行时 |
| 内容顺序 | HARD-GATE、权限、执行、输出、验证、reference 是否归位 |
| reference contract | 引用是否说明触发条件、读取对象、预期内容、消费者和证据 |
| JSON upgrade gate | 是否存在机器消费者；JSON 字段是否有消费者和失败停止点 |

触发式工程能力包括：

| 触发条件 | 启用能力 |
| --- | --- |
| hook、validator、runner 消费 | JSON fact source、schema validation、semantic validation |
| Darwin 候选验收 | candidate package、内容顺序检查、runtime noise 检查、权限差异检查 |
| 跨 Agent handoff | 输入输出合同、scope、evidence、uncertainty、decision_required |
| 跨轮状态或发布验证 | verification package、fresh command 绑定、结果可追溯 |
| 派生报告 | projection package，报告只从 JSON 派生，不能反向定义事实 |

## JSON Fact Source Rule

本设计采用：

```text
canonical when consumed, not JSON everywhere.
```

中文规则是：

```text
JSON 由消费触发，不由审计存在触发。
```

默认审计路径只输出结构化 Markdown：

```text
verdict
severity
file:line
evidence
impact
recommendation
proof_command
```

当出现以下任一条件，审计结果升级为 JSON fact source：

| 触发 | 原因 |
| --- | --- |
| hook / validator / runner 需要读取 | 机器消费不能依赖自然语言 |
| Darwin 候选需要验收 | 候选比较、风险、差异和证据需稳定结构 |
| SubAgent handoff | 跨代理转述会漂移，需要固定输入输出 |
| 跨轮状态 | 状态不能由 LLM 记忆维护 |
| 自动阻断门禁 | fail-closed 需要机器可读事实 |
| 发布或最佳实践声明 | 需要 benchmark、fresh command 和复验记录 |
| 派生 Markdown/HTML 报告 | 展示层需追溯到事实源 |

升级后只定义小型 fact package，不复制 standard-chain 全套 artifacts。

| Package | 用途 |
| --- | --- |
| `audit_package` | 记录目标 Skill、范围、findings、evidence refs、decision、required changes、non-goals |
| `candidate_package` | 记录 Darwin 候选 diff、目标 section、替换 section、行为变化、证据和风险 |
| `verification_package` | 记录 schema、semantic、consumer、manifest command 和 fresh command 结果 |
| `projection_package` | 记录派生报告来源、source pointer、hash 和 renderer 信息 |

## Darwin Collaboration

Darwin 是候选生成器和优化器，不是裁决者。

`skill-harness` 对 Darwin 候选做这些裁决：

| 检查 | 阻断条件 |
| --- | --- |
| 内容顺序 | 新 HARD-GATE、权限、验证规则被追加到末尾或错误 section |
| 权限边界 | 候选放宽写入、Bash、外部调用或危险动作 |
| 证据链 | 候选删除 proof command、证据引用或失败停止点 |
| runtime noise | 候选保留旧入口 alias、历史迁移噪音或无消费者字段 |
| 行为收益 | 候选没有证明触发、加载、验证或维护性提升 |
| 回退能力 | 候选无法说明替换范围和失败后的恢复边界 |

candidate package 只在 Darwin 候选进入机器验收或跨轮比较时启用。人工讨论候选时，结构化 Markdown 足够。

## Content Order Contract

内容顺序不是排版偏好，它保护 LLM 的加载路径和规则优先级。

`SKILL.md` 的运行时信息需要满足：

| 区域 | 位置原则 |
| --- | --- |
| frontmatter | 文件顶部，描述触发、权限和可调用属性 |
| HARD-GATE | 早于流程步骤和参考资料 |
| 权限与写入边界 | 早于执行动作 |
| 执行流程 | 只描述默认路径和分支，不承载历史迁移过程 |
| 输出与验证 | 早于完成声明 |
| references | 通过契约式引用路由，不在正文堆长材料 |
| archive / migration notes | 不进入运行时默认加载路径 |

Darwin 或人工改造不得把新运行时规则追加到尾部“补充说明”。新规则需要归入对应 section；找不到归属时，说明当前 Skill 边界不清。

## Runtime Noise Policy

runtime noise 指没有当前消费者却进入运行时路径的内容。典型形态包括：

- 旧 Skill 名称作为 active alias。
- 历史迁移说明放在 `SKILL.md` 正文。
- 无消费者 JSON 字段、目录或脚本。
- 兼容入口没有退出条件。
- 只为解释过去而影响当前触发或加载的段落。

目标态规则：

| 类别 | 处理 |
| --- | --- |
| CURRENT_CONTRACT | 保留在运行时路径，并绑定消费者和验证 |
| TEST_FIXTURE | 放入 fixtures 或 evals，只服务测试 |
| ARCHIVE_ONLY | 放入 docs/archive 或迁移说明，不进入触发路径 |

`skill-auditor` 不作为运行时兼容入口保留。迁移期间可作为历史对象被读取，但目标运行时只暴露 `skill-harness`。

## Data Flow

默认人类审计路径：

```text
User request
→ LLM scope and semantic audit
→ structured Markdown findings
→ user decision
```

机器消费路径：

```text
User request or machine trigger
→ LLM scope and semantic audit
→ JSON upgrade gate
→ fact package
→ schema / semantic / consumer / manifest validation
→ derived Markdown or blocking result
```

Darwin 候选路径：

```text
Darwin candidate
→ candidate_package when machine comparison exists
→ skill-harness boundary checks
→ accept, revise, or block
```

## Error Handling

`skill-harness` 使用 fail-closed 处理会影响正确性的缺口。

| 错误 | 结果 |
| --- | --- |
| FAIL 无证据 | 阻断 FAIL 结论，只能降为观察或要求补证据 |
| manifest command 不存在 | proof-chain FAIL，不能声称验证可执行 |
| JSON 字段无消费者 | Practice FAIL 或删除字段 |
| Markdown/JSON 双事实源 | Runtime Boundary FAIL |
| 写入范围未授权 | 停止写入，要求用户确认范围 |
| Darwin 候选放宽权限 | 阻断候选 |
| 内容顺序漂移 | 阻断候选或要求重排 |
| standard-chain 结构被默认搬入 | Practice FAIL，回到 JSON upgrade gate |

## Alternatives Considered

| 方案 | 裁决 | 原因 |
| --- | --- | --- |
| A. 新建 `skill-harness`，吸收 `skill-auditor` 内容并重定边界 | 采用 | 能清理旧入口噪音，保留 Harness 正确方向 |
| B. 直接把 `skill-auditor` 改名 | 不采用 | 旧权限、JSON 默认化和 runtime 噪音会被带入新入口 |
| C. 保留 `skill-auditor` 与 `skill-harness` 双入口 | 不采用 | 会制造触发歧义和长期兼容负担 |
| D. 默认复制 standard-chain JSON artifacts | 不采用 | standard-chain 服务强交付链，普通 Skill 审计无需完整 canonical 平台 |
| E. Markdown-only 审计 | 不采用为全局策略 | 人类审计够用，但机器消费、hook、Darwin gate 和发布验证需要 JSON fact source |

推荐方案是 A，并结合触发式 JSON。它保留正确性和可复验能力，同时削减无消费者复杂度。

## Change Scope

本设计只冻结 `skill-harness` 最佳实践基线。后续实现范围限于：

- 新 `skill-harness` 入口、reference、schema 或脚本的目标态设计。
- 现有 `skill-auditor` 内容的吸收、重写或归档策略。
- Darwin 候选验收和 standard-chain JSON 原则的最小结合方式。

本设计不修改运行时 Skill，不替换 standard-chain，不改变 small-chain 的 Markdown 产物模型。

## Invariants

以下不变量在后续实现中保持不变：

- 正确性高于完整性，完整性高于简洁。
- LLM 提议状态转移，工程机制授权状态转移。
- JSON 由消费触发，不由审计存在触发。
- 有机器消费者时，Markdown/HTML 不能作为事实源。
- FAIL 需要证据、位置、影响和验证方式。
- 无消费者字段、目录、脚本、alias 不进入运行时默认路径。
- 旧名称不保留为 active runtime compatibility。
- Darwin 候选不能削弱权限、证据、验证或内容顺序。

## Downstream Impact

`skill-harness` 会影响这些下游：

| 下游 | 影响 |
| --- | --- |
| Darwin | 候选生成后需要接受 Harness 边界裁决 |
| skill-auditor | 作为历史素材被吸收，不作为目标运行时入口 |
| delivery-owner | 作为校准样本，用于识别闭环正确但实践过重 |
| standard-chain | 提供 JSON 合同原则，不被默认复制 |
| hooks / validators | 只有 JSON upgrade gate 通过后才消费 fact package |
| future implementation plans | 需要围绕默认路径、触发路径和验证样本切分 |

## Validation Strategy

验证策略使用校准样本，而不是只看文档是否完整。

| 样本 | 预期裁决 |
| --- | --- |
| `delivery-owner` | `Correctness PASS / Practice FAIL` |
| 当前 `skill-auditor` | Harness 方向有价值，默认 JSON 和权限边界需重构 |
| standard-chain JSON 合同 | 强交付链中是 Essential Complexity；`skill-harness` 默认路径不复制 |
| Darwin 尾部追加运行时规则 | Content Order FAIL |
| manifest 指向不存在命令 | Proof-chain FAIL |
| 无证据 FAIL | Evidence Contract FAIL |
| 旧入口 active alias | Runtime Noise FAIL |
| 机器消费者读取 Markdown | Fact Source FAIL |

后续实现需要用 fresh proving command 证明这些样本。单个 schema 绿灯不能替代语义、消费者、证据和命令存在性验证。

## Risks

| 风险 | 设计裁决 |
| --- | --- |
| Harness 再次变成重型平台 | 默认审计保持结构化 Markdown，JSON 由消费触发 |
| JSON 变成仪式产物 | 每个字段需说明消费者、验证方式和失败停止点 |
| 旧入口保留制造噪音 | 不保留 `skill-auditor` 运行时兼容入口 |
| 过度追求简化削掉正确性 | 权限、证据、授权、fresh command 和 fail-closed 属于 Essential Complexity |
| Darwin 自我证明候选收益 | Harness 独立裁决候选，不接受候选自证 |
| standard-chain 经验被误读 | 吸收原则，不复制完整 canonical 交付链 |
| 文档与实现漂移 | 后续 plan 需绑定设计锚点、验证样本和 fresh proving command |
