# Skill 噪音分类

噪音不是"文字多"，而是没有消费关系、破坏职责边界、让 Agent 误判执行顺序，或让确定性判断停留在 LLM 文本里的内容。

## 分类

| 类型 | 典型表现 | 处理 |
| --- | --- | --- |
| 无消费者内容 | 字段、段落、模板、报告无人读取 | 删除 |
| 运行时泄漏 | 解释 hook、gate、installer 内部实现，且不影响当前办事流程 | 迁移到 runtime 文档或删除 |
| Runtime 二次挂载 | 正文重申 `{{RUNTIME_HOME}}/rules/` 或 `reference/` 已强制的内容 | 删除正文挂载；必要时改为交叉引用段锚点 |
| 说明书口吻 | 背景、历史、引用者、Sync 流水账 | 删除或改成 SOP 动作 |
| 归属声明 | reference 顶部写"供谁使用" | 删除；归属由 SKILL 流程表的引用路由承载 |
| LLM 基础能力教学 | 教通用文件搜索、逐文件读取等 coding 基础操作 | 删除 |
| 指令泄漏 | "读取 references/X，只提取 Y" 这类操作指令侵入专业 SOP | 改为引用路由 |
| 负面引导堆叠 | 大量"不负责/不要/不能"，缺少正向动作 | 改成职责、输入、流程和停手条件；合法反向除外 |
| 同义反复 | 多个说法表达同一约束 | 合并为一条可验证行为 |
| 弱动词混淆 | MUST/SHOULD/MAY 强度混用 | rules = MUST，reference = SHOULD，不得降级 |
| 术语漂移/混用 | SKILL、reference、script、test 术语不一致 | 以 schema / contract 术语为真源对齐 |
| 流程图与脚本兜底重叠 | 流程图列出已由脚本兜底的异常分支 | 删除图中重复分支 |
| 分析维度泄漏 | "输入准入"等诊断维度变成目标 Skill 章节 | 编译为流程动作、输出合同、eval/test 或删除 |
| 工具边界说明 | 单独解释 Bash、hook、projection、runtime | 放到最近执行点，或交给 script/hook/manifest/test |
| 写作约束泄漏 | "用你称呼""避免说明文"进入执行 SOP | 改成正向产物要求或放入 refiner 自身规则 |
| 重复机器合同 | SKILL.md、schema、template 同时定义字段 | 保留机器真源，SOP 只引用消费点 |
| 载体内部字段重复 | 同一脚本 / SKILL 连续重复字段校验或说明 | 去重；高频回潮加自审或测试 |
| SOP 段落重复 | 两个段落讲同一件事 | 保留职责归属最自然的一段 |
| 长方法论默认加载 | 主体塞入长篇原则、案例、判断表 | 迁移到 reference |
| 旧目标固化 | 测试、eval、docs 仍要求旧段落或旧字段 | 更新测试或清理引用 |
| 历史迁移残留 | legacy alias、archive、备用目录仍在 active 链路 | 从 active runtime 清除 |
| 模糊成功标准 | "优化质量""补齐能力"无证据口径 | 改成可验证目标 |

## 合法反向保留场景

以下反向表达应保留原强度，不要为了"正向化"削弱约束：

- 安全红线：直接对应 `{{RUNTIME_HOME}}/rules/` 或 canonical schema 的不可绕过约束。
- 反绕过动作：防止 LLM 用替代手段绕过约束的具体禁令。
- 边界澄清：明确当前 skill 不做什么的非目标清单。

反模式：把禁令改成"仅作补充""只作参考"等软化措辞。

## 扫描路径

- 目标 Skill `SKILL.md`。
- `references/` 的文件头、引用者说明、历史说明和重复流程。
- `scripts/`、`contracts/`、`templates/` 中无人消费的字段。
- `evals/`、`test-prompts.json` 和 tests 中是否仍验证旧噪音。
- installer、catalog、hook、README 和有效性记录中的旧 Skill 引用。

跨文件契约一致性扫描：SKILL HARD-GATE / 输出段 ↔ schema；SKILL 术语 ↔ completion_check；fixture ↔ 最新约束枚举；references ↔ SKILL；runtime 自动加载内容是否被二次挂载。

## 编译降噪审查

执行落地后、验收交付前，对目标 `SKILL.md` 逐句检查：每句话必须能归入执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why。

保留条件：被当前 SOP 调用；被脚本、schema、hook、test、eval 或下游 Skill 消费；是用户必须裁决的专业实践输入；是 owner 裁决、环节证据或验证当前目标所需的当前行为合同；是验证当前目标所需的反例或 fixture 且位于 fixture/archive。
