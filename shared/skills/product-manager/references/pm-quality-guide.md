# PM 判断指南

Self-check 阶段读取本文；按本文复核产品判断，产物字段以 templates/contracts 为准。

## 证据到现状

先定位真实入口：谁在什么地方开始，触发什么动作，当前看到什么结果。

可用的 AS-IS 必须写出 actor、entry、trigger、steps、object state、visible result、pain point 和 evidence。自检 `evidence_sources[]`：`source_type` 写真实来源；`supports` 指向具体 AS-IS、TO-BE、Feature、Risk、AC 或设计交接判断；缺口用 `required_evidence` 和 `blocks_fields` 写清缺什么、阻断什么。只暂停被阻断结论。

可用：`截图支撑 ASIS-1 的入口和触发；缺登录失败日志，阻断 RISK-2 和 AC-3。`
不可用：`需要补证据。`

可用：`运营在后台订单页手动筛选待退款订单`。
不可用：`系统支持退款管理`。

## 现状到目标

固定 Director 范围，只改变达成 Phase 目标所需的业务行为。

TO-BE 必须覆盖：

- 正常路径：什么算成功。
- 边界路径：空态、无权限、额度、重复、超时或阈值。
- 失败路径：什么被阻止、重试、升级或保留。
- 可观察结果：用户、运营、对象状态、记录或通知发生什么变化。

任一路径改变 Phase 出口、范围、非目标或可行性，停止并回到用户或 Director。

## 产品模型到功能清单

流程闭合后再列能力。

- `IN_SCOPE`：本 Phase 必需，能追溯到 UNIT。
- `OUT_OF_SCOPE`：被 Director 或用户排除，不进 UNIT。
- `NEEDS_DECISION`：业务事实未裁决，不进 UNIT。

模块能力回答：哪个业务区域改变，新增什么能力，什么既有行为不能破坏。
入口场景回答：工作从哪里开始，谁触发，证据是什么，哪个 UNIT 负责。

## 业务语义

定义会影响流程、UNIT、AC、风险或 design handoff 的对象、状态、权限和规则。

- 对象：业务含义与生命周期。
- 状态：from -> trigger -> to -> observable result。
- 权限：role -> allowed action -> constraint。
- 规则：校验、审批、可见性、顺序、可逆性或高风险操作。

数据库字段、API 参数、组件属性、代码类型和测试实现留给下游角色。

## 风险

每个实质风险必须降解为 AC、Verification Plan、阻断项、下游 owner 或用户裁决。

`注意风险` 不算关闭。产物必须告诉团队观察什么、阻止什么、验证什么、由谁承接。

## UNIT 边界

一个 UNIT 只完成一个可交付行为闭环：

`输入或触发 -> 核心行为 -> 可观察结果`

出现以下情况继续拆：

- 不同 actor 可独立完成。
- 不同 trigger 互不依赖。
- 一部分可先交付。
- 结果有不同风险、权限或验证方式。

拆开会破坏用户可观察结果时保持在同一 UNIT。

## AC

AC 用业务操作和可观察结果证明行为。

每条 AC 写 example input、expected result、boundary case 和 failure mode。

不可用：`系统合理校验库存`。
可用：`库存调整数量大于当前可用库存时，提交被阻止，库存不变化，操作者看到超量原因。`

## Verification Plan

Verification Plan 告诉 `/test-design` 要证明哪个业务结果。

写业务操作、预期观察和证据目标；命令、测试框架、mock、fixture、selector 和代码由下游定义。

## Design Handoff

交接 PM 已定义业务边界、且需要 `/design` 选择 HOW 的决策。

可用：`审批流可复用 OA 或系统内建；必须保留审批结果可追溯、失败可接管、已执行不可回退；影响 UNIT-4。`

不可用：`设计一个审批接口。`

## 完成判断

下游不用猜这些问题时，PM 产物才算可交付：

- 现在是什么。
- 目标是什么。
- 工作从哪里开始。
- 谁能做。
- 哪个对象如何变更状态。
- 什么在范围内或范围外。
- 风险还剩什么，由谁承接。
- 每个 UNIT 完成什么闭环。
- AC 如何被观察。
- `/design` 必须决策什么。
