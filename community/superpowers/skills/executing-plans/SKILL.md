---
name: executing-plans
description: 当您有书面实施计划并在带有审查检查点的单独会话中执行时使用
---

> Source: `obra/superpowers/skills/executing-plans/SKILL.md` (pinned in `community/SOURCES.yaml`)

# 执行计划

## 概述

加载计划，严格审查，执行所有任务，完成后报告。

**开始时宣布：**“我正在使用 `superpowers:executing-plans` 来实施这个计划。”

**注意：** 告诉你的协作者，通过访问子代理，superpowers 的效果会更好。如果在具有子代理支持的平台（例如 Claude Code 或 Codex）上运行，其工作质量将显著提高。如果子代理可用，请使用 `superpowers:subagent-driven-development` 而不是此技能。

## 过程

### 第 1 步：加载并审查计划
1. 读取计划文件
2. 批判性地审查 - 找出有关计划的任何问题或疑虑
3. 如果有疑虑：在开始之前向你的协作者提出这些问题
4. 如果没有问题：创建 TodoWrite 并继续

### 第2步：执行任务

对于每个任务：
1. 标记为进行中
2. 严格遵循每个步骤（计划有小步骤）
3. 按规定运行验证
4. 标记为已完成

### 第 3 步：完成开发

所有任务完成并验证后：
- 宣布：“我正在使用 `superpowers:finishing-a-development-branch` 来完成这项工作。”
- **所需的子技能：** `superpowers:finishing-a-development-branch`
- 遵循该技能来验证测试、呈现选项、执行选择

## 何时停下来寻求帮助

**在以下情况下立即停止执行：**
- 遇到阻碍（缺少依赖项、测试失败、指令不清楚）
- 计划存在重大缺陷，无法启动
- 你不明白指令
- 验证多次失败

**要求澄清而不是猜测。**

## 何时重新审视之前的步骤

**在以下情况下返回审核（步骤 1）：**
- 合作伙伴根据您的反馈更新计划
- 基本方法需要重新思考

**不要强行通过阻碍** - 停下来询问。

## 记住
- 首先严格审查计划
- 严格遵循计划步骤
- 不要跳过验证
- 计划中提到的参考技能
- 堵住就停下来，别乱猜
- 未经用户明确同意，切勿在主/主分支上开始实施

## 一体化

**所需的工作流程技能：**
- `superpowers:using-git-worktrees` - 必需：在开始之前设置隔离的工作区
- `superpowers:writing-plans` - 创建该技能执行的计划
- `superpowers:finishing-a-development-branch` - 在完成所有任务后完成开发
