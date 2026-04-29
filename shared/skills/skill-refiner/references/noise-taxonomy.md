# Skill 噪音分类

按需读取本文件，用于识别会干扰 Agent 执行的内容，并扫描同类残留。

## 核心定义

噪音不是“文字多”，而是没有消费关系、破坏职责边界、让 Agent 误判执行顺序，或让确定性判断停留在 LLM 文本里的内容。

## 分类

| 类型 | 典型表现 | 处理 |
| --- | --- | --- |
| 无消费者内容 | 字段、段落、模板、报告无人读取 | 删除 |
| 运行时泄漏 | SKILL.md 解释 hook、gate、installer 内部实现 | 迁移到 runtime 文档或删除 |
| 说明书口吻 | 讲背景、历史、引用者、Sync 流水账 | 删除或改成 SOP 动作 |
| LLM 基础能力教学 | 教模型使用通用文件搜索、逐文件读取等 coding 基础操作 | 删除 |
| 负面引导堆叠 | 大量“不负责/不要/不能”，缺少正向动作 | 改成职责、输入、流程和停手条件 |
| 重复机器合同 | SKILL.md、schema、template 同时定义字段 | 保留机器真源，SOP 只引用消费点 |
| 长方法论默认加载 | 主体塞入长篇原则、案例、判断表 | 迁移到按需 reference |
| 旧目标固化 | 测试、eval、docs 仍要求旧段落或旧字段 | 更新测试或清理引用 |
| 历史迁移残留 | legacy alias、archive、备用目录仍在 active 链路 | 从 active runtime 清除 |
| 模糊成功标准 | “优化质量”“补齐能力”无证据口径 | 改成可验证目标 |

## 扫描路径

优先扫描：

- 目标 Skill `SKILL.md`。
- `references/` 中的文件头、引用者说明、历史说明和重复流程。
- `scripts/`、`contracts/`、`templates/` 中无人消费的字段。
- `evals/`、`test-prompts.json` 和 tests 中是否仍验证旧噪音。
- installer、catalog、hook、README 和有效性记录中是否有旧 Skill 引用。

## 保留条件

内容可以保留，前提是至少满足一项：

- 被当前 SOP 的某一步按需读取。
- 被脚本、schema、hook、test、eval 或下游 Skill 消费。
- 是用户必须裁决的专业实践输入。
- 是验证当前目标所需的反例或 fixture，并位于 fixture/archive 位置。
