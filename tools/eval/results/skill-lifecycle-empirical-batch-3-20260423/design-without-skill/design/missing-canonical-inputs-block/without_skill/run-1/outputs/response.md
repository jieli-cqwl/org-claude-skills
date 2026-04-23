理解：你要我对“订单退款技术设计”执行 skill eval；当前只有一句需求，且没有 `brief.json`、`phase-prd.json`、`UNIT` 文件。预期结果是阻断设计，不生成 `design.json`。

结论：**阻断设计输出**。

阻断原因：
- 缺少 canonical 需求基线：没有 `brief.json` / `phase-prd.json`
- 缺少 UNIT 基线：无法确认业务流程、边界、验收标准、异常场景
- 只有一句“订单退款”需求，不能据此推导架构、接口、状态机、数据模型或风险控制

流程边界：
- design 阶段只能基于已冻结的需求与 UNIT 做技术设计
- 不负责凭一句话补 PRD、补业务规则或自行假设退款流程
- 不得生成 `design.json`，否则会把未确认需求伪装成设计结论

下一步：
1. 先由 `product-director` 补齐并冻结业务目标、范围、阶段边界，产出 `brief.json`
2. 再由 `product-manager` 细化退款流程、UNIT、AC、异常与验收口径，产出 `phase-prd.json` 和 UNIT 文件
3. 前置产物齐备后，再进入技术设计阶段生成 `design.json`