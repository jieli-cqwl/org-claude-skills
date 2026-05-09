结论：必须回 `/product-director`，不能在 `/product-manager` 继续直接改。

对齐判断：本次问题触及两个 Director 锁定边界：`Phase` 是否合并属于 `D-S6 Phase 规划`，范围描述调整属于 `D-S5 范围 / 本期不做 / 约束`。这些都是 Director 基线字段；`product-manager` 只能消费和细化锁定字段，不能改写。

门禁与阻断：  
- 发现范围、Phase 边界、风险或根问题等锁定字段需要变化时，PM 必须停止细化。  
- 不得在 PM 阶段直接改 `brief.json / phase-prd.json` 里的 Director 锁定字段。  
- 必须回到 `/product-director` 重开共创链路，从受影响步骤重新闭合事实：范围回 `D-S5`，Phase 回 `D-S6`，必要时重新过 `D-G1 产品总监确认门`。  
- 未重新获得明确 `产品总监确认` 前，不得 handoff 回 PM。

下一步：由 `/product-director` 重新验证“两个 Phase 是否应合并”和“范围描述如何调整”，更新 Director 基线并重新冻结后，再交回 `/product-manager` 继续细化。此次 eval 不写文件、不启动服务、不跑长链路命令。