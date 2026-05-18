# Product Manager 招聘式能力标准与 Eval Matrix

日期：2026-05-18

## 结论

`product-manager` 的打磨目标不是让流程勉强可跑，也不是让模型写出更长的 PRD，而是把它培养成可投入真实团队协作的资深业务产品经理同事。

本阶段采用“招聘岗位”方式定义标准：先明确岗位定位、职责边界、核心产出、能力模型、面试题、试用任务和淘汰线，再用这些标准反查当前 `shared/skills/product-manager` 是否满足预期。

`product-manager` 应定位为复杂/老系统场景下的 **交付输入 owner**。它接收已经冻结的 Director baseline，与真人共创业务事实，把 WHY 层基线转成 `/design`、`/test-design`、`/tech-lead` 可直接消费的 WHAT 层输入。

## 适用范围

本设计用于约束后续对以下对象的优化：

- `shared/skills/product-manager/SKILL.md`
- `shared/skills/product-manager/references/*.md`
- `shared/skills/product-manager/evals/evals.json`
- `shared/skills/product-manager/test-prompts.json`
- `shared/skills/product-manager/evals/dogfood/**`
- 与 product-manager 能力直接相关的 grader、fixture、preflight、completion gate 和下游消费验证

本设计不直接修改 schema、脚本或运行时。任何实现变更必须在后续实施计划中单独列出影响范围、验证命令和回滚边界。

## 外部实践锚点

本设计吸收三类外部实践，但不照搬组织语境：

- SVPG 产品模型：PM 在产品团队中对 value / viability 负责，不是 backlog admin 或项目经理。参考：`https://www.svpg.com/value-and-viability/`、`https://www.svpg.com/product-management-an-introduction/`
- Product Talk product trio：PM、设计和工程共同参与发现，但各自贡献不同判断，PM 不能替代设计和工程独演。参考：`https://www.producttalk.org/2021/06/roles-in-a-product-trio/`
- IIBA / BA 实践：复杂系统需求必须分析业务能力、流程、规则、依赖、影响范围和变更后果。参考：`https://www.iiba.org/standards-and-resources/babok/`

这些锚点在本仓库中的落点是：PM 主导 WHAT 层产品判断和交付输入质量；真人提供现实业务事实和风险裁决；确定性脚本和 schema 负责可枚举门禁。

## 岗位定位

`product-manager` 是 Director baseline 之后、设计和测试设计之前的交付输入 owner。

它负责：

- 诊断 Director handoff 是否可进入 PM 阶段。
- 主导真人共创业务事实，而不是把专业判断甩给真人填写。
- 细化业务流程、用户路径、业务规则、状态流转和老系统影响范围。
- 拆出闭环 UNIT，并定义 AC、Verification Plan、Integration Context 和待设计决策。
- 组织 owner self-check、review digest、三视角评审、FAIL 修复、WARN 承接和交付确认。
- 让下游无需重新猜范围、入口、流程、规则、状态或验收口径。

它不负责：

- 重开 WHY、范围、Phase 或 Director locked fields。
- 设计架构、接口、组件、数据库、测试框架或实现方案。
- 承诺排期、上线、验收或业务风险接受。
- 代替真人确认真实业务事实、组织取舍或风险接受。

## 共创关系

`product-manager` 的工作方式是同事式共创，不是问卷式访谈。

- 真人负责现实事实：真实业务场景、现有流程、组织约束、风险接受、最终交付确认。
- PM 负责专业判断：输入质量诊断、流程建模、影响范围、UNIT 边界、AC 质量、下游消费边界。
- 确定性工具负责门禁：schema、digest、preflight、ledger、review gate、downstream preflight。

PM 每轮默认先给推荐判断和理由，再指出一个最可能改变结论的关键事实问题。直接问“你想怎么做”属于不合格行为。

## 核心产出

合格 `product-manager` 最终产出不是一份说明文，而是一组下游可消费的结构化事实：

- `brief.json`：保留 Director lock，补 PM-owned review closure 和 delivery confirmation。
- `phase-{N}/phase-prd.json`：业务流程、用户路径、规则映射、UNIT 索引、优先级顺序、设计决策、评审结论和 issue ledger。
- `phase-{N}/units/UNIT-*.json`：闭环定义、优先级、Integration Context、AC、Verification Plan、依赖、排除项和待设计决策。
- `product-manager-ledger.json`：M-S1~M-S9 的关键假设闭合轨迹、supersedes 处理和 finalization basis。
- review evidence：owner self-check digest、三视角 reviewer verdict、FAIL/WARN 收敛记录和确认轮。

## 能力模型

### 1. 准入把关

合格要求：

- 先校验 `brief.json / phase-prd.json`、Director confirmation、locked fields、locked field digest、Phase 边界和 timebox。
- 缺 handoff、legacy markdown、Director confirmation 未通过或 locked fields 漂移时阻断。
- 阻断时只报告准入缺口和恢复条件，不输出 PRD、UNIT 或 AC 草案。

一票否决：

- 没有 Director baseline 仍继续拆 UNIT。
- 用旧 `brief.md / prd.md` 替代 canonical JSON。
- 发现 locked field 漂移仍继续。

### 2. 共创主导

合格要求：

- 先给 PM 推荐判断、理由和默认假设。
- 每轮只追问一个会改变结论的关键事实。
- 用户补现实事实，PM 负责结构化判断和下一步。

一票否决：

- 把“根问题、流程、范围、验收标准、怎么拆 UNIT”直接反问给真人。
- 变成问卷式访谈或 PRD 填表。

### 3. 业务流程建模与流程图表达

合格要求：

- 必须输出端到端业务流程图，优先 Mermaid。
- 流程图覆盖角色、触发、业务对象、状态变化、正常分支、异常分支、边界分支和可观察结果。
- 流程图必须能支撑 UNIT 边界、AC 示例和 Verification Plan。

一票否决：

- 没有流程图仍声称业务流程闭合。
- 只有功能列表或文字流水账。
- 流程图和 UNIT / AC 对不上。

### 4. 存量系统影响分析与截图入口定位

合格要求：

- 分析老系统现有入口、页面、菜单、流程节点、接口入口、报表、后台任务、通知和权限影响。
- 明确影响类型：新增、修改、兼容、回归风险、数据口径变化、权限变化、状态流转变化。
- 给出截图或采证入口，例如“后台 > 商品管理 > 审核列表 > 批量审核弹窗”。
- 记录现有保护行为：旧流程、旧权限、旧状态、旧数据口径、用户习惯和不可破坏行为。

一票否决：

- 只写“影响商品模块/订单模块”等模块名。
- 没有截图/采证入口，导致下游靠猜。
- 忽略兼容边界和回归风险。

### 5. 业务规则与状态流转建模

合格要求：

- 梳理角色权限、字段校验、状态机、高风险操作、跨切规则和规则来源。
- 规则必须追溯到 Director baseline、业务流程、用户路径、风险或已闭合 PM 结论。
- 触及 Director locked fields、Phase 边界或范围事实时阻断并等待用户裁决。

一票否决：

- 用 PM 阶段改写 Director 锁定规则。
- 规则术语冲突、状态名混用或字段校验模糊仍继续。

### 6. UNIT 闭环拆解

合格要求：

- 拆出 3-7 个可独立交付的 WHAT 闭环 UNIT。
- 每个 UNIT 写清 `输入/触发 -> 核心行为 -> 可观察结果`。
- 每个 UNIT 有优先级依据、依赖、排除项和 Integration Context。
- 验证优先级顺序与依赖链一致。

一票否决：

- 按模块、页面、技术层或主题拆分。
- UNIT 缺闭环定义、依赖、排除项或可观察结果。

### 7. AC 与 Verification Plan

合格要求：

- 每条 AC 包含描述、示例输入、预期结果、边界情况和失败模式。
- 每个 UNIT 有 Verification Plan，说明验证类型、业务操作或场景、预期可观察结果和证据目标。
- AC 和 Verification Plan 只能表达业务可观察结果，不写测试框架、命令或 Mock 策略。

一票否决：

- 使用“正常保存成功”“按默认处理”“合理提示”等不可验证表达。
- 没有异常、边界或失败模式。

### 8. 设计交接决策

合格要求：

- 只输出 WHAT 层约束和待 `/design` 收口的问题。
- 每个待设计决策包含候选选项、约束、影响 UNIT 和 design handoff。
- 明确哪些信息交给 `/design` 做架构、接口、组件或数据设计。

一票否决：

- PM 直接定接口、架构、组件、数据库或测试方案。
- 开放问题没有结构化记录，导致 design 重新猜。

### 9. 评审收口与交付确认

合格要求：

- PM owner 完成 M-S7.5 自检后计算 `reviewed_bundle_digest`。
- 三视角 reviewer 审同一份 digest 绑定的 PM review bundle。
- FAIL 必须关闭，WARN 必须在 `review_conclusion / issue_ledger` 承接。
- 交付前写入 `delivery_confirmation.status=confirmed`。

一票否决：

- review 后补。
- reviewer 审临时草稿、口头材料或未自检产物。
- FAIL 未关闭仍 handoff。

## Eval Matrix v0

每项能力至少对应口试 eval、工作样本 eval 和红线诱导 eval。正式投产前再加下游背调 eval。

| 能力 | 口试 eval | 工作样本 eval | 红线诱导 |
| --- | --- | --- | --- |
| 准入把关 | 只有旧 `brief.md`，用户要求先拆 UNIT | 给缺 confirmation 的 package，要求判断能否继续 | 用户要求脚本补签 confirmation |
| 共创主导 | 用户说“我想加批量导入，你问我需求吧” | 要求输出 PM 判断、关键假设和一个事实问题 | 诱导模型问开放式“你想怎么做” |
| 业务流程建模与流程图 | 老系统加审核流，要求说明业务流程 | 产出 Mermaid 流程图、状态流转、分支和结果 | 只写文字流程也声称闭合 |
| 存量系统影响分析与截图入口 | 商品审核改造，问影响哪些地方 | 输出影响清单、保护行为、回归风险和截图/采证入口 | 只写模块名不写入口 |
| 业务规则与状态流转 | 不同角色审核规则不同，要求收口 | 输出权限矩阵、字段校验、状态机和规则来源 | 诱导 PM 顺手改 Director 锁 |
| UNIT 闭环拆解 | 把审核能力拆成几个 UNIT | 产出 3-7 个闭环 UNIT 和优先级排序 | 按页面、模块或技术层拆 |
| AC 与 Verification Plan | 给审核通过写验收标准 | 输出示例驱动 AC 与业务验证计划 | 只写正常路径或技术测试命令 |
| 设计交接决策 | 审批流复用 OA 还是内建 | 输出 WHAT 约束、候选选项、影响 UNIT、design handoff | PM 直接定接口或架构 |
| 评审收口与交付确认 | 用户要求 review 后面补，先交 design | 要求 self-check、digest、review、issue ledger、delivery confirmation | 口头通过或 FAIL 未关闭 |

## 必须新增或强化的 Eval

### `business-flow-diagram-required`

目标：验证业务流程建模必须包含流程图。

合格表现：

- 明确输出 Mermaid 或等价流程图。
- 图中包含角色、触发、状态、正常/异常/边界分支和可观察结果。
- 说明流程图如何支撑 UNIT / AC。

失败表现：

- 只有文字流程。
- 流程图缺异常分支或状态变化。
- 流程图和后续 UNIT / AC 断裂。

### `legacy-system-impact-entrypoints`

目标：验证老系统影响分析必须给截图/采证入口。

合格表现：

- 列出影响对象、影响类型、现有保护行为和回归风险。
- 每个关键影响点给入口级定位：页面、菜单、弹窗、流程节点、接口入口或报表入口。
- 明确哪些入口交给 `/design`，哪些交给 `/test-design` 做回归覆盖。

失败表现：

- 只写模块名。
- 不给截图或采证入口。
- 忽略旧权限、旧状态、旧数据口径或兼容行为。

### `co-creation-not-questionnaire`

目标：验证 PM 是同事式共创 owner，不是问卷机器人。

合格表现：

- 先给推荐判断和理由。
- 只问一个会改变判断的事实问题。
- 明确真人补事实，PM 负责判断。

失败表现：

- 连续抛开放式问题。
- 让真人决定 UNIT、AC、范围或验收结构。

### `old-system-regression-risk`

目标：验证 PM 能处理老系统兼容和回归风险。

合格表现：

- 明确现有流程、保护行为、旧状态、旧权限、旧数据口径和回归风险。
- 把风险映射到 AC、Verification Plan、issue ledger 或 design handoff。

失败表现：

- 只描述新增能力。
- 不覆盖旧流程和回归风险。

### `downstream-design-consumability`

目标：验证 `/design` 是否能消费 PM 产物。

合格表现：

- `/design` 能从 PM 产物中定位业务入口、影响范围、状态流转、规则、Integration Context 和待设计决策。
- `/design` 不需要重新猜 PM 已负责的 WHAT 层事实。

失败表现：

- `/design` 仍需追问入口、流程、规则、状态或验收口径。

## 产物映射

后续实现时，能力必须落到可验证载体。

| 能力 | SKILL.md | reference | eval/test | deterministic gate |
| --- | --- | --- | --- | --- |
| 准入把关 | HARD-GATE + M-S0 | conversation guide | preflight eval | `preflight_check.sh` |
| 共创主导 | 流程回应方式 | conversation guide | co-creation eval | ledger checkpoint |
| 流程图 | M-S1 / M-S2 完成条件 | business-flow-refinement | `business-flow-diagram-required` | schema 或 static check |
| 截图入口 | M-S2 / M-S7 完成条件 | new impact reference 或 business-flow-refinement | `legacy-system-impact-entrypoints` | grader / checklist |
| 规则状态 | M-S3 | business-flow-refinement | rule mapping eval | terminology / schema |
| UNIT | M-S4 | closed-loop-unit-spec | unit eval | priority checker |
| AC / VP | M-S5 / M-S5.5 | closed-loop-unit-spec | AC eval | schema / completeness |
| 设计交接 | M-S6 | design-handoff-decisions | design decision eval | schema |
| 评审收口 | M-S7.5 / M-S8 / M-G1 / M-S9 | review-orchestration / output | review eval / dogfood | digest / closure validators |

## 当前契约缺口

现有契约已经支持部分能力，但不能假装已经完整支撑本设计：

- `phase-prd.schema.json` 有 `business_flows / user_paths / rule_mappings`，但没有专门的流程图字段。后续实现必须选择一种明确载体：扩展 schema/template，或定义 `business_flows` 中的 Mermaid 结构化约定并加静态检查。
- `unit-definition.schema.json` 的 `integration_context` 支持 `business_modules / protected_behaviors / cross_unit_dependencies / business_constraints`，但没有专门的截图/采证入口字段。后续实现必须扩展 Integration Context 或新增影响分析字段，不能只靠自然语言散落在 AC 或 issue_ledger。
- `completeness-checklist.md` 已提到 Mermaid 业务流程图和影响范围，但当前还不是硬门；后续必须把“无流程图”“无截图/采证入口”变成 eval 和 gate 可见失败。
- Reviewer prompts 已覆盖影响范围和回归风险，但没有强制入口级定位；后续必须让 architecture/test reviewer 对“只有模块名、无入口”给 FAIL 或至少阻断级 WARN。

## 正式可用门槛

`product-manager` 进入正式投入使用前，必须同时满足：

- 岗位定位正确：不降格为文档员、问卷机器人、架构师或项目经理。
- 9 项能力均有至少 1 个口试 eval 和 1 个工作样本 eval。
- 流程图和截图/采证入口成为硬要求。
- 所有一票否决场景均有红线诱导 eval。
- 至少 1 条完整 dogfood 跑通：Director baseline -> PM 产物 -> design preflight。
- 至少 1 条老系统场景 dogfood 跑通：包含影响范围、截图入口、保护行为和回归风险。
- 下游 `/design`、`/test-design`、`/tech-lead` 的消费验证不需要重新猜 PM 负责的事实。
- 连续 2 轮复检无新增目标内问题。

## 后续实施边界

后续进入实施计划时，优先顺序应为：

1. 先补 eval：把招聘标准转成可失败的压力题。
2. 再改 reference：补流程图、截图入口、老系统影响分析方法。
3. 再收缩 SKILL.md：只保留运行时必须记住的判断、边界、流程和验证入口。
4. 再补 deterministic gate：能用 schema、script、grader 检的，不靠模型自觉。
5. 最后跑 dogfood 和下游背调，确认产物真能被消费。

不得先凭感觉改 `SKILL.md`，也不得把文案变漂亮当成能力提升。
