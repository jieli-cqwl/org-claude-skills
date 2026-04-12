# Direction Validation Report

## 目的

验证当前方向是否成立：

`当前标准流程中的 delivery-owner，不应再被定义为 Project Manager`

并明确这条判断成立的边界与风险。

## 本轮调研维度

1. 角色分摊：标准流程里“项目经理能力”被拆到哪些角色
2. 决策权与升级权：plan、kickoff、执行、QA、sign-off、风险接受分别归谁
3. 目标保真：团队评审、`Scope Freeze`、`goal fidelity review`、`goal closure`、`replan`
4. 执行治理：kickoff、偏差治理、动态 gate escalation 是否形成 Phase owner 骨架
5. 结果闭环：当前流程证明的是“流程跑完”还是“真的推动目标达成”
6. 外部最佳实践映射：与官方/成熟角色模型如何对照

并行挑战：

- Challenger A：治理 / 组织设计挑战
- Challenger B：交付质量 / 执行有效性挑战

## 结论

本轮结论是：

`PASS`

更准确地说：

- 当前 skill 的真实语义更像 `Delivery Owner`
- 当前方向成立，下一步重点是继续清理仓库里的漂移表述

## 为什么说方向成立

### 1. 当前 skill 的真实职责是执行期 owner

从链路契约和 skill 定义看，当前 `delivery-owner` 承担的是：

- `delivery kickoff`
- 执行编排
- 偏差治理
- 动态质量升档
- 签收收口

它不承担：

- 需求定义
- 技术方案设计
- 测试设计
- 独立质量判断
- 最终 sign-off
- 业务风险接受

这更贴近 `Delivery Owner`，而不是完整意义上的 `Project Manager`。

证据：

- [contracts/skill-chain.yaml](/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml:95)
- [shared/skills/delivery-owner/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md:50)
- [docs/delivery-owner-role-20260411/authority-matrix.md](/Users/lijieli/org-claude-skills/docs/delivery-owner-role-20260411/authority-matrix.md:11)

### 2. 当前标准流程已经把关键职责拆到了多角色

当前标准流程已经把关键职责拆到多角色：

- `product`：目标、范围、验收基线
- `tech-lead`：计划评审、`Scope Freeze`、质量基线、再计划入口
- `qa`：独立质量判断、`release_recommendation`、残余风险
- `user`：sign-off、业务风险接受
- `delivery-owner`：执行期推进与交付收口

所以，当前这个 skill 没必要继续背完整 `Project Manager` 的语义。

证据：

- [shared/skills/product/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md:71)
- [shared/skills/tech-lead/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md:37)
- [shared/skills/qa/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/qa/SKILL.md:48)

### 3. 当前链路已经形成 Phase 级防偏航与目标闭环骨架

本轮预扫描确认，当前链路已有 5 个关键机制：

- `tech-lead` 的跨职能计划评审
- `Scope Freeze` 与映射矩阵
- 执行期偏差触发器与 `replan request`
- 执行期动态 gate escalation
- `goal closure` + 签收门禁

这说明当前 skill 已不是单纯流程协调器，而是被制度化的执行期交付 owner。

证据：

- [shared/skills/tech-lead/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md:93)
- [shared/skills/delivery-owner/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md:128)
- [shared/skills/delivery-owner/references/templates/acceptance-summary-template.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md:73)

## 仍需继续优化的点

### 1. 当前更强的是“有信号再动作”，不是持续运行时感知

质量 challenger 的核心提醒也成立：

- 当前已有 `kickoff / deviation governance / dynamic escalation / goal closure`
- 但更偏文档与门禁驱动
- 还缺持续 `runtime state / trace / takeover / observability`

所以它已经有 Phase owner 骨架，但还没有到“最佳实践级完整闭环”。

### 2. 仓库内仍存在少量角色表述漂移

当前 skill 已自称“当前 Phase 的交付目标负责人”，但部分旧文档仍保留“还不是交付目标负责人”的历史表述。  
这说明方向已经清楚，但仓库真源还没完全收敛。

证据：

- [shared/skills/delivery-owner/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md:50)
- [docs/delivery-owner-role-20260411/role-definition-gap.md](/Users/lijieli/org-claude-skills/docs/delivery-owner-role-20260411/role-definition-gap.md:97)

## 外部最佳实践对照

### 支持方向的外部证据

- GOV.UK 服务团队模型把 `product manager`、`service owner`、`delivery manager` 明确拆开，说明执行推进和决策/验收可以分离  
  来源：[What each role does in a service team](https://www.gov.uk/service-manual/the-team/service-manager.html)

- GOV.UK 治理原则强调：团队和 owner 需要清楚决策边界，只在必要时升级；治理要支持交付而不是拖慢交付  
  来源：[Governance principles for agile service delivery](https://www.gov.uk/service-manual/agile-delivery/governance-principles-for-agile-service-delivery)

- DDaT `service owner` 角色明确对质量、绩效、收益、结果、治理和资金负责，这说明“结果与治理 owner”通常高于“执行推进 owner”  
  来源：[Service owner](https://ddat-capability-framework.service.gov.uk/role/service-owner)

- Scrum 把价值、交付效果、质量落实拆给 `Product Owner / Scrum Master / Developers`，说明成熟模型里责任本就可能分布式存在  
  来源：[Scrum Guide 2020](https://scrumguides.org/docs/scrumguide/v2020/2020-Scrum-Guide-US.pdf)

- APM 对 `Project Manager` 的定义天然包含 `scope / schedule / finance / risk / quality / resources / outcomes / benefits`，说明这个词本身容易带来更“全约束 owner”的期待  
  来源：[What does a project manager do?](https://www.apm.org.uk/jobs-and-careers/career-path/what-does-a-delivery-owner-do/)

## 本轮最终判断

本轮最稳的结论是：

1. 当前 skill 更应被理解为 `Delivery Owner`
2. 当前标准流程不需要再把它解释成完整的 `Project Manager`
3. 下一步重点是继续清理仓库真源中的漂移表述

## 下一步建议

按优先级：

1. 冻结一条仓库级真源结论  
   当前 `delivery-owner` 的真实语义是 `Delivery Owner`

2. 做仓库真源收敛  
   清理仍然矛盾的角色表述，避免“新 skill 定义”和“旧差距文档”同时存在

3. 再决定是否做命名迁移  
   先收敛语义，再迁移命名，避免团队把改名误当成功能闭环
