# Design — Phase 1: 登录 + 首页

功能名: weekly-report | Phase: 1 | 产出时间: 2026-04-06

## 输入分析

- PRD: `docs/weekly-report/prd.md`（3 UNIT、16 AC、5 DD、4 CON）
- UNIT 覆盖: UNIT-1（登录）、UNIT-2（首页列表）、UNIT-3（路由守卫）
- 待设计决策: DD-001~DD-005 全部在本阶段裁决

## 上游审查承接

| Issue ID | 视角 | 发现摘要 | 承接方式 | 承接位置 |
|----------|------|---------|---------|---------|
| AR-002 | 架构 | 路由守卫仅前端检查，后端 API 校验边界未识别 | 采纳 | D-004（双层防护方案）|
| AR-003 | 架构 | UNIT-2 对 DB schema 存在隐含依赖 | 采纳 | D-003（display_name NOT NULL）|
| AR-005 | 架构 | 密码哈希库跨平台编译风险 | 采纳 | D-005（passlib[bcrypt] 预编译 wheel）|
| TR-003 | 测试 | token 过期判断逻辑歧义 | 采纳 | D-004（统一使用 JWT exp claim）|
| TR-004 | 测试 | display_name 无 NOT NULL 约束 | 采纳 | D-003 |

## PRD 技术理解校正

无校正。PRD 技术约束（CON-001~CON-004）明确且合理。

## 现状事实

全新项目，无现有代码、依赖或集成点。技术栈：Python+FastAPI / React+TypeScript+Tailwind / SQLite / JWT。

## 设计场景判断

绿地项目（greenfield），无遗留系统约束。采用标准前后端分离 SPA 架构。

## 架构师审视维度

| 维度 | 评估 |
|------|------|
| 外部依赖 | 无第三方服务依赖。SQLite 文件本地存储，无网络数据源。pip/npm 包管理是唯一外部依赖 |
| 部署拓扑 | 单体部署：FastAPI 进程 + React 静态文件。开发阶段前后端独立 dev server（:8000/:3000），通过 CORS 互通 |
| 故障模式 | 单点故障=FastAPI 进程崩溃→全站不可用（10-50 人内网可接受）。SQLite 文件损坏→数据丢失（种子数据可重建）。无级联失败风险 |
| 质量属性 | 安全性 > 可用性 > 性能。安全：密码哈希+JWT+参数化 SQL。可用性：24h token 无 refresh 可接受。性能：10-50 人+SQLite 无瓶颈 |

## 关键决策记录

| 编号 | 决策点 | 决策 | 核心理由 | ADR |
|------|--------|------|----------|-----|
| D-001 | JWT 存储方案 | localStorage | 内网场景 XSS 风险可控，路由守卫需读 token | [ADR-001](design/adr/ADR-001.md) |
| D-002 | API 契约 | RESTful JSON + 统一错误格式 | 2 端点足够，FastAPI 原生支持 | [ADR-002](design/adr/ADR-002.md) |
| D-003 | DB Schema | display_name NOT NULL + created_at 倒序索引 | 消除前端空值逻辑，优化查询 | [ADR-003](design/adr/ADR-003.md) |
| D-004 | 路由守卫 | ProtectedRoute + axios 拦截器双层 | 覆盖路由跳转+API 调用双场景 | [ADR-004](design/adr/ADR-004.md) |
| D-005 | 密码哈希 | bcrypt via passlib | 成熟方案+预编译 wheel+统一接口 | [ADR-005](design/adr/ADR-005.md) |

## 既有约束继承确认

| 来源 | 既有结论 | 本轮处理 | 用户确认记录 | 对设计的影响 |
|------|----------|---------|-------------|-----------|
| 无 | 首次创建，无历史约束 | N/A | N/A | N/A |

## 共创摘要

| 阶段 | 关键提问 | 用户回应 | 对设计的影响 |
|------|---------|---------|------------|
| 问题拆解 | 5 个 DD 分别对应什么技术问题 | 用户委托全权处理 | 5 个决策点全部由设计阶段裁决 |
| 决策点识别 | DD-001~DD-005 + CORS + 后端 token 验证 | 用户委托全权处理 | 7 个决策点 |
| 方案探索 | 每个决策 2-3 方案对比 | 用户委托全权处理 | 选定 5 个 ADR |
| 边界接口 | API 路径/请求/响应格式/错误码 | 用户委托全权处理 | 2 端点 + 统一错误格式 |
| 质量闭环 | 安全/性能/可用性优先级 | 用户委托全权处理 | 安全 > 可用性 > 性能 |
| 实施约束 | 关键路径和并行策略 | 用户委托全权处理 | DD-003 必须先于 UNIT-2 |

## 架构边界

```
┌─────────────────────────────────────────┐
│  Frontend (React + TypeScript + Tailwind) │
│  :3000 (dev)                              │
│  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │ LoginPage│  │ HomePage │  │Protected│ │
│  │          │  │ (列表+分页)│  │ Route   │ │
│  └──────────┘  └──────────┘  └─────────┘ │
│       │              │            │       │
│       └──────┬───────┘            │       │
│              │ axios (+拦截器)     │       │
│              │ Authorization: Bearer <token>│
└──────────────┼────────────────────────────┘
               │ CORS
┌──────────────┼────────────────────────────┐
│  Backend (FastAPI)  :8000                  │
│  ┌──────────┐  ┌──────────┐               │
│  │POST      │  │GET       │               │
│  │/api/login│  │/api/reports│              │
│  └──────────┘  └──────────┘               │
│       │              │                     │
│  ┌────┴──────────────┴────┐               │
│  │   Auth Middleware       │               │
│  │   (JWT 验证 + 401)      │               │
│  └────────────┬───────────┘               │
│               │                            │
│  ┌────────────┴───────────┐               │
│  │   SQLite (file-based)   │               │
│  │   users + reports       │               │
│  └─────────────────────────┘               │
└────────────────────────────────────────────┘
```

## 接口边界

### POST /api/login
- 请求: `{ "username": string, "password": string }`
- 成功响应 200: `{ "token": string, "user": { "id": int, "username": string, "display_name": string, "role": string } }`
- 失败响应 401: `{ "error": { "code": "INVALID_CREDENTIALS", "message": "用户名或密码错误" } }`
- 无 Authorization header 要求

### GET /api/reports?page=N
- 请求: Query param `page`（默认 1，正整数）
- Header: `Authorization: Bearer <token>`（必须）
- **查询约束**: `WHERE status='published' ORDER BY created_at DESC`（R3 业务规则，draft 不可见）
- 成功响应 200: `{ "data": [{ "id": int, "title": string, "author_name": string, "created_at": string }], "pagination": { "page": int, "page_size": 10, "total": int, "total_pages": int } }`
  - `created_at` 格式：后端统一转换为 ISO 8601 格式 `"YYYY-MM-DDTHH:MM:SSZ"`（SQLite 原生 `datetime('now')` 输出为 `"YYYY-MM-DD HH:MM:SS"`，API 层做 `T` 分隔符和 `Z` 后缀转换）
- 空数据响应 200（total=0）: `{ "data": [], "pagination": { "page": 1, "page_size": 10, "total": 0, "total_pages": 0 } }` → 前端显示"暂无周报"
- 页码越界响应 200（total>0 但当前页无数据）: `{ "data": [], "pagination": { "page": N, "page_size": 10, "total": M, "total_pages": P } }` → 前端显示"暂无更多周报"（区分于空数据状态）
- 未认证响应 401: `{ "error": { "code": "UNAUTHORIZED", "message": "请先登录" } }`
- page 参数非法（page<=0 / 非数字）: 由 FastAPI Query 参数校验自动返回 422（Pydantic 默认行为）

### 统一错误格式
```json
{ "error": { "code": "ERROR_CODE", "message": "用户可读消息" } }
```

## 数据边界

### users 表
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('author', 'reader')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### reports 表
```sql
CREATE TABLE reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id INTEGER NOT NULL REFERENCES users(id),
    status TEXT NOT NULL CHECK(status IN ('draft', 'published')) DEFAULT 'draft',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_reports_published_created ON reports(status, created_at DESC);
```

### 种子数据
- 3 个用户: admin(author), alice(author), bob(reader)
- 12 条已发布周报 + 2 条草稿（验证 draft 不展示 + 验证分页）
- 密码统一为 `password123`（开发环境）
- 测试辅助数据: 固定 JWT_SECRET=`test-secret-key-for-dev`（仅开发/测试环境）、预生成的过期 token 字符串、非法格式 token 示例 `"not.a.jwt"`

## 质量属性

| 属性 | 目标 | 实现手段 |
|------|------|---------|
| 安全-密码 | 数据库无明文密码 | bcrypt via passlib，cost factor=12 |
| 安全-注入 | SQL 注入免疫 | 所有 SQL 使用参数化查询（`?` 占位符） |
| 安全-XSS | token 不被 XSS 窃取 | React 默认转义 + 禁止 dangerouslySetInnerHTML |
| 安全-JWT | payload 不含敏感信息 | 仅含 user_id, role, exp, iat |
| 性能 | API < 500ms, 页面 < 1000ms | SQLite 索引 + 分页查询 |

## 迁移策略

全新项目，无迁移需求。种子数据通过 `seed.py` 脚本初始化。

## 验证与可观测性

| 验证项 | 方法 |
|--------|------|
| API 契约 | FastAPI 自动生成 /docs（Swagger UI） |
| 密码哈希 | 查询 users 表确认 password_hash 以 `$2b$` 开头 |
| SQL 注入 | 登录时输入 `' OR 1=1 --` 确认返回 401 |
| CORS | 前端跨域请求确认无浏览器 CORS 报错 |
| 分页 | 种子数据 12 条 published 确认 2 页；验证 data[0].created_at > data[1].created_at 确认倒序 |
| draft 隔离 | 查询 API 确认 2 条草稿 id 不在响应中（R3 验证） |
| JWT payload | base64 解码 token payload 确认仅含 user_id, role, exp, iat |
| 无 Auth 请求 | 直接请求 GET /api/reports 不带 Authorization header → 返回 401 |

## 回滚方案

全新项目，回滚 = 删除项目目录。无生产数据风险。

## 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| SQLite 文件被意外删除 | 数据丢失 | seed.py 可重建，开发环境可接受 |
| JWT secret 硬编码泄露 | token 可伪造 | 从环境变量 `JWT_SECRET` 读取，不写入代码 |
| bcrypt wheel 不可用 | pip install 失败 | passlib 可降级到 pbkdf2_sha256（最后手段） |

## 影响范围清单

| scope_item_id | 变更类型 | 旧边界 | 新边界 | 风险等级 | 证据 | owner |
|---------------|----------|--------|--------|----------|------|-------|
| 全新项目，无影响范围 | — | — | — | — | — | — |

## 待计划约束

| 编号 | 约束或风险点 | 对计划拆分的影响 | 必须前置验证的事项 | 不可并行项或关键依赖 |
|------|-------------|------------------|-------------------|----------------------|
| PC-001 | DB schema 必须先于 UNIT-2 实现 | UNIT-2 开发前需先建表+种子数据 | SQLite 表创建和种子数据正确性 | schema 初始化 → UNIT-1/UNIT-2 |
| PC-002 | CORS 配置必须在首次前后端联调前完成 | 影响所有 UNIT 的联调 | FastAPI CORSMiddleware: `allow_origins=["http://localhost:3000"]`, `allow_methods=["*"]`, `allow_headers=["*"]`, `allow_credentials=false`（生产环境需收紧 origins） | CORS → 所有 API 调用 |
| PC-003 | 环境变量配置 | 需在项目初始化时配置 .env | `.env` 变量清单: `JWT_SECRET`(必须), `JWT_ALGORITHM=HS256`(默认), `JWT_EXPIRE_HOURS=24`(默认), `DB_PATH=./data/weekly_report.db`(默认) | 环境配置 → UNIT-1 |

## 覆盖表

| UNIT | AC | 设计覆盖 |
|------|----|---------|
| UNIT-1 | AC-U1-01 登录成功 | POST /api/login → 200 + token → localStorage |
| UNIT-1 | AC-U1-02 密码错误 | POST /api/login → 401 INVALID_CREDENTIALS |
| UNIT-1 | AC-U1-03 用户不存在 | 同上（统一错误码） |
| UNIT-1 | AC-U1-04 空输入 | 前端表单 required 属性 |
| UNIT-1 | AC-U1-05 SQL 注入 | 参数化查询 `?` 占位符 |
| UNIT-2 | AC-U2-01 列表展示 | GET /api/reports → data[] + JOIN users.display_name |
| UNIT-2 | AC-U2-02 翻页 | pagination 对象 + page 参数 |
| UNIT-2 | AC-U2-03 空数据 | data=[] + 前端"暂无周报"判断 |
| UNIT-2 | AC-U2-04 恰好 10 条 | total_pages=1 → 前端隐藏分页控件 |
| UNIT-2 | AC-U2-05 API 失败 | axios 拦截器 catch → 错误提示组件 |
| UNIT-2 | AC-U2-06 页码越界 | SQL OFFSET 超出 → 空 data[] |
| UNIT-3 | AC-U3-01 未登录拦截 | ProtectedRoute 检查 localStorage token |
| UNIT-3 | AC-U3-02 已登录访问 | ProtectedRoute 放行 |
| UNIT-3 | AC-U3-03 token 过期 | JWT exp claim 解码比对 + axios 401 拦截器 |
| UNIT-3 | AC-U3-04 已登录访问登录页 | LoginPage useEffect 检查 token → navigate('/') |
| UNIT-3 | AC-U3-05 非法 token | JWT 解码 try/catch → 清除 + 跳转 |
| 全局 | GAC-001 密码哈希 | bcrypt via passlib, cost=12 |
| 全局 | GAC-002 性能 | SQLite 索引 + 分页 |
| 全局 | GAC-003 JWT payload | {user_id, role, exp, iat} |

## 已排查并排除的潜在问题

| 编号 | 潜在问题 | 排查过程 | 排除证据 |
|------|---------|---------|---------|
| EP-001 | React 开发模式双渲染导致 API 重复调用 | StrictMode 在 dev 环境会双渲染 | 不影响功能正确性，仅开发环境，且 GET 请求幂等 |
| EP-002 | SQLite datetime 默认值时区问题 | datetime('now') 返回 UTC | 统一使用 UTC 存储，前端格式化时转本地时区 |

## 审查结论

- 架构: WARN (2 必修+5 建议) | 产品: WARN (4) | 测试: WARN (1H+3M)
- 无 FAIL 项，全部 WARN 已处理
- 已修复：
  - 种子数据改为 12 条 published（修复分页验证矛盾）
  - created_at 明确 API 层转换为 ISO 8601 格式
  - WHERE status='published' 显式写入接口规范
  - 区分两种空状态（total=0 vs 页码越界）
  - CORS 具体配置值补充
  - .env 变量清单完善
  - 验证方案补充 draft 隔离/JWT payload/无 Auth 请求/倒序验证
  - 种子数据补充测试辅助数据（过期 token、非法 token）
  - page 非法值处理明确（FastAPI 422）
- 承接到下游：
  - 前端表单校验实现方式（React 状态校验 vs HTML required）→ /tech-lead 任务拆分时明确
  - ESLint 规则禁止 dangerouslySetInnerHTML → /tech-lead 开发规范
- 详见: design-cross-review.md

## 交付确认

- 确认状态: 确认
- 确认时间: 2026-04-06 14:00
- 确认备注: S9 三视角审查通过，高优先级问题已修复

## 交接项

- 关键决策: 5 个 ADR（JWT 存储/API 契约/Schema/路由守卫/密码哈希）
- 待计划约束: 3 个（schema 前置/CORS/JWT secret）
- AC 覆盖: 16 AC + 3 GAC 全覆盖
- 模块: 前端 3 页面组件 + 后端 2 API 端点 + 1 auth middleware + 1 DB 层
