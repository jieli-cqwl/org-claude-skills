# Skill 质量标准

> 触发条件：创建新 Skill、评估 Skill 质量、优化已有 Skill、执行 `/scan` Skill 质量扫描时读取。

本文是 first-party Skill 质量标准真源，采用 Harness Engineering 模型。质量判断评价 Skill 在触发、加载、artifact、权限、流程、验证、演化、复用和存在合理性上的运行时合同，而不仅仅评价 `SKILL.md` 文本结构。默认用于 `shared/skills/*` 下的 first-party Skill 评估；`community/` 以社区结构和 adapter 兼容为基线。

质量结论必须可被证据支持。PASS、PARTIAL、FAIL 需要绑定文件位置、影响、证据和验证方式。JSON 由消费触发，不由审计存在触发；当机器消费者、跨轮状态、自动门禁、发布验证或派生报告需要读取结果并作出阻断、比较、状态转移或发布判定时，JSON artifact 才成为机器事实源，Markdown 和 HTML 是派生视图。否则结构化 Markdown 是默认人类审计输出。

## 质量维度

| 维度 | 名称 | 保护的风险 | 核心消费者 |
| --- | --- | --- | --- |
| D1 | 触发与路由合同 | 错触发、漏触发、邻近 Skill 冲突、创建/优化入口混淆 | runtime、adapter、`skill-creator`、`skill-harness` |
| D2 | 渐进加载与上下文预算 | LLM 读取过多、读取不足、读错资源、reference 路由不稳定 | runtime、`scan`、`skill-harness` |
| D3 | 输入输出与 artifact 合同 | 输出不可消费、状态不可流转、Markdown 与机器事实混用 | `skill-harness`、scripts、hooks、renderer |
| D4 | 执行安全与权限边界 | audit 写文件、review 越权、script 无准入、hook 失控 | runtime、install、hooks、reviewer |
| D5 | 流程自治与异常控制 | 前置条件缺失、失败后继续、handoff 丢上下文、状态不可恢复 | pipeline Skill、SubAgent、hooks |
| D6 | 验证与证据 | 自证式结论、局部绿灯冒充质量、Mock 冒充真实验收 | reviewer、`skill-harness`、CI gate |
| D7 | 演化与兼容性 | 迁移残留、旧入口噪音、adapter 漂移、跨模型失效 | install、runtime catalog、maintainer |
| D8 | 人类可读与组织复用 | 标准难学、报告难审、样例不可复用、团队口径分裂 | 用户、reviewer、团队维护者 |
| D9 | 存在合理性 | Skill 价值衰减未被发现、偏好漂移未被检测、退役延迟导致上下文浪费 | `skill-harness`、skill 维护者、用户 |

## D1 触发与路由合同

D1 定义 Skill 何时被触发、何时不能被触发、与相邻 Skill 如何分流。

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

- 输出只写"生成报告"，没有路径、格式和消费者。
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

- "看起来符合"作为质量结论。
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
- Codex 自动暴露时需确保 `agents/openai.yaml` 存在、`short_description` 25-64 字符、`default_prompt` 包含 `$skill-name`。

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

## D9 存在合理性

D9 定义一个 Skill 为什么仍应存在、如何证明它比裸模型或普通提示更有价值，以及何时进入优化或退役流程。详细协议见 `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`，生命周期门禁见 `{{RUNTIME_HOME}}/reference/Skill生命周期管理.md`。

L2 基线：

- `SKILL.md` frontmatter 声明 `eval-type`，值为 `capability_uplift`、`encoded_preference` 或 `mixed`。
- `evals/evals.json` 的 `eval_type` 与 frontmatter 匹配，并至少包含 3 个 eval 场景。
- `capability_uplift` 或 `mixed` Skill 声明 `grader_dimensions` 和 with-skill / without-skill baseline 路径。
- `encoded_preference` 或 `mixed` Skill 声明 5-10 个偏好锚点。
- `evals/lifecycle-review.json` 记录最近一次 `retain`、`optimize` 或 `retire` 结论、证据引用和下一步。

反例：

- Skill 上线后没有任何 eval 场景或复审记录。
- 模型升级后仍沿用旧 uplift 结论。
- 没有经验数据却把初始 readiness 写成 `retain`。
- 退役候选没有人工确认和影响范围记录。

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
| L2 闭环 | 能稳定独立运行并被审计 | D1-D6 达标；D7 无阻塞性漂移；D8 不阻断理解；D9 有初始评审记录 |
| L3 卓越 | 能跨场景复用、验证和演化 | D1-D9 达标；eval/benchmark/跨模型/迁移/生命周期复审证据齐全 |

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
  "dimension": "D1|D2|D3|D4|D5|D6|D7|D8|D9",
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
| 创建/改造 skill | L2 起，冲 L3 | D1、D2、D4、D6、D8、D9 | 与 `skill-creator`、`skill-harness` 边界清晰 |
| 工具类 skill | L1 起，冲 L2 | D1、D3、D4、D6 | 输入输出与权限边界优先 |
| manual-only skill | L1 起，按职责提升 | D1、D4、D7 | 两端暴露策略需要一致 |
