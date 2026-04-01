---
name: requesting-code-review
description: 在完成任务、实现主要功能时或在合并之前使用以验证工作是否满足要求
---

> Source: `obra/superpowers/skills/requesting-code-review/SKILL.md` (pinned in `community/SOURCES.yaml`)

# 请求代码审查

派遣 `superpowers:code-reviewer` 子代理在问题级联发生之前发现问题。审阅者可以获得精确设计的评估上下文，而不是您的会话历史记录。这可以让审阅者专注于工作产品，而不是您的思维过程，并保留您自己的上下文以供继续工作。

**核心原则：**早复习、常复习。

## 何时请求审查

**强制的：**
- 子代理驱动开发中的每个任务之后
- 完成主要功能后
- 合并到主程序之前

**可选但有价值：**
- 当卡住时（新视角）
- 重构前（基线检查）
- 修复复杂的错误后

## 如何请求

**1.获取 git SHA：**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2.调度代码审阅者子代理：**

使用超能力任务工具：code-reviewer类型，填写模板`code-reviewer.md`

**占位符：**
- `{WHAT_WAS_IMPLEMENTED}` - 你刚刚构建的内容
- `{PLAN_OR_REQUIREMENTS}` - 它应该做什么
- `{BASE_SHA}` - 开始提交
- `{HEAD_SHA}` - 结束提交
- `{DESCRIPTION}` - 简要总结

**3.根据反馈采取行动：**
- 立即修复关键问题
- 在继续之前修复重要问题
- 注意稍后的小问题
- 如果审稿人错了就退回（有推理）

## 例子

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch superpowers:code-reviewer subagent]
  WHAT_WAS_IMPLEMENTED: Verification and repair functions for conversation index
  PLAN_OR_REQUIREMENTS: Task 2 from openspec/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## 与工作流程集成

**子代理驱动的开发：**
- 每项任务后回顾
- 在问题复杂化之前发现问题
- 在进行下一个任务之前修复

**执行计划：**
- 每批后回顾（3个任务）
- 获取反馈、申请、继续

**临时开发：**
- 合并前审查
- 卡住时回顾

## 危险信号

**绝不：**
- 跳过评论，因为“很简单”
- 忽略关键问题
- 继续处理未解决的重要问题
- 用有效的技术反馈进行争论

**如果审稿人错误：**
- 用技术推理进行反击
- 显示证明其有效的代码/测试
- 要求澄清

请参阅模板：requesting-code-review/code-reviewer.md
