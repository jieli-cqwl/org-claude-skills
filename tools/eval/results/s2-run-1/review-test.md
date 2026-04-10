## 测试审查报告

Verdict: FAIL
Issue Count: 7

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|
| DTR-001 | FAIL | DT-2 | 验证步骤与种子数据直接矛盾：验证步骤 2 要求确认“12 条已发布周报分 2 页展示（第 2 页 2 条）”，但种子数据章节明确只有 10 条 published 周报。10 条只填满 1 页（每页 10 条），第 2 页根本不存在。12 ≠ 10，且 10 条数据无法产生第 2 页。 | 设计文档“种子数据”节：“3 个预置用户 + 10 条 status=published 的周报”；“验证步骤”节第 2 条：“确认 12 条已发布周报分 2 页展示（每页 10 条，第 2 页 2 条）”；PRD 范围节同样确认种子数据为“3用户+10周报” | design.md#验证步骤 / design.md#数据库 Schema |
| DTR-002 | FAIL | DT-2 | CORS 配置完全缺失：接口设计章节未提及任何 CORS 配置方案，导致 React 前端（dev server 通常为 localhost:3000/5173）无法调用 FastAPI 后端（localhost:8000）。所有涉及前后端联调的浏览器端测试将因 CORS 预检请求失败而系统性阻断。 | PRD CON-004 明确要求：“前后端分离需配置 CORS 策略（FastAPI 默认拒绝跨域，React dev server 域不同）”，Owner 为 design，状态为 KNOWN；设计文档接口设计章节覆盖了 3 个 endpoint，但全文无任何 CORS 相关内容 | design.md#接口设计 |
| DTR-003 | WARN | DT-2 | `GET /api/reports` 分页边界行为未定义：设计未说明 `page=0`、`page` 为负数、`page` 超过 `total_pages`、`page` 为非整数时的行为和错误码。这些情形在自动化测试中是必测边界，缺乏定义导致实现行为不确定，测试无法写出确定性断言。 | 接口设计：`?page=1&per_page=10`，仅描述正常路径，无任何边界或错误码定义；PRD R4：“分页每页 10 条，首页默认第 1 页”，未补充异常情形 | design.md#接口设计 |
| DTR-004 | WARN | DT-2 | `POST /api/auth/login` 缺少请求体格式异常的错误码定义：仅定义了 401（密码错误），未定义请求体缺少字段或类型不符时的响应。FastAPI 默认返回 422，但设计未明确声明，自动化测试无法对此产生确定性断言。 | 接口设计 `POST /api/auth/login` 节：“失败响应：`401 { \"detail\": \"用户名或密码错误\" }`”；无其他错误码定义 | design.md#接口设计 |
| DTR-005 | WARN | DT-2 | `GET /api/auth/me` 未区分 token 过期与 token 格式非法两种异常：验证步骤第 4 条只测试“过期 token”，接口定义将两种情形合并为同一 401，但实现中处理路径不同，需独立验证。 | 接口设计：“401 { \"detail\": \"未登录或 token 已过期\" }”；验证步骤第 4 条：“使用过期 token 访问，确认返回 401”；无篡改/格式非法 token 的验证步骤 | design.md#验证步骤 / design.md#接口设计 |
| DTR-006 | WARN | DT-1 | 无依赖隔离设计：设计未描述任何 service 层、repository 层或依赖注入机制。FastAPI 路由直接内联 SQL，单元测试无法在不启动真实 SQLite 数据库的情况下测试业务逻辑，测试间数据污染风险高。 | 接口设计 `GET /api/reports` 节直接内联 SQL：`SELECT ... FROM reports WHERE status='published' ORDER BY created_at DESC LIMIT ? OFFSET ?`；全文无 service/repository 分层或测试隔离机制描述 | design.md#接口设计 / test-cases.md#测试隔离 |
| DTR-007 | WARN | DT-3 | 关键链路无可观测性设计：全文无 request_id、结构化日志、tracing 或 metrics。PRD GAC-002 要求响应 < 500ms，上线后无任何手段验证此目标是否持续满足。PRD 虽全局排除了监控平台，但连最小可观测手段（如耗时日志）也未声明。 | PRD GAC-002：“GET /api/reports 响应时间 < 500ms（Chrome DevTools Network 面板测量）”；PRD 全局排除项：“日志/监控/告警”；设计文档全文无任何 logging、metrics 或 tracing 内容 | design.md#验证与可观测性 |

### 关键问题（FAIL 项详述）

#### DTR-001：种子数据与验证步骤数量矛盾

问题：设计文档种子数据章节写明“3 个预置用户 + 10 条 status=published 的周报”，验证步骤第 2 条却要求确认“12 条已发布周报分 2 页展示（每页 10 条，第 2 页 2 条）”。按每页 10 条的业务规则，10 条数据只能产生 1 页，且 10 与 12 数量直接冲突。

影响：测试在数据准备阶段就会碰到不可执行的验收条件。若按 10 条数据准备环境，分页验证无法成立；若按 12 条数据强行补齐，又会偏离 PRD 与设计文档的既有声明，导致自动化与人工验收都失去确定基线。

修复要求：设计者必须统一种子数据与验证步骤的数量口径。若保留 10 条数据，验证步骤应改为 1 页断言；若需要覆盖分页验证，则应把种子数据提升到至少 11 条，并同步对齐 PRD、设计文档和验证步骤。

#### DTR-002：CORS 配置遗漏

问题：PRD CON-004 已将 CORS 配置列为 Owner=`design`、状态=KNOWN 的前置约束，但设计文档的接口设计章节没有任何 CORS 方案。全文检索 `CORS`、`跨域`、`cross-origin`、`CORSMiddleware` 均无结果，说明该约束没有被设计承接。

影响：浏览器环境下的前后端联调会被同源策略系统性阻断。登录测试、首页列表测试和路由守卫测试都会在预检请求阶段失败，导致完整的浏览器端集成验证不可执行；仅靠 `curl` 或 Postman 成功，无法替代真实联调验收。

修复要求：在接口设计中新增 CORS 配置约束，至少明确开发态与生产态允许的 origin、`allow_credentials=True`、允许的方法和请求头，并说明这些配置如何满足 cookie 认证链路的跨域要求。

### 改进建议（WARN 项）

#### DTR-003：补齐 `GET /api/reports` 的分页边界定义（WARN）
`GET /api/reports` 的分页边界情形（page 超界、负数、非整数）需要在接口契约中明确定义错误码和行为。建议明确：`page < 1` 返回 400 或 clamp 到 1（选择其一并文档化）；`page > total_pages` 返回空列表且 total 仍准确；`page` 非整数返回 422。

#### DTR-004：显式文档化 `POST /api/auth/login` 的 422 响应（WARN）
`POST /api/auth/login` 应显式文档化 422 响应（请求体格式异常）。FastAPI 默认会返回 422，但这属于框架行为而非设计决策，必须在契约中声明才能成为测试可依赖的规范。

#### DTR-005：增加“格式非法 token”验证场景（WARN）
应在验证步骤中增加“使用格式非法 token”场景，与“使用过期 token”场景并列，覆盖 JWT 解析失败（vs. 验签失败/过期）的独立代码路径。两种情形在实现中通常是不同的异常分支，需要分别验证。

#### DTR-006：声明集成测试的数据库隔离机制（WARN）
设计应描述集成测试的数据库隔离机制。推荐方案：通过 FastAPI 的 `dependency_overrides` 在测试时替换数据库连接，每个测试用例使用独立的 in-memory SQLite 实例，避免测试间数据污染。这是可测试性的基础设施要求，应在设计层面声明。

#### DTR-007：补齐最小可观测手段（WARN）
在 PRD 排除完整监控平台的前提下，设计应至少声明最小可观测手段：后端对每次 API 请求记录耗时到 stdout（JSON 结构化格式），字段至少包含 `method`、`path`、`duration_ms`、`status_code`。这样在无监控平台的情况下，仍可手动验证 GAC-002（< 500ms）是否持续满足。
