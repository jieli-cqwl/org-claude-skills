# Design — product-design-cross-review

创建日期: 2026-04-02

## Why

`/product` 的 S11 和 `/design` 的 S9 当前都依赖单个审查子代理顺序完成三视角审查，耗时与视角之间的相互校验能力都受限。需要引入 Team 并行评审，在不改变现有外层修复循环、PASS/WARN/FAIL 判定和 `cross-review.md` 主契约的前提下，让三视角并行执行并支持受控的横向质疑。

## Scope

- 范围内: 为 `/product` S11 和 `/design` S9 设计 Team 并行评审模式；定义 Caller、Review Lead、Reviewer 的职责；定义 `R1 -> R2 -> R2.5 -> R3` 内层流程；定义回退、handoff、输出契约和验证方式。
- 范围外: 改造 `/test-design`、`/tech-lead`、`/project-manager` 的评审流程；重写共享的 `review-iteration-protocol.md` 与 `review-fix-loop-protocol.md`；在本轮设计中直接修改实现代码或 `completion_check.sh`。

## Approach

采用“Caller 管外层、Lead 管内层、Reviewer 只产出结构化结果”的三层执行模型。

外层循环保持现状。Caller 仍然负责 `user_directed` 修复流程、用户确认、不收敛暂停、`BLOCKED` 熔断和“仅 FAIL 视角重审”。Team 只替换一次审查实例内部的执行方式，不改变外层协议本身。

内层流程拆为四段。R1 由 active 视角并行做广度扫描；R2 严格保持原共享协议语义，只基于本视角上一轮 findings 和 coverage gaps 做深挖；R2.5 是 Team 专用的横向质疑协调阶段，不计入共享协议轮次，只负责 challenge、仲裁和合并；R3 仍是对抗审查，只要任一 active 视角在 R2.5 合并后出现新 FAIL，就由全部 active reviewer 统一进入 R3。

写入模型采用单一真相源。Reviewer 保留本视角 stable issue id，但在 Team 模式下不再直接写 `product-cross-review.md` 或 `design-cross-review.md`。Review Lead 作为唯一落盘者，统一生成各视角 section、`## 审查结论`、`## 审查轮次` 和 `## 横向质疑记录`。这样可以避免并发写冲突，并保证 section 头、Issue Count、Delta 声明和汇总表来自同一份归并结果。为保证回退可用，reviewer prompt 需要支持双模式：Team 模式向 Lead 发送结构化结果，单子代理 fallback 模式继续沿用现有直接写文件契约。

兼容性策略采用“主契约不动、附录增强”。`cross-review.md` 的主真相来源仍是 `## 审查结论`、各视角 section 和 `## 审查轮次`。新增的 `## 横向质疑记录` 只作为说明性附录。`[DISPUTED]`、`[WITHDRAWN]`、`[RESOLVED-BY-LEAD]`、`[BLOCKED]` 这类状态不只留在附录里，而是进入最终 finding 本体，并在 `prd.md` / `design.md` 的承接记录里保留。

回退路径保持显式、可解释和最小影响。Team 创建失败、关键 agent 启动失败或 Lead 超时无响应时，Caller 必须显式报告原因，然后回退到单子代理顺序模式；但回退范围只限当前 active 视角集合，不允许重新打开已 PASS 视角。`[FALLBACK-MODE]` 只能作为独立说明块放在文档主标题下方或“横向质疑记录”中，不能污染既有标题和头字段。

## Alternatives Considered

| 方案 | 优势 | 劣势 | 结论 |
|------|------|------|------|
| 保持单子代理顺序三视角 | 实现最小；无兼容性改造成本 | 性能无改善；无法建立横向质疑机制 | 不采用 |
| 三 reviewer 并行，但各自直接写 section | 复用现有 reviewer prompt，改造面较小 | 并发写文件容易冲突；`审查结论`、Issue Count、Delta 很难保证一致 | 不采用 |
| 三 reviewer 并行，Lead 唯一落盘，并把 challenge 拆成 `R2.5` | 并发安全；R2 原语义保持清晰；更容易保证主契约一致 | 需要同步改 reviewer prompt 和 handoff 模板 | 采用 |

## Key Decisions

- D1: Team 模式只替换单次审查实例的内部执行，不改外层 `user_directed` 修复循环。
  - Reason: 这样才能保持 `/product` 和 `/design` 现有的用户确认、不收敛暂停和仅 FAIL 视角重审语义。
- D2: Review Lead 作为 `cross-review.md` 唯一写入者。
  - Reason: 统一生成 section、汇总表和 Delta，避免 reviewer 并发写文件造成格式和计数冲突。
- D3: 横向质疑拆为 `R2.5`，不混入原共享协议的 R2。
  - Reason: R2 需要保持“本视角深挖”的语义；challenge 是 Team 协调行为，不应改写共享协议定义。
- D4: R3 触发范围为全部 active reviewer，而不是局部 reviewer。
  - Reason: 原协议的 R3 是 review instance 级别的第三轮，对抗审查不应退化为局部补审。
- D5: 回退时只审当前 active 视角集合。
  - Reason: 避免在回退时重新打开已 PASS 视角，破坏外层 FAIL 趋势和收敛判断。
- D6: `横向质疑记录` 为说明性附录，争议状态必须进入最终 finding 与 handoff。
  - Reason: 这样既不打破现有 gate 的主解析路径，又不会让关键争议信息在下游承接时丢失。

## Success Criteria

- 在测试 feature 上执行 `/product` S11 和 `/design` S9 时，首轮审查都能够创建 Team，并由 active reviewer 并行完成 R1。
- Reviewer 在 Team 模式下不直接写 `cross-review.md`，最终文件由 Review Lead 统一生成，且 `## 审查结论`、各视角 section、`## 审查轮次` 之间保持一致。
- Team 模式下存在明确的 `R2.5` 横向质疑阶段；R2 仍只处理本视角深度聚焦，R3 只在 R2.5 后出现新 FAIL 时触发。
- FAIL 后的外层流程仍然要求主 agent 修复并 `AskUserQuestion`，且仅对 FAIL 视角重审；连续 2 轮不收敛时暂停，同一 Issue 连续 3 轮未关闭时标记 `BLOCKED`。
- Team 失败时能够显式回退到单子代理顺序模式，但只处理当前 active 视角集合，且不会破坏既有 `cross-review.md` 解析契约。
- `[DISPUTED]` 等状态能在最终 finding 和 `prd.md` / `design.md` 承接记录中保留，而不是只存在于附录。
