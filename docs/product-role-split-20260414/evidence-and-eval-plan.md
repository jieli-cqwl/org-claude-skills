# Product Role Split 取证清单与 Eval 计划

日期：2026-04-15

## 目标

这份文档聚焦 `/product-director + /product-manager` 拆分后的最小可验证证据面：
- 验证 Director 是否把根问题、目标、范围和 Phase 规划收口并冻结。
- 验证 Manager 是否基于 handoff 继续细化 UNIT / AC，而不是重写 Director 锁定内容。
- 验证 lock snapshot、兼容入口和下游链路在真实运行里是否可回归。

## Director Eval

### 场景 1

- 场景 ID：`product-director-p1-clear-single-phase`
- 目标：清晰需求下保持单 Phase、轻量冻结，不做过度切片。

### 场景 2

- 场景 ID：`product-director-p2-solution-anchoring`
- 目标：用户给方案时，仍能先回到真实问题，再冻结 Director 基线。

### 场景 3

- 场景 ID：`product-director-p3-multi-phase-value-slicing`
- 目标：对多闭环需求按业务价值切 Phase，而不是按实现步骤均分。

## Manager Eval

### 场景 4

- 场景 ID：`product-manager-p1-handoff-readiness`
- 目标：验证 Manager 只在 `brief.lock.json + prd.lock.json` 就位后继续工作。

### 场景 5

- 场景 ID：`product-manager-p2-lock-drift-blocking`
- 目标：验证 Manager / reviewer 会阻断对 Director 锁定字段的改写。

### 场景 6

- 场景 ID：`product-manager-p3-unit-boundary-cocreation`
- 目标：验证 Manager 能把 Phase 内需求细化为边界清晰的 UNIT 与 AC。

## Grader 规划

- `tools/eval/graders/product-director-thinking-grader.md`
  - 关注根问题、成功标准、Phase 切片与 Director 冻结质量
- `tools/eval/graders/product-manager-unit-quality-grader.md`
  - 关注 handoff readiness、lock drift 阻断、UNIT 边界与 AC 质量

## 落地顺序

1. 先补齐 6 个新 scenario 文档和 2 个 grader。
2. 更新 `tools/eval/run_skill_eval.sh` 的 check/status/summary 索引。
3. 后续再根据真实 replay 结果细化 grader 维度，而不是先堆更多样本。
