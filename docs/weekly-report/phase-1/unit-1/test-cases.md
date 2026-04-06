# test-cases.md — UNIT-1: 用户账密登录

## 用例统计
| 类别 | 数量 |
|------|------|
| 正例 | 1 |
| 反例 | 3 |
| 边界 | 3 |
| 排除项验证 | 2 |
| 专项测试 | 2 |
| 合计 | 11 |

## UNIT 覆盖视图
| UNIT | 闭环目标 | 关联 AC | 用例编号 | 覆盖状态 |
|------|----------|---------|---------|---------|
| UNIT-1 | 用户输入凭据→验证+签发JWT→进入首页或看到错误提示 | AC-U1-01~05 | TC-U1-001~011 | COVERED |

## AC 覆盖矩阵
| UNIT | AC 编号 | AC 描述 | scope_item_id | 用例编号 | 类型 | 覆盖状态 |
|------|---------|---------|---------------|---------|------|---------|
| UNIT-1 | AC-U1-01 | 正确凭据登录成功 | SCOPE-P1U1-001 | TC-U1-001, TC-U1-004, TC-U1-005 | 正例, 边界, 边界 | COVERED |
| UNIT-1 | AC-U1-02 | 密码错误返回401 | SCOPE-P1U1-002 | TC-U1-002 | 反例 | COVERED |
| UNIT-1 | AC-U1-03 | 用户不存在返回401 | SCOPE-P1U1-003 | TC-U1-003 | 反例 | COVERED |
| UNIT-1 | AC-U1-04 | 空输入前端校验 | SCOPE-P1U1-004 | TC-U1-006, TC-U1-007 | 边界, 反例 | COVERED |
| UNIT-1 | AC-U1-05 | SQL注入防护 | SCOPE-P1U1-005 | TC-U1-008 | 专项测试 | COVERED |

## 等价性对照矩阵
| scope_item_id | 关联 AC | 关联 TC | 对照输入 | 不变量 | 结果状态 | 备注 |
|---------------|---------|---------|----------|--------|----------|------|
| SCOPE-P1U1-001 | AC-U1-01 | TC-U1-001 | 种子用户 admin/password123 | 返回200+token+user对象 | EQ-COVERED | design POST /api/login 200 响应格式匹配 |
| SCOPE-P1U1-002 | AC-U1-02 | TC-U1-002 | admin/wrongpass | 返回401 INVALID_CREDENTIALS | EQ-COVERED | design 401 响应格式匹配 |
| SCOPE-P1U1-003 | AC-U1-03 | TC-U1-003 | nonexist/anything | 返回401 INVALID_CREDENTIALS（与密码错误一致） | EQ-COVERED | R1 业务规则 |
| SCOPE-P1U1-004 | AC-U1-04 | TC-U1-006 | username=""或password="" | 前端拦截不发请求 | EQ-COVERED | 前端表单 required |
| SCOPE-P1U1-005 | AC-U1-05 | TC-U1-008 | username="' OR 1=1 --" | 返回401（非500） | EQ-COVERED | 参数化查询 |

## Design 问题报告

无设计缺口。所有 AC 均有明确的设计承接。

## 测试用例

### TC-U1-001: 正确凭据登录成功
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-01
- scope_item_id: SCOPE-P1U1-001
- 类型: 正例
- 前置条件: 种子数据已初始化，admin 用户存在
- 输入/操作: POST /api/login `{"username":"admin","password":"password123"}`
- 期望输出: HTTP 200，响应体含 `token`（非空字符串）和 `user` 对象（含 id, username, display_name, role）
- 验证命令: `curl -s -X POST http://localhost:8000/api/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"password123"}' | jq '.token,.user.username'`

### TC-U1-002: 密码错误返回统一错误
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-02
- scope_item_id: SCOPE-P1U1-002
- 类型: 反例
- 前置条件: admin 用户存在
- 输入/操作: POST /api/login `{"username":"admin","password":"wrongpassword"}`
- 期望输出: HTTP 401，`{"error":{"code":"INVALID_CREDENTIALS","message":"用户名或密码错误"}}`
- 验证命令: `curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8000/api/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"wrongpassword"}'` 应返回 401

### TC-U1-003: 不存在的用户返回相同错误
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-03
- scope_item_id: SCOPE-P1U1-003
- 类型: 反例
- 前置条件: nonexistuser 不存在于 users 表
- 输入/操作: POST /api/login `{"username":"nonexistuser","password":"anything"}`
- 期望输出: HTTP 401，错误码 INVALID_CREDENTIALS，消息与 TC-U1-002 完全一致
- 验证命令: 对比 TC-U1-002 和 TC-U1-003 的响应体，确认 error.code 和 error.message 字段完全相同

### TC-U1-004: JWT token 格式和内容验证
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-01
- scope_item_id: SCOPE-P1U1-001
- 类型: 边界
- 前置条件: 登录成功获得 token
- 输入/操作: base64 解码 token payload
- 期望输出: payload 仅含 user_id(int)、role(string)、exp(int)、iat(int)，无 password/email 等敏感字段（GAC-003）
- 验证命令: `echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq 'keys'` 应仅含 [exp, iat, role, user_id]

### TC-U1-005: JWT 过期时间为24小时
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-01
- scope_item_id: SCOPE-P1U1-001
- 类型: 边界
- 前置条件: 登录成功获得 token
- 输入/操作: 解码 token，计算 exp - iat
- 期望输出: exp - iat == 86400（24小时，R2 业务规则）
- 验证命令: `echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq '.exp - .iat'` 应返回 86400

### TC-U1-006: 空用户名前端校验
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-04
- scope_item_id: SCOPE-P1U1-004
- 类型: 边界
- 前置条件: 登录页已加载
- 输入/操作: username 为空，password 填写任意值，点击登录
- 期望输出: 前端表单校验拦截，提示"请填写用户名"，不发送 HTTP 请求
- 验证命令: 浏览器 Network 面板确认无 /api/login 请求发出

### TC-U1-007: 空密码前端校验
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-04
- scope_item_id: SCOPE-P1U1-004
- 类型: 反例
- 前置条件: 登录页已加载
- 输入/操作: username 填写任意值，password 为空，点击登录
- 期望输出: 前端表单校验拦截，提示"请填写密码"，不发送 HTTP 请求
- 验证命令: 浏览器 Network 面板确认无 /api/login 请求发出

### TC-U1-008: SQL 注入防护
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-05
- scope_item_id: SCOPE-P1U1-005
- 类型: 专项测试
- 前置条件: 后端运行中
- 输入/操作: POST /api/login `{"username":"' OR 1=1 --","password":"anything"}`
- 期望输出: HTTP 401（非 500），参数化查询正常处理特殊字符
- 验证命令: `curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8000/api/login -H 'Content-Type: application/json' -d '{"username":"'\'' OR 1=1 --","password":"x"}'` 应返回 401

### TC-U1-009: 排除项 — 不存在注册接口
- 关联 UNIT: UNIT-1
- 关联 AC: 排除项
- scope_item_id: SCOPE-P1U1-EX1
- 类型: 排除项验证
- 前置条件: 后端运行中
- 输入/操作: POST /api/register `{"username":"newuser","password":"pass123"}`
- 期望输出: HTTP 404 或 405（接口不存在）
- 验证命令: `curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8000/api/register -H 'Content-Type: application/json' -d '{}'` 应返回 404/405

### TC-U1-010: 排除项 — 不存在密码重置接口
- 关联 UNIT: UNIT-1
- 关联 AC: 排除项
- scope_item_id: SCOPE-P1U1-EX2
- 类型: 排除项验证
- 前置条件: 后端运行中
- 输入/操作: POST /api/reset-password
- 期望输出: HTTP 404 或 405
- 验证命令: `curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8000/api/reset-password` 应返回 404/405

### TC-U1-011: 密码哈希存储验证（GAC-001）
- 关联 UNIT: UNIT-1
- 关联 AC: GAC-001
- scope_item_id: SCOPE-P1U1-GAC1
- 类型: 专项测试
- 前置条件: 种子数据已初始化
- 输入/操作: 直接查询 SQLite users 表的 password_hash 字段
- 期望输出: 所有 password_hash 以 `$2b$` 开头（bcrypt 格式），无明文密码
- 验证命令: `sqlite3 data/weekly_report.db "SELECT password_hash FROM users" | grep -c '^\$2b\$'` 应等于用户总数

## 专项测试触发依据与展开策略

| 专项类型 | 触发依据 | 展开策略 | 备注 |
|---------|---------|---------|------|
| 安全 | design 质量属性：SQL注入免疫、密码哈希、JWT payload 安全 | TC-U1-008（注入）+ TC-U1-011（哈希）+ TC-U1-004（JWT payload） | 必须展开 |

## 审查结论
- 测试质量: WARN (5) | 产品: WARN (3) | 架构: WARN (5)
- 无 FAIL 项
- WARN 承接：前端 E2E 用例 → QA 阶段覆盖；CORS/性能 → 集成测试阶段
- 详见: testdesign-cross-review.md
