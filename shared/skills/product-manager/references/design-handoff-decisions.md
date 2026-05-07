# 设计交接决策

## 写入边界

只写 PM 无法在 WHAT 层收口、但 `/design` 必须接住的问题；写入 `phase-prd.json.design_decision_candidates` 或 `units/UNIT-*.json.design_decision_candidates`，不提前给技术答案。

## 进入 handoff 的条件

- 问题已不改变 Director 根问题、范围、本期不做范围、Phase 边界、规则事实或可行性约束。
- 问题会影响实现路径、架构拆分、界面组织、集成方案或下游技术取舍。
- PM 已能给出业务可接受边界、候选业务选项、约束条件和影响 UNIT。
- 若 PM 可以基于业务事实直接收口，优先在 PM 层收口，不转交 `/design`。

## 字段口径

| 字段 | 写什么 | 不写什么 |
| --- | --- | --- |
| 决策名称 | 待 `/design` 收口的问题。 | 抽象主题或实现任务。 |
| 候选选项 | 业务可接受的方向或体验约束。 | 技术框架、文件路径、接口方案。 |
| 约束条件 | Director baseline、PM 规则、Integration Context 或风险约束。 | 未闭合的个人偏好。 |
| 影响 UNIT | 受该决策影响的 UNIT。 | 泛泛影响面。 |
| design handoff | 交给 `/design` 判断的目标。 | PM 已能决定的 WHAT 结论。 |

## 收口方式

- 先扫描开放问题、Partial / Missing 项、UNIT 依赖和 Integration Context。
- 给一个 PM 推荐：哪些问题在 PM 层直接收口，哪些问题交给 `/design`。
- 只有业务事实存在真实分叉，且会改变 design handoff 的候选边界时，才给 2-3 个业务场景分支，并标明默认推荐。
- 最后只验证一个会改变 handoff 结论的具体业务假设。

## 完成条件

- 每个 design decision candidate 都有候选选项、约束、影响 UNIT 和 design handoff。
- 没有把 PM 可以收口的业务问题推给 `/design`。
- 没有把技术答案写入 PM 工件。
- 触及 Director 锁定内容的问题已回退 `/product-director`，未写入 handoff。
