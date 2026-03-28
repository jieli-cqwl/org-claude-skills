# 法典工具映射

技能使用 Claude Code 工具名称。当您在技能中遇到这些问题时，请使用您的平台等效项：

|技能参考|法典等效项 |
|-----------------|------------------|
| `Task`工具（调度子代理）| `spawn_agent`（请参阅[指定代理调度](#named-agent-dispatch)）|
|多个`Task` 调用（并行）|多个`spawn_agent` 通话 |
|任务返回结果 | `wait` |
|任务自动完成 | `close_agent` 到免费插槽 |
| `TodoWrite`（任务跟踪）| `update_plan` |
| `Skill`工具（调用技能）|技能本地加载 - 只需按照说明操作即可 |
| `Read`、`Write`、`Edit`（文件）|使用您的本机文件工具 |
| `Bash`（运行命令）|使用本机 shell 工具 |

## 子代理调度需要多代理支持

添加到您的 Codex 配置 (`~/.codex/config.toml`)：

```toml
[features]
multi_agent = true
```

这使得`spawn_agent`、`wait` 和`close_agent` 能够获得`dispatching-parallel-agents` 和`subagent-driven-development` 等技能。

## 指定代理调度

Claude Code 技能参考`superpowers:code-reviewer` 等命名代理类型。
Codex 没有命名代理注册表 — `spawn_agent` 创建通用代理
来自内置角色（`default`、`explorer`、`worker`）。

当技能要求派遣指定代理时，类型：

1. 查找代理的提示文件（例如，`agents/code-reviewer.md` 或技能的
   本地提示模板，如`code-quality-reviewer-prompt.md`）
2. 阅读提示内容
3. 填写任何模板占位符（`{BASE_SHA}`、`{WHAT_WAS_IMPLEMENTED}` 等）
4. 生成一个`worker`代理，其填充内容为`message`

|技能指导|法典等效项 |
|-------------------|------------------|
| `Task tool (superpowers:code-reviewer)` | `spawn_agent(agent_type="worker", message=...)` 和 `code-reviewer.md` 内容 |
| `Task tool (general-purpose)` 带有内联提示 | `spawn_agent(message=...)` 具有相同的提示 |

### 消息框架

`message`参数是用户级输入，不是系统提示符。构建它
为了最大限度地遵守指令：

```
Your task is to perform the following. Follow the instructions below exactly.

<agent-instructions>
[filled prompt content from the agent's .md file]
</agent-instructions>

Execute this now. Output ONLY the structured response following the format
specified in the instructions above.
```

- 使用任务委托框架（“你的任务是……”）而不是角色框架（“你是……”）
- 将指令包装在 XML 标签中 — 该模型将带标签的块视为权威
- 以显式执行指令结束以防止指令摘要

### 何时可以删除此解决方法

这种方法弥补了 Codex 的插件系统尚不支持 `agents`
`plugin.json` 中的字段。当`RawPluginManifest`获得`agents`字段时，
插件可以符号链接到`agents/`（镜像现有的`skills/`符号链接）并且
技能可以直接调度指定的代理类型。

## 环境检测

创建工作树或完成分支的技能应该检测它们的
在继续之前具有只读 git 命令的环境：

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → 已经在链接的工作树中（跳过创建）
- `BRANCH` 空 → 分离的 HEAD（无法从沙箱分支/推送/PR）

请参阅`using-git-worktrees` 步骤 0 和 `finishing-a-development-branch`
第 1 步了解每种技能如何使用这些信号。

## Codex 应用程序整理

当沙箱阻止分支/推送操作时（在一个
外部管理的工作树），代理提交所有工作并通知
用户使用应用程序的本机控件：

- **“创建分支”** — 命名分支，然后通过应用程序 UI 提交/推送/PR
- **“移交到本地”** — 将工作转移到用户的本地结帐处

代理仍然可以运行测试、暂存文件并输出建议的分支
供用户复制的名称、提交消息和 PR 描述。
