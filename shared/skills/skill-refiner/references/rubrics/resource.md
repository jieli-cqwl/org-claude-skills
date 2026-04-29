# Resource 环节标准

## Why

资源分层决定上下文成本。内容放错位置会让 Agent 默认读取无关材料，或把确定性逻辑留在自然语言里。

## 目标

`SKILL.md` 是主操作手册；reference、script、schema、template、eval、test 各自承载被消费的内容。

## 裁决标准

1. 主体短而可执行：`SKILL.md` 只保留高频 SOP、路由、停止和完成校验。
2. reference 按需：方法论、案例、判断表只在对应步骤读取。
3. script 承载确定性执行：可枚举、可复验、易错重复操作进入脚本或测试。
4. schema/template 有消费者：机器或人工产物形状有读取方。
5. example 分层：人工评审样例放 `references/examples/`；机器消费样例放 fixture 或 eval。
6. 不重复：同一内容只保留一个真源。
7. 引用可达：所有路由文件存在、路径正确、不会默认加载过多上下文。

## 证据

- Skill 目录结构。
- `SKILL.md` 路由语句。
- references、scripts、templates、schemas、evals 和 tests。
- 消费者引用和验证命令。

## 问题信号

- reference 头部写历史、引用者、同步流水账。
- `SKILL.md` 塞入长方法论、schema 字段全集或脚本逻辑。
- 模板、脚本或字段没有触发点。
- 旧文件为兼容测试继续留在 active 路径。

## 验收

每个资源都能说明谁在何时读取、读取后产出什么、如何验证仍有效；无法说明的资源删除或迁移到 archive/fixture。
