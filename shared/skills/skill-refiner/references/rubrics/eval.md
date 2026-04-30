# Eval 环节标准

## Why

eval 和测试证明 Skill 是否真的按新目标工作。只验证措辞或计划，会把旧噪音固化成门禁。

## 目标

eval、test-prompts、fixtures、dogfood 输出和 tests 覆盖核心行为、偏好锚点和回归风险。

## 裁决标准

1. 证明默认路径：如果 Skill 默认改文件，eval 必须要求真实 diff 和验证命令。
2. 锚点来自目标：preference anchors 对应用户确认的方法和质量判断。
3. 对比对象明确：with/without、old/new 或相邻 Skill 对比有意义。
4. fixture 有代表性：覆盖成功、边界、反触发和历史失败模式。
5. 测试不固化噪音：旧测试验证旧目标时更新或删除。
6. proof 直接：验证命令能证明 eval 期望，而不是只跑无关静态检查。

## 证据

- `evals/evals.json`。
- fixtures、dogfood-result、anchor-fidelity。
- tests 和 run-all 入口。
- proof command 输出。

## 问题信号

- prompt 明确“不需要实际改文件”，但 Skill 默认行为是改文件。
- expected_output 只要求解释理念。
- anchor 不能追溯到用户确认或目标失败模式。
- 测试要求保留已确认噪音。

## 验收

eval 和测试能证明当前 Skill 的主能力、偏好保真和关键反触发；旧目标门禁已改成新目标门禁。
