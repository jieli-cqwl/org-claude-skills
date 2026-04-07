# Design: 团队内部技术周报平台

功能名: weekly-report | 设计时间: 2026-04-06 | PRD 来源: docs/weekly-report/prd.md

## 架构师审视维度

| 维度 | 评估结论 |
|------|---------|
| 外部依赖 | 无第三方服务依赖。SQLite 文件数据库（无需独立数据库服务）。bcrypt 需要 C 编译环境（libffi/gcc），跨平台安装可能遇到编译问题（PRD 审查 WARN 已标记）。PyJWT 纯 Python，无编译依赖。 |
| 部署拓扑 | 单体部署。FastAPI 后端提供 API + 静态文件托管。React SPA 构建后由 FastAPI 的 StaticFiles 中间件分发。开发阶段前后端分离运行，需 CORS 配置（CON-004）。 |
| 故障模式 | **SQLite 文件损坏**：单点故障，建议定期备份（本轮不实现自动备份）。**JWT 密钥泄露**：所有已签发 token 可被伪造，密钥必须从环境变量读取且足够复杂。**bcrypt 编译失败**：部署环境缺少编译工具链时安装失败，需文档说明前置依赖。 |
| 质量属性优先级 | **安全性 > 可用性 > 性能**。内网 10-50 人规模，性能不是瓶颈。安全性优先保障认证边界完整性。可用性保障登录和浏览的基本流畅体验。 |

## 架构总览

```
┌─────────────────────────────────────┐
│           React SPA (前端)           │
│  ┌──────────┐ ┌──────────────────┐  │
│  │ LoginPage│ │ HomePage (列表)   │  │
│  └──────────┘ └──────────────────┘  │
│  ┌──────────────────────────────┐   │
│  │ AuthGuard (路由守卫)          │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ API Client (fetch + cookie)  │   │
│  └──────────────────────────────┘   │
└──────────────┬──────────────────────┘
               │ HTTP (JSON)
               │ Cookie: token=<JWT>
┌──────────────▼──────────────────────┐
│         FastAPI 后端                 │
│  ┌──────────────────────────────┐   │
│  │ Auth Router (/api/auth/*)    │   │
│  │  POST /login                 │   │
│  │  POST /logout                │   │
│  │  GET  /me                    │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ Report Router (/api/reports) │   │
│  │  GET /reports                │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ Auth Middleware (JWT 校验)    │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │ DB Layer (SQLite + raw SQL)  │   │
│  └──────────────────────────────┘   │
└──────────────┬──────────────────────┘
               │
     ┌─────────▼─────────┐
     │  SQLite 文件数据库  │
     │  weekly_report.db  │
     └───────────────────┘
```

## 目录结构

```
weekly-report/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI 应用入口，挂载路由和中间件
│   │   ├── config.py            # 配置管理（环境变量读取）
│   │   ├── database.py          # SQLite 连接管理、初始化、迁移
│   │   ├── auth/
│   │   │   ├── __init__.py
│   │   │   ├── router.py        # 认证路由（login/logout/me）
│   │   │   ├── service.py       # 认证业务逻辑（密码验证、JWT签发）
│   │   │   └── dependencies.py  # FastAPI 依赖项（get_current_user）
│   │   ├── reports/
│   │   │   ├── __init__.py
│   │   │   ├── router.py        # 周报路由（列表查询）
│   │   │   └── service.py       # 周报业务逻辑（分页查询）
│   │   └── models.py            # Pydantic 数据模型（请求/响应 schema）
│   ├── seed.py                  # 种子数据脚本
│   ├── requirements.txt
│   └── tests/
│       └── ...
├── frontend/
│   ├── src/
│   │   ├── main.tsx             # React 入口
│   │   ├── App.tsx              # 路由配置
│   │   ├── api/
│   │   │   └── client.ts        # API 请求封装
│   │   ├── auth/
│   │   │   ├── AuthGuard.tsx    # 路由守卫组件
│   │   │   ├── LoginPage.tsx    # 登录页
│   │   │   └── useAuth.ts      # 认证状态 hook
│   │   ├── reports/
│   │   │   └── HomePage.tsx     # 首页周报列表
│   │   └── types/
│   │       └── index.ts         # TypeScript 类型定义
│   ├── package.json
│   ├── tsconfig.json
│   ├── tailwind.config.js
│   └── vite.config.ts
└── README.md
```

## 决策记录

### DD-001: JWT 存储方案

**决策：httpOnly cookie**

| 维度 | localStorage | httpOnly cookie |
|------|-------------|----------------|
| XSS 防护 | JS 可读取 token，XSS 即泄露 | JS 无法读取，XSS 无法窃取 token |
| CSRF 防护 | 天然免疫（手动 Header） | 需额外防护（SameSite 属性） |
| 实现复杂度 | 低（前端存取） | 中（后端 Set-Cookie + CORS 配置） |
| 登出实现 | 前端删除即可 | 后端清除 cookie |
| 适用场景 | 跨域多服务 | 同域/受控环境 |

**选择理由**：内网应用安全性优先。httpOnly cookie 从根本上防止 XSS 窃取 token。CSRF 风险通过 `SameSite=Lax` 属性缓解（内网同域部署，Lax 已足够）。

**实现要点**：
- `Set-Cookie: token=<jwt>; HttpOnly; SameSite=Lax; Path=/; Max-Age=86400`
- 生产环境加 `Secure` 标志（HTTPS）
- 登出接口清除 cookie（设置 Max-Age=0）
- 前端不存储 token，通过 `GET /api/auth/me` 判断登录态

**对 UNIT 的影响**：
- UNIT-1：登录成功后后端设置 cookie，前端不处理 token 存储
- UNIT-3：路由守卫通过调用 `/api/auth/me` 判断登录态，不检查本地存储

### DD-002: 前后端 API 契约

**决策：RESTful JSON API**

#### 接口定义

**POST /api/auth/login**

用途：用户登录，验证凭据并签发 JWT。

请求：
```json
{
  "username": "string",
  "password": "string"
}
```

成功响应（200）：
```json
{
  "user": {
    "id": "integer",
    "username": "string",
    "display_name": "string",
    "role": "string"
  }
}
```
附带 `Set-Cookie` 头设置 JWT。

失败响应（401）：
```json
{
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "用户名或密码错误"
  }
}
```

---

**POST /api/auth/logout**

用途：用户登出，清除 JWT cookie。

请求：无请求体。

成功响应（200）：
```json
{
  "message": "已登出"
}
```
附带 `Set-Cookie` 头清除 JWT（Max-Age=0）。

---

**GET /api/auth/me**

用途：获取当前登录用户信息，同时用于前端判断登录态。

请求：无请求体，依赖 cookie 中的 JWT。

成功响应（200）：
```json
{
  "user": {
    "id": "integer",
    "username": "string",
    "display_name": "string",
    "role": "string"
  }
}
```

失败响应（401）：
```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "未登录或登录已过期"
  }
}
```

---

**GET /api/reports?page=1&page_size=10**

用途：获取已发布周报列表（分页、时间倒序）。

请求参数：
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| page | integer | 1 | 页码，最小值 1 |
| page_size | integer | 10 | 每页条数，最小 1 最大 50 |

成功响应（200）：
```json
{
  "items": [
    {
      "id": "integer",
      "title": "string",
      "content": "string",
      "author": {
        "id": "integer",
        "display_name": "string"
      },
      "created_at": "string (ISO 8601)",
      "updated_at": "string (ISO 8601)"
    }
  ],
  "pagination": {
    "page": "integer",
    "page_size": "integer",
    "total": "integer",
    "total_pages": "integer"
  }
}
```

失败响应（401）：同 `/api/auth/me` 的 401 格式。

页码越界（page > total_pages）：返回空列表，不报错。
```json
{
  "items": [],
  "pagination": {
    "page": 5,
    "page_size": 10,
    "total": 10,
    "total_pages": 1
  }
}
```

#### 错误码规范

| HTTP 状态码 | error.code | 含义 | 触发场景 |
|-------------|-----------|------|---------|
| 401 | INVALID_CREDENTIALS | 凭据无效 | 登录失败 |
| 401 | UNAUTHORIZED | 未认证 | 无 token / token 过期 / token 无效 |
| 422 | VALIDATION_ERROR | 参数校验失败 | 缺少必填字段 / 格式错误 |
| 500 | INTERNAL_ERROR | 服务器内部错误 | 未预期的异常 |

#### CORS 配置（CON-004）

```python
# 开发环境
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],  # Vite 默认端口
    allow_credentials=True,  # 允许 cookie
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)
```

生产环境由 FastAPI 静态托管前端，同域无需 CORS。

### DD-003: 数据库 Schema

**决策：按 PRD 业务对象设计**

#### 表结构

```sql
-- 用户表
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('author', 'reader')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 用户名索引（登录查询加速）
CREATE UNIQUE INDEX idx_users_username ON users(username);

-- 周报表
CREATE TABLE reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id INTEGER NOT NULL REFERENCES users(id),
    status TEXT NOT NULL CHECK(status IN ('draft', 'published')) DEFAULT 'draft',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 首页查询索引（status 过滤 + 时间倒序）
CREATE INDEX idx_reports_status_created ON reports(status, created_at DESC);

-- 作者关联索引
CREATE INDEX idx_reports_author_id ON reports(author_id);
```

#### 设计说明

- `display_name` 设为 `NOT NULL`（PRD 审查 WARN 承接项）
- 时间字段使用 TEXT 存储 ISO 8601 格式（SQLite 无原生日期类型，TEXT 是推荐做法）
- `status` 使用 CHECK 约束枚举值，数据库层保障数据一致性
- `author_id` 外键关联 users 表，保障引用完整性
- 索引策略：
  - `idx_users_username`：登录查询 O(log n)
  - `idx_reports_status_created`：首页查询（WHERE status='published' ORDER BY created_at DESC）命中复合索引
  - `idx_reports_author_id`：未来按作者查询预留

#### 种子数据策略

通过 `backend/seed.py` 脚本初始化：
- 3 个用户（2 author + 1 reader），密码使用 bcrypt 哈希
- 10 条已发布周报（分布在不同作者和时间）
- 脚本幂等：检查数据是否已存在，避免重复插入

### DD-004: 前端路由守卫实现

**决策：React Router loader + AuthGuard 组件**

| 维度 | 高阶组件 (HOC) | React Router loader | AuthGuard 包裹组件 |
|------|---------------|---------------------|-------------------|
| 路由配置可读性 | 每个路由单独包裹 | 集中在路由配置 | 路由配置中嵌套 |
| 数据预加载 | 组件挂载后请求 | 路由匹配时预加载 | 组件挂载后请求 |
| 闪屏问题 | 有（先渲染再跳转） | 无（loader 先执行） | 需 loading 状态 |
| React Router 契合度 | 传统模式 | 原生支持 | 中等 |

**选择理由**：React Router v6 的 loader 机制在路由匹配阶段即可执行认证检查，避免未认证用户看到页面闪屏。loader 中调用 `/api/auth/me` 接口，失败则 redirect 到登录页。

**实现方案**：

```
路由配置：
/login    → LoginPage（公开路由）
/         → HomePage（受保护路由，需 authLoader）

authLoader 逻辑：
1. fetch GET /api/auth/me（cookie 自动携带）
2. 成功 → 返回 user 数据，注入页面组件
3. 401  → redirect("/login")

loginLoader 逻辑：
1. fetch GET /api/auth/me
2. 成功 → redirect("/")（已登录跳转首页）
3. 401  → 返回 null（继续显示登录页）
```

**token 过期处理**：
- loader 中 `/api/auth/me` 返回 401 时统一 redirect 到登录页
- 首页停留期间 token 过期 → 下次 API 调用（如翻页）返回 401 → 前端捕获后跳转登录页

### DD-005: 密码哈希算法选型

**决策：bcrypt**

| 维度 | bcrypt | argon2 |
|------|--------|--------|
| 成熟度 | 1999 年，久经考验 | 2015 年 PHC 获胜者 |
| 安全强度 | 高（可调 cost factor） | 更高（抗 GPU/ASIC，内存硬） |
| Python 库 | `bcrypt`（C 扩展） | `argon2-cffi`（C 扩展） |
| 编译依赖 | 需要 libffi + gcc | 需要 libffi + gcc + cmake |
| 安装复杂度 | 低（pip install bcrypt） | 中（额外 cmake 依赖） |
| 社区采用度 | 极广泛 | 增长中 |

**选择理由**：内网 10-50 人规模，bcrypt 安全强度完全满足。argon2 虽理论更强，但额外的 cmake 依赖增加部署风险（PRD 审查 WARN 承接项），且本场景无需抗 GPU 暴力破解。

**参数配置**：
- bcrypt rounds: 12（默认值，约 250ms/次哈希，10-50 人场景性能无忧）
- 使用 `bcrypt.hashpw()` 和 `bcrypt.checkpw()`，自动处理 salt

## UNIT 到模块映射

| UNIT | 后端模块 | 前端模块 | 数据库 |
|------|---------|---------|--------|
| UNIT-1 用户登录 | auth/router.py, auth/service.py, models.py | LoginPage.tsx, api/client.ts | users 表 |
| UNIT-2 周报列表 | reports/router.py, reports/service.py, models.py | HomePage.tsx, api/client.ts | reports 表 + users 表（JOIN） |
| UNIT-3 路由守卫 | auth/dependencies.py（get_current_user） | AuthGuard/loader, useAuth.ts | 无直接访问 |

## 关键实现细节

### 认证流程（UNIT-1 + UNIT-3）

```
登录流程：
1. 用户提交 username + password
2. 前端 POST /api/auth/login
3. 后端查询 users 表（参数化查询，防 SQL 注入）
4. bcrypt.checkpw 验证密码
5. 验证通过 → 签发 JWT（payload: {user_id, role, exp}）
6. Set-Cookie 返回 JWT
7. 前端收到 200 → router.navigate("/")

路由守卫流程：
1. 用户访问受保护路由
2. React Router loader 执行
3. fetch GET /api/auth/me（cookie 自动携带）
4. 后端解析 JWT → 查询用户 → 返回用户信息
5. 成功 → 页面渲染；401 → redirect /login
```

### 分页查询（UNIT-2）

```sql
-- 首页查询（命中 idx_reports_status_created 索引）
SELECT r.id, r.title, r.content, r.created_at, r.updated_at,
       u.id AS author_id, u.display_name AS author_display_name
FROM reports r
JOIN users u ON r.author_id = u.id
WHERE r.status = 'published'
ORDER BY r.created_at DESC
LIMIT ? OFFSET ?;

-- 总数查询（分页计算）
SELECT COUNT(*) FROM reports WHERE status = 'published';
```

### JWT 配置

| 配置项 | 值 | 来源 |
|-------|-----|------|
| SECRET_KEY | 随机生成的 256 位密钥 | 环境变量 `JWT_SECRET_KEY` |
| ALGORITHM | HS256 | 应用配置常量 |
| EXPIRE_HOURS | 24 | 应用配置常量（PRD R2） |

**JWT Payload**：
```json
{
  "user_id": 1,
  "role": "author",
  "exp": 1712448000,
  "iat": 1712361600
}
```
符合 GAC-003：不含密码等敏感信息，业务 claim 仅 user_id 和 role。

### 配置管理

```python
# backend/app/config.py
# 职责：集中管理所有配置项，从环境变量读取

# 必须从环境变量读取（无默认值，缺失则启动失败）
JWT_SECRET_KEY: str       # JWT 签名密钥

# 可配置项（有合理默认值）
DATABASE_URL: str         # SQLite 文件路径，默认 "weekly_report.db"
JWT_ALGORITHM: str        # 默认 "HS256"
JWT_EXPIRE_HOURS: int     # 默认 24
BCRYPT_ROUNDS: int        # 默认 12
CORS_ORIGINS: list[str]   # 默认 ["http://localhost:5173"]
```

## 非功能需求实现

| NFR 编号 | 实现方案 |
|----------|---------|
| GAC-001 | bcrypt rounds=12 哈希存储，种子数据脚本验证数据库无明文密码 |
| GAC-002 | SQLite 10 条数据 + 复合索引，响应时间远低于 500ms 阈值。前端单次 fetch + 渲染，低于 1000ms |
| GAC-003 | JWT payload 仅含 user_id + role + exp + iat，service 层硬编码 claim 白名单 |

## 安全设计

| 威胁 | 防护措施 |
|------|---------|
| SQL 注入 | 所有 SQL 使用参数化查询（CON-003），禁止字符串拼接 |
| XSS 窃取 token | httpOnly cookie，JS 无法读取（DD-001） |
| CSRF | SameSite=Lax cookie 属性；本轮 API 均为 GET/POST 且内网使用，风险可控 |
| 暴力破解 | bcrypt 自带 250ms 延迟；本轮不实现速率限制（内网低风险） |
| 密钥泄露 | JWT_SECRET_KEY 从环境变量读取，禁止硬编码（代码规范 MUST） |
| 信息泄露 | 登录失败统一返回"用户名或密码错误"（R1），不暴露用户是否存在 |

## 共创摘要

| 步骤 | 关键提问/展示 | 用户回应 | 对设计的影响 |
|------|-------------|---------|------------|
| S3 问题拆解 | 展示 5 大问题域拆解 | PRD 已锁定技术栈和部署模式，5 个 DD 需展开 | 确认问题域完整，进入决策 |
| S4 决策点识别 | 5 个 DD 与 PRD 一致性确认 | 确认按 PRD 的 5 个 DD 展开 | DD 列表锁定 |
| S5 逐项方案 | 每个 DD 展示方案对比表 + 推荐 | DD-001 选 httpOnly cookie；DD-002 选 RESTful JSON；DD-003 按 PRD 业务对象；DD-004 选 React Router loader；DD-005 选 bcrypt | 5 个决策全部闭合 |
| S6 边界确认 | 展示安全边界、性能边界、部署边界 | 确认 | 边界锁定，无新增约束 |
| S7 质量闭环 | NFR 实现方案 + 验证方式 | 确认 | 3 个 GAC 实现方案锁定 |
| S8 约束收口 | CON-001~004 与设计决策一致性检查 | 确认 | 全部约束已在设计中体现 |

## PRD 约束追溯

| 约束 ID | 约束内容 | 设计体现 |
|---------|---------|---------|
| CON-001 | 技术栈锁定 | 架构总览：FastAPI + React + TypeScript + Tailwind + SQLite + JWT |
| CON-002 | 单体部署，前后端分离同仓库 | 目录结构：backend/ + frontend/ 同仓库；生产 FastAPI 托管静态文件 |
| CON-003 | 不用 ORM，原生 SQL + 参数化查询 | DD-003 schema 使用原生 DDL；查询示例均为参数化 SQL |
| CON-004 | CORS 策略 | DD-002 中明确 CORS 配置（开发环境 localhost:5173，生产同域无需） |

## 业务规则追溯

| 规则 | 设计体现 |
|------|---------|
| R1: 统一错误提示 | DD-002 错误码：INVALID_CREDENTIALS → "用户名或密码错误" |
| R2: JWT 24h 过期 | JWT 配置 EXPIRE_HOURS=24；cookie Max-Age=86400 |
| R3: 只展示 published | 分页查询 WHERE status='published' |
| R4: 每页 10 条 | API 参数 page_size 默认 10 |
