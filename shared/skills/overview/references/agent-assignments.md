# Agent 并行分工

## 输入边界

- 最多启用 8 个 agent，全部使用 Explore 类型
- 所有 agent 只读取预扫描结果、被分配的文件范围和必要的关键文件
- 超出主责任范围的发现只作为补充证据，禁止重复输出别的 agent 的主责任内容
- 查不到证据时返回空数组或空对象，不编造结论

## 分工表

| Agent | 任务 | 输入边界 | 返回格式 |
|-------|------|---------|---------|
| 1 | 目录结构分析 | 目录树、根目录配置、入口目录 | `{directories, core_modules, evidence_files}` |
| 2 | 技术栈识别 | 特征文件、构建配置、入口文件 | `{framework, language, build_tool, versions, evidence_files}` |
| 3 | 依赖关系分析 | 依赖清单、模块导入、共享目录 | `{external_deps, internal_deps, evidence_files}` |
| 4 | 核心模块识别 | 业务目录、入口文件、路由或控制器 | `{modules: [{name, responsibility, key_files}]}` |
| 5 | API 端点收集 | 路由、Controller、接口定义 | `{endpoints: [{path, method, description, file}]}` |
| 6 | 数据模型分析 | model/schema/entity 文件 | `{models: [{name, fields, relations, file}]}` |
| 7 | 配置文件分析 | 配置文件、环境变量模板、构建配置 | `{configs: [{file, key_settings}]}` |
| 8 | 文档收集 | README、docs/、架构说明 | `{docs: [{file, summary}], readme_summary}` |

## 主代理汇总协议

- 去重：相同证据只保留一次，优先保留最接近源文件的描述
- 冲突处理：不同 agent 结论冲突时，主代理回读源文件裁决，并在报告中标注取舍
- 缺口标注：辅助 agent 失败或返回空结果时，在最终概览中显式标注缺失范围
- 结构映射：将并行结果映射回产品视角、架构图、模块说明和入门路径
- 不允许静默回退到串行；核心 agent 失败按错误处理执行，不能假装全量覆盖

## 错误处理

| 失败场景 | 处理方式 |
|---------|---------|
| Agent 1-4 失败（核心） | 重试一次，仍失败则终止报告 |
| Agent 5-8 失败（辅助） | 继续执行，输出中标注缺失 |
| 超过 3 个 Agent 失败 | 终止，建议用户检查项目结构 |
| 单个 Agent 超时 >60s | 终止该 Agent，使用已有结果 |
