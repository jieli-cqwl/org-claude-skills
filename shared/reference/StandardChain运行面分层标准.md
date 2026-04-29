# Standard Chain 运行面分层标准

## Main Runtime Layer

| Layer | Responsibility | Non-Responsibility |
| --- | --- | --- |
| SKILL.md | 触发、角色职责、主流程、硬门禁、输入输出、停机/路由、reference 触发条件 | 长方法论、历史背景、模板正文、机械校验逻辑 |
| references/ | 按需方法论、判断框架、复杂场景指南 | 隐藏 hard gate、定义 runtime truth、承载当前状态 |
| canonical schema | artifact shape、必填字段、枚举、基础结构约束 | 证明语义真实、证明 fresh proof 真的发生 |
| canonical template | artifact 初始骨架 | 字段语义真源、状态流转裁决、完成判定 |
| script | 稳定命令入口、参数解析、调用 validator/gate | 业务判断、设计判断、用户确认 |
| validator | schema、ref、字段、范围、证据结构等确定性校验 | 风险接受、业务取舍、设计方案裁决 |
| gate | 根据校验结果放行、阻断、路由 owner | 静默修复、替角色做决定 |
| projection/report template | 从 canonical artifact 派生的人类 display | runtime truth、机器状态源、反向规则定义 |
| archive/history | 历史追溯 | 当前执行输入，除非 active registry 或恢复流程明确引用 |

## Runtime Integration Layer

hooks 只拦截或提示运行风险，adapters 只转换 runtime payload，runtime catalog 只暴露可用入口，install exposure 只控制暴露范围。它们都不能覆盖 canonical contract。

## Governance And Evidence Layer

evals、examples、lifecycle-review、migration audit 和 regression pilot 只提供行为证据与维护证据，不能反向定义 runtime truth。

## Source Of Truth

每类运行事实只有一个唯一权威裁决源。projection、history、template、示例和自然语言总结可以引用、派生或解释，但不能反向定义规则。

## Progressive Disclosure

SKILL.md 提供主执行骨架和 reference 路由。reference 按需加载；触发条件必须可观察，读取后必须留下消费证据。无条件生效的 hard gate、字段合同、状态流转和完成判定必须进入 SKILL.md、canonical contract、schema、validator 或 gate。

## Fixed Failure Shape

失败输出至少包含 status、failure_code、reason、owner、safe_to_continue、next_action、evidence_refs、user_message。status 使用 BLOCKED、FAIL 或 PARTIAL；safe_to_continue 为 false 时不得进入下游执行。

## Fresh Proof Boundary

fresh proof 必须来自当前命令输出、当前测试或构建结果、当前执行日志，或由 gate/reviewer/closeout 重跑并捕获当前输出。命令字符串本身只是 replay instruction，不能单独证明当前执行已经发生。
