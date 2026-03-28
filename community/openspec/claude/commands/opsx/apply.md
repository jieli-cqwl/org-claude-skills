---
name: "OPSX: Apply"
description: 实施 OpenSpec 变更中的任务（实验）
category: Workflow
tags: [workflow, artifacts, experimental]
---

实施 OpenSpec 变更中的任务。

**输入**：可以选择指定更改名称（例如`/opsx:apply add-auth`）。如果省略，请检查是否可以从对话上下文中推断出来。如果含糊或不明确，您必须提示可用的更改。

**步骤**

1. **选择更改**

   如果提供了名称，请使用它。否则：
   - 从对话上下文中推断用户是否提到了更改
   - 如果仅存在一项活动更改，则自动选择
   - 如果不明确，请运行 `openspec list --json` 获取可用更改并使用 **AskUserQuestion 工具** 让用户选择

   始终宣布：“使用更改：<name>”以及如何覆盖（例如`/opsx:apply <other>`）。

2. **检查状态以了解架构**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析 JSON 即可理解：
   - `schemaName`：正在使用的工作流程（例如“规范驱动”）
   - 哪个工件包含任务（通常是规范驱动的“任务”，检查其他任务的状态）

3. **获取应用说明**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   这将返回：
   - 上下文文件路径（因架构而异）
   - 进度（总计、完成、剩余）
   - 带有状态的任务列表
   - 基于当前状态的动态指令

   **处理状态：**
   - 如果`state: "blocked"`（缺少工件）：显示消息，建议使用`/opsx:continue`
   - 如果`state: "all_done"`：恭喜，建议存档
   - 否则：继续执行

4. **读取上下文文件**

   从应用指令输出中读取 `contextFiles` 中列出的文件。
   这些文件取决于所使用的架构：
   - **规范驱动**：提案、规范、设计、任务
   - 其他模式：遵循 CLI 输出中的 contextFiles

5. **显示当前进度**

   展示：
   - 正在使用的架构
   - 进度：“N/M 个任务完成”
   - 剩余任务概述
   - 来自 CLI 的动态指令

6. **准备强一致同步上下文（tasks-plan）**

   在执行前先定位 `plan.md` 与内置一致性校验器：

   ```bash
   PLAN_PATH="$(ls -1 openspec/plans/*-<name>.md 2>/dev/null | sort | tail -n1)"
   CHECKER_PATH=""
   for p in \
     "$HOME/.codex/skills/openspec-verify-change/scripts/check_task_plan_consistency.py" \
     "$HOME"/.*laude/skills/openspec-verify-change/scripts/check_task_plan_consistency.py
   do
     if [ -f "$p" ]; then
       CHECKER_PATH="$p"
       break
     fi
   done
   [ -n "$PLAN_PATH" ] || { echo "[FAIL] 未找到与 change 对应的 plan.md"; exit 1; }
   [ -n "$CHECKER_PATH" ] || { echo "[FAIL] verify skill 内置一致性校验器缺失"; exit 1; }
   ```

7. **执行任务（循环直到完成或阻塞）**

   对于每个待处理的任务：
   - 显示正在处理哪个任务
   - 进行所需的代码更改
   - 保持变更最小化并集中精力
   - 在任务文件中将当前 task 标记为完成：`- [ ] <task-id>` → `- [x] <task-id>`
   - 在 `plan.md` 中将所有包含 `[<task-id>]` 的 checklist 同步标记为完成：`- [ ]` → `- [x]`
   - 每完成一个 task 后执行：
     ```bash
     python3 "$CHECKER_PATH" "openspec/changes/<name>/tasks.md" "$PLAN_PATH"
     ```
   - 校验失败立即暂停并标记 `CRITICAL`
   - 继续下一个任务

   **如果出现以下情况则暂停：**
   - 任务不清楚→要求澄清
   - 实施揭示了一个设计问题→建议更新工件
   - 遇到错误或阻塞→报告并等待指导
   - 用户中断

8. **完成或暂停时，显示状态**

   展示：
   - 本次会议完成的任务
   - 总体进度：“N/M 个任务完成”
   - 如果全部完成：建议存档
   - 如果暂停：解释原因并等待指导

**实施期间的输出**

```
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
[...implementation happening...]
✓ Task complete

Working on task 4/7: <task description>
[...implementation happening...]
✓ Task complete
```

**完成时输出**

```
## Implementation Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 7/7 tasks complete ✓

### Completed This Session
- [x] Task 1
- [x] Task 2
...

All tasks complete! You can archive this change with `/opsx:archive`.
```

**暂停时输出（遇到问题）**

```
## Implementation Paused

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 4/7 tasks complete

### Issue Encountered
<description of the issue>

**Options:**
1. <option 1>
2. <option 2>
3. Other approach

What would you like to do?
```

**护栏**
- 继续执行任务，直到完成或被阻止
- 在开始之前始终读取上下文文件（来自应用指令输出）
- 如果任务不明确，请在实施之前暂停并询问
- 如果实施过程中发现问题，请暂停并建议工件更新
- 尽量减少代码更改并限制每个任务的范围
- 完成每项任务后立即更新任务复选框
- 完成每项任务后必须同步更新 `plan.md` 对应 `[task-id]` 步骤并通过一致性校验
- 因错误、阻碍或不明确的需求而暂停 - 不要猜测
- 使用 CLI 输出中的 contextFiles，不要假设特定的文件名

**流畅的工作流程集成**

该技能支持“针对变更采取行动”模型：

- **可以随时调用**：在所有工件完成之前（如果任务存在）、部分实现之后、与其他操作交错
- **允许工件更新**：如果实现揭示了设计问题，建议更新工件 - 非锁相，工作流畅
