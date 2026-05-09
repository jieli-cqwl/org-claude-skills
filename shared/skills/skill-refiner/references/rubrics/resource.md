# Resource 诊断口径

**目标**：`SKILL.md` 是主操作手册；reference 承载按需加载的专业判断材料；script、schema、template、eval、test 各自承载被消费的工程材料。

## 裁决标准

1. 主体短而可执行：`SKILL.md` 只保留高频 SOP、路由、停止和完成校验。
2. HARD-GATE Why 有条件保留：只在不可绕过的不变量或失败后果时保留一行。
3. reference 职责清楚：只承载方法论、判定口径、专业框架、案例和检查矩阵；不承载脚本逻辑、schema 合同、模板字段、runtime payload 或历史说明。
4. reference 有目标和收口：聚焦一个专业判断问题；收口为裁决标准、证据要求、问题信号或评审要点。
5. script 承载确定性执行：可枚举、可复验、易错重复操作进入脚本或测试。
6. schema/template 有消费者：机器或人工产物形状有读取方。
7. example 分层：人工评审样例放 `references/examples/`；机器消费样例放 fixture 或 eval。
8. 不重复：同一内容只保留一个真源。
9. 引用可达：所有路由文件存在、路径正确、不默认加载过多上下文。

## 问题信号

- reference 头部写历史、引用者、同步流水账。
- `SKILL.md` 塞入长方法论、schema 字段明细或脚本逻辑。
- HARD-GATE 的 Why 只是复述规则或长篇解释。
- reference 没有聚焦一个专业判断问题，或缺少收口信息。
- reference 混入脚本逻辑、schema 字段、runtime payload 或历史说明。
- 目标 `SKILL.md` 出现分析维度章节或把写作者约束写成执行步骤。
- 模板、脚本或字段没有触发点。
- 旧文件为兼容测试继续留在 active 路径。
