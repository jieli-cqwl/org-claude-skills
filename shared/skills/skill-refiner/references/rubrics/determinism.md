# Determinism 环节标准

## Why

确定性事项靠文字提醒会失败。LLM 应做理解、判断和取舍；可枚举、可复验的检查应由工程机制执行。

## 目标

前置校验、schema 检查、引用扫描、hook gate、静态 checker 和测试都有明确入口、时机和失败状态。

## 裁决标准

1. 判断可分类：区分专业判断和确定性检查。
2. 入口明确：脚本、schema、hook、gate 或测试命令可执行。
3. 时机明确：知道由主流程、hook、CI、eval 或人工复验触发。
4. 参数明确：命令需要的路径、task id、payload 或 fixture 必须可定位；缺参数时阻断，不猜测。
5. 失败可行动：失败结果能指向修复、阻断、回退或上游裁决。
6. 证据新鲜：完成证明来自当前输出、当前产物或可复验命令，不用历史结论替代。

## 证据

- scripts、schemas、hooks、tests、eval proof command。
- `shared/hooks/registry.json` 或 runtime entry。
- shell/python checker 输出。
- 失败 fixture。

## 问题信号

- “执行前确认 X 存在”但没有命令。
- 命令包含 `$PHASE_DIR`、`$TASK_ID` 等参数，但 Skill 没给出参数来源。
- 只有命令字符串，没有当前输出或复验结果。
- hook 何时触发、payload 从哪来、失败如何处理不清楚。
- LLM 自审替代 schema、lint、测试或引用扫描。

## 验收

确定性检查能被直接运行或由明确运行面触发；失败时不会让 Skill 继续假装完成。
