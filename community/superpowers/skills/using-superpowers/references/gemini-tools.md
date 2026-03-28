# Gemini CLI 工具映射

技能使用 Claude Code 工具名称。当您在技能中遇到这些问题时，请使用您的平台等效项：

|技能参考| Gemini CLI 等效项 |
|-----------------|----------------------|
| `Read`（文件读取）| `read_file` |
| `Write`（文件创建）| `write_file` |
| `Edit`（文件编辑）| `replace` |
| `Bash`（运行命令）| `run_shell_command` |
| `Grep`（搜索文件内容）| `grep_search` |
| `Glob`（按名称搜索文件）| `glob` |
| `TodoWrite`（任务跟踪）| `write_todos` |
| `Skill`工具（调用技能）| `activate_skill` |
| `WebSearch` | `google_web_search` |
| `WebFetch` | `web_fetch` |
| `Task`工具（调度子代理）|没有等效项 — Gemini CLI 不支持子代理 |

## 无子代理支持

Gemini CLI 没有相当于 Claude Code 的 `Task` 工具。依赖于子代理调度（`subagent-driven-development`、`dispatching-parallel-agents`）的技能将通过`executing-plans` 回退到单会话执行。

## 其他 Gemini CLI 工具

这些工具在 Gemini CLI 中可用，但没有等效的 Claude Code：

|工具|目的|
|------|---------|
| `list_directory` |列出文件和子目录 |
| `save_memory` |跨会话将事实保留到 GEMINI.md |
| `ask_user` |请求用户结构化输入 |
| `tracker_create_task` |丰富的任务管理（创建、更新、列表、可视化）|
| `enter_plan_mode` / `exit_plan_mode` |进行更改之前切换到只读研究模式 |
