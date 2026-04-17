# Skill 质量标准 v2

> 触发条件：创建新 Skill、评估 Skill 质量、优化已有 Skill、执行 `/scan` Skill 质量扫描时读取。

本文是 first-party Skill 的质量标准真源。它被 `skill-creator`、`skill-optimizer`、`scan`、install/runtime 检查和人工 review 消费。本文不作为 workflow、adapter、community canonical 的统一总规范。

v2 替换现行 D1-D7。旧 D1-D7 只作为迁移词汇保留在映射表中；长期质量评级使用 v2 D1-D8 与 L1/L2/L3。

## 核心裁决

Skill 质量标准采用 Harness Engineering 模型。质量判断不只评价 `SKILL.md` 文本结构，而是评价 Skill 在触发、加载、artifact、权限、流程、验证、演化和复用上的运行时合同。

对审计、优化、验证、流转类 Skill，JSON artifact 是机器事实源。Markdown 和 HTML 是派生视图。人类修改事实时修改上游源或 JSON，再重新渲染视图。

质量结论必须可被证据支持。PASS、PARTIAL、FAIL 需要绑定文件位置、影响、证据和验证方式。

## 权威边界

| 消费方 | 使用方式 | 不拥有的职责 |
| --- | --- | --- |
| `skill-creator` | 创建新 Skill 时读取质量目标，生成 eval assertions 或评估提示 | 不拥有本地质量评级真源 |
| `skill-optimizer` | 审计已有 Skill 时按 v2 维度输出 findings、计划和验证 artifact | 不创建新 Skill，不建立第二套成熟度 |
| `scan` | 对 Skill 目录做静态巡检，输出 v2 可机械检测子集 | 不替代人工裁决、eval 和 semantic validation |
| install/runtime | 校验 adapter、manual-only、retired skill、运行时噪音 | 不定义 Skill 质量维度 |
| reviewer | 按 v2 维度挑战完整性、证据和边界 | 不以主观偏好覆盖 rules 与标准 |

## v2 质量维度

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

## D1 触发与路由合同

D1 定义 Skill 何时被触发、何时不能被触发、与相邻 Skill 如何分流。

L2 基线：

- frontmatter 包含 `name` 与 `description`。
- `description` 同时表达能力边界和触发场景。
- 创建、优化、审计、验证、迁移等相邻场景有明确路由。
- manual-only Skill 同时声明 Claude 侧 invocation 限制和 Codex 侧 adapter 暴露策略。
- 正触发、反触发、邻近 Skill 冲突样例可被 eval 或人工审计消费。

反例：

- `description` 只写能力名，没有触发场景。
- 优化已有 Skill 的请求路由到创建工具。
- manual-only 只在 Claude frontmatter 声明，Codex adapter 仍自动暴露。

## D2 渐进加载与上下文预算

D2 定义 LLM 在什么条件下读取 `SKILL.md`、`references/`、`examples/`、`rules/`、`schemas/` 和其他资源。

L2 基线：

- `SKILL.md` 只承载高频入口、硬门禁、流程骨架和输出合同。
- 低频方法论、长示例、规则细则、schema 和模板进入独立资源目录。
- 每个被 `SKILL.md` 路由的资源都有契约：Trigger、Read、Expect、Consume、Evidence、Sync。
- reference 不通过多层跳转隐藏关键规则。
- 上下文预算按 Skill 类型分档；预算服务触发和执行稳定性。

行数基线：

| Skill 类型 | L2 基线 | L3 卓越 | 理由 |
| --- | --- | --- | --- |
| Pipeline skill | <=250 行 | <150 行 | 多轮共创和阶段 gate 需要流程骨架 |
| 审计/验证 skill | <=200 行 | <120 行 | 证据字段多，长方法论下沉到资源 |
| 独立 skill | <=150 行 | <80 行 | 单轮或少轮交互，保持入口精简 |
| 工具类 skill | <=100 行 | <60 行 | 简单 I/O 和权限边界优先 |
| hook-only skill | <=60 行 | <40 行 | 入口只保留触发、输入、输出和失败状态 |

官方 `skill-creator` 给出的 `SKILL.md < 500 行` 是通用软边界。本体系对 first-party Skill 使用更紧的本地分档。

反例：

- `SKILL.md` 内嵌大量低频方法论。
- 裸路径引用 `references/x.md`，未说明触发条件和内容预期。
- reference 再嵌套引用 reference，导致运行时只读到部分规则。

## D3 输入输出与 artifact 合同

D3 定义 Skill 输入、输出、运行时 artifact、schema 和下游消费者。

L2 基线：

- 输入包含前置文件、状态、授权范围、外部依赖和缺失时的终止行为。
- 输出包含路径、格式、必填字段和消费方。
- JSON artifact 字段进入合同前通过 consumer-first gate。
- schema 证明形状，semantic validator 证明状态、证据、消费者和流转一致性。
- Markdown/HTML 报告声明派生来源，不反向成为机器事实源。

反例：

- 输出只写“生成报告”，没有路径、格式和消费者。
- JSON 字段没有下游消费方。
- 人类改了 Markdown 报告后把它当成 runtime fact source。

## D4 执行安全与权限边界

D4 定义 Skill 能使用什么工具、何时只读、何时可写、脚本如何准入、hook 如何接入。

L2 基线：

- audit、review、explain 默认只读。
- 写文件、删除、迁移、提交、外部写 API 需要本轮明确授权和精确范围。
- `allowed-tools` 与实际职责一致，review 类 Skill 不默认拥有 Edit。
- scripts 有 manifest、超时、参数约束、路径限制、退出码语义和验证命令。
- hook 接入需要 adapter contract、owner、failure state 和 rollback。

反例：

- 审计 Skill 默认允许 Edit。
- 脚本无 manifest、无超时、无参数边界。
- hook 直接接入全局 registry，却没有失败状态和回滚合同。

## D5 流程自治与异常控制

D5 定义 Skill 能否在独立运行时闭环，并在失败时停在正确状态。

L2 基线：

- 前置条件不满足时终止并说明缺失项。
- 流程步骤可按顺序执行，不能靠隐含会话记忆补关键上下文。
- 分支条件、退出条件、失败状态和回退动作可被审计。
- SubAgent/fork 有输入合同、输出合同、handoff 证据和接受标准。
- pipeline Skill 明确上游输入、下游消费者和阶段边界。

反例：

- 缺少输入时继续执行。
- fork 子代理依赖主会话未显式提供的历史。
- 失败后继续推进下游交付。

## D6 验证与证据

D6 定义质量结论如何被证明。

L2 基线：

- 每个 PASS/PARTIAL/FAIL 都有文件、位置、证据、影响和验证方式。
- fresh proving command 直接对应成功标准。
- eval 覆盖正触发、反触发、邻近 Skill、缺参、权限不足、格式诱导和失败路径。
- benchmark 用于证明改造收益，不能替代失败路径验证。
- human review 只覆盖主观判断项，不能覆盖硬门禁失败。

反例：

- “看起来符合”作为质量结论。
- 用局部 grep 绿灯替代运行时 artifact 验证。
- 用 Mock 或跳过外部交互伪造验收信心。

## D7 演化与兼容性

D7 定义 Skill 如何随官方工具、本地 runtime、adapter、模型和旧入口变化而保持可维护。

L2 基线：

- official/community source 有来源锁定和本地补丁边界。
- adapter、install、runtime catalog 和 retired skill 规则保持同步。
- 迁移、退役和兼容策略有验证命令。
- 跨模型测试用于 L3 质量证明，尤其覆盖触发、流程理解和格式遵循。
- 旧入口退出后不保留无消费者目录。

反例：

- 旧 Skill 入口退役后仍被安装到运行时。
- `agents/openai.yaml` 暴露能力与 `SKILL.md` 描述不一致。
- community canonical 被改写后无法追溯来源。

## D8 人类可读与组织复用

D8 定义人类如何理解、审查、复用和维护 Skill。

L2 基线：

- examples 独立于 reference，服务触发、反例、失败路径和报告解释。
- rendered Markdown/HTML 报告可追溯到 JSON artifact。
- 术语、维度、评级和严重度在标准、scan、optimizer、review 报告中一致。
- 5/10/30 可作为学习成本和可用性信号，但不单独证明质量收益。
- 文档表达服务执行，不用长解释替代硬合同。

反例：

- reference、examples、rules 混在同一文件，LLM 难以按场景加载。
- 报告视图无法追溯到结构化证据。
- 同一类问题在 scan 和 optimizer 中使用不同评级词。

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

## L1/L2/L3 分级

| 级别 | 定位 | 判定含义 |
| --- | --- | --- |
| L1 可用 | 能被触发并完成单次任务 | D1、D3、D5 有最小合同；D6 有最小完成校验 |
| L2 闭环 | 能稳定独立运行并被审计 | D1-D6 达标；D7 无阻塞性漂移；D8 不阻断理解 |
| L3 卓越 | 能跨场景复用、验证和演化 | D1-D8 达标；eval/benchmark/跨模型/迁移证据齐全 |

评级按最低阻塞维度收敛。D4 或 D6 出现硬失败时，不能评为 L2 或 L3。

## 评估方法

逐维度输出 PASS/PARTIAL/FAIL。

| 结果 | 含义 |
| --- | --- |
| PASS | 该维度合同完整，有证据和验证方式 |
| PARTIAL | 该维度有合同雏形，但消费者、证据、失败路径或同步义务缺失 |
| FAIL | 该维度缺失，或存在越权、伪证、错误路由、失败后继续等硬风险 |

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
| 创建/改造 skill | L2 起，冲 L3 | D1、D2、D4、D6、D8 | 与 `skill-creator`、`skill-optimizer` 边界清晰 |
| 工具类 skill | L1 起，冲 L2 | D1、D3、D4、D6 | 输入输出与权限边界优先 |
| manual-only skill | L1 起，按职责提升 | D1、D4、D7 | 两端暴露策略需要一致 |

## 与 `skill-creator` 的关系

`skill-creator` 是创建与迭代工具，v2 是质量目标。

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

## Codex 双端兼容检查

新增或修改 Skill 时需确认以下条件：

| 检查项 | 必需 | 说明 | v2 维度 |
| --- | --- | --- | --- |
| `SKILL.md` 有 `name` + `description` | 是 | 两端共用的触发依据 | D1 |
| `description` 能表达能力与触发场景 | 是 | Codex 依赖它理解适用时机 | D1 |
| `agents/openai.yaml` 存在 | Codex 自动暴露时需要 | 表示 Codex 自动暴露面 | D1、D7 |
| `short_description` 25-64 字符 | Codex 自动暴露时需要 | Codex UI 约束 | D7、D8 |
| `default_prompt` 包含 `$skill-name` | Codex 自动暴露时需要 | Codex 触发模板 | D1 |
| Claude 专用字段 | 按 Skill 类型 | `user-invocable`、`allowed-tools`、`hooks` | D4、D7 |

manual-only 需要同时处理 Claude frontmatter 与 Codex adapter 移除。

## 迁移对照

| 旧模型 | v2 去向 |
| --- | --- |
| D1 结构合规 | 拆入 D1 触发与路由、D2 渐进加载、D8 可读复用 |
| D2 闭环自治 | 升级为 D5 流程自治与异常控制 |
| D3 I/O 契约 | 升级为 D3 输入输出与 artifact 合同，并覆盖 schema/consumer |
| D4 角色与对抗 | 拆入 D5 流程自治、D6 证据、D8 复用 |
| D5 验证即证据 | 升级为 D6 验证与证据 |
| D6 Token 效率 | 升级为 D2 渐进加载；reference 契约拆入 D2/D3/D7 |
| D7 跨模型适配 | 升级为 D7 演化与兼容性 |

旧 D1-D7 不作为新的审计输出维度。

## 适用边界

- 本文件默认用于 `shared/skills/*` 下的 first-party Skill 评估。
- `community/` 下的本地 canonical runtime 不强行套用本文件，仍以社区结构、来源锁定和 adapter 兼容模型为基线。
- 平台 adapter、OpenSpec command、runtime truth 文档使用各自 authority，不纳入本文件统一评级。
- 对 `community/` 的本地化只能处理说明文字、路径统一、平台 metadata 和兼容补丁；不能改写核心流程顺序、角色边界和状态机语义。

## 标准来源

| 规则 | 来源 |
| --- | --- |
| description 作为主触发合同 | 官方 `skill-creator` |
| 渐进加载与资源下沉 | 官方 Skill anatomy 与本地运行经验 |
| Harness JSON artifact 与 validator | 本地 `skill-optimizer` 设计与实现 |
| 证据先于结论 | 本地 rules 与完成前验证规范 |
| 权限、脚本、hook 边界 | 本地安全与执行纪律 |
| L1/L2/L3 成熟度 | 本地历史质量模型，按 v2 重写语义 |
