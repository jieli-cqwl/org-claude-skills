# Skill 质量标准

> 触发条件：创建新 Skill、评估 Skill 质量、优化已有 Skill、执行 `/scan` Skill 质量扫描时读取。

本文是 first-party Skill 质量标准真源。Phase 1 MVP 的适用范围：standard-chain first-party Skills 与 skill-harness。

Phase 1 只裁决 Skill runtime surface 是否清晰、可加载、可遵循、可审计。D1-D8 是运行时表面质量标准；D9 在 Phase 1 只作为 readiness 边界，不能被解释为有效性、retain、retire 或 proven-effectiveness 结论。

skill-harness 消费本标准，不定义本标准，不自证正确，不做最终生命周期决定。

质量结论必须可被证据支持。Phase 1 使用 PASS / FAIL / COMMENT findings，且需要绑定文件位置、影响、证据和验证方式。JSON 由消费触发，不由审计存在触发；当机器消费者、跨轮状态、自动门禁、发布验证或派生报告需要读取结果并作出阻断、比较、状态转移或发布判定时，JSON artifact 才成为机器事实源，Markdown 和 HTML 是派生视图。否则结构化 Markdown 是默认人类审计输出。

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
- 上下文预算服务触发和执行稳定性，但固定行数阈值不单独产生 FAIL。

## 本地启发式

line-count budgets 只能作为 COMMENT 或 warning-level signal。固定行数阈值不是 Phase 1 hard quality standard。

当行数或上下文预算产生风险时，finding 必须说明具体运行时影响：例如 active path 噪音导致触发混淆、低频细节没有下沉到资源、或 reference 合同不可消费。没有这种影响证据时，行数只能提示人工复核。

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

- 每个 PASS / FAIL / COMMENT finding 都有文件、位置、证据、影响和验证方式。
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

D9 在完整生命周期中仍由 `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md` 和 `{{RUNTIME_HOME}}/reference/Skill生命周期管理.md` 细化。Phase 1 不裁决 retain、optimize 或 retire。

Phase 1 只检查 readiness evidence 是否存在并被正确解释：`eval-type`、`evals/evals.json`、偏好锚点或 grader dimensions、`evals/lifecycle-review.json` 可以证明 review frame 存在；它们不能证明有效性、保留、退役或长期价值。

Readiness 基线：

- `SKILL.md` frontmatter 声明 `eval-type`，值为 `capability_uplift`、`encoded_preference` 或 `mixed`。
- `evals/evals.json` 的 `eval_type` 与 frontmatter 匹配，并至少包含 3 个 eval 场景。
- `capability_uplift` 或 `mixed` Skill 声明 `grader_dimensions` 和 with-skill / without-skill baseline 路径。
- `encoded_preference` 或 `mixed` Skill 声明 5-10 个偏好锚点。
- `evals/lifecycle-review.json` 存在并记录 evidence refs、measurement status 与下一步真实评估计划。

反例：

- Skill 上线后没有任何 eval 场景或复审记录。
- 模型升级后仍沿用旧 uplift 结论。
- 没有经验数据却把初始 readiness 写成有效性或生命周期结论。
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
| L2 闭环 | 能稳定独立运行并被审计 | D1-D6 达标；D7 无阻塞性漂移；D8 不阻断理解；D9 readiness frame 不被误读 |
| L3 卓越 | 能跨场景复用、验证和演化 | D1-D8 达标；eval/benchmark/跨模型/迁移证据齐全；D9 effectiveness 另按生命周期标准评估 |

评级按最低阻塞维度收敛。D4 或 D6 出现硬失败时，不能评为 L2 或 L3。

## 评估方法

Phase 1 使用 findings，不使用数字评分。逐项输出 PASS / FAIL / COMMENT。

| 结果 | 含义 |
| --- | --- |
| PASS | 该 MVP quality concern 合同完整，有证据和验证方式 |
| FAIL | 阻断 Skill 被可靠加载、遵循或审计的问题 |
| COMMENT | warning-level 风险或改进建议，不单独阻断 |

`FAIL` 只用于阻断 Skill 被可靠加载、遵循或审计的问题。`COMMENT` 用于 warning-level 风险，包括表达、重复、行数或上下文预算信号；除非有证据证明影响角色、触发、加载、权限、输出或证据合同，否则 COMMENT 不阻断。

每个 finding 必须映射到一个 MVP quality concern。只引用 `skill-harness` 维度、历史标签、固定行数阈值或 D9 readiness metadata 不能作为阻断依据。

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
