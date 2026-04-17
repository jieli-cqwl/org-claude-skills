# Skill 质量标准 v2 设计裁决

## 文档关系

本文是 `shared/reference/Skill质量标准.md` 升级到 v2 的设计真源。它只冻结长期裁决、边界、维度模型、消费方关系和验证口径，不承载实施进度。

相关文档职责如下：

| 文件 | 职责 | 权威边界 |
| --- | --- | --- |
| `shared/reference/Skill质量标准.md` | first-party Skill 质量标准运行时真源 | 改造后承载 v2 正文 |
| `shared/skills/skill-optimizer/SKILL.md` | 已有 Skill 审计、优化、验证入口 | 消费质量标准，不定义新评级体系 |
| `shared/skills/skill-optimizer/references/d1-d7-mapping.md` | optimizer 审计维度到质量维度的映射 | v2 改造时同步为新维度映射 |
| `shared/skills/scan/references/skills-scan-rules.md` | scan 的 Skill 静态巡检规则 | 消费质量标准中的可机械检测子集 |
| `docs/skill-optimizer/2026-04-16-course-derived-methodology/design.md` | `skill-optimizer` 的 Harness 设计依据 | 提供运行链路和 artifact 经验，不替代质量标准 |

## 背景

现行 `Skill质量标准.md` 起源于早期 first-party Skill 写作治理，核心关注 `SKILL.md` 的结构、闭环、I/O、角色、验证、Token 效率和跨模型适配。该版本在 `skill-creator`、`new-skills` 并存阶段有效，因为当时的主要问题是“如何写出结构清晰、可被扫描的 Skill”。

当前体系已经变化：

- 官方 `skill-creator` 接管从零创建、eval 迭代、benchmark 和 description 优化。
- `skill-optimizer` 接管已有 Skill 或草稿 Skill 的审计、优化计划、运行时 artifact、schema、semantic validation、eval 和派生视图。
- `new-skills` 已退役，旧的“创建 + 结构审计”混合入口不再作为质量治理中心。
- 用户目标从“写得像一个好 Skill”升级为“Skill 在运行时可触发、可加载、可执行、可验证、可演化、可审计”。

因此，质量标准需要从文档结构评分升级为 Harness Engineering 质量合同。

## 总裁决

`Skill质量标准.md` v2 采用 Harness Engineering 质量模型。它不再只评价 `SKILL.md` 文本质量，而是定义 first-party Skill 在触发、加载、artifact、权限、流程、验证、演化和复用上的质量合同。

v2 替换现行 D1-D7，而不是创建并行评级体系。旧 D1-D7 作为迁移词汇保留在映射表中；长期质量评级只使用 v2 维度与 L1/L2/L3 分级。

## 目标

1. 将质量标准从“文档结构合规”升级为“运行时合同合规”。
2. 明确 `skill-creator`、`skill-optimizer`、`scan`、install/runtime、reviewer 各自如何消费质量标准。
3. 将 JSON artifact、schema、semantic validation、eval、fresh proving command 纳入质量标准。
4. 将 reference、examples、rules、schemas、evals、scripts、templates、hooks 统一纳入资源合同。
5. 保留 L1/L2/L3 成熟度模型，但重写分级判定，让它服务 Harness 稳定性。
6. 消除旧 D1-D7 与 `skill-optimizer` 运行链路之间的语义漂移。

## 非目标

v2 不接管官方 `skill-creator` 的创建流程、with/without eval 编排、benchmark viewer 和 description improver。

v2 不把所有 Skill 都改造成 JSON-first 工具。JSON artifact 是对审计、优化、验证、流转类 Skill 的强约束；对轻量工具类 Skill，质量标准只要求输出契约可验证。

v2 不强制 `community/` canonical skill 套用 first-party 结构。社区 Skill 以来源锁定、adapter 兼容和本地补丁边界为准。

v2 不把 `scan` 的静态检测结果等同于最终质量结论。`scan` 只能给出可机械检测的信号；完整评级需要结合上下文、证据和运行结果。

## 权威边界

质量标准处在本地 Skill 治理体系的 Layer 2：它定义“什么算高质量”，不定义“如何创建”或“如何执行每一次改造”。

| 消费方 | 使用方式 | 不拥有的职责 |
| --- | --- | --- |
| `skill-creator` | 创建新 Skill 时读取质量目标，生成 eval assertions 或评估提示 | 不拥有本地质量评级真源 |
| `skill-optimizer` | 审计已有 Skill 时按 v2 维度输出 findings、计划和验证 artifact | 不创建新 Skill，不建立第二套成熟度 |
| `scan` | 对 Skill 目录做静态巡检，输出 v2 可机械检测子集 | 不替代人工裁决、eval 和 semantic validation |
| install/runtime | 校验 adapter、manual-only、retired skill、运行时噪音 | 不定义 Skill 质量维度 |
| reviewer | 按 v2 维度挑战完整性、证据和边界 | 不以主观偏好覆盖 rules 与标准 |

## 设计原则

### Harness 优先

质量标准优先服务运行时稳定性。章节结构、表达风格和人类可读性重要，但它们不能替代触发准确、资源加载、权限边界、状态流转和验证证据。

### Consumer-first

任何字段、目录、脚本、schema、hook、artifact 进入标准前，都需要有明确消费者。没有消费者的内容只能作为说明或派生视图，不能进入运行时合同。

### JSON 真源

对审计、优化、验证、流转类 Skill，机器事实源为 JSON artifact。Markdown 和 HTML 是派生视图。人类修改事实时修改上游源或 JSON，再重新渲染视图。

### 证据先于结论

PASS、PARTIAL、FAIL 必须绑定证据。证据包括文件位置、schema validation、semantic validation、fresh proving command、eval、benchmark、rendered-view validation 和人工裁决记录。

### 标准不等于工具

质量标准只定义判定模型。`skill-creator`、`skill-optimizer`、`scan`、install 脚本和 hooks 是执行工具。工具可以实现标准子集，但不能改写标准语义。

## v2 质量维度

v2 使用 D1-D8。每个维度都要能回答三个问题：它保护什么运行时风险，谁消费它，如何证明它达标。

| 维度 | 名称 | 保护的风险 | 核心消费者 |
| --- | --- | --- | --- |
| D1 | 触发与路由合同 | 错触发、漏触发、邻近 Skill 冲突、创建/优化入口混淆 | runtime、adapter、`skill-creator`、`skill-optimizer` |
| D2 | 渐进加载与上下文预算 | LLM 读取过多、读取不足、读错资源、reference 路由不稳定 | runtime、`scan`、`skill-optimizer` |
| D3 | 输入输出与 artifact 合同 | 输出不可消费、状态不可流转、Markdown 与机器事实混用 | `skill-optimizer`、scripts、hooks、renderer |
| D4 | 执行安全与权限边界 | audit 写文件、review 越权、script 无准入、hook 失控 | runtime、install、hooks、reviewer |
| D5 | 流程自治与异常控制 | 前置条件缺失、失败后继续、handoff 丢上下文、状态不可恢复 | pipeline Skill、SubAgent、hooks |
| D6 | 验证与证据 | 自证式结论、局部绿灯冒充质量、Mock 冒充真实验收 | reviewer、`skill-optimizer`、CI gate |
| D7 | 演化与兼容性 | 迁移残留、旧入口噪音、adapter 漂移、跨模型失效 | install、runtime catalog、maintainer |
| D8 | 人类可读与组织复用 | 标准难学、报告难审、样例不可复用、团队口径分裂 | 用户、reviewer、团队维护者 |

### D1 触发与路由合同

D1 定义 Skill 何时被触发、何时不能被触发、与相邻 Skill 如何分流。

达标含义：

- frontmatter 包含 `name` 与 `description`。
- `description` 同时表达能力边界和触发场景。
- 创建、优化、审计、验证、迁移等相邻场景有明确路由。
- manual-only Skill 同时声明 Claude 侧 invocation 限制和 Codex 侧 adapter 暴露策略。
- 正触发、反触发、邻近 Skill 冲突样例可被 eval 或人工审计消费。

D1 是 v2 的第一入口。结构完整但触发不准的 Skill 不能评为高质量。

### D2 渐进加载与上下文预算

D2 定义 LLM 在什么条件下读取 `SKILL.md`、`references/`、`examples/`、`rules/`、`schemas/` 和其他资源。

达标含义：

- `SKILL.md` 只承载高频入口、硬门禁、流程骨架和输出合同。
- 低频方法论、长示例、规则细则、schema 和模板进入独立资源目录。
- 每个被 `SKILL.md` 路由的资源都有契约：Trigger、Read、Expect、Consume、Evidence、Sync。
- reference 不通过多层跳转隐藏关键规则。
- 上下文预算按 Skill 类型分档，但预算不是质量目标本身；预算服务触发和执行稳定性。

### D3 输入输出与 artifact 合同

D3 定义 Skill 输入、输出、运行时 artifact、schema 和下游消费者。

达标含义：

- 输入包含前置文件、状态、授权范围、外部依赖和缺失时的终止行为。
- 输出包含路径、格式、必填字段和消费方。
- JSON artifact 字段进入合同前通过 consumer-first gate。
- schema 证明形状，semantic validator 证明状态、证据、消费者和流转一致性。
- Markdown/HTML 报告声明派生来源，不反向成为机器事实源。

### D4 执行安全与权限边界

D4 定义 Skill 能使用什么工具、何时只读、何时可写、脚本如何准入、hook 如何接入。

达标含义：

- audit、review、explain 默认只读。
- 写文件、删除、迁移、提交、外部写 API 需要本轮明确授权和精确范围。
- `allowed-tools` 与实际职责一致，review 类 Skill 不默认拥有 Edit。
- scripts 有 manifest、超时、参数约束、路径限制、退出码语义和验证命令。
- hook 接入需要 adapter contract、owner、failure state 和 rollback。

### D5 流程自治与异常控制

D5 定义 Skill 能否在独立运行时闭环，并在失败时停在正确状态。

达标含义：

- 前置条件不满足时终止并说明缺失项。
- 流程步骤可按顺序执行，不能靠隐含会话记忆补关键上下文。
- 分支条件、退出条件、失败状态和回退动作可被审计。
- SubAgent/fork 有输入合同、输出合同、handoff 证据和接受标准。
- pipeline Skill 明确上游输入、下游消费者和阶段边界。

### D6 验证与证据

D6 定义质量结论如何被证明。

达标含义：

- 每个 PASS/PARTIAL/FAIL 都有文件、位置、证据、影响和验证方式。
- fresh proving command 直接对应成功标准。
- eval 覆盖正触发、反触发、邻近 Skill、缺参、权限不足、格式诱导和失败路径。
- benchmark 用于证明改造收益，不能替代失败路径验证。
- human review 只覆盖主观判断项，不能覆盖硬门禁失败。

### D7 演化与兼容性

D7 定义 Skill 如何随官方工具、本地 runtime、adapter、模型和旧入口变化而保持可维护。

达标含义：

- official/community source 有来源锁定和本地补丁边界。
- adapter、install、runtime catalog 和 retired skill 规则保持同步。
- 迁移、退役和兼容策略有验证命令。
- 跨模型测试用于 L3 质量证明，尤其覆盖触发、流程理解和格式遵循。
- 旧入口退出后不保留无消费者目录。

### D8 人类可读与组织复用

D8 定义人类如何理解、审查、复用和维护 Skill。

达标含义：

- examples 独立于 reference，服务触发、反例、失败路径和报告解释。
- rendered Markdown/HTML 报告可追溯到 JSON artifact。
- 术语、维度、评级和严重度在标准、scan、optimizer、review 报告中一致。
- 5/10/30 可作为学习成本和可用性信号，但不单独证明质量收益。
- 文档表达服务执行，不用长解释替代硬合同。

## L1/L2/L3 分级

v2 保留 L1/L2/L3，但评级含义从“文档成熟度”升级为“运行时合同成熟度”。

| 级别 | 定位 | 判定含义 |
| --- | --- | --- |
| L1 可用 | 能被触发并完成单次任务 | D1、D3、D5 有最小合同；D6 有最小完成校验 |
| L2 闭环 | 能稳定独立运行并被审计 | D1-D6 达标；D7 无阻塞性漂移；D8 不阻断理解 |
| L3 卓越 | 能跨场景复用、验证和演化 | D1-D8 达标；eval/benchmark/跨模型/迁移证据齐全 |

评级按最低阻塞维度收敛。D4 或 D6 出现硬失败时，不能评为 L2 或 L3。

## Skill 类型画像

不同 Skill 类型使用同一质量模型，但检查深度不同。

| 类型 | 目标等级 | 强约束维度 | 说明 |
| --- | --- | --- | --- |
| Pipeline skill | L2 起，冲 L3 | D1-D7 | 涉及阶段流转、handoff、验证闭环 |
| 审计/验证 skill | L2 起，冲 L3 | D1、D3、D4、D6、D7 | 结论必须证据化，默认只读 |
| 创建/改造 skill | L2 起，冲 L3 | D1、D2、D4、D6、D8 | 与 `skill-creator`、`skill-optimizer` 边界清晰 |
| 工具类 skill | L1 起，冲 L2 | D1、D3、D4、D6 | 输入输出与权限边界优先 |
| manual-only skill | L1 起，按职责提升 | D1、D4、D7 | 两端暴露策略需要一致 |

## 资源合同

v2 将 Skill 资源拆成可消费对象，而不是把所有内容都塞进 `references/`。

| 目录 | 角色 | 合同要求 |
| --- | --- | --- |
| `references/` | 方法论、规则细则、决策依据 | 完整 Trigger/Read/Expect/Consume/Evidence/Sync |
| `examples/` | 正例、反例、触发样例、失败样例 | 声明消费者，优先被 eval 或报告使用 |
| `rules/` | skill-local 硬约束或权限 profile | 不覆盖全局 rules；只承载当前 Skill 的局部约束 |
| `schemas/` | JSON artifact 形状、枚举、状态词表 | 有 validator 和消费者 |
| `evals/` | 测试输入、assertions、benchmark input | 有复跑命令和评分口径 |
| `scripts/` | 确定性检查、转换、渲染、验证 | 有 manifest、边界、超时和退出码语义 |
| `templates/` | Markdown/HTML 派生视图模板 | 只由 renderer 消费，不承载事实真源 |
| `hooks/` | 拦截和状态控制 adapter | 有 owner、failure state、rollback 和接入门禁 |
| `assets/` | 模板资产、图片、字体、示例文件 | 有输出消费者和许可边界 |

资源合同字段如下：

| 字段 | 含义 |
| --- | --- |
| Trigger | 何时读取或执行该资源 |
| Read | 读取哪个路径或对象 |
| Expect | 从中获得什么信息或能力 |
| Consume | 谁消费该结果 |
| Evidence | 如何证明资源被正确消费 |
| Sync | 资源变化时同步哪些入口、schema、测试或报告 |

## 与 `skill-creator` 的关系

`skill-creator` 是创建与迭代工具，v2 是质量目标。二者关系如下：

| 阶段 | `skill-creator` 职责 | v2 质量标准职责 |
| --- | --- | --- |
| 意图捕获 | 访谈、提炼用户目标、确定触发场景 | 提供 D1/D3/D6 的目标口径 |
| 草稿生成 | 写 `SKILL.md`、组织资源、设置 eval prompts | 提供结构、资源和权限边界 |
| eval 迭代 | 运行 with-skill/baseline、benchmark、viewer | 提供 assertions 与质量维度映射 |
| description 优化 | 改进触发描述 | 用 D1 判断触发合同质量 |
| 交付审查 | 输出创建结果 | 按 L1/L2/L3 判定质量等级 |

`skill-creator` 可以消费 v2，但不成为 v2 的权威来源。

## 与 `skill-optimizer` 的关系

`skill-optimizer` 是 v2 的主要运行时消费者。它把目标 Skill 的事实转成 `skill-audit.json`、`optimization-plan.json` 和 `verification-result.json`，再映射回 v2 维度。

映射关系如下：

| optimizer 审计链路 | v2 维度 |
| --- | --- |
| 触发 | D1 |
| 加载 | D2 |
| 决策 | D2、D3、D5 |
| 执行 | D4、D5 |
| 验证 | D6 |
| 演化 | D7、D8 |

`skill-optimizer` 的 JSON artifact 字段必须能映射到 v2 维度、消费者和验证命令。找不到消费者的字段不进入 runtime artifact。

## 与 `scan` 的关系

`scan` 消费 v2 的静态可检测子集。它输出健康信号，不输出最终质量裁决。

| scan 规则 | v2 来源 |
| --- | --- |
| frontmatter、description、Use when | D1 |
| 行数、reference 存在、嵌套引用 | D2 |
| 输出路径、格式、必填字段 | D3 |
| allowed-tools、manual-only、script manifest | D4 |
| 前置条件、失败路径、完成校验 | D5、D6 |
| retired skill、adapter、install 暴露 | D7 |
| examples、术语一致性、报告追溯 | D8 |

`scan` 结果中“严重”代表需要人工或 optimizer 复核，不直接等同最终 FAIL。

## 与 install/runtime 的关系

install/runtime 负责证明 Skill 在 Claude 与 Codex 两端暴露正确、退役正确、噪音受控。

v2 对 install/runtime 的约束：

- Claude 与 Codex 的 Skill 暴露策略需要一致表达。
- `agents/openai.yaml` 表示 Codex 自动暴露面，不等同 Skill 质量达标。
- manual-only 需要同时处理 Claude frontmatter 与 Codex adapter 移除。
- retired skill 不能留在运行时路径制造触发噪音。
- runtime catalog 不挂载 `reference/Skill质量标准.md` 为全局运行时合同；install/runtime 通过文件存在、adapter、retired skill 与噪音门禁保持该标准可用但不常驻。

## 验证口径

v2 正文改造完成时，需要用以下证据证明没有引入漂移：

| 证明面 | 证明内容 |
| --- | --- |
| 文档一致性 | `Skill质量标准.md`、optimizer 映射、scan 规则使用同一维度词汇 |
| 触发边界 | `skill-creator` 负责创建，`skill-optimizer` 负责优化审计 |
| 资源合同 | references、examples、rules、schemas、evals、scripts、templates、hooks 有清晰消费者 |
| runtime artifact | JSON 真源、schema、semantic validation、renderer 派生关系一致 |
| 安装面 | Claude/Codex 暴露与 retired skill 规则不回退 |
| 静态扫描 | scan 的规则能映射到 v2 维度 |
| 回归测试 | skill-optimizer、install、runtime、context budget、runtime catalog 相关测试通过 |

## 迁移策略

v2 迁移采用替换式升级。

| 旧模型 | v2 去向 |
| --- | --- |
| D1 结构合规 | 拆入 D1 触发与路由、D2 渐进加载、D8 可读复用 |
| D2 闭环自治 | 升级为 D5 流程自治与异常控制 |
| D3 I/O 契约 | 升级为 D3 输入输出与 artifact 合同，并覆盖 schema/consumer |
| D4 角色与对抗 | 拆入 D5 流程自治、D6 证据、D8 复用 |
| D5 验证即证据 | 升级为 D6 验证与证据 |
| D6 Token 效率 | 升级为 D2 渐进加载；reference 契约拆入 D2/D3/D7 |
| D7 跨模型适配 | 升级为 D7 演化与兼容性 |

旧 D1-D7 的最大价值是提供本地历史词汇。v2 实施后，旧词汇只用于迁移对照，不作为新的审计输出维度。

## 改造影响范围

v2 正文改造会影响以下文件和测试面：

| 范围 | 影响 |
| --- | --- |
| `shared/reference/Skill质量标准.md` | 主体重写为 v2 标准 |
| `shared/skills/skill-optimizer/references/d1-d7-mapping.md` | 从旧 D1-D7 映射更新为 v2 维度映射 |
| `shared/skills/scan/references/skills-scan-rules.md` | 静态规则改为 v2 子集 |
| `tests/test-runtime-contract-catalog.sh` | 确认标准不被 runtime catalog 常驻挂载 |
| `tests/test-skill-runtime-noise.sh` | 确认标准不制造运行时噪音 |
| `tests/test-skill-context-budget.sh` | 校准上下文预算和 reference 规则 |
| `tests/test-skill-optimizer-contract.sh` | 校准 optimizer 对质量维度的引用 |
| `docs/skill-optimizer/2026-04-16-course-derived-methodology/design.md` | 若仍写旧 D1-D7，需要同步术语或增加迁移说明 |

## 下游实施原则

正文改造时遵守以下原则：

- 先让测试暴露旧维度漂移，再更新正文和消费者。
- 不在 `Skill质量标准.md` 中堆实施日志。
- 不让 `skill-optimizer` 发明新评级；它只消费 v2。
- 不让 `scan` 冒充最终审计；它只输出静态信号。
- 不把 reference 契约继续埋在 Token 效率下。
- 不把 Markdown 派生视图当成 runtime fact source。
- 不保留无消费者的 legacy 入口或目录。

## 成功状态

v2 落地后的成功状态是：

- first-party Skill 质量标准以 Harness 合同为中心。
- `skill-creator`、`skill-optimizer`、`scan`、install/runtime 各自职责清楚。
- D1-D8、L1/L2/L3、PASS/PARTIAL/FAIL 使用同一套语义。
- reference、examples、rules、schemas、evals、scripts、templates、hooks 都有资源合同。
- JSON artifact 与 Markdown/HTML 视图的事实关系清楚。
- 后续任一 Skill 审计都能回答：触发是否准、加载是否稳、输出谁消费、权限是否安全、失败是否停住、证据是否可复跑、演化是否可维护。
