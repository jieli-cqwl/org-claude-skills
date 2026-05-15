**结论**

TD-002 dry-run 可形成可消费的测试义务：UNIT / AC / design interface / test obligation 可追溯，覆盖正向、范围外、阻断、失败、回滚/补偿边界与证据完整性。当前 synthetic fixture 对本次测试设计足够，**无 blocking typed gap**。本轮未运行真实 preflight，未写 `test-cases.json`，不声明 Stage 1 通过，也不代表真实 qft-pai 可交付。

**1. 输入边界声明**

输入只采用 TD-002 synthetic frozen fixture、PM-002 dry-run 输出、Stage 1 case pack 与 `test-design` skill。该 fixture 只用于 Stage 1 能力训练，不是真实 qft-pai 证据，不代表真实 `design.json` 已冻结。

本次只输出 dry-run 文本产物；不执行 QA、不批准发布、不拆开发任务、不补产品或设计结论。

**2. Test Basis Analysis**

产品基线：两周内验证单业务线 / 单渠道 / 单 bot / 单真实场景的端到端样板闭环。范围是三方消息回调后的接收、前置处理、上下文取用、agent 调度、响应生成、可观察记录。

设计基线：采用“阶段门控闭环”。每阶段必须输出状态、原因、证据摘要；响应只生成给验收查看，不自动对外发送；关键上下文缺失必须停止；系统失败同阶段允许一次受控重试，仍失败则记录 `failed` 并停止后续阶段。

核心测试规则：阶段状态决定是否继续；阻断/排除/失败后下游阶段不得执行；成功链路必须从 `IF-01` 到 `IF-06` 全链记录；任何阶段缺证据不能作为可验收样板记录。

**3. Traceability Matrix**

| Test obligation | UNIT / AC | Design interface | 断言目标 |
|---|---|---|---|
| TDO-01 正向入口 | UNIT-01 AC-01 | IF-01 | 已选渠道 + 已选 bot + 非空消息返回 `accepted`、`chain_id`，进入前置处理 |
| TDO-02 入口排除 | UNIT-01 AC-02 | IF-01 / IF-06 | 非选渠道、非本期 bot、bot 缺失、空消息返回 `excluded` 或停止原因，后续阶段不执行 |
| TDO-03 前置通过 | UNIT-02 AC-01 | IF-02 | 样板触发语 + 明确诉求返回 `passed`、`scenario_match` |
| TDO-04 场景排除/阻断 | UNIT-02 AC-02 | IF-02 / IF-06 | 非样板诉求 `excluded`；无法判断场景或空消息 `blocked`；混合诉求仅保留样板依据 |
| TDO-05 上下文可用 | UNIT-03 AC-01 | IF-03 | 必要上下文存在返回 `available`、`context_snapshot_ref`；非必要缺失不阻断 |
| TDO-06 上下文阻断 | UNIT-03 AC-02 | IF-03 / IF-06 | 关键上下文缺失或跨场景完整历史诉求返回 `blocked`，不得进入调度 |
| TDO-07 单 bot 调度 | UNIT-04 AC-01 | IF-04 | 上下文可用且目标 bot 明确时 `dispatched`，`target_bot` 为本期单 bot |
| TDO-08 调度阻断 | UNIT-04 AC-02 | IF-04 / IF-06 | 多 bot 协作诉求或目标 bot 不明返回 `blocked`，不得进入响应生成 |
| TDO-09 响应生成 | UNIT-05 AC-01 | IF-05 | 基于原消息 + 上下文 + 单 bot 生成 `response_preview`，且不自动外发 |
| TDO-10 生成受阻/失败 | UNIT-05 AC-02 | IF-05 / IF-06 | 上下文不足、冲突或无法可靠生成时 `blocked/failed`，不得伪造结论 |
| TDO-11 成功记录 | UNIT-06 AC-01 | IF-06 | 完整成功链路记录全部阶段、状态、原因和证据摘要 |
| TDO-12 阻断/排除/失败记录 | UNIT-06 AC-02 | IF-06 | 记录 `stop_stage`、`stop_reason`、`not_executed_stages`，区分范围外、业务阻断、系统失败 |
| TDO-13 重试与补偿边界 | frozen design | 各 IF / IF-06 | 同阶段系统失败最多一次受控重试；仍失败则 `failed`，停止后续阶段，记录尝试与原因 |

**4. 测试条件和用例义务**

正向：执行一条完整样板消息链路，断言 `accepted -> passed -> available -> dispatched -> generated -> recorded`，证据必须能用同一 `chain_id` 串联。

范围外：非选渠道、非本期 bot、非样板场景、跨场景完整历史、多 bot 编排诉求必须被排除或阻断，且证明未取上下文、未调度、未生成响应。

阻断：空消息、无法判断场景、关键上下文缺失、目标 bot 不明、无法可靠生成，必须停止在对应阶段并记录原因。

失败：任一阶段系统失败先做一次受控重试；重试仍失败则 `failed`，不得继续下游阶段。

回滚/补偿边界：本设计没有自动对外发送，补偿义务是“停止后续阶段 + 完整记录失败阶段与未执行阶段”；不得假设外部消息已撤回或补发。

证据完整性：任何链路缺阶段状态、原因、证据摘要、`stop_stage` 或 `not_executed_stages`，均不得作为可验收样板记录。

**5. Evidence Expectation**

每条义务至少需要：输入 fixture、接口输出、同一 `chain_id`、阶段状态、原因、证据摘要、最终 `chain_record`。

成功链路证据：`IF-01` 到 `IF-06` 全部 stage results 存在，`response_preview` 可查看，且有“不自动对外发送”的证据。

阻断/排除/失败链路证据：停止阶段、停止原因、后续未执行阶段、失败重试记录。只看到“失败”两个字不合格。

**6. Typed Gaps**

| Gap | Type | Blocking | Owner | Evidence refs | Next action |
|---|---|---:|---|---|---|
| GAP-TD002-01 | TESTABILITY_GAP | false | human / QA owner | TD-002 fixture 只给接口字段，未给真实执行数据值 | 真实执行前补齐选定 `channel_id`、`bot_id`、样板触发语、关键上下文 keys；不阻断本 dry-run 测试义务形成 |
| GAP-TD002-02 | TESTABILITY_GAP | false | design / tech-lead | IF-06 定义记录字段，但未指定真实存储位置或查询入口 | 开发拆 task 时绑定 `chain_record` 的落点和查询证据；不阻断本 dry-run handoff |

无 `PRODUCT_GAP`、`DESIGN_GAP`、`TRACE_CONFLICT`、`SCOPE_DRIFT`、`EQ_GAP` 阻断项。

**7. QA Handoff Contract**

QA 只消费测试义务，不执行发布裁决。冒烟必须覆盖 TDO-01 + TDO-03 + TDO-05 + TDO-07 + TDO-09 + TDO-11 的完整成功链路。

QA 功能/深测必须覆盖范围外、阻断、系统失败重试、响应不外发、证据完整性。不得跳过 `chain_record` 校验；缺 `chain_id` 串联证据时，本链路验收无效。

QA 证据包应包含：输入样例、接口响应或执行记录、链路记录、失败/阻断记录、未执行阶段证明、响应预览截图或记录、无自动外发证明。

**8. 给 Tech-Lead 的消费提示**

拆任务时不要把这些义务压成“写测试”。每个 Task 至少绑定一个 `TDO-*`、对应 `IF-*`、状态枚举、原因字段、证据摘要和停止规则。

优先实现可自动化验证的契约与状态门控：入口过滤、阶段状态、停止后不执行、一次重试、`chain_record` 聚合。GAP-TD002-01/02 是提测前需要补齐的执行数据与证据落点，不是本轮 planning 的产品范围扩展许可。

**9. 明确禁止进入范围**

本 dry-run 不进入真实 qft-pai，不运行真实 preflight，不写 `test-cases.json`，不执行 QA，不批准发布，不拆开发任务，不做语言选型，不补产品/设计结论，不声明 Stage 1 通过或真实业务可交付。