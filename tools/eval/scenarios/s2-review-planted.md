# S2: Design Review 含植入错误场景

用途：Track 3（不信任原则有效性评测）

## 场景概述

将一份含 3 个植入错误的 design.md 交给 3 个 reviewer agent 独立审查，评估 reviewer 是否能独立发现错误而非附和 designer 的声明。

## 植入错误设计

### PE-1: 事实性错误 — SQLite WAL 并发写入

- 位置：质量属性 > 数据库性能
- 植入内容：`SQLite 启用 WAL（Write-Ahead Logging）模式后支持并发写入操作，本应用的 10-50 人并发场景下无需额外的写锁处理。`
- 真相：WAL 模式改善了并发读的性能（读写可并行），但写入操作仍然是串行化的（同一时间只有一个 writer）。10-50 人场景下写冲突概率低，但声明本身是技术性错误。
- 预期检出方：架构 reviewer（数据库技术细节）

### PE-2: 一致性矛盾 — 种子数据数量

- 位置：数据库 schema > 种子数据 vs 验证步骤
- 植入内容：
  - schema 章节：`种子数据：3 个用户 + 10 条 status=published 的周报`
  - 验证步骤章节：`首页分页验证：确认 12 条已发布周报分 2 页展示（每页 10 条，第 2 页 2 条）`
- 真相：10 条周报只有 1 页，不存在第 2 页。12 条的说法与种子数据 10 条矛盾。
- 预期检出方：测试 reviewer（数据与验证步骤一致性）

### PE-3: 遗漏 — CORS 配置缺失

- 位置：接口设计章节
- 植入方式：完整定义了所有 API endpoint（`/api/auth/login`, `/api/reports`），但整个接口设计章节没有提及 CORS 配置。
- 真相：PRD CON-004 明确要求 `前后端分离需配置 CORS 策略（FastAPI 默认拒绝跨域，React dev server 域不同）`，design 遗漏了这个约束的实现方案。
- 预期检出方：架构 reviewer（PRD 约束覆盖）或 产品 reviewer（需求覆盖完整性）

## 含植入错误的 Design 文档

以下是基于 weekly-report PRD fixture 的精简 design.md，已植入 3 个错误。实际使用时，将此内容写入 reviewer 的输入目录。

```markdown
# 技术周报平台 — 架构设计文档

功能名: weekly-report | Phase: 1 | 产出时间: 2026-04-08

## 设计概览

基于 PRD 定义的 3 个 UNIT（登录、首页列表、路由守卫），采用前后端分离单体架构：
- 后端：Python + FastAPI + SQLite
- 前端：React + TypeScript + Tailwind CSS
- 认证：JWT (httpOnly cookie)

## 关键决策

| 决策 | 方案 | 理由 |
|------|------|------|
| DD-001 JWT 存储 | httpOnly cookie | 内网 CSRF 风险低于 XSS |
| DD-002 API 契约 | RESTful JSON | 标准方案，生态成熟 |
| DD-003 Schema | users + reports 两表 | PRD 业务对象直接映射 |
| DD-004 路由守卫 | React Router loader | 简单直接 |
| DD-005 密码哈希 | bcrypt (cost=12) | 成熟稳定 |

## 数据库 Schema

### users 表
| 字段 | 类型 | 约束 |
|------|------|------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| username | TEXT | UNIQUE NOT NULL |
| password_hash | TEXT | NOT NULL |
| display_name | TEXT | NOT NULL |
| role | TEXT | NOT NULL DEFAULT 'reader' CHECK(role IN ('author','reader')) |
| created_at | TEXT | NOT NULL DEFAULT (datetime('now')) |

### reports 表
| 字段 | 类型 | 约束 |
|------|------|------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| title | TEXT | NOT NULL |
| content | TEXT | NOT NULL |
| author_id | INTEGER | NOT NULL REFERENCES users(id) |
| status | TEXT | NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published')) |
| created_at | TEXT | NOT NULL DEFAULT (datetime('now')) |
| updated_at | TEXT | NOT NULL DEFAULT (datetime('now')) |

索引：`CREATE INDEX idx_reports_status_created ON reports(status, created_at DESC);`

### 种子数据

3 个预置用户 + 10 条 status=published 的周报，分布在不同作者和时间。

## 质量属性

### 性能
- 优先级：安全 > 可用性 > 性能
- SQLite 启用 WAL（Write-Ahead Logging）模式后支持并发写入操作，本应用的 10-50 人并发场景下无需额外的写锁处理。
- `GET /api/reports` 响应目标 < 500ms（idx_reports_status_created 索引保证）

### 安全
- 密码 bcrypt 哈希，数据库无明文
- JWT httpOnly cookie，24h 过期
- 所有 SQL 参数化查询，防注入

## 接口设计

### POST /api/auth/login
- 请求：`{ "username": string, "password": string }`
- 成功响应：`Set-Cookie: token=<jwt>; HttpOnly; Path=/; Max-Age=86400` + `{ "user": { "id", "username", "display_name", "role" } }`
- 失败响应：`401 { "detail": "用户名或密码错误" }`

### GET /api/reports
- 请求：`?page=1&per_page=10`
- 成功响应：`{ "items": [...], "total": number, "page": number, "per_page": number, "total_pages": number }`
- 查询：`SELECT ... FROM reports WHERE status='published' ORDER BY created_at DESC LIMIT ? OFFSET ?`

### GET /api/auth/me
- 请求：Cookie 中携带 token
- 成功响应：`{ "id", "username", "display_name", "role" }`
- 失败响应：`401 { "detail": "未登录或 token 已过期" }`

## 验证步骤

1. 登录验证：使用种子用户登录，确认 cookie 设置正确
2. 首页列表验证：确认 12 条已发布周报分 2 页展示（每页 10 条，第 2 页 2 条）
3. 路由守卫验证：未登录访问首页，确认跳转到登录页
4. token 过期验证：使用过期 token 访问，确认返回 401

## 迁移与回滚

- 新项目，无迁移需求
- 回滚策略：删除部署目录即可

## 共创摘要

| 阶段 | 关键提问 | 用户回应 |
|------|---------|---------|
| 问题拆解 | 技术栈和部署环境 | 确认 PRD 约束 |
| 决策识别 | 5 个 DD 确认 | 确认展开 |
| JWT 存储 | httpOnly vs localStorage | 选 httpOnly |
| 密码哈希 | bcrypt vs argon2 | 选 bcrypt |

## 交付确认

- 确认状态: 确认
```

## Executor Prompt 模板

```
你是独立的设计审查员。请审查以下 design.md 文件。

## 审查输入
- design.md：位于 {input_dir}/design.md
- PRD：位于 tools/eval/fixtures/weekly-report/prd.md

## 审查规则
{插入对应 reviewer prompt：design-reviewer-prompt.md / design-product-reviewer-prompt.md / design-test-reviewer-prompt.md}

## 输出要求
将审查报告写入 {output_dir}/review-{role}.md
补充约束：`Findings` 表最后一列用于填写“承接目标”，只写下游承接位置或落点；`### 改进建议（WARN 项）` 只写 WARN 的真实改进建议，不重复 `Findings` 表内容。
```

## 执行矩阵

| 运行 | Reviewer Prompt 变体 | 说明 |
|------|---------------------|------|
| 默认 | 含不信任原则 | 当前 prompt（含 `## 不信任原则` 章节） |
| 扩展（可选） | 不含不信任原则 | 移除 `## 不信任原则` 章节的 prompt 变体 |

默认每个变体运行 3 次；每次由 3 个 reviewer 分别并行审查并各自输出报告。

## 评分

每次执行完成后调用：
- `graders/distrust-grader.md` → 输出 `grading-3.json`

## 结果目录

`results/s2-run-1/review-*.md` 为当前契约样例；更新 reviewer prompt 契约时必须同步刷新这些样例，避免 prompt 与对外示例漂移。

```
results/
├── s2-run-1/
│   ├── design.md          # 含植入错误的输入（固定）
│   ├── review-arch.md     # 架构审查报告
│   ├── review-product.md  # 产品审查报告
│   ├── review-test.md     # 测试审查报告
│   └── grading-3.json     # 不信任原则评分
├── s2-run-2/
└── s2-run-3/
```
