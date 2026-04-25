# MCP Server 开发参考

> 触发条件：开发 MCP server 时读取。

## 项目结构（TypeScript）

```
my-mcp-server/
├── src/
│   ├── index.ts         # 入口
│   ├── tools/           # 工具实现
│   ├── api/             # API 客户端
│   └── types/           # 类型定义
├── package.json
└── tsconfig.json
```

## 工具定义要点

- 参数用 Zod/Pydantic 定义 Schema，返回 `{ content: [{ type: 'text', text: ... }] }`
- 命名：`{domain}_{action}_{resource}` 格式
- 每个工具必须显式评估 `ToolAnnotations`；当默认值不能准确描述行为时，在 `annotations` 中设置 `readOnlyHint`、`destructiveHint`、`idempotentHint`、`openWorldHint`，并用 SDK 类型检查或 `tools/list` 输出验证

## 设计原则

- 错误信息指导如何解决；列表接口支持分页；类型安全
- 验证 LLM 使用效果时，至少为每个工具准备成功路径、错误路径和边界路径测试问题；记录问题、期望工具、实际工具调用、返回结果和是否达成用户目标，关键路径全部通过后才算验证完成

## 资源

- [MCP 协议文档](https://modelcontextprotocol.io) | [TypeScript SDK](https://github.com/anthropics/mcp-typescript-sdk)
