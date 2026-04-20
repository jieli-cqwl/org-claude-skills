# Feishu Docs Skill Research Report

调研模式: selection  
呈现模式: decision  
调研日期: 2026-04-20

## 结论

采用官方 `larksuite/cli` 作为执行底座，在本仓库创建 `feishu-docs` first-party manual-only Skill 作为安全编排层。

这个组合最适合当前需求：Claude Code 与 Codex 都通过同一个 Skill 手动触发，Skill 负责确认目标、选择读写删路径、保护高风险操作和汇报飞书侧证据；真正的飞书 API 调用交给官方 `lark-cli`。

## 用户需求

用户需要一个可手动调用的飞书文档 Skill，覆盖两类核心场景。

第一类是写入飞书：头脑风暴、PRD、设计、计划、复盘等开发文档产出后，用户手动调用 Skill，把指定内容创建到飞书、追加到已有文档、替换章节或覆盖全文。

第二类是读取飞书：用户给定文档链接、文档名、知识库链接或目录信息后，Skill 读取文档内容并进行总结、分析、提炼结构和风险。

读、增、改、删都在范围内，但写入、覆盖和删除属于外部高风险操作，需要显式确认和飞书侧证据。

## 方案对比

| 方案 | 证据 | 优势 | 主要风险 | 结论 |
| --- | --- | --- | --- | --- |
| 官方 `larksuite/cli` + 本地 `feishu-docs` Skill | 官方 CLI 仓库说明其面向人类与 AI Agent，覆盖 Docs、Wiki、Drive，并提供 `lark-doc`、`lark-wiki`、`lark-drive` 等 agent skills；npm 最新版本为 `@larksuite/cli@1.0.14` | 官方维护，命令面向 Agent 调优，支持文档创建、读取、更新、搜索、Wiki 解析、Drive 导入导出与权限；Skill 可收紧安全边界 | 需要本地安装与授权；飞书权限模型仍需要用户配合 | 推荐 |
| 官方 `lark-openapi-mcp` | 官方 MCP README 标注 Beta，支持 OpenAPI MCP、OAuth 和按工具启用 | 适合 MCP 客户端直接调用飞书 OpenAPI | 工具面大，README 明确直接编辑云文档能力受限；对 manual Skill 的可控性弱于 CLI | 备选 |
| 第三方 `feishu-docx` | PyPI 与仓库说明支持 Docx、Sheet、Bitable、Wiki 导出 Markdown，并支持文档写入、追加、更新 | Markdown 保真和导出能力强 | 第三方依赖，部分导出路径依赖浏览器/Playwright；不适合作为唯一底座 | 增强项 |
| 第三方 Feishu MCP/CLI | 社区 Feishu-MCP 覆盖文档块 CRUD、搜索、Wiki、图片等能力 | 社区能力完整 | 第三方封装厚，权限、安全和维护链路需要额外审计 | 强备选，不作为主线 |
| 自研 OpenAPI SDK 封装 | 飞书 OpenAPI 原生支持 Docx、Drive、Wiki、Bitable | 控制力最高 | 开发和维护成本最高，需要自己处理认证、限流、转换、错误、安装 | 暂不采纳 |

## 官方能力边界

飞书新版文档是 block tree，不是普通 Markdown 文件。OpenAPI 支持：

| 能力 | 官方 API 面 | 设计含义 |
| --- | --- | --- |
| 创建文档 | `POST /open-apis/docx/v1/documents` | Skill 可新建飞书文档 |
| 读取文档 | 文档基本信息、纯文本、所有块 | 快速总结用纯文本；结构分析用 blocks |
| 新增内容 | 创建块、Markdown/HTML 转 blocks | 写入路径优先使用官方 CLI 的 Markdown shortcut |
| 修改内容 | 更新块、批量更新块 | 章节替换、局部插入走 `docs +update` |
| 删除内容 | 删除块 | 删除章节/块必须二次确认 |
| 文件层删除 | Drive 删除文件/文件夹 | 删除文档和文件夹属于高风险路径 |
| Wiki | Wiki space/node API | Wiki 链接先解析 `obj_type` 与 `obj_token`，再调用实际对象 API |
| 导入导出 | Drive import/export | 本地 Markdown、Word、Excel、CSV 等可导入为云文档 |

## 认证与权限判断

飞书权限分两层：开放平台 scope 和具体资源权限。两层都满足时，读写才成立。

`lark-cli` 支持应用身份和用户身份：

| 身份 | 使用场景 | 风险 |
| --- | --- | --- |
| `--as bot` | 应用级自动化、bot 创建的文档、被授予权限的文档 | 看不到用户私人空间；创建资源归属 bot |
| `--as user` | 读取用户有权访问的文档、个人云空间、以用户身份创建文档 | 需要 OAuth；授权范围内 AI 可访问用户资源 |

Skill 设计采用最小权限原则：读操作优先检查现有授权；写操作要求目标、身份、scope 和资源权限都明确；权限不足时停止并输出修复入口，不静默切换身份。

## 命名与对象解析

链接解析规则：

| 输入 | 处理 |
| --- | --- |
| `/docx/{token}` | 直接作为新版文档 token |
| `/doc/{token}` | 作为旧版文档 token，优先读取，写入能力按 CLI 支持边界处理 |
| `/wiki/{token}` | 先调用 Wiki node 解析，取得真实 `obj_type` 与 `obj_token` |
| `/drive/folder/{token}` | 作为目标文件夹或列表范围 |
| 文档名 | 先搜索，若命中多个候选，交给用户选择 |

同名文档不能自动选择。候选输出需要包含标题、类型、链接、更新时间或所在空间。

## 推荐 Skill 形态

名称: `feishu-docs`  
运行源: `shared/skills/feishu-docs/`  
触发方式: manual-only  
执行底座: `lark-cli`

目录结构：

```text
shared/skills/feishu-docs/
├── SKILL.md
├── agents/openai.yaml
├── references/
│   ├── auth-and-config.md
│   ├── document-read-playbook.md
│   └── document-write-playbook.md
├── scripts/
│   ├── manifest.json
│   └── feishu_doc.py
└── evals/evals.json
```

第一版只把 `lark-cli` 作为硬依赖。`feishu-docx` 保留为格式增强候选，在后续证实 Markdown 保真度不足时再接入。

## 独立挑战记录

最强反方挑战：飞书权限模型和 AI 写操作风险大于工具选择风险。即使选择官方 CLI，只要 Skill 默认允许全量读写删，也会产生敏感数据泄露、误覆盖、误删除和权限漂移问题。

采纳结论：`feishu-docs` 必须手动触发，并把能力分为默认读、受控写、高风险删改三层。写入前确认目标和内容范围；覆盖与删除二次确认；完成时必须返回飞书侧证据。

## 检索路径与覆盖证明

名称变体覆盖：

- Feishu / 飞书 / Lark / larksuite
- CLI / MCP / OpenAPI / SDK / Skill
- doc / docs / docx / wiki / drive / bitable

对象类型覆盖：

- 官方 CLI: `larksuite/cli`, `@larksuite/cli`
- 官方 MCP: `larksuite/lark-openapi-mcp`, `@larksuiteoapi/lark-mcp`
- 第三方 CLI: `feishu-docx`, `feishu-cli`
- 第三方 MCP: Feishu-MCP、mcp-lark-doc-manage、larkmcp
- 官方 OpenAPI: Docx、Drive、Wiki、Bitable

排除对象：

- Cookie 或逆向协议方案：安全风险高，不进入组织级 Skill 底座。
- 只支持消息、日历、表格写入的 MCP：不满足飞书文档读写目标。
- 纯 SDK 自研：控制力高，但第一版交付成本高于官方 CLI 路线。

## 资料来源

- [larksuite/cli GitHub](https://github.com/larksuite/cli)
- [@larksuite/cli npm](https://www.npmjs.com/package/@larksuite/cli)
- [Feishu CLI site](https://feishu-cli.com/)
- [larksuite/lark-openapi-mcp GitHub](https://github.com/larksuite/lark-openapi-mcp)
- [lark-openapi-mcp CLI reference](https://github.com/larksuite/lark-openapi-mcp/blob/main/docs/reference/cli/cli.md)
- [飞书新版文档 OpenAPI 概述](https://feishu.apifox.cn/doc-1950636)
- [飞书创建文档 API](https://feishu.apifox.cn/api-58540235)
- [飞书新版文档接入指南](https://feishu.apifox.cn/doc-412914)
- [飞书导入文件说明](https://feishu.apifox.cn/doc-412907)
- [飞书导出文件指南](https://feishu.apifox.cn/doc-1950023)
- [feishu-docx PyPI](https://pypi.org/project/feishu-docx/)
