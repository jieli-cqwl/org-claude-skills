# Skill 质量标准

> 触发条件：创建新 Skill、评估 Skill 质量、优化已有 Skill、执行 `/scan` Skill 质量扫描时读取。

本文是 first-party Skill 质量裁决标准真源。

本标准裁决 first-party Skill 的运行面质量：触发与路由、渐进加载、输入输出、权限边界、流程自治、验证证据、演化兼容、表达可审计与口径一致性。

质量裁决必须可被证据支持。裁决输出使用 PASS / FAIL / COMMENT findings，每条 finding 必须绑定文件位置、影响、证据和验证方式。

- 机器消费者需要阻断、比较、状态转移、发布判定或派生报告时，必须输出 JSON artifact，并以该 JSON 作为机器事实源。
- 仅供人工阅读且无机器消费者时，输出结构化 Markdown；Markdown 和 HTML 必须声明派生来源，不反向成为机器事实源。

## 本体质量裁决模型

Skill 本体质量裁决目标是判断 `SKILL.md` 能否稳定改变 agent 的执行行为，而不是判断文本是否顺眼。所有本体质量 finding 必须映射到 D1-D8，不新增独立维度。

本体质量至少覆盖 5 个裁决面：

| 裁决面 | 判定问题 | 主要映射 |
| --- | --- | --- |
| 目标合同 | Skill 要达成什么、不做什么、完成后用什么证据证明？ | D1、D3、D5、D6 |
| SOP 可执行性 | agent 能否按顺序执行步骤，并在分支、缺参、失败时停在正确状态？ | D5、D6 |
| 指令精准度 | 指令是否短、明确、可观察，避免用空泛词替代判据？ | D5、D8 |
| 渐进加载 | 主体、reference、example、script、schema 是否按读取频率和消费者分层？ | D2、D3、D8 |
| 表达结构化 | 复杂流程是否用流程图、流程表或状态表降低歧义，简单线性流程是否不过度包装？ | D5、D8 |

目标裁决可使用 SMART 作为审视助记：具体、可证明、可达到、匹配触发意图、边界明确。SMART 不是必写章节；只有当目标不可执行、不可验证或边界不清时才形成 finding。

## 质量维度

| 维度 | 名称 | 保护的风险 | 核心消费者 |
| --- | --- | --- | --- |
| D1 | 触发与路由合同 | 错触发、漏触发、邻近 Skill 冲突、创建/优化入口混淆 | runtime、adapter、`skill-creator`、`skill-harness` |
| D2 | 渐进加载与上下文预算 | LLM 读取过多、读取不足、读错资源、reference 路由不稳定 | runtime、`scan`、`skill-harness` |
| D3 | 输入输出与 artifact 合同 | 输出不可消费、状态不可流转、Markdown 与机器事实混用 | `skill-harness`、scripts、hooks、renderer |
| D4 | 工具权限与执行边界 | audit 写文件、review 越权、script 无准入、hook 失控 | runtime、install、hooks、reviewer |
| D5 | 流程自治与异常控制 | 前置条件缺失、失败后继续、handoff 丢上下文、状态不可恢复 | pipeline Skill、TeamCreate、SubAgent、hooks |
| D6 | 验证与证据 | 自证式结论、局部绿灯冒充质量、Mock 冒充真实验收 | reviewer、`skill-harness`、CI gate |
| D7 | 演化与兼容性 | 迁移残留、旧入口噪音、adapter 漂移、跨模型失效 | install、runtime catalog、maintainer |
| D8 | 表达可审计与口径一致性 | 表达噪音、报告不可追溯、样例无消费者、术语/评级漂移 | reviewer、`scan`、optimizer、renderer |

## D1 触发与路由合同

D1 裁决 Skill 何时触发、何时不触发、与相邻 Skill 如何分流。

L2 基线：

- frontmatter 包含 `name` 与 `description`。
- `description` 同时表达能力边界和触发场景。
- 创建、优化、审计、验证、迁移等相邻场景有明确路由。
- manual-only Skill 同时声明 Claude 侧 invocation 限制和 Codex 侧 adapter 暴露策略。manual-only 需要同时处理 Claude frontmatter 与 Codex adapter 移除。
- 正触发、反触发、邻近 Skill 冲突样例可被 eval 或人工审计消费。

反例：

- `description` 只写能力名，没有触发场景。
- 优化已有 Skill 的请求路由到创建工具。
- manual-only 只在 Claude frontmatter 声明，Codex adapter 仍自动暴露。
- `agents/openai.yaml` 暴露能力与 `SKILL.md` 描述不一致。

## D2 渐进加载与上下文预算

D2 裁决 LLM 在什么条件下读取 `SKILL.md`、`references/`、`examples/`、`rules/`、`schemas/` 和其他资源。

L2 基线：

- `SKILL.md` 只承载高频入口、硬门禁、流程骨架和输出合同。
- 低频方法论、长示例、规则细则、schema 和模板进入独立资源目录。
- 主体内容保留目标合同、主 SOP、关键分支、完成边界和必须先读的安全约束；背景解释、长方法论、长样例、评分细则和领域知识下沉到资源。
- 每个被 `SKILL.md` 路由的资源都有契约：Trigger、Read、Expect、Consume、Evidence、Sync。
- reference 不通过多层跳转隐藏关键规则。
- 上下文预算服务触发和执行稳定性，但固定行数阈值不单独产生 FAIL。

行数口径与本地启发式：

- 官方软上限：`SKILL.md` 接近或超过 500 行 / 5000 tokens 时，必须拆分或记录豁免理由。
- 本地审视信号：超过 250 行触发职责数量、读取频率、低频内容比例、reference 合同质量和工程化替代空间审视；不自动判失败。
- 行数预算只能作为 COMMENT 或 warning-level signal。固定行数阈值不是 hard quality standard。
- 当行数或上下文预算产生风险时，finding 必须说明具体运行时影响：例如 active path 噪音导致触发混淆、低频细节没有下沉到资源、或 reference 合同不可消费。没有这种影响证据时，行数只能提示人工复核。
- 不为了压缩行数删除 HARD-GATE、前置条件、完成边界或失败路径。
- 评估结论以职责清晰、渐进加载质量、消费者证据和工程化替代空间为准；行数只提供风险信号。

反例：

- `SKILL.md` 内嵌大量低频方法论。
- 裸路径引用 `references/x.md`，未说明触发条件和内容预期。
- reference 再嵌套引用 reference，导致运行时只读到部分规则。
- 长示例、模板正文和评分细则塞在主流程中，导致 agent 先读低频细节再读执行步骤。

## D3 输入输出与 artifact 合同

D3 裁决 Skill 输入、输出、运行时 artifact、schema 和下游消费者。

L2 基线：

- 输入包含前置文件、状态、授权范围、外部依赖和缺失时的终止行为。
- 输出包含路径、格式、必填字段和消费方。
- JSON artifact 字段进入合同前通过 consumer-first gate。
- schema 证明形状，semantic validator 证明状态、证据、消费者和流转一致性。
- Markdown/HTML 报告声明派生来源，不反向成为机器事实源。

反例：

- 输出只写“生成报告”，没有路径、格式和消费者。
- JSON 字段没有下游消费方。
- 人工改动 Markdown 报告后把它当成 runtime fact source。

## D4 工具权限与执行边界

D4 裁决 agent 在该 Skill 下可使用的工具权限，以及这些权限如何被只读、可写、脚本、hook 和外部写入边界约束。权限边界优先看 runtime 暴露给 agent 的工具能力；脚本和 hook 是工具能力的执行放大器，必须被同一边界约束。

L2 基线：

- `allowed-tools` 与实际职责一致，且能解释每个非只读工具的必要性。
- audit、review、explain 默认只读，只暴露读取、检索和受限诊断工具。
- `Edit`、`Write`、`MultiEdit`、外部写 API、commit、delete、migrate、deploy 需要本轮明确授权、精确范围和验证方式。
- `Bash` 默认按命令意图裁决：只读诊断可允许；写入、删除、网络变更、进程管理或环境变更必须有准入边界。
- `Agent`、`TeamCreate` 或 SubAgent 工具需要明确输入、输出、可写范围和接受标准。
- scripts 有 manifest、超时、参数约束、路径限制、退出码语义和验证命令。
- hook 接入需要 adapter contract、owner、failure state 和 rollback。

反例：

- 审计 Skill 默认暴露 `Edit`、`Write` 或 `MultiEdit`。
- `allowed-tools` 未声明，却要求 agent 执行写文件、提交或外部写 API。
- 裸 `Bash` 允许写入、删除或网络变更，没有 manifest runner 或只读命令边界。
- 脚本无 manifest、无超时、无参数边界。
- hook 直接接入全局 registry，却没有失败状态和回滚合同。

## D5 流程自治与异常控制

D5 裁决 Skill 能否在独立运行时闭环，并在失败时停在正确状态。

L2 基线：

- 主流程从目标、输入、执行步骤、输出到验证形成闭环，目标可通过产物、报告、命令或 eval 证明。
- SOP 步骤使用可执行动词表达，例如读取、判断、执行、输出、验证、停止；每个关键步骤能定位输入、动作、产物和下一步。
- 前置条件不满足时终止并说明缺失项。
- 流程步骤可按顺序执行，不能靠隐含会话记忆补关键上下文。
- 分支条件、退出条件、失败状态和回退动作可被审计。
- 多阶段、强分支、状态流转、handoff 或失败回退流程需要流程图、流程表或状态表；简单线性流程不要求流程图。
- TeamCreate/SubAgent/fork 有输入合同、输出合同、handoff 证据和接受标准。
- pipeline Skill 明确上游输入、下游消费者和阶段边界。
- “充分考虑”“合理处理”“尽量完善”“保证质量”等模糊指令必须绑定可观察判据、证据字段或终止条件。

反例：

- 目标只写“提升质量”，没有完成边界或证明方式。
- SOP 是原则清单，agent 读完不知道先做什么、缺什么要停、输出到哪里。
- 缺少输入时继续执行。
- fork 子代理依赖主会话未显式提供的历史。
- 失败后继续推进下游交付。
- 复杂分支只用长段落描述，没有结构化步骤、流程图、流程表或状态表。

## D6 验证与证据

D6 裁决质量结论如何被证明。

L2 基线：

- 每个 PASS / FAIL / COMMENT finding 都有文件、位置、证据、影响和验证方式。
- fresh proving command 直接对应成功标准。
- 本体质量结论必须能回放到目标合同、SOP 步骤、资源加载证据、输出 artifact 或 eval 结果。
- eval 覆盖正触发、反触发、邻近 Skill、缺参、权限不足、格式诱导和失败路径。
- benchmark 用于证明改造收益，不能替代失败路径验证。
- 人工审查只覆盖主观判断项，不能覆盖硬门禁失败。

反例：

- “看起来符合”作为质量结论。
- 用局部 grep 绿灯替代运行时 artifact 验证。
- 用 Mock 或跳过外部交互伪造验收信心。

## D7 演化与兼容性

D7 裁决 Skill 如何随官方工具、本地 runtime、adapter、模型和旧入口变化而保持可维护。

L2 基线：

- official/community source 有来源锁定和本地补丁边界。
- adapter、install、runtime catalog 和 retired skill 规则保持同步。
- 迁移、退役和兼容策略有验证命令。
- 跨模型测试用于 L3 质量证明，尤其覆盖触发、流程理解和格式遵循。
- 旧入口退出后不保留无消费者目录。
- Codex 自动暴露时需确保 `agents/openai.yaml` 存在、`short_description` 25-64 字符、`default_prompt` 包含 `$skill-name`。

反例：

- 旧 Skill 入口退役后仍被安装到运行时。
- `agents/openai.yaml` 暴露能力与 `SKILL.md` 描述不一致。
- community canonical 被改写后无法追溯来源。

## D8 表达可审计与口径一致性

D8 裁决 Skill 文本、examples、报告模板和评审术语是否能被定位、复核和一致消费。

L2 基线：

- 主体表达优先服务执行路径：短句、命令式、少背景、少口号，必要解释必须说明它影响哪个裁决或步骤。
- examples 独立于 reference，有明确消费者，服务触发、反例、失败路径和报告解释。
- rendered Markdown/HTML 报告可追溯到 JSON artifact 或上游事实源。
- 术语、维度、评级、严重度和 finding 字段在标准、scan、optimizer、review 报告中一致。
- 文档表达服务执行路径和裁决项，不用背景解释、历史标签或口号替代合同。
- 表达类 finding 只有在影响触发、加载、权限、输出、证据或裁决一致性时才升为 FAIL；其余为 COMMENT。

反例：

- examples、templates 或报告样例没有消费者。
- 报告视图无法追溯到 JSON artifact 或上游事实源。
- 同一类问题在标准、scan、optimizer 和 review 报告中使用不同维度、严重度或 finding 字段。
- 用背景说明、历史标签或口号替代 Trigger、Consume、Evidence 等可审计合同。
- 用长段落解释意图，但没有对应步骤、判据、输出字段或消费者。

## 资源合同

Skill 资源拆成可消费对象，而不是把所有内容都塞进 `references/`。

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

## L1/L2/L3 分级

| 级别 | 定位 | 判定含义 |
| --- | --- | --- |
| L1 可用 | 能被触发并完成单次任务 | D1、D3、D5 有最小合同；D6 有最小完成校验 |
| L2 闭环 | 能稳定独立运行并被审计 | D1-D6 达标；D7 无阻塞性漂移；D8 不阻断复核和一致消费 |
| L3 卓越 | 能跨场景稳定运行、验证和演化 | D1-D8 达标；eval、benchmark、跨模型、迁移证据齐全 |

评级按最低阻塞维度收敛。当 D4 或 D6 存在 `severity: FAIL` 且影响权限、验证证据或完成门禁时，评级最高只能为 L1；相关 FAIL 修复并由验证方式证明后，才能评为 L2 或 L3。

## 评估方法

逐项输出 PASS / FAIL / COMMENT finding。

| 结果 | 含义 |
| --- | --- |
| PASS | 该质量裁决项合同完整，有证据和验证方式 |
| FAIL | 阻断 Skill 被可靠加载、遵循或审计的问题 |
| COMMENT | warning-level 风险或改进建议，不单独阻断 |

`FAIL` 只用于阻断 Skill 被可靠加载、遵循或审计的问题。`COMMENT` 用于 warning-level 风险，包括表达、重复、行数或上下文预算信号；除非有证据证明影响角色、触发、加载、权限、输出或证据合同，否则 COMMENT 不阻断。

每个 finding 必须映射到一个质量裁决项。只引用工具维度、历史标签或固定行数阈值不能作为阻断依据。

发现字段需要包含：

```json
{
  "severity": "FAIL|WARN|INFO",
  "dimension": "D1|D2|D3|D4|D5|D6|D7|D8",
  "file_ref": "path:line",
  "evidence_refs": ["command-or-file-ref"],
  "impact": "runtime or user-visible effect",
  "recommendation": "specific contract change",
  "verification": "fresh proving command"
}
```

## Skill 类型画像

| 类型 | 目标等级 | 强约束维度 | 说明 |
| --- | --- | --- | --- |
| Pipeline skill | L2 起，冲 L3 | D1-D7 | 涉及阶段流转、handoff、验证闭环 |
| 审计/验证 skill | L2 起，冲 L3 | D1、D3、D4、D6、D7 | 结论必须证据化，默认只读 |
| 创建/改造 skill | L2 起，冲 L3 | D1、D2、D4、D6、D8 | 与 `skill-creator`、`skill-harness` 边界清晰 |
| 工具类 skill | L1 起，冲 L2 | D1、D3、D4、D6 | 输入输出与权限边界优先 |
| manual-only skill | L1 起，按职责提升 | D1、D4、D7 | 两端暴露策略需要一致 |
