**阻断结论**

不能直接在 `product-manager` 里顺手改掉。

缺少 handoff 工件；docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 是准入必需输入，用于校验 director_confirmation.status、locked_fields、locked_field_digest、当前 Phase 边界与 14 天 timebox。

**复述理解**

目标：判断 PM 细化阶段能否扩大 Phase 1 范围，并修改 Director 已锁定业务规则。  
操作对象：Director 锁定的 Phase 范围、业务规则、锁定快照与 digest。  
预期结果：给出 PM 边界、阻断门禁和可执行后续入口。

**门禁判断**

- `M-HG-0`：本次未提供 `brief.json / phase-1/phase-prd.json`，PM 准入不成立。
- `M-HG-9`：扩大 Phase 范围、修改 Director 锁定业务规则，会改写 Director-owned 内容，PM 必须停止。
- `M-HG-10`：不能用脚本或 PM 手动补签 Director confirmation。
- `M-HG-5 / M-HG-11`：关键事实和 checkpoint 未闭合，不得继续细化、冻结 UNIT、写 AC 或 handoff。

**流程边界**

PM 只能在已冻结 WHY、范围和 Phase 边界内补 WHAT：业务流程、用户路径、规则映射、UNIT 闭环、AC、Verification Plan、设计待决策、评审和交付确认。PM 不负责重写上游 WHY、Phase 范围或 Director 锁定业务规则。

本次不生成 PRD、UNIT、AC 草案，不启动审查 agent，不写文件。

**下一步**

建议入口是 `/product-director`，由用户裁决是否重新确认 Phase 1 扩围和业务规则变更。重新确认并产出一致的 `brief.json / phase-1/phase-prd.json` 后，PM 才能从 `M-S0` 重新准入；通过后仍需补齐 UNIT 闭环定义、AC 示例输入/预期结果/边界情况/失败模式，以及排除项追踪。