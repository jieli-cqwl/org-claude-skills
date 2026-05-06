# MCP Server 开发参考

MCP Server 的核心是让模型安全、准确地调用外部能力。设计工具时先保证 schema 清楚、行为边界清楚、错误可恢复，再考虑实现组织。

## 工具定义

- 参数用 Zod/Pydantic 等结构化 schema 定义，避免自然语言约定参数形状。
- 返回值使用 MCP 约定的 content 结构，文本、图片或资源引用按协议类型表达。
- 命名使用 `{domain}_{action}_{resource}`，让模型能从名字理解能力边界。
- 每个工具必须显式评估 `ToolAnnotations`；当默认值不能准确描述行为时，在 `annotations` 中设置 `readOnlyHint`、`destructiveHint`、`idempotentHint`、`openWorldHint`。
- 注解必须用 SDK 类型检查或 `tools/list` 输出验证，不能只停留在代码意图。

## 行为边界

- 成功路径要返回模型可继续使用的信息，而不只是“done”。
- 错误信息要说明用户或模型下一步该怎么处理，避免暴露内部堆栈和敏感细节。
- 列表接口默认支持分页或限制返回规模。
- 外部 API、文件、网络和长任务必须有超时、错误分类和可观察上下文。
- 破坏性动作、开放世界动作和非幂等动作必须在工具描述和注解中清楚表达。

## 验证

验证 LLM 使用效果时，至少为每个工具准备成功路径、错误路径和边界路径测试问题；记录问题、期望工具、实际工具调用、返回结果和是否达成用户目标。

MCP 验收必须覆盖 fresh commands：构建或启动 server、`tools/list` 验证工具 schema、实际 tool call 成功路径、错误路径和边界路径；关键路径全部通过后才算验证完成。

## TypeScript 结构参考

```text
my-mcp-server/
├── src/
│   ├── index.ts
│   ├── tools/
│   ├── api/
│   └── types/
├── package.json
└── tsconfig.json
```
