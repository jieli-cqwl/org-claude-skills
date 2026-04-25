# Product Role Split 取证清单与严格 Eval 计划

日期：2026-04-15

## 目标

这份文档回答的不是“split 看起来更合理吗”，而是：
- 当前 `/product-director + /product-manager` 是否保住了旧 monolith 的关键能力
- 当前 split 是否在 handoff 纪律、一致性和可验证性上取得可复核优势

## 严格验证边界

以下结论不能靠文案自证：
- “split 后更强”
- “最佳实践没有丢”
- “当前版本没有剩余风险”

这些结论必须同时经过下面 4 层证据约束：
- contract：关键入口、角色本地模板、review prompt、handoff 纪律有明确断言
- benchmark：用真实案例同时对比 split 与旧 monolith
- blind comparison：在不暴露版本标签的前提下，让比较器直接看输出质量
- human-reviewable artifacts：保留 `benchmark.json / review.html / comparison-*.json / report.md`

只要核心 contract 仍失败，就不能宣称当前版本可放行。
接线存在性不是输出质量证明；历史 benchmark 只能作为参考证据，当前结论必须说明是否来自 fresh run。

## 证据分层

### 第 1 层：Runtime / Doc Contract

验证这些点是否真实存在：
- 运行时不再保留 `/product` 旧入口
- `/product-director` 显式承载问题、目标、范围、Phase 冻结
- `/product-manager` 显式承载 UNIT / AC / Agent Team 审查闭环
- Director / Manager 各自目录自带所需模板，不再依赖第三层共享 runtime 目录
- 产品 reviewer prompt 显式包含 `R13` 和 `PR-C1`

### 第 2 层：Outcome-based Benchmark

采用 skill-creator 风格 benchmark，对比两套配置：
- `with_split`：当前 split 方案
- `old_monolith`：基于历史提交 `f548a32` 的旧 `/product`

每个案例 3 轮，记录：
- expectation pass rate
- blind comparison winner
- reviewer 可直接打开的 HTML 证据

### 第 3 层：Blind Comparison

比较器只看：
- 用户问题
- 输出 A
- 输出 B

不暴露：
- 哪个是 split
- 哪个是旧 monolith

比较重点：
- 路由是否更清楚
- handoff 边界是否更稳
- 方法论是否更显性
- reviewer 编排是否更完整

### 第 4 层：Fresh Proving

在文档、prompt、benchmark 结果落盘后，重新运行：
- product role split contract
- product stability guidance contract
- product eval contract
- product split benchmark contract

## Benchmark 案例集

### Case 1：Entry Routing

- ID：`entry-routing-recommendation-rebuild`
- 问题：用户只有想法，还没冻结根问题和范围
- 关注：是否明确先去 `/product-director`，而不是继续 monolith 一把梭

### Case 2：Solution Anchoring

- ID：`solution-anchoring-growth-dashboard`
- 问题：用户上来就给方案
- 关注：是否先把方案拉回真实问题与成功标准

### Case 3：Handoff Boundary

- ID：`handoff-boundary-loyalty-phase-change`
- 问题：Manager 阶段想改 Director 已锁定的范围 / Phase
- 关注：是否明确回退 `/product-director`

### Case 4：Legacy Migration

- ID：`legacy-brief-migration-pricing-center`
- 问题：旧 brief 没有确认门和 lock snapshot
- 关注：是否拒绝自动补确认放行

### Case 5：Review Orchestration

- ID：`review-orchestration-internal-approval`
- 问题：用户问 split 后 reviewer team 怎么组织
- 关注：是否明确三视角、`CONFIRMATION`、`ASK_USER`、`BLOCKED`、`R13`、`PR-C1`

### Case 6：Phase Planning

- ID：`phase-planning-partner-onboarding`
- 问题：多闭环需求要按什么拆 Phase
- 关注：是否按交付价值切 Phase，而不是按实现步骤均分

## 通过门槛

只有同时满足以下条件，才允许把当前 split 作为候选最佳实践进入下一阶段：
- 核心 contract 全部通过
- `with_split` 的 benchmark pass rate 明显高于 `old_monolith`
- blind comparison 不出现 `old_monolith` 在关键维度整体胜出的案例
- reviewer 可复核证据完整存在

## 证据落点

- benchmark 结果目录：`tools/eval/results/product-split-benchmark-20260415/iteration-1/`
- 汇总结论：`docs/archive/product-role-split-20260414/deep-validation-report.md`
