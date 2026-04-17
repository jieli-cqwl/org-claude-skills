# skill-optimizer 最终设计

## 文档关系

`design.md` 是后续 `tasks.md`、`plan.md` 和实现工作的设计真源。它只冻结长期设计裁决、目标边界、交付形态和验收口径，不承载外部 review 过程和 runtime schema 细则。

配套文档的职责如下：

| 文件 | 职责 | 权威边界 |
| --- | --- | --- |
| `source-notes.md` | 极客时间 Skills 课程 7 讲的 source map、证据等级和不可外推边界 | 课程证据真源 |
| `review-report.md` | Claude 外部挑战输入 | 外部意见，不直接约束实施 |
| `review-resolution.md` | 对 Claude 反馈的采纳、拒绝和转化裁决 | review 仲裁真源 |
| `runtime-blueprint.md` | JSON artifact、schema、状态、validator、renderer、hook adapter 的工程合同 | Harness runtime 细节真源 |
| `design.md` | skill-optimizer 的最终设计裁决 | 计划与实现的上游真源 |

## 背景

本设计围绕 Harness Engineering 建立 `skill-optimizer`。目标不是再写一份 Skill 写作总结，而是把 Skill 的触发、加载、引用、权限、执行、验证和演化变成可审计、可验证、可迁移的工程合同。

极客时间「Skills 技能系统」7 讲是重要信息来源，提供 Skill 结构、触发、渐进式披露、SubAgent 配合和开放标准等方法论。课程信息沉淀见 `source-notes.md`。官方 `skill-creator` 负责从零创建、评估和迭代 Skill；`skill-optimizer` 负责优化已有 Skill 或草稿 Skill 的质量、稳定性和工程可验证性。

## 总裁决

`skill-optimizer` 保留 Harness Engineering 方向。JSON runtime artifact、schema、semantic validator、eval 和派生 Markdown/HTML 视图是最终交付的一部分，不退回 Markdown-only 路线。

Claude review 的核心提醒被采纳为边界约束：每个 runtime 字段、目录、脚本、schema 和 hook adapter 都要有明确消费者；没有消费者的内容进入 reference 或渲染视图，不进入 runtime 合同。外部 review 不能推翻 Harness 目标，但能约束 Harness 的进入条件。

实施可按依赖切片推进，但最终交付边界是完整闭环：Skill 包、runtime artifact、validator、renderer、eval、迁移兼容和验证证据全部可用。任一切片未通过对应 fresh proving command 时，不声明交付完成。

## 目标

1. 建立 `shared/skills/skill-optimizer/`，作为优化已有 Skill 或草稿 Skill 的默认入口。
2. 让 `skill-optimizer` 读取目标 Skill 后，输出带证据的结构化审计、优化计划和验证结果。
3. 用 JSON runtime artifact 作为机器可消费事实源，用 Markdown/HTML 作为派生视图。
4. 用 schema validation、semantic validation、eval 和 fresh proving command 验证改造质量。
5. 彻底退役 `new-skills`，避免旧入口继续制造触发噪音。
6. 将课程方法论、本仓库 rules/reference、官方 skill-creator 经验和本地 Harness 推断分层标注，防止权威混用。

## 非目标

`skill-optimizer` 不替代官方 `skill-creator` 的从零访谈、with/without eval 编排和 description 触发优化能力。

`skill-optimizer` 不把课程原文、Harness 文章或外部 review 全量沉淀为知识库。外部材料进入仓库时，只能变成 source map、设计裁决、审计维度、runtime 合同或验证证据。

`skill-optimizer` 不在首个交付闭环中改写全仓标准链路，不直接替换 product/design/tech-lead/qa 等既有 Markdown 模板。跨链路推广需由 eval 和失败样本证明收益。

## 证据与规范强度

| 等级 | 来源 | 可进入的规范强度 |
| --- | --- | --- |
| E1 | 课程正文明确表达的原则或机制 | 审计维度；经本仓库样例验证后可硬化 |
| E2 | 课程案例归纳出的工程模式 | 默认路径或反模式提示 |
| E3 | 本仓库 rules/reference/contracts 的既有约束 | MUST 级门禁 |
| E4 | 官方 `skill-creator` 或 Codex/Claude Skill 文档的工具约束 | 兼容性约束和流程参考 |
| E5 | 主线程、agent team、Harness 转译和 Claude review 裁决 | 试点假设、实验协议或蓝图 |

硬门禁只来自 E3，或来自 E1 且绑定本仓库验证样例。E5-only 结论不进入 `SKILL.md` HARD-GATE；它进入 `runtime-blueprint.md`、eval 或回退合同。

## 核心运行链路

`skill-optimizer` 审计目标 Skill 时，按六段运行链路组织发现：

```text
触发 → 加载 → 决策 → 执行 → 验证 → 演化
```

| 环节 | 审计对象 | 典型证据 |
| --- | --- | --- |
| 触发 | description、manual-only、相邻 Skill 冲突、禁触发样例 | frontmatter、触发 fixture、adapter |
| 加载 | `SKILL.md` 内联体量、渐进式披露、resource 路由 | 文件行数、引用合同、资源索引 |
| 决策 | 分支条件、reference 契约、规则优先级 | source marker、rules 路径、反例 |
| 执行 | allowed-tools、script manifest、SubAgent/fork、危险动作确认 | 权限 profile、脚本准入、handoff |
| 验证 | fresh proving command、schema、semantic invariant、eval | 命令输出、artifact、测试结果 |
| 演化 | 迁移、benchmark、质量收益、legacy 兼容 | 前后对比、coverage 表、退出条件 |

审计发现必须绑定目标文件、具体位置、问题类型、影响、证据等级、改造建议和验证方式。缺少证据的观察只能进入说明区，不进入 FAIL 结论。

## 产物模型

最终交付包含机器事实源和人类视图两层。

| 产物 | 角色 | 消费者 |
| --- | --- | --- |
| `skill-audit.json` | 目标 Skill 的结构化审计事实源 | semantic validator、renderer、人工复审、优化计划生成 |
| `optimization-plan.json` | 被采纳改造策略、文件边界、风险和回退 | `tasks.md`、`plan.md`、执行 Agent |
| `verification-result.json` | schema、semantic validation、fresh command、eval 结果 | final report、hook adapter、benchmark |
| `audit-report.md` | 给人读的审计报告 | 用户、reviewer |
| `audit-report.html` | 可视化派生视图 | 用户、长期复盘 |

JSON artifact 是机器事实源；Markdown/HTML 是派生视图。人类修改事实时修改 JSON 或上游源文件，再重新渲染视图。Markdown/HTML 不能反向成为 runtime fact source。

Runtime 细节以 `runtime-blueprint.md` 为准。`design.md` 只冻结三条原则：

1. 字段进入 JSON 前需要通过 consumer-first gate。
2. schema 只证明形状，semantic validator 证明状态、证据、流转和消费者一致性。
3. renderer 只消费 JSON 与 evidence refs，输出需带 source hash 和 renderer version。

## Skill 包结构

目标目录为 `shared/skills/skill-optimizer/`。

| 路径 | 职责 | 创建条件 |
| --- | --- | --- |
| `SKILL.md` | 入口、触发、流程路由、关键 gate | 必需 |
| `agents/openai.yaml` | Codex 暴露和触发 adapter | 必需 |
| `rules/` | skill-local 规则、权限和职责边界 | 与全局 rules 不同且有消费者 |
| `references/` | 审计方法、反模式、迁移说明、agent prompt | 被 `SKILL.md` 契约式引用 |
| `examples/` | 正例、反例、触发/非触发样例 | 被 eval 或报告使用 |
| `schemas/` | runtime artifact schema 与 state vocabulary | runtime artifact 进入交付 |
| `scripts/` | 确定性检查、validator、renderer、manifest 校验 | 有 manifest、测试和超时边界 |
| `evals/` | seed dataset、assertions、manifest command case、benchmark input | 有复跑命令、结果 artifact 和证明边界说明 |
| `templates/` | Markdown/HTML 派生视图模板 | 输出结构稳定且 renderer 消费 |
| `hooks/` | hook adapter 说明和局部入口 | validator 稳定后接入 |

目录创建不作为验收目标。没有消费者、验证路径和失败边界的目录不创建。

## 触发与权限

`skill-optimizer` 是审计与优化 Skill 的入口，不处理通用代码 review、不接管官方 `skill-creator` 的新建流程。

| 场景 | 触发方式 | 权限 |
| --- | --- | --- |
| 审计已有 Skill | 自动触发或手动入口 | 只读 |
| 生成优化计划 | 审计完成后由用户确认 | 只读，输出 artifact |
| 执行改造 | 用户明确要求实施后进入开发流程 | 精确写范围 |
| commit/deploy/delete | 不由 `skill-optimizer` 自动执行 | 本轮显式授权 |

review、audit、explain 默认只读。涉及写文件、迁移、删除、提交或外部写 API 时，必须转入实施模式并重新确认范围。

## 契约式引用

课程核心契约包含触发条件、读取对象和内容预期。本仓库扩展消费方式、证据要求和同步义务。

关键 runtime reference 使用完整契约：

```markdown
当 {动作/判断/异常} 时：
→ 读取 `{path}` 获取 {内容预期}，用于 {消费方式}；输出需体现 {证据要求}；引用变化时同步 {同步义务}
```

背景材料、一次性调研和历史注释不强制写同步义务。进入 `SKILL.md` 路由、影响判断、影响权限或影响验证的 reference 需要完整契约。

## SubAgent 与 fork

Skill 管 HOW：方法、规范、流程和判断框架。SubAgent 管 WHO/WHAT：独立执行者、职责隔离、并行分析和对抗审查。

显式 SubAgent 通过 `skills:` 预加载 Skill 时，Skill 内容在子代理创建时注入。`context: fork` 适合一次性、自包含、只需回传报告的独立任务。fork 子代理不能依赖主会话完整历史。

Fork input contract 包含 `task`、`scope`、`input_refs`、`required_context`、`excluded_context`、`allowed_tools`、`expected_output` 和 `acceptance_basis`。Handoff 包含 `scope`、`consumer`、`evidence`、`uncertainty`、`blockers`、`output_contract`、`acceptance_basis`、`decision_required` 和 `next_step`；pipeline 场景增加 `stage_id` 与 `input_from`。

## 与 D1-D7 的关系

`shared/reference/Skill质量标准.md` 继续作为质量真源。`skill-optimizer` 不重建一套平行评级，而是把运行链路审计映射回 D1-D7。

| skill-optimizer 维度 | 映射 |
| --- | --- |
| 触发契约 | D1 触发准确性、D2 适用边界 |
| 渐进加载 | D6 上下文效率 |
| 契约式引用 | D6 上下文效率、D7 可维护性 |
| 权限与脚本 | D3 安全性、D5 可验证性 |
| SubAgent/fork | D4 流程清晰度、D5 可验证性 |
| Runtime artifact | D5 可验证性、D7 可维护性 |
| eval 与 benchmark | D5 可验证性、L3 组织复用 |
| 旧入口退役 | D7 可维护性 |

成熟度模型只作为诊断输出维度，不替代 L1/L2/L3。

## new-skills 退役

`new-skills` 不再保留为 legacy compatibility。官方 `skill-creator` 负责默认创建入口；`skill-optimizer` 负责优化已有或草稿 Skill。安装器把旧运行时残留视为 retired skill，安装时归档清理。

| 源路径 | 目标策略 | 验证命令 | 回滚动作 | 退出条件 |
| --- | --- | --- | --- | --- |
| `shared/skills/new-skills/` | 删除旧 Skill 入口、adapter、references、scripts | `bash tests/test-skill-optimizer-migration.sh` | 恢复本次删除补丁 | `skill-creator` 与 `skill-optimizer` 分工通过安装和 adapter 测试 |
| 运行时旧 `skills/new-skills` 残留 | 安装时按 retired skill 归档清理 | `bash tests/test-install-smoke.sh`; `bash tests/test-runtime-integrity.sh` | 恢复 retired list 变更 | Claude/Codex runtime 均不再出现该目录 |
| eval 迁移样例 | 从 legacy routing 改为 retired entry 样例 | `bash tests/test-skill-optimizer-evals.sh` | 恢复 eval case | 退役请求不再把 `new-skills` 作为目标 Skill |

接入全局 hook registry 仍需要独立用户确认。

## Runtime 与 Hook 边界

Hook 是拦截和门禁 adapter，不替代 Skill 判断。首个完整交付包含 hook adapter 合同和可验证输入输出；全局 hook registry 接入在 semantic validator、state vocabulary 和失败样例稳定后执行。

`runtime-blueprint.md` 冻结 hook lifecycle 字段：`phase`、`trigger`、`input_artifact`、`allowed_action`、`output_artifact`、`failure_state`、`owner` 和 `rollback`。

## 验证设计

验证分为五层：

| 层级 | 证明内容 | 典型命令 |
| --- | --- | --- |
| 静态结构 | 文件树、frontmatter、adapter、目录消费者存在 | install smoke、contract check |
| schema validation | JSON 形状、类型、枚举、必填字段 | schema validator |
| semantic validation | 证据、状态、流转、消费者和 design anchor 一致 | semantic validator |
| eval | 触发、非触发、冲突、权限、失败路径 | eval runner |
| human review | 主观判断项和策略裁决 | review-resolution 覆盖表 |

Seed dataset 包含触发、非触发、相邻 Skill 冲突、缺参/错参/权限不足、格式诱导和迁移兼容样例。每条 case 记录目标 Skill 版本、邻近 Skill 版本、输入、期望决策、评分器、命令和通过条件。

5/10/30 只证明可用性，不单独证明质量收益。质量收益以触发误判减少、reference 契约完整、runtime 字段稳定、失败路径覆盖提升、人工复审发现减少和 contract test 通过为准。

## 实施追踪契约

后续实施按如下链路追踪：

```text
source-notes.md source marker
→ review-resolution.md 裁决
→ design.md 设计锚点
→ runtime-blueprint.md 字段合同
→ tasks.md AC
→ plan.md Task step
→ file diff
→ fresh proving command
```

`tasks.md` 的每个 AC 需包含 `Design anchor`、`Verification method`、`Fresh proving command` 和 `Pass/Fail condition`。`plan.md` 的每个 Task 需包含 `Files`、`Change boundary`、`Verification command` 和 `Expected output`。

只改名称、只移动文件或只改格式的任务不能单独通过；它需要绑定至少一个运行链路环节，并用验证命令证明语义已承接。

## 设计锚点

| 锚点 | 范围 | 下游消费者 |
| --- | --- | --- |
| SO-TRIGGER-01 | description、manual-only、触发/非触发样例 | `SKILL.md`、eval |
| SO-LOAD-01 | 渐进加载、resource 路由、context budget | `SKILL.md`、reference |
| SO-REFERENCE-01 | 契约式引用、同步义务、证据要求 | reference audit、validator |
| SO-PERMISSION-01 | allowed-tools、权限 profile、危险动作确认 | frontmatter、review gate |
| SO-SCRIPT-01 | script manifest、参数校验、退出码 | scripts、hook adapter |
| SO-SUBAGENT-01 | fork input、handoff、pipeline | agent prompts、eval |
| SO-RUNTIME-01 | JSON artifact、schema、state、renderer | runtime-blueprint、validator |
| SO-VALIDATION-01 | seed dataset、audit fixture eval、benchmark、5/10/30 | eval runner、final report |
| SO-MIGRATION-01 | `new-skills` 退役、运行时残留清理、安装兼容 | migration tasks |
| SO-TRACKING-01 | source → design → task → proof 链路 | tasks、plan、final report |

## 风险与裁决

| 风险 | 裁决 |
| --- | --- |
| 外部 review 反向拉回 Markdown-only | 不采纳；Markdown/HTML 只做派生视图 |
| runtime artifact 变成无消费者字段堆积 | consumer-first gate 拦截 |
| E5 试点被写成硬门禁 | E5 只进蓝图、eval 或回退合同 |
| schema 只校验形状 | 增加 semantic validator |
| hooks 过早接入全局 registry | 先交付 hook adapter 合同和失败样例 |
| `new-skills` 与 `skill-creator` 抢入口 | 退役 `new-skills`，创建归 `skill-creator`，优化归 `skill-optimizer` |

## 最终裁决

`skill-optimizer` 是本仓库 Skill 治理的质量优化层。它的核心竞争力是用 Harness Engineering 把 Skill 的触发、加载、引用、执行、验证和演化转成稳定合同。

最终设计冻结为：JSON runtime artifact 作为机器事实源，schema 与 semantic validator 作为合同门禁，Markdown/HTML 作为派生视图，eval 与 fresh proving command 作为收益证据，`review-resolution.md` 作为外部反馈仲裁记录，`runtime-blueprint.md` 作为 Harness 细节合同。
