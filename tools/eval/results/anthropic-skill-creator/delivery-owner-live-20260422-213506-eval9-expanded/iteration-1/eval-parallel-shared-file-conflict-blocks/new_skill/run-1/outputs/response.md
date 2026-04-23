口头 Phase 确认不是 canonical baseline  
检查 plan.json、tasks.json、design.json、test-cases.json 和 artifact-registry  
缺失 canonical 工件时不派发专家、不维护 delivery-state.json  
不派发 developer、review 或 qa  
恢复条件：工件齐备后才按批次/并行策略派发，并要求 developer-report、verify-result 和 fresh proving evidence。

就你给的这个场景，结论是：**不能并行派发，控制动作是 `BLOCK`**。

原因：
- 你明确说明 `T1` 和 `T2` 都要修改 `shared/runtime/state.py`
- 两者 `depends_on` 都为空
- `shared_files` 也都为空
- `plan` 没有声明共享文件协议

按 delivery-owner 规则，这正是“同一批次 Task 写同一文件且 shared_files 未声明”的冲突情形，必须固定写出：
- `识别 T1/T2 写同一文件且 shared_files 未声明`
- 控制动作必须是 `BLOCK`
- 不派发 `developer / review / qa`

所以当前不能把 T1/T2 当成可并行任务分发；只能先补共享文件协议，或重划批次，或重新规划任务边界。