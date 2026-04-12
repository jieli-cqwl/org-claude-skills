# 复杂链路 sub agent 最佳实施计划

## 文档目标

把当前已经确认的调研结论，收敛成一条可执行、可回滚、可扩圈的实施路线。

这份计划只回答 3 件事：

- 先改哪里，后改哪里
- 每一阶段要交付什么、验证什么、什么情况下停止
- 什么时候允许把试点结论写回主 skill，什么时候不允许

## 核心结论

最佳实践不是同时改整条复杂链路，而是按下面顺序推进：

1. 先冻结 `主 Agent / sub agent` 职责合同与试点口径
2. 先在 `tech-lead` 做单点试点
3. 只在 `tech-lead` 试点 `PASS` 后，才扩到 `test-design`
4. `design` 只作为第三站候选，不提前进入首批改造
5. `product` 与 `delivery-owner` 当前都不作为主改造对象

## 实施原则

1. 节点责任不下放
复杂链路 5 个主阶段都保持 `position: main`，只允许下放可回收工序。

2. 先试点，再回写主 skill
在真实样本证明“确实降噪且不降质”之前，不把试点逻辑写进主流程。

3. 一次只推进一个实验阶段
同一时间只允许一个主阶段处于 sub agent 改造试点中，避免结果互相污染。

4. 先保交付，再追求降噪
任何试点只要破坏既有 Gate、completion check、sign-off 或 reviewer 收敛，就立即停。

5. 证据优先于感受
阶段是否通过，只看真实复杂样本、基线对照和 fail-fast 结果，不看主观体感。

## 推荐路线总览

| 波次 | 目标 | 范围 | 进入条件 | 退出条件 |
|------|------|------|----------|----------|
| `Wave 0` | 冻结合同与试点资产 | docs-only | 调研结论已确认 | 试点文档、模板、样本规则齐备 |
| `Wave 1` | 跑 `tech-lead` 单点试点 | 仅 `tech-lead` | `Wave 0` 完成 | 得出 `PASS / FAIL / INCONCLUSIVE` |
| `Wave 2` | 最小必要回写 `tech-lead` 主 skill | 仅 `tech-lead` | `Wave 1 = PASS` | 主 skill 与模板/门禁完成必要集成 |
| `Wave 3` | 扩到 `test-design` | `test-design` | `Wave 2` 稳定 | 完成第二站验证 |
| `Wave 4` | 评估 `design` 是否值得进入 | `design` | `Wave 3 = PASS` | 决定扩或不扩 |

## Wave 0：冻结合同与试点资产

### 目标

让试点在不改主 skill 的前提下可以独立执行。

### 本波次交付物

- 已确认文档：
  - [research-report.md](/Users/lijieli/org-claude-skills/docs/subagent-context-audit-20260411/research-report.md:1)
  - [responsibility-matrix.md](/Users/lijieli/org-claude-skills/docs/subagent-context-audit-20260411/responsibility-matrix.md:1)
  - [tech-lead-pilot-plan.md](/Users/lijieli/org-claude-skills/docs/subagent-context-audit-20260411/tech-lead-pilot-plan.md:1)
- 试点执行资产：
  - `pilot-result.md`
  - `before-after-metrics.md`
  - `metric-counting-notes.md`
  - `what-to-keep.md`
  - `what-to-roll-back.md`

### 本波次不做的事

- 不改 `shared/skills/product/SKILL.md`
- 不改 `shared/skills/design/SKILL.md`
- 不改 `shared/skills/test-design/SKILL.md`
- 不改 `shared/skills/tech-lead/SKILL.md`
- 不改 `shared/skills/delivery-owner/SKILL.md`

### 完成条件

- 试点范围、角色边界、样本口径、基线口径、fail-fast 规则都已写死
- 不在场 reader 能独立读懂并执行试点

## Wave 1：`tech-lead` 单点试点

### 为什么先做这里

`tech-lead` 同时满足：

- 噪音密度高
- 输入明确
- 输出真源单一，只有 `plan.md`
- 不直接碰用户共创与最终签收
- 已有强 Gate 和 completion check 可兜底

### 试点范围

只允许试 3 类 sub agent：

- `Traceability Draft Agent`
- `Task Decomposition Draft Agent`
- `Evidence Field Draft Agent`

主 Agent 保留：

- `DESIGN_OK`
- 计划模式选择
- `Scope Freeze`
- Task 最终编号与依赖
- 用户确认记录
- 最终 `plan.md`

### 执行方式

- 不改主 skill，先按 [tech-lead-pilot-plan.md](/Users/lijieli/org-claude-skills/docs/subagent-context-audit-20260411/tech-lead-pilot-plan.md:1) 做 `manual pilot`
- 至少跑 `3` 个连续真实复杂样本
- 每个样本都必须有配对基线
- 样本选择、基线配对、`M1~M6`、fail-fast 全部沿用 [tech-lead-pilot-plan.md](/Users/lijieli/org-claude-skills/docs/subagent-context-audit-20260411/tech-lead-pilot-plan.md:1) 的既定口径，`rollout-plan.md` 不另起一套规则
- 任一样本命中 fail-fast，整轮试点立即停止

### 本波次输出

- `3` 组试点样本的原始回收件
- `pilot-result.md`
- `before-after-metrics.md`
- `metric-counting-notes.md`

### 决策规则

- `PASS`：进入 `Wave 2`
- `FAIL`：停止扩圈，只保留调研与失败原因
- `INCONCLUSIVE`：只允许补样本一次或缩小试点范围一次；仍不清晰则停止，不进入 `Wave 2`

## Wave 2：最小必要回写 `tech-lead`

### 目标

只把已经被 `Wave 1` 证明有效的必要部分写回主 skill，避免把试点逻辑整包搬进生产流程。

### 推荐修改面

- `shared/skills/tech-lead/SKILL.md`
- `shared/skills/tech-lead/references/planning-modes.md`
- `shared/skills/tech-lead/references/plan-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-product-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-test-reviewer-prompt.md`
- `shared/skills/tech-lead/references/templates/plan-template.md`
- `shared/skills/tech-lead/scripts/completion_check.sh`

### 回写原则

- 只回写 `PASS` 样本里稳定有效的部分
- reviewer 层数不增加
- `DESIGN_OK`、用户确认、`plan.md` 真源、completion check 兜底不变
- 若某个试点角色只在部分样本有效，不进入主 skill，只保留为可选 playbook

### 完成条件

- 主 skill 可在不依赖人工额外解释的情况下运行
- 既有门禁不弱化
- 至少再跑 `1` 个非试点样本，且同时满足：
  - `bash shared/skills/tech-lead/scripts/completion_check.sh` 退出码为 `0`
  - 没有命中 `Wave 1` 同口径的 fail-fast
  - `M3` 不高于该样本配对基线
  - `M4` 不高于该样本配对基线，且最多多 `1` 轮

## Wave 3：扩到 `test-design`

### 前提

只有当 `tech-lead` 已经：

- 连续通过试点
- 完成最小回写
- 回写后新增样本满足：
  - completion check 通过
  - `M3 <=` 配对基线
  - `M4 <=` 配对基线，且最多多 `1` 轮
  - `M5 = 0`

才允许进入 `test-design`。

### 允许扩的工序

- `AC -> 用例` 映射草稿
- 等价性矩阵草稿
- `QA 交接契约` 草案
- 专项测试建议草稿

### 明确不扩的部分

- 不下放 `DESIGN-GAP(EQ)` 判定
- 不下放是否回流 `/design` 的裁决
- 不增加额外 reviewer 常驻角色

### 推荐修改面

- `shared/skills/test-design/SKILL.md`
- `shared/skills/test-design/references/testdesign-reviewer-prompt.md`
- `shared/skills/test-design/references/testdesign-product-reviewer-prompt.md`
- `shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md`
- `shared/skills/test-design/scripts/completion_check.sh`

## Wave 4：评估 `design`

### 进入条件

只有当 `tech-lead + test-design` 两站都证明：

- 沿各自试点口径，`M1 / M2` 中位数都低于各自配对基线
- `M3 / M4` 都不高于各自配对基线
- `M5 = 0`
- 观测窗口都沿用各自试点计划中“从阶段开始读取输入工件，到最终工件达到可交付收敛状态”为止

才允许讨论 `design`。

### 若进入，只允许试

- 只读运行时/依赖扫描
- 竞争假设
- 方案对比草稿
- ADR 初稿

### 仍然禁止

- 不下放最终技术裁决
- 不下放接口/边界最终确认
- 不把 `design` 改造成并行主脑

## 当前不建议动的两个阶段

### `product`

当前不进入本轮 rollout，只保留为后续候选：

- `S1` 静默信息收集
- 候选问题清单
- 影响范围初筛

原因：

- 它直接绑定用户共创
- 一旦误杀，会把歧义推迟到下游
- 当前优先级低于 `tech-lead`

### `delivery-owner`

当前不建议作为主改造对象。

只在任务量非常大时，才考虑补一个只做汇总、不做额外裁决的：

- 状态汇总工序
- 证据汇总工序

原因：

- 它更像收口放大器，不是首要根因
- 继续叠加协调者，很容易变成“管理管理者”

## 整体停机线

出现任一项，整体 rollout 暂停，不进入下一波：

- 某一波的主阶段试点触发 fail-fast
- 新增 sub agent 让主 Agent 需要阅读更多草稿才能裁决
- Gate、completion check、sign-off 被削弱或被绕开
- 没有真实样本和配对基线，却试图直接写回主 skill

## 推荐的立即下一步

按最佳实践，下一步不是直接改 `shared/skills/tech-lead/SKILL.md`，而是先补齐 `Wave 0` 的 5 个试点执行资产模板，然后再正式跑 `Wave 1`。

## 一句话版本

最佳实施计划就是：`先冻结合同和度量 → 先做 tech-lead 单点 manual pilot → 用真实样本判定 → 通过后最小化回写 tech-lead → 再扩到 test-design → 最后才评估 design`。
