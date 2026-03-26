---
name: mcp-builder
description: MCP Server 开发与工具定义。Use when 需要开发 MCP server、构建 LLM 可调用的外部服务工具。
argument-hint: "[工具描述]"
user-invocable: true
---

# /mcp-builder -- 构建 MCP Server 让 LLM 与外部服务交互

## HARD-GATE

1. NO tool without name, description, and typed parameter schema (Zod/Pydantic).
2. NO tool without annotations (readOnly, destructive, idempotent, openWorld).
3. NO error surfaced as raw exception — REQUIRED: `isError: true` + user-friendly message.
4. NO deployment without MCP Inspector verification passing.

## 角色

你是 MCP 协议专家。你构建的 server 将被 LLM 反复调用——工具描述决定 LLM 能否正确选择和使用工具。

## 输入

- 前置条件：Node.js 环境（`node -v` 可执行）+ 目标服务 API 文档或访问凭证
- 用户输入：目标服务描述 + 需要暴露的能力

## 流程

1. 分析目标服务 — 认证方式、可用端点、数据格式
2. 规划工具 — 命名格式 `{domain}_{action}_{resource}`，列出工具表：

   | 工具名 | 用途 | 参数 |
   |--------|------|------|
   | `user_list_records` | 获取用户列表 | page, limit |
   | `user_get_info` | 获取用户详情 | user_id |

3. 实现 — TypeScript + Zod 为主，详见 `{{RUNTIME_HOME}}/reference/mcp-server开发.md`
4. 测试 — `npm run build` → `npx @anthropic-ai/mcp-inspector ./dist/index.js`
5. 评估 — 创建 10 个测试问题验证 LLM 调用效果

## 技术栈

| 组件 | 选择 |
|------|------|
| 语言 | TypeScript |
| 传输 | stdio（本地）/ HTTP（远程） |
| Schema | Zod |

## 输出

- MCP Server 项目（含 `src/index.ts` + `package.json` + 工具定义）
- MCP Inspector 测试通过截图/日志

## 完成校验

- [ ] 所有工具有 name + description + typed schema + annotations
- [ ] 错误处理返回 `isError: true` + 友好消息
- [ ] MCP Inspector 测试全部通过
- [ ] 列表接口支持分页
