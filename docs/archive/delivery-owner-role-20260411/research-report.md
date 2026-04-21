# Delivery Owner 方向与能力模型调研报告

> 调研模式：analysis
> 呈现模式：audit

## 当前判断
- 这次要回答的问题：当前标准流程里，将该角色收敛为 `delivery-owner` 是否成立；围绕整个链路反推出来的能力模型是否成立；当前仓库是否已经证明它具备最佳实践级能力并可作为团队默认真源。
- 当前结论：部分成立
- 一句话判断：`delivery-owner` 的角色方向成立，8 项能力模型基本成立，但当前仓库还没有证明它已经具备最佳实践级、可全量 rollout 的能力。
- 最大风险：把“强门禁 + 强汇报 + 强模板”误当成“已具备主动收敛执行、动态升级质量、稳定暴露风险”的能力。
- 下一步动作：继续采纳 `delivery-owner` 方向，但把下一轮重点从“命名/角色争论”切到“能力硬化与 rollout 证据补齐”。

## 关键论点挑战表
| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| 当前角色应收敛为 `delivery-owner`，而不是继续混用 `project-manager` | 链路真源已经将 `plan_owner / phase_delivery_owner / quality_judgment_owner / sign_off_owner` 明确分离，`delivery-owner` 只负责执行期交付治理。证据：`contracts/skill-chain.yaml:95-103`、`shared/skills/delivery-owner/SKILL.md:50-52`、官方对照见 [DDaT Delivery manager](https://ddat-capability-framework.service.gov.uk/delivery-manager.html)、[DDaT Service owner](https://ddat-capability-framework.service.gov.uk/role/service-owner) | 仓库内仍残留少量历史表述漂移，说明语义冻结还未完全做完。证据：`docs/delivery-owner-role-20260411/role-definition-gap.md:97-101`、`docs/delivery-owner-role-20260411/direction-validation-report.md:113-118` | 成立 | 高 |
| `Execution Readiness / Execution Orchestration / Progress & State Awareness / Deviation Governance / Quality Governance / Goal Closure / Evidence Governance / Sign-off Orchestration` 构成当前最小能力全集 | 能力矩阵与失败场景审计都显示，这 8 项覆盖了执行准备、推进、偏差、质量、目标闭环和签收收口；失败场景没有出现“完全空白”的能力位。证据：`docs/delivery-owner-role-20260411/delivery-owner-capability-matrix.md:16-62`、失败场景审计结论 `6 PASS / 2 PARTIAL` | 其中 `Execution Orchestration / Progress & State Awareness / Sign-off Orchestration` 现在仍偏流程化，说明能力集合本身成立，但其中几项需要更强的操作语义才能算最佳实践。证据：能力审计结论 `5 真实具备 / 3 部分具备` | 成立 | 中 |
| 当前仓库已经证明 `delivery-owner` 具备最佳实践级能力，并可以稳定带着开发、验证、QA 做高质量交付 | 当前链路已经把 kickoff、preflight、goal closure、一手证据、Phase 3 gate、签收一致性做进 `SKILL.md + templates + scripts + tests`，不是纯文案。证据：`shared/skills/delivery-owner/SKILL.md:125-175`、`shared/skills/delivery-owner/scripts/completion_check.sh:808-1883`、`tests/test-delivery-owner-phase3-contract.sh` | challenger 指出当前更像“强门禁、强汇报、弱控制面”的执行骨架：动态升档不可执行、状态感知偏事后、replan 闭环弱、goal closure 更像表格校验、QA 边界还有自相矛盾点。证据：独立挑战记录 A/B | 不成立 | 高 |

## 覆盖证明摘要
- 已查入口摘要：本轮覆盖了 `contracts/skill-chain.yaml`、`contracts/small-chain.yaml`、`shared/skills/{delivery-owner,tech-lead,qa,developer,test-design}/SKILL.md`、`delivery-owner` 相关 templates/scripts/tests、`docs/delivery-owner-role-20260411/*.md`，以及官方外部角色模型与治理资料。
- 最大剩余盲区：还没有真实 pilot/replay 执行证据，也没有基于真实项目运行数据的 runtime observability 反馈。
- 为什么当前仍可判断：这次要回答的是“方向和能力模型是否成立”，不是“试点是否成功”；角色边界、门禁设计、能力缺口和治理盲区都已经能从真源和 challenger 的结构性证据里看清。

## 拆解对象概览
- 对象类型：项目方法 / 角色模型 / 交付治理能力模型
- 原始观点：当前标准流程里的这个角色不应继续被理解为完整 `Project Manager`，而应收敛为 `Delivery Owner`；同时要明确它真正应具备哪些能力，才能判断这条方向有没有价值。
- 需要回答的问题：
  1. 这条角色方向是否成立。
  2. 围绕整个标准流程反推出来的能力模型是否成立。
  3. 当前仓库是否已经把这些能力真正做实，足以对外宣称“最佳实践且可投入团队使用”。

## 核心判断依据

### 1. 角色方向成立：当前真源已经把它锁成执行期交付 owner
- `contracts/skill-chain.yaml` 已将 `tech-lead / delivery-owner / qa / developer / user` 的 owner 边界拆开：`delivery-owner` 是 `phase_delivery_owner`，`qa` 是 `quality_judgment_owner`，`user` 保留 `sign_off_owner` 和 `business_risk_acceptance_owner`。证据：`contracts/skill-chain.yaml:95-103`
- `shared/skills/delivery-owner/SKILL.md` 已把它写成“当前 Phase 的交付目标负责人”，并明确它的抓手是 `kickoff / 开发执行 / 偏差治理 / 动态质量升档 / 签收收口`。证据：`shared/skills/delivery-owner/SKILL.md:50-52`
- 外部官方角色模型也支持这种拆分：
  - [DDaT Delivery manager](https://ddat-capability-framework.service.gov.uk/delivery-manager.html)：强调推进团队交付、去除阻塞、管理节奏和依赖。
  - [DDaT Service owner](https://ddat-capability-framework.service.gov.uk/role/service-owner)：强调对结果、治理、预算、服务绩效负责，说明“结果/服务 owner”可以高于“执行推进 owner”。
  - [Scrum Guide 2020](https://scrumguides.org/scrum-guide.html?source=post_page-----3b79f3adbd3f----------------------)：责任本身被拆给 `Product Owner / Scrum Master / Developers`，并不要求单一角色包办全部项目治理。
  - [APM Project Manager](https://www.apm.org.uk/jobs-and-careers/career-path/what-does-a-project-manager-do/%5C)：`project manager` 天然包含范围、资源、预算、风险、收益等更完整约束，容易引入不必要预期。

### 2. 能力模型基本成立：8 项能力构成当前最小全集
- 能力矩阵把执行期交付治理收敛成 6 项核心能力和 2 项支撑能力，并明确每项能力要落到 `SKILL.md / templates / scripts / tests`。证据：`docs/delivery-owner-role-20260411/delivery-owner-capability-matrix.md:16-62`
- 失败场景审计显示，这 8 项能力对关键失败模式并非空心覆盖：
  - `错误前提开工 / 不收敛 / 接口漂移 / shared_files 扩大 / 签收伪闭环 / 证据不可追溯` 为 `PASS`
  - `任务失控 / 质量强度不足` 为 `PARTIAL`
- 这说明能力模型本身没有明显缺位，但其中几项还没有被做成最强约束。

### 3. 当前成熟度不成立：还不能宣称“已是最佳实践级 Delivery Owner”
- 独立能力审计给出的结论是：`5 项真实具备，3 项部分具备，没有“只有文案”`。这意味着基础已经不错，但最弱的 3 项恰好都是 `Execution Orchestration / Progress & State Awareness / Sign-off Orchestration` 这类决定“能不能稳带团队”的能力。
- challenger 从工程执行视角提出的 4 个推翻级质疑成立：
  - `Execution Orchestration` 仍更像“按 plan 派发 + 等结果回来”，不是主动收敛控制面。
  - `Progress & State Awareness` 更像事后表格，不是运行中的状态感知。
  - `Deviation Governance` 和动态升档主要还是文案承诺，执行约束不够硬。
  - `Blocked / Replan` 触发偏晚，且执行侧没有完整再计划闭环。
- challenger 从质量治理视角提出的 4 个推翻级质疑也成立：
  - 动态质量升档还不是强门禁。
  - `goal closure` 更像表格校验，不是目标达成校验。
  - `qa` 边界仍有自相矛盾点。
  - 签收前风险暴露还没有成为仓库级默认真源。

### 4. 当前最强的是“能拦住明显问题”，不是“能持续掌舵”
- `Execution Readiness` 已被做成硬门：`Delivery Kickoff`、`preflight-evidence`、`kickoff_status` 和 readiness 字段都被脚本拦截。证据：`shared/skills/delivery-owner/SKILL.md:125-130`、`shared/skills/delivery-owner/scripts/completion_check.sh:808-825`
- `Quality Governance` 已有较强基线：Phase 3 分级矩阵、`browser_required` 规则、`release_recommendation / residual_risk`、QA 模板和合同测试都较完整。证据：`shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh:5-59`、`shared/skills/qa/references/templates/qa-report-template.md:5-15`
- `Goal Closure` 和 `Evidence Governance` 已经进入脚本与模板：不是空口判断。证据：`shared/skills/delivery-owner/references/templates/acceptance-summary-template.md:73-79`、`shared/skills/delivery-owner/scripts/completion_check.sh:1834-1883`
- 但团队可用性和运行态控制仍是 `PARTIAL`：
  - 缺持续 runtime snapshot / trace / takeover / observability
  - 缺把 `replay-scenarios.md` 变成可执行检查的落地证据
  - 缺对“动态升档动作必须发生”的可执行约束

### 5. 外部最佳实践对照支持“方向对，但不能过度宣称完成度”
- [GOV.UK governance principles for agile service delivery](https://www.gov.uk/service-manual/governance) 强调治理应支持交付、按风险比例实施、并要求持续透明的进展和问题暴露。
- [PMI Project Success](https://www.pmi.org/learning/thought-leadership/project-success) 强调项目成功不能只看产出和进度，还要看价值、结果和组织能力。
- 这些外部基准与当前仓库状态是匹配的：
  - 角色方向和分责方式没有问题。
  - 真正的差距不在“有没有文档”，而在“有没有把状态感知、动态治理和风险暴露做成持续、可执行、可审计的控制面”。

## 吸收建议

### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 当前角色应固定为 `delivery-owner` | 仍保持标准流程中 `tech-lead / qa / user` 等角色分责 | 继续以 `delivery-owner` 为执行期交付 owner 真源，不再回退到 `project-manager` 叙事 |
| `Execution Readiness` 必须是硬门 | 仍沿用 `brief / prd / design / plan / test-cases` 作为执行基线 | 保留 `Delivery Kickoff + preflight-evidence + kickoff_status` 的硬门模型 |
| 目标闭环与一手证据治理必须保留 | 仍需避免“门禁全绿但目标未达成” | 保留 `goal closure`、`developer_report_ref`、`evidence_target` 这条证据链 |

### 改写后吸收
| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| `delivery-owner` 已能稳定带团队收敛 | `delivery-owner` 已具备执行 owner 骨架，但仍需补强 orchestration / state awareness / dynamic escalation / sign-off risk package` | 当前成熟度证据还不够，不能过度宣称 |
| 动态质量升档已成立 | 把 drift -> gate escalation 变成可执行规则和失败用例，而不只记录 `deviation_trigger / control_action` | 目前更多是文案和记录，不是硬门 |
| `goal closure` 已证明目标达成 | 让 `goal closure` 回绑 `brief / prd` 真源，并校验 evidence 锚点存在且可支撑结论 | 当前主要是表格枚举校验 |
| 团队可用标准已经具备 | 以 replay 场景执行证据和 pilot 结果作为“可投入团队使用”的最终门槛 | 现在只有 rubric 和场景定义，没有运行证据 |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 现在就对外宣称“已达到最佳实践，可作为团队默认流程全面上线” | 当前 strongest evidence 还不足以支撑这个结论，challenger 已给出多个推翻级反例 |

## 落地行动项
- `P0`：把动态升档做成强门禁。要求 `deviation_trigger` 命中指定风险时，`Phase 3` 必跑阶段和回归范围必须升级，漏升档应直接失败。
- `P0`：把 `Progress & State Awareness` 从事后汇总改成运行态控制面。至少新增 `runtime_snapshot / last_observed_at / blocker_owner / takeover_note / decision_basis` 这类固定字段，并让脚本校验。
- `P0`：把 `goal closure` 从“表格存在”升级为“真源绑定”。要求目标来源必须回指 `brief/prd`，证据锚点必须存在，且 `acceptance_release_recommendation` 允许比 QA 更保守，不能只能等于 QA。
- `P0`：修复 `qa` 边界矛盾。去掉 `qa-report` 对尚未生成的 `acceptance-summary` 的前置依赖，改成 QA 输出自身的风险与义务完成情况，`delivery-owner` 再承接。
- `P1`：把 `replay-scenarios.md` 里的 4 个场景做成可执行 contract/replay tests；全部通过前，不再宣称“可投入团队使用”。
- `P1`：补齐签收前风险包。`acceptance-summary` 需要承接 `qa-report` 的 `not_executed_reason`、条件放行依据和未覆盖边界，避免把风险压平成摘要。

## 论点挑战总表
| 论点 | 最强支持证据 | 最强反方挑战 | 当前判定 | 对我们的启示 |
|------|-------------|-------------|---------|-------------|
| `delivery-owner` 角色方向成立 | 链路 owner 已分离，外部角色模型支持执行 owner 与结果 owner 分层 | 术语漂移仍未完全清零 | 成立 | 继续收敛语义，不再回退命名争论 |
| 8 项能力模型成立 | 生命周期覆盖和失败场景覆盖都基本完整 | 其中 3 项仍偏流程协调，操作语义不够硬 | 成立 | 能力模型可继续用作真源，但要补强最弱 3 项 |
| 当前仓库已经具备最佳实践级能力 | `kickoff / gate / evidence / goal closure` 已进脚本和测试 | challenger 给出多项推翻级问题 | 不成立 | 下一轮重点不是再包装，而是把薄弱能力做实 |

## 证据索引
1. `contracts/skill-chain.yaml`
2. `contracts/small-chain.yaml`
3. `shared/skills/delivery-owner/SKILL.md`
4. `shared/skills/delivery-owner/scripts/completion_check.sh`
5. `shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh`
6. `shared/skills/delivery-owner/references/kickoff-checklist.md`
7. `shared/skills/delivery-owner/references/templates/dev-report-template.md`
8. `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
9. `shared/skills/qa/references/templates/qa-report-template.md`
10. `shared/skills/qa/scripts/completion_check.sh`
11. `tests/test-delivery-owner-phase3-contract.sh`
12. `tests/test-skill-output-and-gate-contract.sh`
13. `docs/delivery-owner-role-20260411/delivery-owner-capability-matrix.md`
14. `docs/delivery-owner-role-20260411/role-definition-gap.md`
15. `docs/delivery-owner-role-20260411/direction-validation-report.md`
16. `docs/delivery-owner-role-20260411/quality-rubric.md`
17. `docs/delivery-owner-role-20260411/replay-scenarios.md`
18. [DDaT Delivery manager](https://ddat-capability-framework.service.gov.uk/delivery-manager.html)
19. [DDaT Service owner](https://ddat-capability-framework.service.gov.uk/role/service-owner)
20. [Scrum Guide 2020](https://scrumguides.org/scrum-guide.html?source=post_page-----3b79f3adbd3f----------------------)
21. [GOV.UK Governance principles for agile service delivery](https://www.gov.uk/service-manual/governance)
22. [PMI Project Success](https://www.pmi.org/learning/thought-leadership/project-success)
23. [APM Project Manager](https://www.apm.org.uk/jobs-and-careers/career-path/what-does-a-project-manager-do/%5C)

## 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| `Execution Orchestration` | 当前更像按 plan 批处理排空，不是主动收敛控制面 | 接受。把“当前已具备稳定收敛能力”的结论从“成立”调整为“不成立” | 是 |
| `Progress & State Awareness` | 当前主要靠事后表格和轮次信号，不是运行中的状态感知 | 接受。将其从“部分具备的小缺口”升级为下一轮 `P0` 补强项 | 是 |
| `Dynamic Quality Escalation` | 当前是文案承诺，不是强门禁 | 接受。保留方向，但必须把 drift -> gate escalation 做成脚本与失败用例 | 是 |
| `Goal Closure` | 当前是表格校验，不是目标达成校验 | 部分接受。`goal closure` 方向成立，但当前实现还未做到审计级，需要加强真源绑定与证据锚点校验 | 是 |
| `QA` 边界 | QA 模板对 `acceptance-summary` 的前置依赖会造成边界自相矛盾 | 接受。需要修正 QA 与 delivery-owner 的收口契约 | 是 |
| `签收前风险暴露` | 当前还不是仓库级默认真源，且风险包被压平 | 接受。补齐 rollout/default chain 和 acceptance risk package 前，不宣称全量上线 | 是 |

## 检索路径与覆盖证明
- 名称归一化：`delivery-owner / delivery owner / project-manager / project manager / phase delivery owner`
- 已查对象类型：仓库 contracts、skills、scripts、templates、tests、design docs、官方角色模型与治理文档
- 已查 discovery 入口：本地代码搜索、合同测试、文档真源、官方站点检索
- 已排除候选：
  - “把当前角色继续叫 `project-manager`”：
    原因：与链路分责和外部角色模型都不匹配
  - “当前已经是最佳实践级 team-ready”：
    原因：challenger 已给出多个推翻级结构性证据
- 剩余盲区：真实 pilot、replay 执行结果、运行态遥测证据

## 项目上下文
- 技术栈：本仓库是 skill/contracts/tests/docs 驱动的流程型仓库，关键行为依赖 `SKILL.md + templates + scripts + contract tests`
- 已有相关实现：`delivery-owner` 已与 `tech-lead / qa / developer / test-design` 形成链路契约，且 `Phase 3` 质量门禁、`goal closure`、`preflight-evidence` 已进入脚本
- 约束条件：
  - 必须沿用当前标准流程的分责结构
  - 不能靠口头解释支撑团队使用
  - 需要把能力落成 `templates + scripts + tests + replay`
