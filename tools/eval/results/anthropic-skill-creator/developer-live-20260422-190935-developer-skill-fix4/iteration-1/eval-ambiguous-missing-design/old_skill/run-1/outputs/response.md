按 `shared/skills/developer/SKILL.md` 处理后，当前必须阻断，不能直接实现 T2。

阻断原因：
- 缺少 Task 需求全文，尤其是 `AC 列表`
- 缺少 `design.json`
- 缺少权威 `file_range / files / task_scope`
- 当前 workspace 里也没有任何可执行的输入文件

按该 skill 规则，以上前置条件缺失时只能停止并上报，不能猜测实现范围、不能直接改代码、也不能进入 TDD。

如果你补齐这些材料，我可以继续按 developer skill 走完整流程：
- 先做代码探索和复用判断
- 再按 AC 做 RED → GREEN → REFACTOR
- 最后输出 `developer-report.json` 和自测结果