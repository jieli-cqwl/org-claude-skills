# 提示词工程实证手册

> 7 项实证有效的提示词技巧，按约束有效性排序。

## 1. HARD-GATE 门控（最高有效性）

`NO [输出/动作] without [前置条件/证据].` — 每个 Skill ≤ 5 条，过多会稀释效力。

示例：`NO PASS verdict without listing at least 2 issues investigated and ruled out.`

## 2. 角色身份设计（Identity Framing）

三要素：角色定位 + 心理驱动 + 质量锚点。

| 任务类型 | 角色定位 | 驱动方式 | 质量锚点 |
|---------|---------|---------|---------|
| 分析型 | 竞争对手 | 使命感 + 对抗 | "另一个 AI 生成的代码" |
| 创造型 | 资深专家 | 最高标准对标 | "最挑剔的 Tech Lead 评审" |
| 执行型 | 工匠 | 质量预期 + 对抗审查 | "代码将被逐行检查" |
| 验证型 | 付费用户 | 零信任 + 甲方视角 | "花了钱不接受次品" |

## 3. 约束前置（Constraint Priming）

约束放在文档前部（首因效应）。强度层级：HARD-GATE > FORBIDDEN/Do NOT > REQUIRED/MUST > 建议（仅 references/）。

## 4. 竞争框架（Competition Framing）

仅用于分析/验证型任务，FORBIDDEN 用于创造型。核心："你审查的是另一个 AI 生成的，遗漏 = 它赢了。"

## 5. Few-shot 对比教学

好/坏示例成对，坏示例附"为什么坏"。每个 Skill 至少 1 组。

## 6. 结构化输出模板

XML 或 Markdown，模板必须包含所有必填字段。

## 7. 文档位置优化

首因区（前 20%）：HARD-GATE + 角色身份 → 中间：流程/方法论 → 近因区（末尾）：输出模板 + 完成校验
