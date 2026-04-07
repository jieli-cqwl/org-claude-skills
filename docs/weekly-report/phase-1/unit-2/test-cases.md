# test-cases.md — UNIT-2: 首页周报列表展示

## 用例统计
| 类别 | 数量 |
|------|------|
| 正例 | 2 |
| 反例 | 2 |
| 边界 | 4 |
| 排除项验证 | 2 |
| 专项测试 | 1 |
| 合计 | 12 |

## UNIT 覆盖视图
| UNIT | 闭环目标 | 关联 AC | 用例编号 | 覆盖状态 |
|------|----------|---------|---------|---------|
| UNIT-2 | 已登录用户访问首页→查询已发布周报→展示分页倒序列表 | AC-U2-01~06 | TC-U2-001~011 | COVERED |

## AC 覆盖矩阵
| UNIT | AC 编号 | AC 描述 | scope_item_id | 用例编号 | 类型 | 覆盖状态 |
|------|---------|---------|---------------|---------|------|---------|
| UNIT-2 | AC-U2-01 | 列表展示（标题/作者/时间/倒序） | SCOPE-P1U2-001 | TC-U2-001, TC-U2-005 | 正例, 边界 | COVERED |
| UNIT-2 | AC-U2-02 | 分页（总数>10显示分页控件） | SCOPE-P1U2-002 | TC-U2-002, TC-U2-006 | 正例, 边界 | COVERED |
| UNIT-2 | AC-U2-03 | 空数据显示"暂无周报" | SCOPE-P1U2-003 | TC-U2-003 | 反例 | COVERED |
| UNIT-2 | AC-U2-04 | 恰好10条无分页控件 | SCOPE-P1U2-004 | TC-U2-007 | 边界 | COVERED |
| UNIT-2 | AC-U2-05 | API失败显示错误提示 | SCOPE-P1U2-005 | TC-U2-004, TC-U2-012 | 反例, 反例 | COVERED |
| UNIT-2 | AC-U2-06 | 页码越界返回空列表 | SCOPE-P1U2-006 | TC-U2-008 | 边界 | COVERED |

## 等价性对照矩阵
| scope_item_id | 关联 AC | 关联 TC | 对照输入 | 不变量 | 结果状态 | 备注 |
|---------------|---------|---------|----------|--------|----------|------|
| SCOPE-P1U2-001 | AC-U2-01 | TC-U2-001 | GET /api/reports?page=1 | 返回200+data数组+pagination对象 | EQ-COVERED | design 接口定义匹配 |
| SCOPE-P1U2-002 | AC-U2-02 | TC-U2-002 | GET /api/reports?page=2 | 返回第11-12条数据 | EQ-COVERED | 种子数据12条published |
| SCOPE-P1U2-003 | AC-U2-03 | TC-U2-003 | 空表场景 | data=[], total=0 | EQ-COVERED | design 空数据响应格式 |
| SCOPE-P1U2-006 | AC-U2-06 | TC-U2-008 | page=999 | data=[], total>0 | EQ-COVERED | design 页码越界响应 |

## Design 问题报告

无设计缺口。所有 AC 均有明确的设计承接。

## 测试用例

### TC-U2-001: 首页列表正常展示
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-01
- scope_item_id: SCOPE-P1U2-001
- 类型: 正例
- 前置条件: 已登录（有效 token），种子数据 12 条 published
- 输入/操作: GET /api/reports?page=1（携带 Authorization header）
- 期望输出: HTTP 200，data 数组含 10 条记录，每条含 id/title/author_name/created_at；pagination.total=12, pagination.total_pages=2；data[0].created_at >= data[1].created_at（倒序）
- 验证命令: `curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/reports?page=1 | jq '.data | length, .pagination.total'` 应返回 10 和 12

### TC-U2-002: 翻页到第二页
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-02
- scope_item_id: SCOPE-P1U2-002
- 类型: 正例
- 前置条件: 已登录，种子数据 12 条 published
- 输入/操作: GET /api/reports?page=2
- 期望输出: HTTP 200，data 数组含 2 条记录，pagination.page=2, pagination.total=12
- 验证命令: `curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/reports?page=2 | jq '.data | length'` 应返回 2

### TC-U2-003: 无已发布周报时显示空状态
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-03
- scope_item_id: SCOPE-P1U2-003
- 类型: 反例
- 前置条件: 已登录，reports 表为空或全部 status=draft
- 输入/操作: GET /api/reports?page=1
- 期望输出: HTTP 200，`{"data":[],"pagination":{"page":1,"page_size":10,"total":0,"total_pages":0}}`
- 验证命令: API 返回 total=0，前端显示"暂无周报"

### TC-U2-004: 未携带 token 访问报告列表
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-05
- scope_item_id: SCOPE-P1U2-005
- 类型: 反例
- 前置条件: 后端运行中
- 输入/操作: GET /api/reports?page=1（不携带 Authorization header）
- 期望输出: HTTP 401，`{"error":{"code":"UNAUTHORIZED","message":"请先登录"}}`
- 验证命令: `curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/api/reports?page=1` 应返回 401

### TC-U2-005: 列表时间倒序验证
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-01
- scope_item_id: SCOPE-P1U2-001
- 类型: 边界
- 前置条件: 已登录，种子数据含不同 created_at 的周报
- 输入/操作: GET /api/reports?page=1
- 期望输出: data 数组中 created_at 严格递减（data[i].created_at > data[i+1].created_at）
- 验证命令: 遍历 data 数组比较相邻元素的 created_at

### TC-U2-006: draft 周报不出现在列表中
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-02
- scope_item_id: SCOPE-P1U2-002
- 类型: 边界
- 前置条件: 种子数据含 2 条 draft 周报
- 输入/操作: 获取所有页数据，收集所有返回的 report id
- 期望输出: 返回的 id 集合不包含 draft 周报的 id（R3 业务规则）
- 验证命令: `sqlite3 data/weekly_report.db "SELECT id FROM reports WHERE status='draft'"` 的结果不在 API 返回中

### TC-U2-007: 恰好 10 条 published 时无分页
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-04
- scope_item_id: SCOPE-P1U2-004
- 类型: 边界
- 前置条件: 数据库恰好 10 条 published 周报
- 输入/操作: GET /api/reports?page=1
- 期望输出: pagination.total=10, pagination.total_pages=1，前端不显示分页控件
- 验证命令: API 返回 total_pages=1

### TC-U2-008: 页码越界返回空列表
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-06
- scope_item_id: SCOPE-P1U2-006
- 类型: 边界
- 前置条件: 已登录，种子数据 12 条 published（共 2 页）
- 输入/操作: GET /api/reports?page=999
- 期望输出: HTTP 200，data=[]，pagination.total=12, pagination.total_pages=2（total 仍正确）
- 验证命令: `curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/reports?page=999 | jq '.data | length, .pagination.total'` 应返回 0 和 12

### TC-U2-009: created_at 格式为 ISO 8601
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-01
- scope_item_id: SCOPE-P1U2-001
- 类型: 专项测试
- 前置条件: 已登录
- 输入/操作: GET /api/reports?page=1，检查 data[0].created_at 格式
- 期望输出: created_at 匹配 `YYYY-MM-DDTHH:MM:SSZ` 格式（ISO 8601，design 明确要求 API 层转换）
- 验证命令: `curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/reports?page=1 | jq '.data[0].created_at'` 应匹配正则 `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$`

### TC-U2-010: 排除项 — 不存在周报详情接口
- 关联 UNIT: UNIT-2
- 关联 AC: 排除项
- scope_item_id: SCOPE-P1U2-EX1
- 类型: 排除项验证
- 前置条件: 后端运行中
- 输入/操作: GET /api/reports/1
- 期望输出: HTTP 404 或 405
- 验证命令: `curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/reports/1` 应返回 404/405

### TC-U2-011: 排除项 — 不存在搜索接口
- 关联 UNIT: UNIT-2
- 关联 AC: 排除项
- scope_item_id: SCOPE-P1U2-EX2
- 类型: 排除项验证
- 前置条件: 后端运行中
- 输入/操作: GET /api/reports/search?q=test
- 期望输出: HTTP 404 或 405
- 验证命令: `curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/reports/search?q=test` 应返回 404/405

### TC-U2-012: API 服务端错误时前端显示错误提示
- 关联 UNIT: UNIT-2
- 关联 AC: AC-U2-05
- scope_item_id: SCOPE-P1U2-005
- 类型: 反例
- 前置条件: 已登录，后端在请求处理中触发 500 错误（如数据库文件损坏或被删除）
- 输入/操作: 停止后端服务或删除 SQLite 文件后，前端请求 GET /api/reports
- 期望输出: 前端显示错误提示"加载失败，请刷新重试"，不显示空白页或未处理异常
- 验证命令: 停止后端后在浏览器访问首页，确认错误提示组件出现

## 专项测试触发依据与展开策略

| 专项类型 | 触发依据 | 展开策略 | 备注 |
|---------|---------|---------|------|
| 契约 | design 明确 created_at ISO 8601 转换 | TC-U2-009（格式验证） | 后端 SQLite datetime 到 API ISO 8601 转换 |

## 审查结论
- 测试质量: WARN (5, R1 含 1 FAIL 已修复) | 产品: WARN (2) | 架构: WARN (3)
- R1 FAIL 项（U2-I01: AC-U2-05 覆盖缺失）已修复：新增 TC-U2-012
- WARN 承接：CORS/性能 → 集成测试阶段
- 详见: testdesign-cross-review.md
