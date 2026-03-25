# Description 编写规范

## Skill Description 标准格式

```
{一句话能力陈述}。Use when {场景化触发条件}。
```

## Agent Description 标准格式

```
{专家身份}。Proactively {能力陈述}。Use when {触发条件}。
```

## 规范要点

- 首句必须是能力陈述（做什么），不是触发条件
- 必须使用第三人称（官方）：description 注入 system prompt，视角不一致会导致 Skill 发现失败
- 使用 `Use when` 自然语言句式
- 触发条件用场景描述，不用引号包裹的精确话术
- 长度指南：1-2 句，建议 <= 120 字符
- Agent 额外：包含 `Proactively` 鼓励主动委托
- 语言：中文为主（用户输入为中文），技术术语保留英文

## 第三人称要求（官方）

description 被注入 system prompt 后由 Claude 读取，不一致的视角会干扰 Skill 选择。

| 正确（第三人称） | 错误 |
|-----------------|------|
| `全项目代码健康度巡检与技术债分析。` | `我可以帮你扫描代码质量。` |
| `Extracts text and tables from PDF files.` | `You can use this to extract PDF text.` |

## 禁止项

- `TRIGGER when:` / `DO NOT TRIGGER when:` 结构化标签
- `REQUIRES:` 前置条件声明（已被 HARD-GATE 覆盖）
- `Input:` 路径声明
- `（-> /xxx）` 路由指向
- 第一人称（"我"/"I"）或第二人称（"你"/"You"）叙述

## 示例

| 类型 | 错误 | 正确 |
|------|------|------|
| Skill | `TRIGGER when: "报错了"... DO NOT TRIGGER when: ...` | `系统性根因分析与问题诊断。Use when 遇到报错、测试失败、运行异常等需要定位原因的技术问题。` |
| Agent | `架构师 agent，基于 PRD 输出...TRIGGER when: ...Input: ...` | `系统架构设计专家。Proactively 分析需求并输出高层设计和详细设计文档。Use when PRD 完成后需要架构设计。` |
