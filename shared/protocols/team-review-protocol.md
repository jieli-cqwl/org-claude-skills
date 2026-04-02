# Team Review 协议

> 类型：skill-specific 协议（非通用按需知识）。
> 职责：为 `/product` S11 与 `/design` S9 提供 Team 并行审查执行模型。
> 边界：本协议只定义 Team 模式下的角色协作、消息契约、`R1 -> R2 -> R2.5 -> R3`、回退与输出归并；外层修复循环仍遵循 `protocols/review-fix-loop-protocol.md`，共享内层轮次语义仍以 `protocols/review-iteration-protocol.md` 为准。

## 角色

| 角色 | 职责 |
|------|------|
| Caller | 管外层循环、`fix_mode=user_directed`、每轮修复后的 `AskUserQuestion`、仅 FAIL 视角重审、回退与最终修复 |
| Review Lead | 协调 R1 / R2 / R2.5 / R3、处理 challenge、统一写 `cross-review.md` |
| Reviewer | 维护本视角 stable issue id、执行审查、回传结构化 `review_result` |

## active 视角集合

- 首轮：3 个视角全部 active
- 重审：仅 FAIL 视角 active
- active 视角数量 `< 2` 时禁用横向质疑

## 写入模型

- Reviewer 只发结构化消息，不直接写 `product-cross-review.md` 或 `design-cross-review.md`
- Review Lead 是唯一文件写入者
- stable issue id 由 reviewer 分配并持有，Lead 不得重编号

## 消息契约

```text
review_result:
  perspective: 产品 | 架构 | 测试
  round: R1 | R2 | R3
  verdict: PASS | WARN | FAIL
  issue_ids: [...]
  findings: [...]
  covered: [...]
  coverage_gaps: [...]
  delta:
    new_issue_ids: [...]
    confirmed_issue_ids: [...]
    overturned_issue_ids: [...]
  challenges: [...]

challenge_result:
  round: R2.5
  challenge_id: CH-<perspective>-NNN
  challenger_perspective: 产品 | 架构 | 测试
  target_perspective: 产品 | 架构 | 测试
  target_issue_id: <stable issue id>
  challenge_type: 事实矛盾 | FAIL 证据不足 | 边界越权 | 遗漏关联
  claim: ...
  evidence: [...]
  requested_action: 保持 | 降级 | 撤回 | 补证

challenge_response:
  round: R2.5
  challenge_id: CH-<perspective>-NNN
  responder_perspective: 产品 | 架构 | 测试
  disposition: 接受 | 拒绝 | 部分接受
  response_issue_ids: [...]
  rationale: ...

lead_decision:
  round: R2.5
  challenge_id: CH-<perspective>-NNN
  status: accepted | withdrawn | disputed | resolved-by-lead
  target_issue_id: <stable issue id>
  decision: ...
  follow_up: 保持 | 降级 | 撤回 | R3 继续对抗
```

- `challenge_id` 由发起 challenge 的 reviewer 分配并保持稳定
- `target_issue_id` 必须引用目标 reviewer 持有的 stable issue id
- Lead 依据 `challenge_result + challenge_response` 生成唯一 `lead_decision`
- `accepted / withdrawn / disputed / resolved-by-lead` 的裁决结果必须同步回写最终 finding 本体与 `## 横向质疑记录`

## 内层流程

### R1

- active reviewer 并行做广度扫描
- Lead 收集各视角结果，为每个 active reviewer 构造 R2 注入

### R2

- 严格保持共享协议语义
- 仅基于本视角上一轮 findings 与 coverage_gaps 做深度聚焦
- 不在此阶段处理横向裁决

### R2.5

- Team 模式专用协调阶段，不计入共享轮次
- 仅在 active 视角数 >= 2 时启用
- reviewer 可对其他视角 findings 发起 `challenge_result`，目标 reviewer 必须返回 `challenge_response`
- challenge 类型仅限：事实矛盾、FAIL 证据不足、边界越权、遗漏关联
- Lead 完成 `lead_decision`，并将 `accepted / withdrawn / disputed / resolved-by-lead` 归并到最终 finding

### R3

- 任一 active 视角在 R2.5 合并态中出现新 FAIL，则所有 active 视角进入 R3
- R3 不接受新的横向质疑
- R3 只执行共享协议中的对抗审查

## 外层循环保真

- `fix_mode=user_directed`
- 每轮修复后必须 `AskUserQuestion`
- 连续 2 轮 FAIL 数不减少时暂停并升级用户决策
- 同一 Issue 连续 3 轮未关闭时标记 `BLOCKED`
- 外层重审粒度保持为仅 FAIL 视角

## 输出契约

- `## 审查结论`、各视角 section、`## 审查轮次` 仍是主真相来源
- `## 横向质疑记录` 为说明性附录
- `[DISPUTED]`、`[WITHDRAWN]`、`[RESOLVED-BY-LEAD]`、`[BLOCKED]` 必须进入最终 finding 本体

## 回退

- TeamCreate 失败、关键 agent 启动失败或 Review Lead 超时无响应时，Caller 必须显式报告原因
- 回退到单子代理顺序模式
- 只处理当前 active 视角集合，不得重新打开已 PASS 视角
- `[FALLBACK-MODE]` 只允许出现在独立说明块或 `## 横向质疑记录` 中
