---
name: writing-plans
description: 当您在接触代码之前对多步骤任务有规范或要求时使用
---

# 写作计划

## 概述

假设工程师对我们的代码库的背景为零并且品味有问题，则编写全面的实施计划。记录他们需要知道的一切：每个任务要接触哪些文件、代码、测试、他们可能需要检查的文档、如何测试它。将整个计划作为小任务交给他们。干燥。亚格尼。时分驱动。频繁提交。

假设他们是一位熟练的开发人员，但对我们的工具集或问题领域几乎一无所知。假设他们不太了解良好的测试设计。

**开始时宣布：**“我正在使用写作计划技能来创建实施计划。”

**上下文：** 这应该在专用工作树中运行（通过头脑风暴技能创建）。

**将计划保存到：** `openspec/plans/YYYY-MM-DD-<change-name>.md`
- （计划位置的用户首选项会覆盖此默认值）

## 强一致契约（必须）

为了让 `opsx:verify` 做强一致阻断，计划文档必须满足：

- 每条 checklist 必须显式引用 `tasks.md` 中的 task id（如 `[1.1]` / `[T1]`）。
- 禁止出现“无 task id 的 checklist”。
- `plan.md` 中引用的 task id 必须全部来自当前 `tasks.md`，不能凭空新增。
- 计划生成后要能被一致性校验器通过，否则视为计划无效。

## 范围检查

如果规范涵盖多个独立的子系统，则应在头脑风暴期间将其分解为子项目规范。如果不是，建议将其分成单独的计划——每个子系统一个。每个计划都应该自行生成可工作、可测试的软件。

## 文件结构

在定义任务之前，先确定将创建或修改哪些文件以及每个文件负责什么。这就是分解决策被锁定的地方。

- 设计单元具有清晰的边界和明确的接口。每个文件都应该有一个明确的职责。
- 您可以最好地推理可以立即在上下文中保存的代码，并且当聚焦于文件时，您的编辑会更加可靠。优先选择较小的、集中的文件，而不是功能过多的大文件。
- 一起更改的文件应该一起存在。按职责划分，而不是按技术层划分。
- 在现有代码库中，遵循既定模式。如果代码库使用大文件，请不要单方面重组 - 但如果您正在修改的文件变得难以处理，那么在计划中进行拆分是合理的。

该结构告知任务分解。每项任务都应该产生独立且有意义的独立变化。

## 一口大小的任务粒度

**每一步都是一个动作（2-5 分钟）：**
- “编写失败的测试”-步骤
- “运行它以确保它失败”-步骤
- “实现最少的代码以使测试通过” - 步骤
- “运行测试并确保它们通过”- 步骤
- “提交”-步骤

## 计划文档标题

**每个计划必须以此标题开头：**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking and MUST include task-id tags like `[1.1]`.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## 任务结构

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] [1.1] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    结果 = 函数（输入）
    断言结果==预期
```

- [ ] [1.1] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] [1.1] **Step 3: Write minimal implementation**

```python
def 函数（输入）：
    预期回报
```

- [ ] [1.1] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] [1.1] **Step 5: Commit**

```bash
git add 测试/路径/test.py src/path/file.py
git commit -m“壮举：添加特定功能”
```
````

## 无占位符

每个步骤都必须包含工程师需要的实际内容。这些是**计划失败**——永远不要写它们：
- “待定”、“TODO”、“稍后实施”、“填写详细信息”
- “添加适当的错误处理”/“添加验证”/“处理边缘情况”
- “为上述内容编写测试”（没有实际的测试代码）
- “与任务 N 类似”（重复代码 - 工程师可能会乱序读取任务）
- 描述要做什么而不显示如何做的步骤（代码步骤所需的代码块）
- 对任何任务中未定义的类型、函数或方法的引用
- 缺少 `[task-id]` 的 checklist 行

## 记住
- 始终精确的文件路径
- 每个步骤中的完整代码 - 如果某个步骤更改了代码，请显示代码
- 具有预期输出的精确命令
- DRY、YAGNI、TDD、频繁提交

## 自我检讨

写完完整的计划后，以新的眼光审视规范并对照它检查计划。这是您自己运行的清单，而不是子代理调度。

**1.规范覆盖范围：** 浏览规范中的每个部分/要求。你能指出一个实现它的任务吗？列出所有差距。

**2.占位符扫描：** 在您的计划中搜索危险信号 - 上面“无占位符”部分中的任何模式。修复它们。

**3.类型一致性：** 您在后续任务中使用的类型、方法签名和属性名称是否与您在早期任务中定义的相匹配？任务 3 中名为 `clearLayers()` 但任务 7 中名为 `clearFullLayers()` 的函数是一个错误。

**4.tasks-plan 强一致：** 逐行检查 `plan.md` checklist 是否都带 `[task-id]`，并且 task id 都能在 `tasks.md` 中找到。

如果发现问题，请内联修复它们。无需重新审查——只需修复并继续。如果您发现没有任务的规范要求，请添加任务。

## 执行交接

保存计划后，提供执行选择：

**“计划完成并保存至`openspec/plans/<filename>.md`。两种执行选项：**

**1.子代理驱动（推荐）** - 我为每个任务调度一个新的子代理，在任务之间进行审查，快速迭代

**2.内联执行** - 使用执行计划、带检查点的批量执行来执行此会话中的任务

**哪种方法？”**

**如果选择子代理驱动：**
- **所需的子技能：** 使用超能力：子代理驱动开发
- 每个任务新的子代理+两阶段审查

**如果选择内联执行：**
- **所需的子技能：** 使用超能力：执行计划
- 批量执行并带有检查点以供审查
