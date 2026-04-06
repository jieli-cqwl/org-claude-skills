# 全链路测试接力文件

> 创建时间: 2026-04-06
> 当前 session 完成点: /developer Task-2（后端 API 全部可用）
> 下个 session 目标: 完成 Task-3~5 + /review + /qa + 摩擦点报告

## 已完成的链路节点

| 节点 | 状态 | 产出位置 |
|------|------|---------|
| /product | 完成 | docs/weekly-report/prd.md, units/, product-cross-review.md |
| /design | 完成 | phase-1/design.md, design/adr/ADR-*.md, design-cross-review.md |
| /test-design | 完成 | phase-1/unit-{1,2,3}/test-cases.md + testdesign-cross-review.md |
| /tech-lead | 完成 | phase-1/plan.md (6 Task, 审查分级=完整) |
| /developer Task-0 | 完成 | app/backend/ 脚手架 + DB + 种子数据 + CORS |
| /developer Task-1 | 完成 | app/backend/app/auth/ (POST /api/login) |
| /developer Task-2 | 完成 | app/backend/app/reports/ + auth/dependencies.py |

## 待完成的工作

### Task-3: 前端 LoginPage
- 文件: frontend/src/auth/LoginPage.tsx, frontend/src/api/client.ts, frontend/src/types/index.ts, frontend/src/App.tsx
- AC: 正确凭据→token存localStorage→跳转/；错误→显示错误提示；空输入→前端拦截

### Task-4: 前端 HomePage + 分页
- 文件: frontend/src/reports/HomePage.tsx
- AC: 展示列表（标题/作者/时间/倒序）；分页控件；空状态；错误提示

### Task-5: 前端 ProtectedRoute + axios 拦截器
- 文件: frontend/src/auth/AuthGuard.tsx, frontend/src/auth/useAuth.ts
- AC: 无token→/login；有效token→放行；过期/非法→清除+/login；已登录访问/login→/；401拦截器

### /review
- 审查分级: 完整 (REVIEW_A + REVIEW_B)
- 不信任原则已注入 3 个 reviewer prompt

### /qa
- 审查分级: 完整 (QA_A + QA_B + QA_C + QA_D)
- 32 个 test-cases 覆盖 16 AC + 3 GAC + 排除项

### 链路摩擦点报告
- 汇总全链路发现
- 输出: docs/weekly-report/chain-test-report.md

## 已发现的摩擦点

| # | 节点 | 摩擦点 | 影响 |
|---|------|--------|------|
| F-1 | /developer Task-0 | passlib 与新版 bcrypt 库不兼容（`__about__` 属性缺失） | 需切换到直接用 bcrypt 库，design 中选型 passlib 与实际运行时冲突 |
| F-2 | /developer Task-1 | JWT secret 长度警告（23 bytes < 推荐 32 bytes） | dev 环境可接受，但 design 应指定最小 secret 长度 |
| F-3 | /test-design | AC-U2-05 测试用例语义错位（TC-U2-004 测 401 而非 5xx） | 跨职能评审 R1 发现并修复，证明评审流程有效 |
| F-4 | /tech-lead | plan 模板字段非常多（覆盖矩阵、scope freeze、constraint mapping），填写成本高 | 对 LLM 有利（结构化），但人工填写会很痛苦 |
| F-5 | /test-design | 前端 UI 测试用例验证命令不可自动化（"浏览器确认"） | 需要 Playwright 基础设施，test-cases 设计时应区分 API 测试和 UI 测试 |

## 下个 session 执行指令

```
1. 读取本文件了解进度
2. 读取 phase-1/plan.md 的 Task-3~5 定义
3. cd docs/weekly-report/app 进入项目目录
4. 实现 Task-3 (LoginPage) → 启动前端验证登录流程
5. 实现 Task-4 (HomePage) → 验证列表展示和分页
6. 实现 Task-5 (AuthGuard) → 验证路由守卫全部 AC
7. 前后端联调验证：登录→首页→登出→拦截 完整旅程
8. 执行 /review（code-review-fix skill，3 agent 并行）
9. 执行 /qa（qa skill，审查分级=完整）
10. 写 chain-test-report.md 汇总全链路摩擦点和结论
```

## 后端验证状态

所有后端 TC 通过：
- TC-U1-001 登录成功 ✓（200 + token + user）
- TC-U1-002 密码错误 ✓（401）
- TC-U1-008 SQL注入 ✓（401 非 500）
- TC-U2-001 列表第1页 ✓（10 items, total=12）
- TC-U2-002 列表第2页 ✓（2 items）
- TC-U2-004 无token ✓（401）
- TC-U2-008 页码越界 ✓（0 items, total=12）
- TC-U2-009 ISO 8601 ✓（2026-03-12T10:00:00Z）

## 环境信息

- venv: docs/weekly-report/app/backend/.venv
- 启动命令: `cd docs/weekly-report/app/backend && source .venv/bin/activate && JWT_SECRET=test-secret-key-for-dev uvicorn app.main:app --port 8000`
- 种子数据: `JWT_SECRET=test-secret-key-for-dev python seed.py`
- DB 文件: data/weekly_report.db
