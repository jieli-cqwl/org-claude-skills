# plan.md — Phase 1: 登录 + 首页

## 输入分析

- PRD: 3 UNIT (登录/首页列表/路由守卫), 16 AC + 3 GAC, 4 CON
- Design: 2 API endpoint + auth middleware + 2 DB tables + CORS + JWT localStorage
- Test-cases: 32 用例 (UNIT-1: 11, UNIT-2: 12, UNIT-3: 9)
- 待计划约束: PC-001(schema先行), PC-002(CORS先行), PC-003(环境变量)

## Design 评审结论

- REVIEW: DESIGN_OK
- 评审摘要: 5 Gate 全部通过。设计覆盖 16 AC + 3 GAC，接口定义完整（请求/响应/错误码），schema 含索引策略，安全模型（bcrypt+JWT+参数化SQL）完备。
- 关键结论: 无 DESIGN_ISSUE。待计划约束 3 项已在 Task 中承接。

## PRD 前置约束映射

| Constraint ID | 类型 | 约束内容 | Owner | 影响 UNIT | scope_item_id | preflight_ref | test_ref | 映射 Task | 验收证据 | 状态 |
|---------------|------|----------|-------|-----------|---------------|---------------|----------|-----------|----------|------|
| CON-001 | runtime | 技术栈锁定 Python+FastAPI+React+TS+Tailwind+SQLite+JWT | 用户 | 全局 | 全局 | N/A | N/A | Task-0 | 项目依赖文件 | MAPPED |
| CON-002 | runtime | 单体部署，前后端分离同仓库 | 用户 | 全局 | 全局 | N/A | N/A | Task-0 | 目录结构 | MAPPED |
| CON-003 | runtime | 不用 ORM，原生 SQL 参数化查询 | 用户 | UNIT-1,2 | SCOPE-P1U1-005 | N/A | TC-U1-008 | Task-1,2 | SQL 注入测试 PASS | MAPPED |
| CON-004 | runtime | CORS 策略配置 | design | 全局 | 全局 | PC-002 | N/A | Task-0 | 跨域请求成功 | MAPPED |

## PRD / Design 覆盖矩阵

| UNIT | requirement_type | requirement_ref | requirement_desc | scope_item_id | design_ref | Task | test_ref | 影响分析 | 覆盖状态 |
|------|------------------|-----------------|------------------|---------------|-----------|------|----------|---------|---------|
| UNIT-1 | AC | AC-U1-01 | 登录成功 | SCOPE-P1U1-001 | HLD-inline | Task-1,3 | TC-U1-001 | 后端+前端 | COVERED |
| UNIT-1 | AC | AC-U1-02 | 密码错误401 | SCOPE-P1U1-002 | HLD-inline | Task-1,3 | TC-U1-002 | 后端+前端 | COVERED |
| UNIT-1 | AC | AC-U1-03 | 用户不存在401 | SCOPE-P1U1-003 | HLD-inline | Task-1 | TC-U1-003 | 后端 | COVERED |
| UNIT-1 | AC | AC-U1-04 | 空输入前端校验 | SCOPE-P1U1-004 | HLD-inline | Task-3 | TC-U1-006,007 | 前端 | COVERED |
| UNIT-1 | AC | AC-U1-05 | SQL注入防护 | SCOPE-P1U1-005 | HLD-inline | Task-1 | TC-U1-008 | 后端 | COVERED |
| UNIT-1 | EX | EX-U1-01 | 无注册接口 | SCOPE-P1U1-EX1 | HLD-inline | Task-1 | TC-U1-009 | 后端 | EX-VERIFIED |
| UNIT-1 | EX | EX-U1-02 | 无密码重置 | SCOPE-P1U1-EX2 | HLD-inline | Task-1 | TC-U1-010 | 后端 | EX-VERIFIED |
| UNIT-2 | AC | AC-U2-01 | 列表展示 | SCOPE-P1U2-001 | HLD-inline | Task-2,4 | TC-U2-001 | 后端+前端 | COVERED |
| UNIT-2 | AC | AC-U2-02 | 分页翻页 | SCOPE-P1U2-002 | HLD-inline | Task-2,4 | TC-U2-002 | 后端+前端 | COVERED |
| UNIT-2 | AC | AC-U2-03 | 空数据提示 | SCOPE-P1U2-003 | HLD-inline | Task-2,4 | TC-U2-003 | 后端+前端 | COVERED |
| UNIT-2 | AC | AC-U2-04 | 恰好10条 | SCOPE-P1U2-004 | HLD-inline | Task-2,4 | TC-U2-007 | 后端+前端 | COVERED |
| UNIT-2 | AC | AC-U2-05 | API失败提示 | SCOPE-P1U2-005 | HLD-inline | Task-4 | TC-U2-012 | 前端 | COVERED |
| UNIT-2 | AC | AC-U2-06 | 页码越界 | SCOPE-P1U2-006 | HLD-inline | Task-2 | TC-U2-008 | 后端 | COVERED |
| UNIT-2 | EX | EX-U2-01 | 无详情接口 | SCOPE-P1U2-EX1 | HLD-inline | Task-2 | TC-U2-010 | 后端 | EX-VERIFIED |
| UNIT-2 | EX | EX-U2-02 | 无搜索接口 | SCOPE-P1U2-EX2 | HLD-inline | Task-2 | TC-U2-011 | 后端 | EX-VERIFIED |
| UNIT-3 | AC | AC-U3-01 | 未登录拦截 | SCOPE-P1U3-001 | HLD-inline | Task-5 | TC-U3-001 | 前端 | COVERED |
| UNIT-3 | AC | AC-U3-02 | 已登录访问 | SCOPE-P1U3-002 | HLD-inline | Task-5 | TC-U3-002 | 前端 | COVERED |
| UNIT-3 | AC | AC-U3-03 | token过期 | SCOPE-P1U3-003 | HLD-inline | Task-5 | TC-U3-003 | 前端 | COVERED |
| UNIT-3 | AC | AC-U3-04 | 已登录访问登录页 | SCOPE-P1U3-004 | HLD-inline | Task-5 | TC-U3-005 | 前端 | COVERED |
| UNIT-3 | AC | AC-U3-05 | 非法token | SCOPE-P1U3-005 | HLD-inline | Task-5 | TC-U3-006 | 前端 | COVERED |
| UNIT-3 | EX | EX-U3-01 | 无角色权限 | SCOPE-P1U3-EX1 | HLD-inline | Task-5 | TC-U3-008 | 前端 | EX-VERIFIED |
| UNIT-3 | EX | EX-U3-02 | 无多设备管控 | SCOPE-P1U3-EX2 | HLD-inline | Task-5 | TC-U3-009 | 前端 | EX-VERIFIED |
| 全局 | GAC | GAC-001 | 密码bcrypt哈希 | GAC-001 | HLD-inline | Task-0,1 | TC-U1-011 | 后端 | COVERED |
| 全局 | GAC | GAC-002 | API<500ms | GAC-002 | HLD-inline | Task-1,2 | N/A | 后端 | COVERED-NO-TEST |
| 全局 | GAC | GAC-003 | JWT仅含user_id+role | GAC-003 | HLD-inline | Task-1 | TC-U1-004 | 后端 | COVERED |

## Scope Freeze 与映射矩阵

| scope_item_id | 变更类型 | 风险等级 | 映射 Task | test_ref | impact_files | rollback_ref | 状态 |
|---------------|----------|----------|-----------|----------|--------------|--------------|------|
| 全新项目 | 全量新建 | P2 | Task-0~5 | 全部 TC | 全部文件 | 删除项目目录 | FROZEN |

## Task 清单

### Task-0: 项目脚手架 + DB + 种子数据 + CORS
- 文件: `backend/app/__init__.py`(Create), `backend/app/main.py`(Create), `backend/app/config.py`(Create), `backend/app/database.py`(Create), `backend/seed.py`(Create), `backend/requirements.txt`(Create), `frontend/package.json`(Create), `frontend/vite.config.ts`(Create), `frontend/tsconfig.json`(Create), `frontend/tailwind.config.js`(Create), `frontend/src/main.tsx`(Create)
- unit_ref: 全局
- design_ref: HLD-inline
- scope_item_ref: 全局
- constraint_ref: CON-001, CON-002, CON-003, CON-004
- api_ref: 无接口交互
- test_ref: TC-U1-011 (bcrypt 哈希验证)
- complexity: M
- split_reason: 共享基础设施边界——DB/种子数据/CORS 是所有 UNIT 的前提
- AC:
  1. `python backend/seed.py` 执行后 SQLite 数据库包含 3 用户 + 12 published + 2 draft 周报
  2. `pip install -r backend/requirements.txt` 成功安装所有依赖
  3. `cd frontend && npm install` 成功安装所有依赖
  4. FastAPI 启动后 CORS 允许 localhost:5173 跨域请求
  5. 环境变量 JWT_SECRET 未设置时 FastAPI 启动失败并报错
- depends_on: []
- shared_files: [`backend/app/main.py`, `backend/app/database.py`]
- impact_files: []

### Task-1: 后端 POST /api/login
- 文件: `backend/app/auth/__init__.py`(Create), `backend/app/auth/router.py`(Create), `backend/app/auth/service.py`(Create), `backend/app/models.py`(Create)
- unit_ref: UNIT-1
- design_ref: HLD-inline (POST /api/login 接口定义)
- scope_item_ref: SCOPE-P1U1-001, SCOPE-P1U1-002, SCOPE-P1U1-003, SCOPE-P1U1-005
- constraint_ref: CON-003
- api_ref: design.md#POST-/api/login
- test_ref: TC-U1-001, TC-U1-002, TC-U1-003, TC-U1-004, TC-U1-005, TC-U1-008
- complexity: M
- split_reason: 接口边界——登录 API 是独立端点，前端 Task-3 依赖此 API
- AC:
  1. POST /api/login `{"username":"admin","password":"password123"}` → 200 + `{token, user{id,username,display_name,role}}`
  2. POST /api/login 错误密码 → 401 `{error:{code:"INVALID_CREDENTIALS",message:"用户名或密码错误"}}`
  3. POST /api/login 不存在用户 → 401（响应体与密码错误完全一致，R1）
  4. JWT payload 仅含 user_id, role, exp, iat (GAC-003)，exp-iat=86400 (R2)
  5. SQL 注入攻击字符串 → 401（非 500）
- depends_on: [Task-0]
- shared_files: [`backend/app/main.py`]
- impact_files: []

### Task-2: 后端 GET /api/reports + auth middleware
- 文件: `backend/app/reports/__init__.py`(Create), `backend/app/reports/router.py`(Create), `backend/app/reports/service.py`(Create), `backend/app/auth/dependencies.py`(Create)
- unit_ref: UNIT-2
- design_ref: HLD-inline (GET /api/reports 接口定义 + auth middleware)
- scope_item_ref: SCOPE-P1U2-001, SCOPE-P1U2-002, SCOPE-P1U2-003, SCOPE-P1U2-006
- constraint_ref: CON-003
- api_ref: design.md#GET-/api/reports
- test_ref: TC-U2-001, TC-U2-002, TC-U2-003, TC-U2-004, TC-U2-005, TC-U2-006, TC-U2-008, TC-U2-009
- complexity: M
- split_reason: 接口边界——报告列表 API + auth middleware 是独立功能，前端 Task-4 依赖此 API
- AC:
  1. GET /api/reports?page=1 (有效 token) → 200 + data[10条] + pagination{page:1,page_size:10,total:12,total_pages:2}
  2. GET /api/reports?page=2 → 200 + data[2条]
  3. GET /api/reports (无 token) → 401 `{error:{code:"UNAUTHORIZED",message:"请先登录"}}`
  4. WHERE status='published' ORDER BY created_at DESC (R3, R4)
  5. created_at 格式为 ISO 8601 `YYYY-MM-DDTHH:MM:SSZ`
  6. page=999 → 200 + data=[] + total=12（页码越界不报错）
- depends_on: [Task-0, Task-1]
- shared_files: [`backend/app/main.py`]
- impact_files: []

### Task-3: 前端 LoginPage
- 文件: `frontend/src/auth/LoginPage.tsx`(Create), `frontend/src/api/client.ts`(Create), `frontend/src/types/index.ts`(Create), `frontend/src/App.tsx`(Create)
- unit_ref: UNIT-1
- design_ref: HLD-inline (LoginPage + axios client)
- scope_item_ref: SCOPE-P1U1-001, SCOPE-P1U1-004
- constraint_ref: 无
- api_ref: design.md#POST-/api/login
- test_ref: TC-U1-006, TC-U1-007
- complexity: M
- split_reason: 全栈强制拆分——前端 LoginPage 独立于后端 login API
- AC:
  1. 正确凭据登录 → token 写入 localStorage → 跳转到 /
  2. 错误凭据 → 页面显示"用户名或密码错误"
  3. 空 username 或空 password → 前端表单校验拦截，不发请求
- depends_on: [Task-1]
- shared_files: [`frontend/src/App.tsx`]
- impact_files: []

### Task-4: 前端 HomePage + 分页
- 文件: `frontend/src/reports/HomePage.tsx`(Create)
- unit_ref: UNIT-2
- design_ref: HLD-inline (HomePage 列表 + 分页)
- scope_item_ref: SCOPE-P1U2-001, SCOPE-P1U2-002, SCOPE-P1U2-003, SCOPE-P1U2-005
- constraint_ref: 无
- api_ref: design.md#GET-/api/reports
- test_ref: TC-U2-003, TC-U2-007, TC-U2-012
- complexity: M
- split_reason: 全栈强制拆分——前端 HomePage 独立于后端 reports API
- AC:
  1. 已登录访问 / → 展示周报列表（标题/作者名/时间），倒序
  2. total > 10 → 分页控件可见，点击翻页加载下一页
  3. total <= 10 → 无分页控件
  4. total = 0 → 显示"暂无周报"
  5. API 返回 5xx/网络错误 → 显示"加载失败，请刷新重试"
- depends_on: [Task-2]
- shared_files: [`frontend/src/App.tsx`]
- impact_files: []

### Task-5: 前端 ProtectedRoute + axios 拦截器
- 文件: `frontend/src/auth/AuthGuard.tsx`(Create), `frontend/src/auth/useAuth.ts`(Create)
- unit_ref: UNIT-3
- design_ref: HLD-inline (ProtectedRoute + axios 拦截器)
- scope_item_ref: SCOPE-P1U3-001, SCOPE-P1U3-002, SCOPE-P1U3-003, SCOPE-P1U3-004, SCOPE-P1U3-005
- constraint_ref: 无
- api_ref: 无直接 API 交互（通过 axios 拦截器间接关联）
- test_ref: TC-U3-001~009
- complexity: M
- split_reason: 子功能边界——路由守卫是独立的前端横切关注点
- AC:
  1. 无 token 访问 / → redirect /login
  2. 有效 token 访问 / → 正常展示
  3. 过期 token 访问 / → 清除 token + redirect /login
  4. 有效 token 访问 /login → redirect /
  5. 非法 token（乱码/篡改）→ 清除 token + redirect /login
  6. axios 拦截器：API 返回 401 → 清除 token + redirect /login
- depends_on: [Task-1, Task-3]
- shared_files: [`frontend/src/App.tsx`, `frontend/src/api/client.ts`]
- impact_files: []

## 依赖关系

```
Task-0 (脚手架+DB)
  ├── Task-1 (后端登录)
  │     ├── Task-2 (后端报告+auth middleware)
  │     │     └── Task-4 (前端首页)
  │     ├── Task-3 (前端登录页)
  │     │     └── Task-5 (前端路由守卫)
```

## 并行策略

团队规模：1 名开发者（Claude Code agent）

串行执行：Task-0 → Task-1 → Task-2 → Task-3 → Task-4 → Task-5

> 单开发者无并行需求。后端先行（Task-0→1→2），前端跟进（Task-3→4→5）。Task-3 和 Task-4 理论可并行但共享 App.tsx，串行更安全。

## Phase 3 审查分级

审查分级: 完整

判定依据: 6 Task，涉及认证安全链路（登录+JWT+auth middleware+路由守卫），属核心业务链路。

强门禁矩阵:
- REVIEW_A + REVIEW_B + QA_A + QA_B + QA_C + QA_D

## 独立审查收敛

独立审查收敛状态: REVIEW_PASS

## 前置验证点
- Task-0 完成后验证：SQLite 数据库文件存在 + 种子数据正确 + CORS 配置生效
- Task-1 完成后验证：curl 登录 API 返回 token

## 关键里程碑
- M1: 后端 API 全部可用（Task-0+1+2 完成）— 可用 curl 全量验证
- M2: 前后端联调通过（Task-3+4+5 完成）— 浏览器端到端验证

## 风险与执行注意事项
- SQLite datetime('now') 返回 UTC 格式 "YYYY-MM-DD HH:MM:SS"，API 层需转换为 ISO 8601
- bcrypt 需要 C 编译环境，passlib[bcrypt] 提供预编译 wheel
- React Router v6.4+ 的 loader API 需确认版本兼容

## 用户确认记录
- 确认状态: 确认
- 确认时间: 2026-04-06 19:00
- 确认备注: 6 Task 串行执行，后端先行前端跟进

## 交接项
- 执行顺序：Task-0 → Task-1 → Task-2 → Task-3 → Task-4 → Task-5
- 每个 Task 含 assertable AC，开发者按 TDD 逐条实现
- 审查分级：完整（REVIEW_A+B + QA_A+B+C+D）
- 前置约束 4 项全部 MAPPED
- 覆盖矩阵 25 行，仅 GAC-002 为 COVERED-NO-TEST（QA 冒烟验证）
