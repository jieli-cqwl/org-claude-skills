**结论：TL-002 dry-run 只输出规划草案，不进入真实执行。**
Planning 判断为：上游 PM / Design / Test-design 齐备到可做 Stage 1 synthetic planning，但存在两个高风险执行未知项，必须先设 readiness gate；未通过 readiness 前，不得释放 developer、不写真实 `tasks.json/plan.json`、不声明真实 qft-pai 可交付。

**1. 输入边界声明**

本次输入是 `synthetic planning fixture`，只用于 Stage 1 能力训练。已消费：TL-002 input、TD-002 test-design output、TD-002 evaluator、PM-002 output、TD-002 design fixture、tech-lead skill 与规则。未运行真实 preflight，未进入 `/Users/lijieli/project/qft-pai`。

**2. Planning Readiness 判断**

状态：`DRY_RUN_PLANNING_READY_WITH_EXECUTION_STOP`。
理由：产品范围、UNIT/AC、设计 IF、TDO-01~13 可追溯；TD evaluator 为 `warn / continue / P2`。但 `GAP-TD002-01/02` 是执行前提风险，不能埋进普通开发任务，必须成为 readiness task 和后续 stop condition。

**3. Readiness Task**

`TL002-RDY-01`：证明样板执行数据与链路记录证据入口可用。
覆盖 `GAP-TD002-01`：真实 `channel_id`、`bot_id`、样板触发语、关键上下文 keys。
覆盖 `GAP-TD002-02`：`chain_record` 真实落点与查询证据入口。
成功信号：能用同一 `chain_id` 关联输入样例、阶段输出、最终记录查询入口。
失败/停止：任一真实值缺失，或 `chain_record` 无可复验查询入口，则停止释放 `TL002-T1~T5`。

**4. 风险驱动实施批次**

| Batch | Task | 排序原因 |
|---|---|---|
| B0 | `TL002-RDY-01` | 最大未知项前置，先验证执行数据与证据入口 |
| B1 | `TL002-T1` 链路状态与记录基础合同 | 所有阶段门控和证据都依赖它 |
| B2 | `TL002-T2` 入口 + 前置门控 | 最早暴露范围外、空消息、场景判断风险 |
| B3 | `TL002-T3` 上下文门控 | 直接消费 GAP-TD002-01，关键上下文缺失必须阻断 |
| B4 | `TL002-T4` 单 bot 调度 + 响应生成 | 依赖上下文可用，且必须证明不自动外发 |
| B5 | `TL002-T5` 端到端证据矩阵与重试/停止验证 | 集成收口，不是先做包装 |

**5. 关键路径与依赖**

关键路径：`TL002-RDY-01 -> TL002-T1 -> TL002-T2 -> TL002-T3 -> TL002-T4 -> TL002-T5`。
依赖根是 readiness 与 `IF-06 chain_record` 证据入口。任何一环失败，后续依赖任务停止，不允许用 mock-only 证据替代。

**6. Task 合同草案**

| task id | 目标 | 上游 refs | test refs | 证据路径 | 依赖 | 风险 / stop condition |
|---|---|---|---|---|---|---|
| `TL002-RDY-01` | 补齐真实执行数据与 `chain_record` 查询入口 | TL input GAP-TD002-01/02；TD evaluator downstream_impact | 影响 TDO-01/03/05/11/12/13 | `dry-runs/tl-002/evidence/readiness-data-and-chain-record.md` | 无 | 高风险；缺任一真实值或查询入口即停止全部实施 |
| `TL002-T1` | 建立阶段状态、原因、证据摘要、停止字段、一次重试记录的基础合同 | PM UNIT-06；Design IF-06；TD output Evidence Expectation | TDO-11/12/13 | `dry-runs/tl-002/evidence/stage-contract-and-record-foundation.md` | RDY | 高风险；无法证明 `chain_id` 串联或未执行阶段记录则停止 |
| `TL002-T2` | 完成消息入口与前置场景门控，范围外/空消息不得继续 | PM UNIT-01/02 AC；Design IF-01/02/06 | TDO-01/02/03/04/12/13 | `dry-runs/tl-002/evidence/entry-preprocess-gates.md` | T1 | 风险：边界误放行；任一排除/阻断后仍执行下游即停止 |
| `TL002-T3` | 完成上下文取用门控，关键上下文缺失必须停止 | PM UNIT-03 AC；Design IF-03/06；GAP-TD002-01 | TDO-05/06/12/13 | `dry-runs/tl-002/evidence/context-gate.md` | T2 | 高风险；缺关键 keys 或跨场景历史被放行即停止 |
| `TL002-T4` | 完成单 bot 调度与响应预览生成，不自动外发 | PM UNIT-04/05 AC；Design IF-04/05/06 | TDO-07/08/09/10/12/13 | `dry-runs/tl-002/evidence/dispatch-response.md` | T3 | 风险：多 bot/未知 bot 误调度、无依据生成；任一发生即停止 |
| `TL002-T5` | 汇总成功、排除、阻断、失败、一次重试的端到端证据矩阵 | PM UNIT-01~06；Design IF-01~06；TD QA handoff | TDO-01~13 | `dry-runs/tl-002/evidence/e2e-chain-record-matrix.md` | T2/T3/T4 | 集成风险；证据缺阶段状态/原因/未执行阶段/重试记录即不可验收 |

以上证据路径均为 dry-run 目标路径，本次不创建文件。

**7. 不可并行 / 可并行边界**

不可并行：B0、B1 必须串行；B2~B4 是同一业务链路关键路径，默认串行；B5 必须最后收口。
可并行：只有在真实执行阶段确认无共享文件、无共享状态写入、测试数据隔离后，B2 内部的正向/排除用例证据准备可并行；这不等于本 dry-run 可派发 developer。

**8. 给 Delivery-owner 的消费提示**

只能把本输出当 TL-002 dry-run 草案消费。真实交付前必须重新跑真实 preflight，等待用户确认当前 plan version，再写 canonical `plan.json/tasks.json`。调度时先看 `TL002-RDY-01`，它未通过时不得释放任何后续任务。

**9. 明确禁止进入范围**

禁止语言、框架、数据库、云产品选择。禁止写真实 `tasks.json/plan.json`。禁止派发 developer。禁止真实排期。禁止声明 Stage 1 通过。禁止把本 synthetic fixture 当真实 qft-pai 证据或真实交付依据。