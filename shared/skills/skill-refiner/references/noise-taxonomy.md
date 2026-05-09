# Skill 噪音分类

用于识别会干扰 Agent 执行的内容，并扫描同类残留。

## 核心定义

噪音不是“文字多”，而是没有消费关系、破坏职责边界、让 Agent 误判执行顺序，或让确定性判断停留在 LLM 文本里的内容。

## 分类

| 类型 | 典型表现 | 处理 |
| --- | --- | --- |
| 无消费者内容 | 字段、段落、模板、报告无人读取 | 删除 |
| 运行时泄漏 | SKILL.md 解释 hook、gate、installer 内部实现，且不影响当前办事流程 | 迁移到 runtime 文档或删除 |
| 说明书口吻 | 讲背景、历史、引用者、Sync 流水账 | 删除或改成 SOP 动作 |
| LLM 基础能力教学 | 教模型使用通用文件搜索、逐文件读取等 coding 基础操作 | 删除 |
| 负面引导堆叠 | 大量“不负责/不要/不能”，缺少正向动作 | 改成职责、输入、流程和停手条件 |
| 分析维度泄漏 | “输入准入”“下游消费者成功标准”等共创分析维度直接变成目标 Skill 章节 | 编译为流程动作、输出合同、eval/test 或删除 |
| 工具边界说明 | 单独解释 Bash、hook、projection、runtime 如何使用，但具体步骤已经能触发 | 放到最近的执行点，或交给 script/hook/manifest/test |
| 写作约束泄漏 | “用你称呼”“避免说明文”等写作者约束进入执行 SOP | 改成正向产物要求或放入 refiner 自身规则 |
| 重复机器合同 | SKILL.md、schema、template 同时定义字段 | 保留机器真源，SOP 只引用消费点 |
| 长方法论默认加载 | 主体塞入长篇原则、案例、判断表 | 迁移到对应 reference |
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

## 编译降噪审查

执行落地后、验收交付前，对目标 `SKILL.md` 逐句检查：每句话必须能归入执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why。

处理规则：

- 分析维度只决定流程动作、资源分层、schema/template、script/hook、eval/test 或删除项。
- 消费者价值不写成长篇解释；它进入产物字段、handoff contract、schema/template、eval/test 或流程动作。
- 确定性检查进入 preflight、completion gate、schema、hook、validator 或测试。
- 工具边界写在使用该工具的流程步骤里，明确触发点、参数和失败结果。
- 写作约束改成正向产物要求，或放入 refiner 自身规则。
- eval/test 保护行为、消费者价值和失败模式；只保护旧句子的断言必须删除或改写。

## 保留条件

内容保留条件至少满足一项：

- 被当前 SOP 的某一步调用。
- 被脚本、schema、hook、test、eval 或下游 Skill 消费。
- 是用户必须裁决的专业实践输入。
- 是 owner 裁决、环节证据或验证当前目标所需的当前行为合同。
- 是验证当前目标所需的反例或 fixture，并位于 fixture/archive 位置。
