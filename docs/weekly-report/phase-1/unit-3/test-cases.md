# test-cases.md — UNIT-3: 登录态路由守卫

## 用例统计
| 类别 | 数量 |
|------|------|
| 正例 | 2 |
| 反例 | 3 |
| 边界 | 2 |
| 排除项验证 | 2 |
| 专项测试 | 0 |
| 合计 | 9 |

## UNIT 覆盖视图
| UNIT | 闭环目标 | 关联 AC | 用例编号 | 覆盖状态 |
|------|----------|---------|---------|---------|
| UNIT-3 | 用户访问任意页面→检查JWT→按登录态路由到正确页面 | AC-U3-01~05 | TC-U3-001~009 | COVERED |

## AC 覆盖矩阵
| UNIT | AC 编号 | AC 描述 | scope_item_id | 用例编号 | 类型 | 覆盖状态 |
|------|---------|---------|---------------|---------|------|---------|
| UNIT-3 | AC-U3-01 | 无token访问首页→跳转登录 | SCOPE-P1U3-001 | TC-U3-001, TC-U3-004 | 反例, 边界 | COVERED |
| UNIT-3 | AC-U3-02 | 有效token访问首页→正常展示 | SCOPE-P1U3-002 | TC-U3-002 | 正例 | COVERED |
| UNIT-3 | AC-U3-03 | 过期token→清除并跳转登录 | SCOPE-P1U3-003 | TC-U3-003 | 反例 | COVERED |
| UNIT-3 | AC-U3-04 | 已登录访问登录页→跳转首页 | SCOPE-P1U3-004 | TC-U3-005 | 正例 | COVERED |
| UNIT-3 | AC-U3-05 | 非法token→清除并跳转登录 | SCOPE-P1U3-005 | TC-U3-006, TC-U3-007 | 反例, 边界 | COVERED |

## 等价性对照矩阵
| scope_item_id | 关联 AC | 关联 TC | 对照输入 | 不变量 | 结果状态 | 备注 |
|---------------|---------|---------|----------|--------|----------|------|
| SCOPE-P1U3-001 | AC-U3-01 | TC-U3-001 | localStorage 无 token | 路由 redirect 到 /login | EQ-COVERED | ProtectedRoute 检查 |
| SCOPE-P1U3-002 | AC-U3-02 | TC-U3-002 | localStorage 有有效 token | 路由放行到首页 | EQ-COVERED | ProtectedRoute 放行 |
| SCOPE-P1U3-003 | AC-U3-03 | TC-U3-003 | localStorage 有过期 token | 清除 token + redirect /login | EQ-COVERED | JWT exp 解码比对 |
| SCOPE-P1U3-005 | AC-U3-05 | TC-U3-006 | localStorage 有乱码 token | 清除 token + redirect /login | EQ-COVERED | JWT 解码 try/catch |

## Design 问题报告

无设计缺口。所有 AC 均有明确的设计承接。

## 测试用例

### TC-U3-001: 未登录访问首页被拦截
- 关联 UNIT: UNIT-3
- 关联 AC: AC-U3-01
- scope_item_id: SCOPE-P1U3-001
- 类型: 反例
- 前置条件: 浏览器 localStorage 中无 token
- 输入/操作: 在浏览器中访问 http://localhost:3000/
- 期望输出: 自动跳转到 /login，URL 变为 http://localhost:3000/login
- 验证命令: 浏览器地址栏确认 URL 为 /login

### TC-U3-002: 已登录访问首页正常展示
- 关联 UNIT: UNIT-3
- 关联 AC: AC-U3-02
- scope_item_id: SCOPE-P1U3-002
- 类型: 正例
- 前置条件: localStorage 中存有有效 token（未过期）
- 输入/操作: 在浏览器中访问 http://localhost:3000/
- 期望输出: 正常展示首页内容（周报列表），URL 保持为 /
- 验证命令: 页面包含周报列表元素

### TC-U3-003: 过期 token 被清除并跳转登录
- 关联 UNIT: UNIT-3
- 关联 AC: AC-U3-03
- scope_item_id: SCOPE-P1U3-003
- 类型: 反例
- 前置条件: localStorage 中存有过期 token（exp < 当前时间）。使用种子数据中的预生成过期 token
- 输入/操作: 在浏览器中访问 http://localhost:3000/
- 期望输出: localStorage 中 token 被清除，自动跳转到 /login
- 验证命令: `localStorage.getItem('token')` 为 null，URL 为 /login

### TC-U3-004: 未登录直接访问不存在的路由
- 关联 UNIT: UNIT-3
- 关联 AC: AC-U3-01
- scope_item_id: SCOPE-P1U3-001
- 类型: 边界
- 前置条件: localStorage 中无 token
- 输入/操作: 在浏览器中访问 http://localhost:3000/some-random-path
- 期望输出: 跳转到 /login（而非 404 页面），因为未认证用户的所有路由都应导向登录
- 验证命令: URL 变为 /login

### TC-U3-005: 已登录用户访问登录页被重定向
- 关联 UNIT: UNIT-3
- 关联 AC: AC-U3-04
- scope_item_id: SCOPE-P1U3-004
- 类型: 正例
- 前置条件: localStorage 中存有有效 token
- 输入/操作: 在浏览器中访问 http://localhost:3000/login
- 期望输出: 自动跳转到 /，不展示登录页
- 验证命令: URL 变为 /

### TC-U3-006: 非法格式 token 被清除
- 关联 UNIT: UNIT-3
- 关联 AC: AC-U3-05
- scope_item_id: SCOPE-P1U3-005
- 类型: 反例
- 前置条件: localStorage 中存有非法 token（如 "not.a.jwt"，种子测试辅助数据）
- 输入/操作: 在浏览器中访问 http://localhost:3000/
- 期望输出: localStorage token 被清除，跳转到 /login
- 验证命令: `localStorage.getItem('token')` 为 null，URL 为 /login

### TC-U3-007: 被篡改的 token payload 被拒绝
- 关联 UNIT: UNIT-3
- 关联 AC: AC-U3-05
- scope_item_id: SCOPE-P1U3-005
- 类型: 边界
- 前置条件: 取一个有效 token，修改 payload 中的 user_id 后重组（签名不匹配）
- 输入/操作: 将篡改 token 存入 localStorage，访问 /
- 期望输出: 前端 JWT 解码可能成功（仅检查格式），但后端 API 调用返回 401，axios 拦截器清除 token 并跳转 /login
- 验证命令: 后端 API 返回 401，前端最终跳转到 /login

### TC-U3-008: 排除项 — 无角色权限控制
- 关联 UNIT: UNIT-3
- 关联 AC: 排除项
- scope_item_id: SCOPE-P1U3-EX1
- 类型: 排除项验证
- 前置条件: 使用 role=reader 的用户（bob）登录
- 输入/操作: 访问首页 /
- 期望输出: 正常展示首页内容，与 author 用户体验一致（本轮不区分角色权限）
- 验证命令: reader 用户看到的周报列表与 author 用户相同

### TC-U3-009: 排除项 — 无多设备登录管控
- 关联 UNIT: UNIT-3
- 关联 AC: 排除项
- scope_item_id: SCOPE-P1U3-EX2
- 类型: 排除项验证
- 前置条件: 同一用户在浏览器 A 和浏览器 B 分别登录
- 输入/操作: 两个浏览器同时访问首页
- 期望输出: 两个会话都正常工作，互不影响
- 验证命令: 两个浏览器都能正常展示首页

## 专项测试触发依据与展开策略

无。UNIT-3 是纯前端路由逻辑，安全边界由 UNIT-1（JWT签发）和后端 auth middleware 保障，无需额外专项。

## 审查结论
- 测试质量: WARN (3) | 产品: WARN (1) | 架构: WARN (2)
- 无 FAIL 项
- WARN 承接：E2E 旅程 → QA 阶段；axios 拦截器 → 集成测试
- 详见: testdesign-cross-review.md
