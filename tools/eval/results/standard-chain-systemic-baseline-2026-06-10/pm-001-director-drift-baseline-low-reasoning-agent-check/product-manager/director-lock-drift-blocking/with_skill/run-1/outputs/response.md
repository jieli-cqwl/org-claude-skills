结论：不能。PM 不能在 `product-manager` 里顺手改 Director 已锁定的业务规则，也不能扩大 Phase 1 范围。

状态：`BLOCKED at Handoff gate`

owner：Director / 用户裁决  
阻断事实：Phase 1 范围需要扩大，且原 Director locked business rules 需要变更，已触发 Director baseline drift。  
影响产物：`phase-prd.json`、后续 UNIT、AC、Verification Plan、Design handoff 全部不能继续基于旧 baseline 细化。  
推荐默认值：PM 保持当前 Director baseline 不变；仅记录漂移，不产出新的 PM 产品结论。  
回流节点：Director handoff / Director Phase 重新确认。  
恢复条件：Director 重新确认 Phase 1 的范围、目标、出口、非目标、业务规则、风险和时间盒，并更新/确认 `director_confirmation.status=passed` 后，PM 才能重新进入 Handoff gate。

下一步问题：是否确认把“扩大 Phase 1 范围 + 修改原锁定业务规则”回流给 Director 重新裁决？