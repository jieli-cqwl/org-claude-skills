---
name: "OPSX: Propose"
description: 提出一项新的变更 - 创建它并一步生成所有工件
category: Workflow
tags: [workflow, artifacts, experimental]
---

提出一项新的变更 - 创建变更并一步生成所有工件。

我将使用工件创建更改：
- 提案.md（内容和原因）
- design.md（如何）
- tasks.md（实现步骤）

准备好实施时，运行 /opsx:apply

---

**输入**：`/opsx:propose` 之后的参数是更改名称（短横线大小写），或者用户想要构建的内容的描述。

**步骤**

1. **如果没有提供任何信息，询问他们想要构建什么**

   使用 **AskUserQuestion 工具**（开放式，无预设选项）询问：
   > “你想要进行什么改变？描述一下你想要构建或修复什么。”

   从他们的描述中，得出一个短横线命名（例如，“添加用户身份验证”→ `add-user-auth`）。

   **重要**：在不了解用户想要构建什么的情况下不要继续。

2. **创建更改目录**
   ```bash
   openspec new change "<name>"
   ```
   这会在 `openspec/changes/<name>/` 和 `.openspec.yaml` 处创建脚手架更改。

3. **获取工件构建顺序**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析JSON得到：
   - `applyRequires`：实现前所需的工件 ID 数组（例如，`["tasks"]`）
   - `artifacts`：所有工件及其状态和依赖项的列表

4. **按顺序创建工件直到应用就绪**

   使用 **TodoWrite 工具** 跟踪工件的进度。

   按依赖关系顺序循环遍历工件（首先是没有挂起的依赖关系的工件）：

   一个。 **对于每个 `ready` 的工件（满足依赖关系）**：
      - 获取说明：
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - 指令 JSON 包括：
        - `context`：项目背景（对您的限制 - 不包含在输出中）
        - `rules`：特定于工件的规则（对您的限制 - 不包含在输出中）
        - `template`：用于输出文件的结构
        - `instruction`：此工件类型的特定于架构的指南
        - `outputPath`：在哪里写入工件
        - `dependencies`：已完成的工件以供阅读上下文
      - 读取任何已完成的依赖文件以了解上下文
      - 使用`template`作为结构创建工件文件
      - 应用 `context` 和 `rules` 作为约束 - 但不要将它们复制到文件中
      - 显示简要进度：“已创建<artifact-id>”

   b. **继续，直到所有 `applyRequires` 工件完成**
      - 创建每个工件后，重新运行 `openspec status --change "<name>" --json`
      - 检查`applyRequires`中的每个工件ID在工件数组中是否有`status: "done"`
      - 当所有 `applyRequires` 工件完成后停止

   c. **如果工件需要用户输入**（上下文不清楚）：
      - 使用 **AskUserQuestion 工具** 进行澄清
      - 然后继续创作

5. **显示最终状态**
   ```bash
   openspec status --change "<name>"
   ```

**输出**

完成所有工件后，总结一下：
- 更改名称和位置
- 创建的工件列表以及简要说明
- 准备就绪：“所有工件均已创建！准备实施。”
- 提示：“运行`/opsx:apply`开始实施。”

**文物创建指南**

- 对于每个工件类型，遵循 `openspec instructions` 中的 `instruction` 字段
- 该模式定义了每个工件应包含的内容 - 遵循它
- 在创建新项目之前，请阅读依赖项的上下文
- 使用 `template` 作为输出文件的结构 - 填写其部分
- **重要**：`context` 和 `rules` 是对您的约束，而不是文件的内容
  - 不要将 `<context>`、`<rules>`、`<project_context>` 块复制到工件中
  - 这些指导您编写的内容，但不应出现在输出中

**护栏**
- 创建实现所需的所有工件（由架构的`apply.requires`定义）
- 在创建新的依赖项之前，请务必先阅读依赖项
- 如果上下文非常不清楚，请询问用户 - 但更愿意做出合理的决定以保持动力
- 如果具有该名称的更改已存在，询问用户是否要继续它或创建一个新的
- 写入后验证每个工件文件是否存在，然后再继续下一步


## 本地工作流程注释

在此存储库的融合工作流程中，`/opsx:propose` 完成后，您应该在 `/opsx:apply` 之前运行 `writing-plans`。
如果明确调用`/opsx:propose`，请不要跳回头脑风暴。
