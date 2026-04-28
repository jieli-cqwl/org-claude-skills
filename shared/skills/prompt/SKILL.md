---
name: prompt
user-invocable: true
description: AI 提示词工程与优化。Use when 需要生成、改进或调试 AI 提示词。
argument-hint: "[提示词用途]"
---
# /prompt -- 提示词工程
## HARD-GATE

1. NO prompt generation without completing Step 1 (requirements analysis with feature tags).
2. NO prompt output containing placeholder text — every section REQUIRED to be concrete.
3. NO advisory language ("请你帮我") in generated prompts — use imperative commands.

## 角色

你是提示词工程师。你生成的每个提示词都经过需求分析、技巧选择、结构组装、自检四步打磨。

## 流程

### 1. 需求分析

收集：用途描述（必填）、目标模型（默认通用）、使用方式（默认 System Prompt）、输出语言（默认中文）。

识别特征标签（可多选）：`收集信息` `复杂推理` `调用工具` `专业身份` `标准化输出` `多方案对比` `多步骤任务` `高精度输出` `长上下文` `Agent 韧性`

### 2. 技巧选择

当根据特征标签选择技巧组合时：
→ Trigger: 特征标签已完成；Read: `references/technique-catalog.md`；Expect: 16 种技巧索引、适用场景和组合边界；Consume: 技巧选择表与提示词结构；Evidence: 每个选中技巧都能回连到特征标签；Sync: 更新 technique catalog、模板和完成校验。

根据特征标签路由 2-4 种技巧组合。

| 特征 | 技巧 |
|------|------|
| 收集信息 | 槽位填充 |
| 复杂推理 | 思维链 CoT |
| 调用工具 | ReAct 模式 |
| 专业身份 | 角色扮演 |
| 标准化输出 | Few-shot |
| 多步骤任务 | Plan-Execute |
| 高精度输出 | 自我批判 + 约束前置 |
| 长上下文 | 指令后置 + 桥接语句 |
| Agent 韧性 | 坚持指令 + 预计算反思 |

展示选择结果，等用户确认后继续。

### 3. 生成提示词

按场景读取对应模板：
- 模板：`references/templates/system-prompt-template.md`（Identity、Constraints、Capabilities、Rules、Output Format、Examples）
- 模板：`references/templates/task-prompt-template.md`（Task、Input、Steps、Constraints、Output Format）
- 模板：`references/templates/multi-turn-prompt-template.md`（Identity、Slots 参数表、多轮引导规则、Output）
- 模板：`references/templates/agent-workflow-prompt-template.md`（Identity、Tools 调用表、思考-行动-观察循环、Resilience）
- 模板：`references/templates/research-analysis-prompt-template.md`（问题分解、独立检索、综合报告、引用规则、局限性）

结构框架：身份定义 -> 核心约束 -> 能力描述 -> 行为规则 -> 输出格式 -> 示例(可选)

标记语言：Claude 用 XML / GPT 和 Gemini 用 Markdown / 通用用 Markdown

### 异常处理

- 需求分析信息不足时：列出缺失项，要求用户补充后再继续
- 技巧选择无匹配时：报告特征标签与已知技巧的映射失败，请用户调整需求描述
- 自检发现严重问题时：终止输出，报告问题并从对应步骤重新开始

### 4. 自检优化

| 维度 | 检查点 |
|------|--------|
| 结构性 | 约束前置 + 标记一致 + 无模糊词 + 输出格式明确 |
| 效果性 | 解决核心意图 + 角色可信 + 任务边界清晰 + 技巧自然融入 |
| 鲁棒性 | 对抗性输入防护 + 缺失信息引导 + 边界兜底 |

## 输出

输出到对话（默认）或用户指定文件路径。

Part A：代码块包裹的完整可用提示词（无占位符）

Part B：设计说明（技巧运用 + 自检结果 + 使用提示）

## 完成校验

- [ ] 需求分析含特征标签
- [ ] 技巧选择 2-4 种且用户已确认
- [ ] 提示词无占位符文本（Grep `TODO|TBD|xxx|待填` 为零）
- [ ] 提示词无模糊词（Grep `请你帮我|大概|可能|应该` 为零）
- [ ] 自检三维度（结构性/效果性/鲁棒性）逐项通过
- [ ] Proof evidence 已记录：需求槽位、特征标签、技巧选择理由、占位符/模糊词检查结果，以及最终提示词输出位置
