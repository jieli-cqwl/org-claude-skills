# Delivery Owner 能力矩阵

## 目的

冻结 `delivery-owner` 真正必须具备的能力，作为后续能力审计、脚本落地和交付验收的统一判断基线。

本矩阵只覆盖执行期交付治理，不扩展到需求定义、技术方案设计和代码实现。

## 能力定义原则

- 从整条标准链路反推能力，而不是从当前文案倒推能力
- 只保留“为了稳定完成当前 Phase 交付”真正必需的能力
- 每项能力都必须能继续映射到 `SKILL.md / templates / scripts / tests`
- 不能落到真约束的内容，不进入核心能力矩阵

## 核心能力矩阵

| 能力 | 链路位置 | 要解决的问题 | 关键决策 | 关键输入 | 关键输出 | 成功判据 |
|------|----------|--------------|----------|----------|----------|----------|
| `Execution Readiness` | Phase 1 开始前 | 已确认计划是否真的具备开工条件 | 现在能否启动执行；哪些前置项必须先补齐 | `brief / prd / design / plan / test-cases / preflight-evidence / readiness constraints` | `kickoff_status`、阻塞项、ready/blocked 结论 | 未 ready 时不会进入执行；ready 时执行边界清楚 |
| `Execution Orchestration` | Phase 2 执行期 | 开发、验证、QA、签收如何按同一节奏推进 | 当前先派发什么、并行还是串行、批次如何编排、何时 merge | `plan.md`、Task 依赖、批次策略、执行状态 | 派发动作、批次顺序、`dev-report`、Phase 状态 | 各 Task 状态清楚，推进顺序与依赖一致 |
| `Progress & State Awareness` | Phase 2-3 全程 | 当前执行到底卡在哪、偏在哪、是否在收敛 | 当前链路是继续推进还是已经失控 | developer/verifier/review/qa 回传、测试结果、BLOCKED/轮次信号 | 进度状态、瓶颈定位、收敛判断 | 不靠感觉推进，任何关键判断都有当前状态依据 |
| `Deviation Governance` | Phase 2-3 全程 | 复杂度漂移、接口变化、依赖变化、不收敛等偏差如何治理 | `CONTINUE / ESCALATE / REPLAN / BLOCK` 怎么选 | `COMPLEXITY_DRIFT / INTERFACE_* / SHARED_FILES_EXPANSION / DEPENDENCY_DRIFT / NON_CONVERGENCE / BLOCKED_ACCUMULATION` | 偏差结论、升级动作、replan request、阻塞结论 | 偏差不会被静默吞掉，都会进入明确治理动作 |
| `Quality Governance` | Phase 3 | 如何保证真实风险和验证强度匹配 | 当前是否需要升级 review / QA 强度、扩大回归范围 | `phase3 grade`、风险信号、review/qa 结果、影响范围 | 升档决定、回归范围、质量门禁结论 | 实际验证强度不低于真实风险强度 |
| `Goal Closure` | 签收前 | 门禁通过后，当前 Phase 是否真的达成目标 | 结果是 `已达成 / 部分达成 / 未达成`；缺口是否可签收 | `brief success criteria / phase goal / delivery value / qa-report / acceptance-summary` | 目标闭环结论、remaining gap、签收输入包 | 签收建立在目标达成证据上，而不是只看流程绿灯 |

## 支撑能力矩阵

| 能力 | 链路位置 | 要解决的问题 | 关键输入 | 关键输出 | 成功判据 |
|------|----------|--------------|----------|----------|----------|
| `Evidence Governance` | 全链路 | 结论如何可追溯、可抽查、不过度重复搬运 | developer 一手证据、review/qa 报告、acceptance-summary | `developer_report_ref`、`evidence_target`、跨工件引用关系 | 任一关键结论都能追到权威证据源 |
| `Sign-off Orchestration` | 签收阶段 | 用户如何在完整上下文下做签收决定 | `goal closure`、`release_recommendation`、`residual_risk`、QAR 台账、waivers | 签收摘要、确认/拒绝记录、进入 commit 或暂停 | 用户签收基于完整上下文，拒绝和接受都能被承接 |

## 为什么这 8 项是当前最小全集

如果少掉其中任一项，就会出现明确缺口：

- 没有 `Execution Readiness`，执行会在错误前提下启动
- 没有 `Execution Orchestration`，链路只剩角色堆叠，没有 owner 推进
- 没有 `Progress & State Awareness`，推进会变成“等报告再反应”
- 没有 `Deviation Governance`，风险会被静默吸收进执行噪音
- 没有 `Quality Governance`，流程会通过，但质量强度可能失真
- 没有 `Goal Closure`，签收只能证明流程结束，不能证明目标达成
- 没有 `Evidence Governance`，所有结论都会变得不可抽查
- 没有 `Sign-off Orchestration`，最后一公里无法稳定收口

## 后续使用方式

这份矩阵会直接用于 3 个后续动作：

1. 能力审计
   - 判断每项能力当前是 `真实具备 / 部分具备 / 只有文案`

2. 能力落地
   - 把每项能力映射到 `SKILL.md / templates / scripts / tests / replay`

3. 改造验收
   - 以后判断“delivery-owner 是否做到位”，以这份矩阵为准，而不是以零散改动为准

## 一句话结论

`delivery-owner` 的核心，不是“帮忙推进流程”，而是具备执行准备、执行推进、状态感知、偏差治理、质量治理和目标收口这 6 项核心能力，并由证据治理和签收推进 2 项支撑能力托底。
