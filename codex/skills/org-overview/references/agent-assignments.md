# Agent 并行分工

## 分工表

| Agent | 任务 | 返回格式 |
|-------|------|---------|
| 1 | 目录结构分析 | `{directories, core_modules}` |
| 2 | 技术栈识别 | `{framework, language, build_tool, versions}` |
| 3 | 依赖关系分析 | `{external_deps, internal_deps}` |
| 4 | 核心模块识别 | `{modules: [{name, responsibility, key_files}]}` |
| 5 | API 端点收集 | `{endpoints: [{path, method, description}]}` |
| 6 | 数据模型分析 | `{models: [{name, fields, relations}]}` |
| 7 | 配置文件分析 | `{configs: [{file, key_settings}]}` |
| 8 | 文档收集 | `{docs: [{file, summary}], readme_summary}` |

所有 Agent 使用 subagent_type: Explore，等待全部完成后继续。

## 错误处理

| 失败场景 | 处理方式 |
|---------|---------|
| Agent 1-4 失败（核心） | 重试一次，仍失败则终止报告 |
| Agent 5-8 失败（辅助） | 继续执行，输出中标注缺失 |
| 超过 3 个 Agent 失败 | 终止，建议用户检查项目结构 |
| 单个 Agent 超时 >60s | 终止该 Agent，使用已有结果 |
