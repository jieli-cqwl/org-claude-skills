理解：`sample-feature` 的设计方案已讨论完，本次只说明交给 `tech-lead` 前的收口要求，不读取目标 `SKILL.md`，不写文件，不联网，不启动服务。

交付给 `tech-lead` 前必须收口的 canonical 产物是：

`<phase工作区>/design.json`

该文件必须包含至少这些顶层内容：

```json
{
  "input_analysis": {},
  "key_decisions": [],
  "interface_boundary": {},
  "quality_attributes": {},
  "migration": {},
  "verification": {},
  "rollback": {}
}
```

门禁要求：

- `input_analysis`：说明输入文件、业务目标、范围边界、已确认前提。
- `key_decisions`：沉淀关键设计决策、取舍理由、不可变约束。
- `interface_boundary`：明确模块/API/数据/责任边界，避免交给实现阶段再猜。
- `quality_attributes`：明确性能、可靠性、安全性、可维护性等质量要求。
- 必须保留迁移闭环：如何从旧状态迁移到新设计。
- 必须保留验证闭环：如何证明设计满足目标和验收条件。
- 必须保留回滚闭环：失败后如何恢复或降级到已知安全状态。
- 若设计审查仍有未解决的 `FAIL`，不得标记设计完成，也不得交给 `tech-lead` 进入计划拆解。

下一步：补齐并确认 `<phase工作区>/design.json` 后，只有在审查无阻塞、迁移/验证/回滚闭环完整时，才能交给 `tech-lead` 继续生成实施计划。