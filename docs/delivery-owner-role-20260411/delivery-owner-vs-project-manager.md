# Delivery Owner vs Project Manager 角色边界定义

## 目的

澄清两个容易被混用的概念：

- `Project Manager`：项目级角色
- `Delivery Owner`：执行期 / Phase 级角色

并基于当前标准流程，说明为什么当前 skill 应收敛为 `delivery-owner`，而不是继续沿用 `Project Manager`。

## 结论

当前仓库中的 `delivery-owner` skill，语义上更接近：

`Delivery Owner`

而不是完整意义上的：

`Project Manager`

原因不是它能力弱，而是当前标准流程已经把“项目经理能力”分摊到整条链路里：

- `product / brief / prd` 负责目标定义与范围澄清
- `tech-lead` 负责计划评审、范围冻结、质量基线与再计划入口
- `developer` 负责 Task 实现与偏差信号回传
- `qa` 负责独立质量判断、残余风险与放行建议
- `user` 负责 sign-off 与业务风险接受
- 当前 `delivery-owner` skill 主要负责执行 kickoff、交付调度、偏差治理、动态 gate 升档与签收收口

因此，当前 skill 更适合作为“标准流程中的执行期交付 owner”，而不是“单点承载项目经理全部职责的项目级 owner”。

## 当前链路中的两类角色

### Project Manager

`Project Manager` 是项目级目标推进角色。

它的关注点通常包括：

- 项目目标是否清楚、是否被持续维护
- 团队评审是否发生、是否形成有效共识
- 资源是否匹配排期与目标
- 跨阶段里程碑、风险、依赖、范围变化是否被持续治理
- 每一轮交付是否真的推动项目向最终目标收敛

它的时间尺度是：

- 跨 Phase
- 跨里程碑
- 跨角色协同

### Delivery Owner

`Delivery Owner` 是执行期交付结果角色。

它的关注点通常包括：

- 当前 Phase 是否准备好进入执行
- 当前执行是否围绕已确认目标推进
- 执行中偏差是否被及时识别、升级、再计划
- QA / Review 强度是否与真实风险匹配
- 最终签收是否建立在目标闭环而不是只看流程绿灯

它的时间尺度是：

- 单个 Phase
- 单次交付窗口
- 已确认目标下的执行治理

## 对照表

| 维度 | Project Manager | Delivery Owner | 当前 skill 更像谁 |
|------|-----------------|----------------|------------------|
| 作用层级 | 项目级 | Phase / 执行级 | `Delivery Owner` |
| 核心目标 | 推动项目整体达成目标 | 推动当前 Phase 达成交付目标 | `Delivery Owner` |
| 时间跨度 | 跨多个里程碑 / Phase | 当前执行窗口 | `Delivery Owner` |
| 主要输入 | 目标、路线图、资源、里程碑、跨团队依赖 | `brief / prd / design / plan / test-cases` | `Delivery Owner` |
| 主要输出 | 项目级节奏、资源协调、风险升级、项目状态 | kickoff、dev/code-review/qa/acceptance 工件、执行期决策 | `Delivery Owner` |
| 是否组织团队评审 | 是，项目级必备能力 | 可承接已定义评审输入，但不是评审真源 owner | `Project Manager` |
| 是否负责计划评审真源 | 关注并推动发生，但不一定亲自写 plan | 否，承接已确认 `plan.md` | `Delivery Owner` |
| 是否负责执行调度 | 是 | 是 | 两者都有 |
| 是否负责项目级 replan | 是 | 识别并发起 replan request | `Delivery Owner` 只负责触发 |
| 是否负责业务风险接受 | 否，通常推动决策发生 | 否，不可单方接受 | 两者都不是 |
| 是否负责最终 sign-off | 否，推动签收发生 | 否，推动签收发生 | 两者都不是 |
| 在当前链路中是否已被单独建模 | 否 | 是 | `Delivery Owner` |

## 为什么当前 skill 不宜继续直接叫 Project Manager

如果继续把当前 skill 直接视为 `Project Manager`，会自然引发 4 类错误期待：

1. 期待它负责项目级团队评审组织  
但当前评审真源主要在 `tech-lead`、`product` 和 `qa`。

2. 期待它负责项目级资源协调与里程碑治理  
但当前 skill 的输入输出主要围绕单个 Phase 的执行工件，不是项目级节奏盘。

3. 期待它对“整个项目目标是否收敛”负总责  
但当前链路里它主要对“当前 Phase 的交付目标”负责。

4. 期待它单点覆盖标准流程里的 PM 能力  
但当前标准流程已经把这些能力拆散到多角色协同中，不再由一个 skill 独占。

因此，继续把它直接叫 `Project Manager`，会让名字大于真实职责，增加误用成本。

## 为什么当前 skill 更适合叫 Delivery Owner

现有改造后的 skill 已经具备 `Delivery Owner` 的关键特征：

- 它承接已确认的 `plan.md`，而不是生成项目级计划
- 它负责 `delivery kickoff`
- 它负责执行调度与偏差治理
- 它可以在 guardrail 内动态升档 review / QA
- 它负责把签收收口到“目标闭环”
- 它不定义需求、不发明设计、不接受业务风险

这和“执行期交付 owner”的职责高度一致。

## 命名结论

当前仓库采用下面这组口径作为真源：

1. 当前 skill 的正式名称是 `delivery-owner`
2. 当前 skill 不再沿用 `project-manager` 作为运行时入口
3. `project-manager` 只作为历史讨论中的旧名称保留

## 对当前仓库的建议结论

对当前仓库，我建议采用下面这组结论作为真源：

- 当前 `delivery-owner` skill 的真实角色是 `Delivery Owner`
- 现阶段先把语义和口径收敛清楚，不再把它解释成完整的 `Project Manager`

## 一句话收口

当前这版 skill 最准确的描述不是：

`项目经理`

而是：

`标准流程中的 Delivery Owner（执行期交付负责人）`
