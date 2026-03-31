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
- 注解必填：`readOnly`、`destructive`、`idempotent`、`openWorld`

## 设计原则

- 错误信息指导如何解决；列表接口支持分页；类型安全
- 创建 10 个测试问题验证 LLM 使用效果

## 资源

- [MCP 协议文档](https://modelcontextprotocol.io) | [TypeScript SDK](https://github.com/anthropics/mcp-typescript-sdk)
