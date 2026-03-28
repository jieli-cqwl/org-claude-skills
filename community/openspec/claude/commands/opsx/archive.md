---
name: "OPSX: Archive"
description: 归档实验工作流程中已完成的更改
category: Workflow
tags: [workflow, archive, experimental]
---

归档实验工作流程中已完成的更改。

**输入**：可以选择在`/opsx:archive`后指定更改名称（例如`/opsx:archive add-auth`）。如果省略，请检查是否可以从对话上下文中推断出来。如果含糊或不明确，您必须提示可用的更改。

**步骤**

1. **如果未提供更改名称，则提示选择**

   运行 `openspec list --json` 以获取可用的更改。使用 **AskUserQuestion 工具** 让用户选择。

   仅显示活动更改（尚未存档）。
   包括用于每个更改的架构（如果有）。

   **重要**：不要猜测或自动选择更改。始终让用户选择。

2. **检查工件完成状态**

   运行 `openspec status --change "<name>" --json` 以检查工件完成情况。

   解析 JSON 即可理解：
   - `schemaName`：正在使用的工作流程
   - `artifacts`：工件列表及其状态（`done` 或其他）

   **如果有任何工件不是`done`：**
   - 显示警告列出不完整的工件
   - 提示用户确认以继续
   - 如果用户确认则继续

3. **检查任务完成状态**

   读取任务文件（通常为`tasks.md`）以检查是否有未完成的任务。

   计算标有`- [ ]`（不完整）和`- [x]`（完成）的任务。

   **如果发现未完成的任务：**
   - 显示警告，显示未完成任务的计数
   - 提示用户确认以继续
   - 如果用户确认则继续

   **如果不存在任务文件：** 继续，不会出现与任务相关的警告。

4. **评估增量规格同步状态**

   检查增量规格`openspec/changes/<name>/specs/`。如果不存在，则继续而不提示同步。

   **如果存在增量规格：**
   - 将每个增量规格与其相应的主规格进行比较 `openspec/specs/<capability>/spec.md`
   - 确定将应用哪些更改（添加、修改、删除、重命名）
   - 在提示之前显示综合摘要

   **提示选项：**
   - 如果需要更改：“立即同步（推荐）”、“存档而不同步”
   - 如果已同步：“立即存档”、“仍然同步”、“取消”

   如果用户选择同步，则使用任务工具（subagent_type：“通用”，提示：“使用技能工具调用 openspec-sync-specs 进行更改'<name>'。Delta 规格分析：<include the analyzed delta spec summary>”）。无论选择如何，都继续存档。

5. **执行归档**

   如果存档目录不存在，则创建它：
   ```bash
   mkdir -p openspec/changes/archive
   ```

   使用当前日期生成目标名称：`YYYY-MM-DD-<change-name>`

   **检查目标是否已经存在：**
   - 如果是：失败并出现错误，建议重命名现有存档或使用不同的日期
   - 如果否：将更改目录移至存档

   ```bash
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

6. **显示摘要**

   显示存档完成摘要，包括：
   - 更改姓名
   - 使用的架构
   - 存档位置
   - 规格同步状态（已同步/同步已跳过/无增量规格）
   - 注意任何警告（不完整的工件/任务）

**成功时的输出**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs

All artifacts complete. All tasks complete.
```

**成功时的输出（无 Delta 规格）**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** No delta specs

All artifacts complete. All tasks complete.
```

**成功时输出并带有警告**

```
## Archive Complete (with warnings)

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** Sync skipped (user chose to skip)

**Warnings:**
- Archived with 2 incomplete artifacts
- Archived with 3 incomplete tasks
- Delta spec sync was skipped (user chose to skip)

Review the archive if this was not intentional.
```

**错误输出（存档存在）**

```
## Archive Failed

**Change:** <change-name>
**Target:** openspec/changes/archive/YYYY-MM-DD-<name>/

Target archive directory already exists.

**Options:**
1. Rename the existing archive
2. Delete the existing archive if it's a duplicate
3. Wait until a different date to archive
```

**护栏**
- 如果未提供，始终提示更改选择
- 使用工件图（openspec status --json）进行完成检查
- 不要因警告而阻止存档 - 只需通知并确认
- 移动到存档时保留 .openspec.yaml（它随目录移动）
- 显示所发生事件的清晰摘要
- 如果请求同步，请使用技能工具调用`openspec-sync-specs`（代理驱动）
- 如果存在差异规格，请始终运行同步评估并在提示之前显示组合摘要
