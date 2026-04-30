我理解：你要在当前 eval 中模拟 `product-manager` 的准入流程，但不得读取目标 skill 文件、不联网、不生成完整 PRD/UNIT/AC。本轮只能执行 **M-S0 准入校验**。

**M-S0 结果：BLOCKED**

原因：当前 workspace 没有输入文件，且不能只接受“已通过 Director 确认”的口头描述。进入业务流程细化、UNIT 与 AC 收口前，必须先校验 Director 基线材料。

需要你提供以下之一：

1. `brief.json` 的路径或完整内容  
2. `phase-prd.json` 的路径或完整内容  

校验重点：

- `director_confirmation` 是否明确通过
- `locked_fields` 是否存在且已冻结
- 当前 Phase 是否确认为 Phase 1
- Phase 1 边界、目标、范围与不可变字段是否清楚
- 「商家入驻自动审核」是否属于该 Phase 的已确认范围

在准入通过前，我不会输出 PRD、UNIT 或 AC 草案。

下一步：请提供 `brief.json` 与 `phase-prd.json` 的路径或内容，我将继续执行 M-S0 校验，并只在通过后进入后续细化。