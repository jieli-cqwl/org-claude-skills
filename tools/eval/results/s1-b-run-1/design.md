# Design: 团队内部技术周报平台 — Phase 1

功能名: weekly-report | Phase: 1 | 产出时间: 2026-04-06

## 输入分析

- PRD: `docs/weekly-report/prd.md`（已锁定，交付确认状态=确认）
- UNIT: 3 个（UNIT-1 用户账密登录, UNIT-2 首页周报列表展示, UNIT-3 登录态路由守卫）
- 待设计决策: 5 个（DD-001 ~ DD-005）
- 前置约束: CON-001 ~ CON-004
- 非功能需求: GAC-001 ~ GAC-003

## 上游审查承接

> 来源: product-cross-review.md

| Issue ID | 视角 | 发现摘要 | 承接方式 | 承接位置 |
|----------|------|---------|---------|---------|
| AR-002 | 架构 | UNIT-3 路由守卫仅前端检查，后端 API 校验边界未识别 | 采纳 | D-002 API 契约 + D-004 路由守卫方案 |
| AR-003 | 架构 | UNIT-2 对 DB schema 存在隐含依赖（联表查询 display_name） | 采纳 | D-003 数据库 schema |
| AR-005 | 架构 | 密码哈希库跨平台编译依赖风险 | 采纳 | D-005 密码哈希选型 |
| TR-003 | 测试 | token 过期判断逻辑存在实现歧义 | 采纳 | D-004 路由守卫方案 |
| TR-004 | 测试 | display_name 无 NOT NULL 约束 | 采纳 | D-003 数据库 schema |
| PR-007 | 产品 | 并发登录/重复提交行为未定义 | 采纳 | 接口边界（登录接口前端防重提交） |

## PRD 技术理解校正

| PRD 描述 | 技术解读 | 需注意 |
|----------|---------|-------|
| 账号由管理员预置 | 种子数据脚本初始化，本轮无注册 API | 种子密码需 bcrypt 预哈希 |
| JWT token 有效期 24h | exp claim 设置为 `now + 24h`，前端通过解码 exp 判断过期 | 前端判断仅作 UX 优化，后端必须独立校验 |
| 不引入 ORM，直接用 SQLite | 所有 SQL 手写，必须参数化查询 | 需要统一的 DB 连接管理（connection per request） |
| 前后端分离但同一仓库 | monorepo 结构：`backend/` + `frontend/` | CORS 必须配置 |
| status=published 的周报 | SQL WHERE 条件硬编码 `status = 'published'` | draft 状态在本轮不可通过任何 API 访问 |

## 现状事实

- 全新项目，无已有代码、依赖或集成点
- 无 constitution.md（标记为首次创建）
- 技术栈锁定：Python 3.x + FastAPI（后端），React + TypeScript + Tailwind CSS（前端），SQLite（数据库）
- 部署模式：内网单体，10-50 人规模

## 架构师审视维度

### 外部依赖识别

| 依赖项 | 类型 | 控制范围 | 风险 |
|--------|------|---------|------|
| Python 运行时 | 环境前提 | 部署环境 | 低：内网服务器可控 |
| Node.js 运行时 | 环境前提 | 开发/构建环境 | 低：仅构建时需要 |
| SQLite | 数据存储 | 完全自控 | 低：嵌入式数据库，无外部服务依赖 |
| bcrypt 库 | 密码哈希 | pip 安装 | 中：需要 C 编译环境（AR-005 承接） |

无第三方 API 调用、无外部认证服务、无跨区域合规要求。

### 部署拓扑

```
[浏览器] --HTTP--> [FastAPI 后端 :8000] --SQLite--> [weekly_report.db]
                        |
                   [React 静态文件]
```

- 单体部署：FastAPI 进程同时托管 API 和前端静态文件（生产模式）
- 开发模式：Vite dev server (:5173) + FastAPI (:8000)，需 CORS
- 网络边界：仅内网可访问，无公网暴露
- 无 CDN、无负载均衡、无反向代理（10-50 人规模不需要）

### 故障模式

| 故障场景 | 影响范围 | 用户可见行为 | 缓解措施 |
|---------|---------|------------|---------|
| SQLite 文件被锁（写操作冲突） | 本轮不受影响（登录只读） | 无影响 | 本轮无写操作 |
| JWT 签名密钥泄露 | 全部用户 session 被伪造 | 攻击者可冒充任意用户 | 密钥从环境变量读取，不硬编码 |
| FastAPI 进程崩溃 | 全部用户 | 页面无法加载 | 单进程部署的固有风险，内网可接受 |
| SQLite 文件损坏 | 全部数据 | 所有 API 返回 500 | 定期备份（本轮不实现，记录为演进项） |

### 质量属性优先级

**安全性 > 正确性 > 可用性 > 性能**

- 安全性最高：内部周报含技术细节，未授权访问不可接受
- 性能要求低：10-50 人 + SQLite 10 条数据，GAC-002 阈值（500ms API / 1000ms 端到端）极易达到

## 设计场景判断

全新 greenfield 项目，前后端分离的简单 CRUD（本轮只有 Read）应用。无遗留系统迁移、无服务拆分、无复杂架构模式需求。设计重点在：安全模型（认证链路）、API 契约、数据库 schema。

## 关键决策记录

| 编号 | 决策点 | 决策 | 核心理由 | 方案对比 |
|------|--------|------|----------|---------|
| D-001 | JWT 存储方案 | httpOnly cookie | XSS 防护更强，内网场景 CSRF 风险可控 | 见下方 DD-001 方案对比 |
| D-002 | 前后端 API 契约 | RESTful JSON | 简单直接，团队熟悉度高，工具链成熟 | 见下方 DD-002 方案对比 |
| D-003 | 数据库 schema | 按 PRD 业务对象建表 | 1:1 映射业务概念，无过度设计 | 见下方 DD-003 方案对比 |
| D-004 | 前端路由守卫 | React Router loader | 路由级拦截，关注点分离，支持数据预加载 | 见下方 DD-004 方案对比 |
| D-005 | 密码哈希算法 | bcrypt | 成熟稳定，Python 生态支持好，跨平台编译风险可控 | 见下方 DD-005 方案对比 |

### DD-001: JWT 存储方案

| 维度 | 方案 A: httpOnly cookie | 方案 B: localStorage |
|------|------------------------|---------------------|
| XSS 防护 | JS 无法读取 cookie，天然免疫 | JS 可直接读取，XSS 即泄露 |
| CSRF 风险 | cookie 自动附带，需 CSRF 防护 | 不自动附带，天然免疫 CSRF |
| 实现复杂度 | 中（需配置 SameSite + CORS credentials） | 低（前端手动管理 header） |
| 前端读取 token | 无法直接读取（需额外接口获取用户信息） | 可解码获取用户信息 |
| 内网场景适配 | SameSite=Lax 足够防 CSRF | XSS 风险在内网同样存在 |

**决策：方案 A — httpOnly cookie**

理由：XSS 是 Web 应用最常见的攻击向量，httpOnly cookie 从根本上阻断 token 被 JS 窃取。内网场景下 CSRF 风险可通过 SameSite=Lax 属性有效缓解（同站请求不受限，跨站 POST 被阻止）。前端无法直接读取 token 的问题通过 `/api/me` 接口解决。

**迁移/验证/回滚：**
- 迁移：无（全新项目）
- 验证：登录后检查浏览器 DevTools → Application → Cookies，确认 httpOnly 和 SameSite 属性
- 回滚：如 cookie 方案在特殊内网环境（如跨子域）出现问题，可切换到 localStorage，改动集中在登录响应处理和请求拦截器

### DD-002: 前后端 API 契约

| 维度 | 方案 A: RESTful JSON | 方案 B: GraphQL |
|------|---------------------|----------------|
| 学习成本 | 低（团队普遍掌握） | 高（需学习 schema/resolver） |
| 本轮 API 数量 | 3 个端点足够 | 过度设计 |
| 工具链 | FastAPI 原生支持 | 需引入 Strawberry/Ariadne |
| 类型安全 | FastAPI Pydantic 模型 | GraphQL schema 类型系统 |
| 适用规模 | 小型 CRUD 完美匹配 | 复杂查询/多实体关联时价值高 |

**决策：方案 A — RESTful JSON**

理由：本轮仅 3 个 API 端点（登录、周报列表、当前用户），RESTful 简单直接，FastAPI 原生支持 Pydantic 模型验证和 OpenAPI 文档自动生成。GraphQL 在本规模下引入不必要的复杂度。

**API 端点定义：**

#### POST /api/auth/login

用途：用户账密登录

请求：
```json
{
  "username": "string (required, non-empty)",
  "password": "string (required, non-empty)"
}
```

成功响应 (200)：
```json
{
  "user": {
    "id": "integer",
    "username": "string",
    "display_name": "string",
    "role": "author | reader"
  }
}
```
- Set-Cookie: `access_token={jwt}; HttpOnly; SameSite=Lax; Path=/; Max-Age=86400`

失败响应 (401)：
```json
{
  "detail": "用户名或密码错误"
}
```

错误码：
| HTTP Status | 含义 | 触发条件 |
|-------------|------|---------|
| 200 | 登录成功 | 凭据验证通过 |
| 401 | 认证失败 | 用户名不存在或密码错误 |
| 422 | 请求格式错误 | 缺少必填字段或类型错误 |

#### GET /api/reports

用途：获取已发布周报列表（分页）

请求参数（Query）：
- `page`: integer, 默认 1, 最小 1
- `page_size`: integer, 固定 10（本轮不开放自定义）

认证：需要有效的 access_token cookie

成功响应 (200)：
```json
{
  "items": [
    {
      "id": "integer",
      "title": "string",
      "author_name": "string (display_name)",
      "created_at": "string (ISO 8601)"
    }
  ],
  "total": "integer",
  "page": "integer",
  "page_size": "integer"
}
```

失败响应：
| HTTP Status | 含义 | 触发条件 |
|-------------|------|---------|
| 200 | 查询成功 | 正常（含空列表） |
| 401 | 未认证 | 无 token 或 token 无效/过期 |
| 500 | 服务器错误 | 数据库查询异常 |

#### GET /api/auth/me

用途：获取当前登录用户信息（前端无法读取 httpOnly cookie，通过此接口获取用户信息和验证登录态）

认证：需要有效的 access_token cookie

成功响应 (200)：
```json
{
  "id": "integer",
  "username": "string",
  "display_name": "string",
  "role": "author | reader"
}
```

失败响应：
| HTTP Status | 含义 | 触发条件 |
|-------------|------|---------|
| 200 | 查询成功 | token 有效 |
| 401 | 未认证 | 无 token 或 token 无效/过期 |

#### 后端认证中间件

所有 `/api/` 路径（除 `/api/auth/login`）必须经过 JWT 验证中间件：
1. 从 cookie 中提取 `access_token`
2. 验证 JWT 签名和 exp claim
3. 无效/过期 → 返回 401 + 清除 cookie
4. 有效 → 将 user_id 和 role 注入请求上下文

这解决了 AR-002 指出的"后端 API 校验边界未识别"问题——后端独立验证 token，不依赖前端路由守卫。

**迁移/验证/回滚：**
- 迁移：无（全新项目）
- 验证：FastAPI 自动生成 OpenAPI 文档（/docs），可直接在 Swagger UI 中测试
- 回滚：API 契约变更只需修改 Pydantic 模型和对应前端调用

### DD-003: 数据库 Schema

| 维度 | 方案 A: 按 PRD 业务对象建表 | 方案 B: 宽表（用户+周报合一） |
|------|--------------------------|--------------------------|
| 规范化 | 2NF/3NF，干净分离 | 反规范化，冗余字段 |
| 查询复杂度 | 需 JOIN（但 SQLite JOIN 性能好） | 单表查询，无 JOIN |
| 扩展性 | 自然支持后续 CRUD 和新实体 | 改结构代价高 |
| 数据一致性 | 外键约束保证 | 需手动维护一致性 |

**决策：方案 A — 按 PRD 业务对象建表**

理由：users + weekly_reports 两表结构清晰，JOIN 查询在 SQLite + 10 条数据规模下性能无忧。为后续 CRUD 功能预留自然扩展路径。

**Schema 定义：**

```sql
-- 用户表
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL CHECK (role IN ('author', 'reader')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX idx_users_username ON users(username);

-- 周报表
CREATE TABLE weekly_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    author_id INTEGER NOT NULL REFERENCES users(id),
    status TEXT NOT NULL CHECK (status IN ('draft', 'published')) DEFAULT 'draft',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_reports_status_created ON weekly_reports(status, created_at DESC);
CREATE INDEX idx_reports_author ON weekly_reports(author_id);
```

设计要点：
- `display_name TEXT NOT NULL DEFAULT ''`：解决 TR-004（NOT NULL 约束），默认空字符串作为降级值，前端展示时空字符串可 fallback 到 username
- `idx_reports_status_created`：覆盖首页核心查询 `WHERE status='published' ORDER BY created_at DESC`
- `idx_users_username`：覆盖登录查询 `WHERE username=?`
- 所有时间字段使用 ISO 8601 TEXT 格式（SQLite 无原生 datetime 类型）
- `REFERENCES users(id)`：外键约束，需启用 `PRAGMA foreign_keys = ON`

**种子数据初始化方式：**
- Python 脚本 `backend/seed.py`，执行 `CREATE TABLE IF NOT EXISTS` + `INSERT OR IGNORE`
- 3 个用户（密码预 bcrypt 哈希）+ 10 条已发布周报
- 幂等执行（重复运行不报错、不重复插入）

**迁移/验证/回滚：**
- 迁移：无（全新项目，建表即初始化）
- 验证：`sqlite3 weekly_report.db ".schema"` 检查表结构，`SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM weekly_reports WHERE status='published';` 检查种子数据
- 回滚：删除 `.db` 文件重新初始化（开发阶段）

### DD-004: 前端路由守卫实现方案

| 维度 | 方案 A: React Router loader | 方案 B: 高阶组件 (HOC) ProtectedRoute | 方案 C: useEffect 内检查 |
|------|---------------------------|--------------------------------------|------------------------|
| 执行时机 | 路由匹配前，在 loader 中执行 | 组件渲染时 | 组件挂载后 |
| 闪烁问题 | 无（loader 阻塞渲染直到完成） | 可能短暂闪烁 | 必定闪烁 |
| 数据预加载 | loader 可同时获取页面数据 | 需额外处理 | 需额外处理 |
| 代码组织 | 路由配置集中 | 组件级分散 | 最分散 |
| React Router 版本要求 | v6.4+ (data router) | v5+ | 任意版本 |

**决策：方案 A — React Router loader**

理由：loader 在路由匹配阶段执行，天然避免未认证用户看到受保护页面的闪烁问题。可以在 loader 中调用 `/api/auth/me` 同时验证登录态和获取用户信息，一石二鸟。

**实现方案：**

路由守卫流程（解决 TR-003 token 过期判断歧义）：

```
用户访问任意路由
  → React Router 触发对应 loader
  → loader 调用 GET /api/auth/me（cookie 自动附带）
  → 后端验证 JWT（签名 + exp claim）
    → 401 → loader 返回 redirect('/login')
    → 200 → loader 返回用户数据，组件正常渲染
```

关键设计：
- **token 过期判断统一由后端负责**（解决 TR-003）：前端不解码 JWT 判断 exp，而是通过 `/api/auth/me` 接口让后端验证。这保证了过期判断的权威性。
- **登录页守卫**：`/login` 路由的 loader 也调用 `/api/auth/me`，200 则 redirect('/')，401 则正常渲染登录页
- **401 响应处理**：后端返回 401 时同时清除 access_token cookie（Set-Cookie: access_token=; Max-Age=0），前端不需要手动清除

注意：UNIT-3 的 AC 描述中提到"检查 localStorage 中 JWT token"，但由于 D-001 决策选择了 httpOnly cookie，token 不在 localStorage 中。前端路由守卫通过调用 `/api/auth/me` 接口间接验证 token 存在性和有效性，功能等价地满足所有 AC。

**迁移/验证/回滚：**
- 迁移：无（全新项目）
- 验证：浏览器无 cookie 时访问 `/` → 自动跳转 `/login`；有效 cookie 访问 `/login` → 跳转 `/`
- 回滚：如 React Router v6.4 data router 有兼容问题，回退到方案 B（HOC），改动集中在路由配置文件

### DD-005: 密码哈希算法选型

| 维度 | 方案 A: bcrypt | 方案 B: argon2 |
|------|---------------|---------------|
| 成熟度 | 1999 年发布，久经考验 | 2015 年 Password Hashing Competition 冠军 |
| Python 库 | `bcrypt`（pip install bcrypt） | `argon2-cffi`（pip install argon2-cffi） |
| 编译依赖 | 需要 C 编译器（cffi） | 需要 C 编译器（cffi） |
| 跨平台安装 | 预编译 wheel 覆盖 Linux/macOS/Windows | 预编译 wheel 覆盖面略窄 |
| 安全强度 | 高（GPU 抗性好） | 更高（内存硬函数，抗 GPU/ASIC） |
| 配置复杂度 | 单参数 rounds（默认 12） | 三参数 time_cost/memory_cost/parallelism |
| 内网场景适配 | 足够（10-50 人，无高价值目标） | 过度（参数调优收益小） |

**决策：方案 A — bcrypt**

理由：内网 10-50 人场景，bcrypt 安全强度完全充足。预编译 wheel 覆盖主流平台（解决 AR-005 跨平台编译风险），单参数配置简单。argon2 虽然理论更强，但在本场景下额外安全收益不显著，配置复杂度更高。

**参数配置：**
- rounds = 12（bcrypt 默认值，约 250ms/次哈希，10-50 人场景下不构成性能瓶颈）

**迁移/验证/回滚：**
- 迁移：无（全新项目）
- 验证：种子数据中密码使用 bcrypt 哈希，登录时验证通过即可
- 回滚：如遇编译问题，可切换到 argon2-cffi（接口兼容，只需替换 hash/verify 函数调用）

## 既有约束继承确认

| 来源 | 既有结论 | 本轮处理 | 用户确认记录 | 对设计的影响 |
|------|----------|---------|------------|-----------|
| 无 constitution.md | 无历史约束 | 首次创建 | S3 共创确认 | 本轮决策将成为初始 Constitution |

## 共创摘要

| 阶段 | 关键提问 | 用户回应 | 对设计的影响 |
|------|---------|---------|------------|
| S3 问题拆解 | PRD 锁定的技术栈和部署模式是否有额外约束？规模和部署形态？ | PRD 已锁定 Python+FastAPI+React+TypeScript+Tailwind+SQLite，10-50 人内网，单体部署。5 个 DD 需展开 | 确认技术画像：greenfield 单体应用，设计重心在认证安全模型和 API 契约 |
| S4 决策点识别 | PRD 中 5 个 DD（JWT 存储、API 契约、DB schema、路由守卫、密码哈希）是否完整？是否有遗漏？ | 确认，按 PRD 的 5 个 DD 展开 | 锁定 5 个决策点，无新增 |
| S5 方案探索 | 逐项 DD 方案对比和推荐 | DD-001 选 httpOnly cookie；DD-002 选 RESTful JSON；DD-003 按 PRD 业务对象；DD-004 选 React Router loader；DD-005 选 bcrypt | 5 个决策全部收口，可进入边界定义 |
| S6 边界接口 | 架构边界、接口定义、数据边界是否完整？ | 确认，继续 | 边界定义锁定 |
| S7 质量闭环 | 迁移策略、验证方案、回滚方案、风险清单是否充分？ | 确认，继续 | 质量闭环完成 |
| S8 实施约束 | 待计划约束和影响范围是否完整？ | 确认，继续 | 约束收口，可进入输出 |

## 架构边界

### 整体架构

```
┌─────────────────────────────────────────────┐
│                   Browser                    │
│  ┌─────────────────────────────────────────┐│
│  │   React App (TypeScript + Tailwind)     ││
│  │  ┌──────────┐  ┌──────────────────────┐ ││
│  │  │LoginPage │  │   HomePage           │ ││
│  │  │          │  │  (ReportList + Pager) │ ││
│  │  └──────────┘  └──────────────────────┘ ││
│  │  ┌──────────────────────────────────────┐││
│  │  │  React Router (loader-based guard)  │ ││
│  │  └──────────────────────────────────────┘││
│  └─────────────────────────────────────────┘│
└───────────────────────┬─────────────────────┘
                        │ HTTP (cookie-based auth)
┌───────────────────────┴─────────────────────┐
│              FastAPI Backend                  │
│  ┌──────────────┐  ┌──────────────────────┐ │
│  │ Auth Module   │  │  Reports Module      │ │
│  │ POST /login   │  │  GET /reports        │ │
│  │ GET /me       │  │                      │ │
│  └──────────────┘  └──────────────────────┘ │
│  ┌──────────────────────────────────────────┐│
│  │  JWT Middleware (cookie extraction)       ││
│  └──────────────────────────────────────────┘│
│  ┌──────────────────────────────────────────┐│
│  │  DB Layer (raw SQL, parameterized)        ││
│  └──────────────────────────────────────────┘│
└───────────────────────┬─────────────────────┘
                        │
┌───────────────────────┴─────────────────────┐
│           SQLite (weekly_report.db)           │
│  ┌──────────┐  ┌──────────────────────────┐ │
│  │  users    │  │  weekly_reports          │ │
│  └──────────┘  └──────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### 模块职责

| 模块 | 职责 | 边界 |
|------|------|------|
| Auth Module | 登录验证、JWT 签发、当前用户查询 | 只负责认证，不含授权逻辑 |
| Reports Module | 周报列表查询（分页、排序） | 只读，本轮不含写操作 |
| JWT Middleware | 从 cookie 提取 token、验证签名和过期、注入用户上下文 | 不含业务逻辑 |
| DB Layer | SQLite 连接管理、参数化 SQL 执行 | 每个请求独立连接，请求结束关闭 |
| React Router Guard | 路由级认证检查（通过 /api/auth/me） | 仅前端 UX 层面，不替代后端验证 |

## 接口边界

### 前后端接口

详见 DD-002 方案对比中的 API 端点定义。

汇总：
| 端点 | 方法 | 认证 | 用途 |
|------|------|------|------|
| `/api/auth/login` | POST | 无 | 登录 |
| `/api/auth/me` | GET | cookie | 获取当前用户 + 验证登录态 |
| `/api/reports` | GET | cookie | 获取已发布周报列表 |

### 前端防重提交（承接 PR-007）

登录按钮点击后立即 disabled，请求完成（成功或失败）后恢复。纯前端 UI 层面控制，不需要后端幂等机制。

### CORS 配置（承接 CON-004）

```python
# 开发模式
allow_origins = ["http://localhost:5173"]  # Vite dev server
allow_credentials = True  # 允许 cookie 跨域
allow_methods = ["GET", "POST"]
allow_headers = ["Content-Type"]
```

生产模式下前端静态文件由 FastAPI 托管，同源，无需 CORS。

## 数据边界

### 数据流

```
登录流：
  前端 LoginForm → POST /api/auth/login (username, password)
    → 后端查询 users WHERE username = ? (参数化)
    → bcrypt.verify(password, password_hash)
    → 成功: 签发 JWT, Set-Cookie → 前端跳转 /
    → 失败: 401 → 前端显示错误

首页流：
  前端 loader → GET /api/auth/me (cookie 自动附带)
    → 后端验证 JWT → 200: 用户数据 / 401: redirect /login
  前端 loader → GET /api/reports?page=1 (cookie 自动附带)
    → 后端 SELECT ... FROM weekly_reports wr JOIN users u ON wr.author_id = u.id
       WHERE wr.status = 'published' ORDER BY wr.created_at DESC
       LIMIT 10 OFFSET 0
    → 200: { items, total, page, page_size }
```

### JWT Token 结构

```json
{
  "sub": "user_id (integer)",
  "role": "author | reader",
  "exp": "unix timestamp (now + 24h)",
  "iat": "unix timestamp (now)"
}
```

- 签名算法：HS256
- 密钥来源：环境变量 `JWT_SECRET_KEY`（不硬编码）
- 业务 claim 仅 sub (user_id) 和 role，满足 GAC-003

## 质量属性

| 属性 | 目标 | 验证方式 |
|------|------|---------|
| 安全性 - 密码存储 | bcrypt 哈希，DB 无明文密码（GAC-001） | `SELECT password_hash FROM users` 检查前缀 `$2b$` |
| 安全性 - JWT 内容 | 不含密码等敏感信息（GAC-003） | 解码 token payload 检查 claim 列表 |
| 安全性 - SQL 注入 | 所有 SQL 参数化查询（CON-003） | 输入 SQL 特殊字符验证返回 401 非 500（AC-U1-05） |
| 安全性 - XSS | httpOnly cookie 阻断 token 窃取 | 浏览器 DevTools 检查 cookie httpOnly 标志 |
| 性能 - API 响应 | GET /api/reports < 500ms（GAC-002） | Chrome DevTools Network 面板 |
| 性能 - 端到端 | 请求到渲染 < 1000ms（GAC-002） | Chrome DevTools Performance 面板 |

## 迁移策略

全新项目，无迁移需求。

初始化流程：
1. 创建项目目录结构（`backend/` + `frontend/`）
2. 后端：`pip install fastapi uvicorn python-jose[cryptography] bcrypt`
3. 前端：`npm create vite@latest -- --template react-ts` + `npm install react-router-dom`
4. 执行 `backend/seed.py` 初始化数据库和种子数据
5. 配置环境变量 `JWT_SECRET_KEY`

## 验证与可观测性

| 验证项 | 方式 | 预期结果 |
|--------|------|---------|
| 登录成功 | POST /api/auth/login 正确凭据 | 200 + Set-Cookie: access_token |
| 登录失败 | POST /api/auth/login 错误密码 | 401 + "用户名或密码错误" |
| 路由守卫-未登录 | 无 cookie 访问 / | 跳转到 /login |
| 路由守卫-已登录 | 有效 cookie 访问 /login | 跳转到 / |
| 路由守卫-过期 | 过期 cookie 访问 / | 跳转到 /login |
| 首页列表 | 有效 cookie GET /api/reports | 200 + 周报列表 JSON |
| 分页 | GET /api/reports?page=2 | 正确偏移量的数据 |
| 空列表 | 所有周报为 draft | 200 + items=[] |
| 性能 | GET /api/reports 响应时间 | < 500ms |
| 密码安全 | 数据库查询 password_hash | `$2b$` 前缀 |
| JWT 安全 | 解码 token payload | 仅 sub, role, exp, iat |

## 回滚方案

全新项目，回滚 = 不部署。

单个决策的回滚路径已在各 DD 方案对比中说明。关键回滚路径：
- D-001 (httpOnly cookie → localStorage)：修改登录响应处理 + 添加 Authorization header 拦截器
- D-004 (loader → HOC)：修改路由配置文件 + 创建 ProtectedRoute 组件
- D-005 (bcrypt → argon2)：替换 hash/verify 调用 + 重新生成种子数据

## 风险与缓解

| 编号 | 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|------|---------|
| RISK-001 | bcrypt 安装需要 C 编译器 | 低 | 中 | 主流平台有预编译 wheel；Alpine Linux 需安装 gcc |
| RISK-002 | React Router v6.4 data router API 学习曲线 | 中 | 低 | API 文档完善，loader 模式简单直接 |
| RISK-003 | SQLite 文件权限问题（不同 OS） | 低 | 低 | 种子脚本自动创建文件，部署文档说明权限 |
| RISK-004 | JWT_SECRET_KEY 未配置导致启动失败 | 中 | 中 | 启动时校验环境变量，缺失则报错退出（fail fast） |

## 影响范围清单

> 全新项目，无已有系统受影响。以下列出新建模块间的关键依赖关系。

| scope_item_id | 变更类型 | 旧边界 | 新边界 | 风险等级 | 证据 | owner |
|---------------|----------|--------|--------|----------|------|-------|
| SCOPE-P1U1-001 | 新建 | 无 | POST /api/auth/login + GET /api/auth/me | P1 | PRD UNIT-1 | 后端开发 |
| SCOPE-P1U2-001 | 新建 | 无 | GET /api/reports + 首页组件 | P1 | PRD UNIT-2 | 全栈 |
| SCOPE-P1U3-001 | 新建 | 无 | React Router loader 守卫 | P1 | PRD UNIT-3 | 前端开发 |
| SCOPE-P1U1-002 | 新建 | 无 | users + weekly_reports 表 + 种子数据 | P1 | DD-003 | 后端开发 |

## 待计划约束

| 编号 | 约束或风险点 | 对计划拆分的影响 | 必须前置验证的事项 | 不可并行项或关键依赖 |
|------|-------------|------------------|-------------------|----------------------|
| PC-001 | DB schema 必须先于所有业务接口 | 种子脚本是第一个交付物 | SQLite 建表 + 种子数据可正常执行 | UNIT-2, UNIT-3 依赖 UNIT-1 的 JWT 签发 |
| PC-002 | JWT_SECRET_KEY 环境变量 | 后端启动前必须配置 | 环境变量读取 + fail fast | 所有 API 依赖此配置 |
| PC-003 | CORS 开发模式配置 | 前后端联调前必须配置 | 跨域请求 cookie 正常携带 | 前端开发依赖后端 CORS 配置 |
| PC-004 | httpOnly cookie 影响前端获取用户信息的方式 | 前端不能直接读 token，必须通过 /api/auth/me | /api/auth/me 接口优先实现 | 路由守卫实现依赖 /api/auth/me |
| PC-005 | React Router v6.4+ data router API | 前端路由架构依赖此版本特性 | 确认 react-router-dom 版本 >= 6.4 | 路由守卫方案依赖 loader API |

## 覆盖表

| UNIT | AC | 设计覆盖位置 | 覆盖说明 |
|------|-----|------------|---------|
| UNIT-1 | AC-U1-01 | D-001 (httpOnly cookie) + DD-002 (POST /api/auth/login) | 登录成功 → Set-Cookie + 跳转首页 |
| UNIT-1 | AC-U1-02 | DD-002 (登录接口 401 响应) | 错误密码 → 401 + "用户名或密码错误" |
| UNIT-1 | AC-U1-03 | DD-002 (登录接口 401 响应) | 不存在用户 → 401 + 同一错误提示 |
| UNIT-1 | AC-U1-04 | 接口边界（前端表单校验） | 前端空值校验阻断请求 |
| UNIT-1 | AC-U1-05 | DD-003 (参数化查询) + DD-002 (422/401 而非 500) | SQL 特殊字符正常处理 |
| UNIT-2 | AC-U2-01 | DD-002 (GET /api/reports) + DD-003 (JOIN 查询) | 列表展示 title, display_name, created_at |
| UNIT-2 | AC-U2-02 | DD-002 (分页参数 page/page_size) | total > 10 时分页控件可用 |
| UNIT-2 | AC-U2-03 | DD-002 (空 items 数组) | 无数据 → items=[], 前端显示"暂无周报" |
| UNIT-2 | AC-U2-04 | DD-002 (分页逻辑) | 恰好 10 条 → total=10, 1 页 |
| UNIT-2 | AC-U2-05 | DD-002 (500 响应) | API 失败 → 前端显示"加载失败，请刷新重试" |
| UNIT-2 | AC-U2-06 | DD-002 (页码越界) | 超出范围 → 返回空 items |
| UNIT-3 | AC-U3-01 | D-004 (loader 调用 /api/auth/me) | 无 cookie → /api/auth/me 401 → redirect /login |
| UNIT-3 | AC-U3-02 | D-004 (loader 成功路径) | 有效 cookie → /api/auth/me 200 → 正常渲染 |
| UNIT-3 | AC-U3-03 | D-004 (后端 exp 校验) + DD-002 (401 + 清除 cookie) | 过期 token → 后端 401 + 清除 cookie → redirect /login |
| UNIT-3 | AC-U3-04 | D-004 (/login loader) | 有效 cookie → /api/auth/me 200 → redirect / |
| UNIT-3 | AC-U3-05 | D-004 (后端签名校验) + DD-002 (401 + 清除 cookie) | 非法 token → 后端验证失败 401 → redirect /login |

## 已排查并排除的潜在问题

| 编号 | 潜在问题 | 排查过程 | 排除证据 |
|------|---------|---------|---------|
| EP-001 | httpOnly cookie 在跨子域场景失效 | 内网部署为单域名/IP 直接访问 | 无跨子域需求，SameSite=Lax 足够 |
| EP-002 | SQLite 并发写入导致锁超时 | 本轮所有 API 均为读操作 | 登录=读 users 表验证，首页=读 reports 表查询 |
| EP-003 | React Router loader 阻塞渲染导致白屏 | /api/auth/me 预期 < 50ms（本地 SQLite + JWT 解码） | 内网 + 本地数据库，延迟可忽略 |
| EP-004 | bcrypt 哈希时间过长影响登录体验 | rounds=12 约 250ms/次 | 单次登录可接受，无批量场景 |

## 审查结论

> 注：本次执行跳过跨职能评审步骤（S9），审查将在单独场景测试中进行。

- 架构: PENDING | 产品: PENDING | 测试: PENDING
- 状态: 待跨职能评审
- 详见: 待生成 design-cross-review.md

## 交付确认

- 确认状态: 确认
- 确认时间: 2026-04-06
- 确认备注: S3-S8 共创完成，5 个 DD 全部收口。跳过 S9 跨职能评审（评审在单独场景测试）。用户 S10 最终确认通过。

## 交接项

- 决策数量: 5（D-001 ~ D-005 全部收口）
- API 端点: 3（POST /api/auth/login, GET /api/auth/me, GET /api/reports）
- 数据表: 2（users, weekly_reports）
- 待计划约束: 5（PC-001 ~ PC-005）
- 影响范围项: 4（SCOPE-P1U1-001/002, SCOPE-P1U2-001, SCOPE-P1U3-001）
- 上游红旗承接: 6 项（AR-002, AR-003, AR-005, TR-003, TR-004, PR-007）
- Constitution: 需首次创建（本轮 5 个决策作为初始 Constitution 内容）
