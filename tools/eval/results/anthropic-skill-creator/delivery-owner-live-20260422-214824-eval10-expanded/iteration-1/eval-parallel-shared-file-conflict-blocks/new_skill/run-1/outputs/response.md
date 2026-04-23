结论：**不能并行派发，控制动作是 `BLOCK`**。

- `口头 Phase 确认不是 canonical baseline`
- `检查 plan.json、tasks.json、design.json、test-cases.json 和 artifact-registry`
- `缺失 canonical 工件时不派发专家、不维护 delivery-state.json`
- `不派发 developer、review 或 qa`
- `恢复条件：工件齐备后才按批次/并行策略派发，并要求 developer-report、verify-result 和 fresh proving evidence。`

这次还额外触发了共享文件冲突阻断：

- `识别 T1/T2 写同一文件且 shared_files 未声明`

原因很直接：
- `T1` 和 `T2` 都要改 `shared/runtime/state.py`
- 两个任务的 `depends_on` 都为空，不能证明先后解锁关系
- `shared_files` 为空，plan 也没声明共享文件协议
- 在这种情况下，delivery-owner 不能把它们当作安全并行批次派发

如果你愿意，我下一步可以继续按 delivery-owner 的口径，给出“必须补哪些 canonical 工件后才能恢复派发”的最小清单。