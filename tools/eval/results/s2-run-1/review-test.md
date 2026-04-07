## 测试审查报告

Verdict: FAIL
Issue Count: 7

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 建议 |
|----------|----------|------|------|------|------|
| T-001 | FAIL | DT-2 | 验证步骤与种子数据直接矛盾：验证步骤 2 要求确认"12 条已发布周报分 2 页展示（第 2 页 2 条）"，但种子数据章节明确只有 10 条 published 周报。10 条只填满 1 页（每页 10 条），第 2 页根本不存在。12 ≠ 10，且 10 条数据无法产生第 2 页。 | 设计文档"种子数据"节："3 个预置用户 + 10 条 status=published 的周报"；"验证步骤"节第 2 条："确认 12 条已发布周报分 2 页展示（每页 10 条，第 2 页 2 条）"；PRD 范围节同样确认种子数据为"3用户+10周报" | 种子数据与验证步骤必须对齐：若保持 10 条种子数据，验证步骤应改为"确认 10 条展示在第 1 页（共 1 页，total=10）"；若需测试分页，则种子数据需增至 ≥ 11 条并在 schema 节明确声明 |
| T-002 | FAIL | DT-2 | CORS 配置完全缺失：接口设计章节未提及任何 CORS 配置方案，导致 React 前端（dev server 通常为 localhost:3000/5173）无法调用 FastAPI 后端（localhost:8000）。所有涉及前后端联调的浏览器端测试将因 CORS 预检请求失败而系统性阻断。 | PRD CON-004 明确要求："前后端分离需配置 CORS 策略（FastAPI 默认拒绝跨域，React dev server 域不同）"，Owner 为 design，状态为 KNOWN；设计文档接口设计章节覆盖了 3 个 endpoint，但全文无任何 CORS 相关内容 | 接口设计章节需补充 CORS 配置方案：明确允许的 origin 列表（dev/prod 分别列出）、`allow_credentials=True`（httpOnly cookie 必须）、allowed methods 和 headers |
| T-003 | WARN | DT-2 | `GET /api/reports` 分页边界行为未定义：设计未说明 `page=0`、`page` 为负数、`page` 超过 `total_pages`、`page` 为非整数时的行为和错误码。这些情形在自动化测试中是必测边界，缺乏定义导致实现行为不确定，测试无法写出确定性断言。 | 接口设计："`?page=1&per_page=10`"，仅描述正常路径，无任何边界或错误码定义；PRD R4："分页每页 10 条，首页默认第 1 页"，未补充异常情形 | 补充边界规则：page < 1 → 400 或 clamp 到 1（需明确选择）；page > total_pages → 返回空列表（total 仍准确）；非整数 → 422 |
| T-004 | WARN | DT-2 | `POST /api/auth/login` 缺少请求体格式异常的错误码定义：仅定义了 401（密码错误），未定义请求体缺少字段或类型不符时的响应（FastAPI 默认返回 422，但设计未明确声明，自动化测试无法对此产生确定性断言）。 | 接口设计 POST /api/auth/login 节："失败响应：`401 { \"detail\": \"用户名或密码错误\" }`"；无其他错误码定义 | 补充：请求体字段缺失/类型错误 → 422 Unprocessable Entity（FastAPI 默认行为需显式文档化以锁定契约） |
| T-005 | WARN | DT-2 | `GET /api/auth/me` 未区分 token 过期与 token 格式非法两种异常：验证步骤第 4 条只测试"过期 token"，接口定义将两种情形合并为同一 401，但实现中处理路径不同，需独立验证。 | 接口设计："401 { \"detail\": \"未登录或 token 已过期\" }"；验证步骤第 4 条："使用过期 token 访问，确认返回 401"；无篡改/格式非法 token 的验证步骤 | 新增验证步骤：使用格式非法 token（如随机字符串）访问 `/api/auth/me`，确认同样返回 401，覆盖 JWT 解析失败的独立代码路径 |
| T-006 | WARN | DT-1 | 无依赖隔离设计：设计未描述任何 service 层、repository 层或依赖注入机制。FastAPI 路由直接内联 SQL，单元测试无法在不启动真实 SQLite 数据库的情况下测试业务逻辑，测试间数据污染风险高。 | 接口设计 GET /api/reports 节直接内联 SQL："`SELECT ... FROM reports WHERE status='published' ORDER BY created_at DESC LIMIT ? OFFSET ?`"；全文无 service/repository 分层或测试隔离机制描述 | 设计应至少描述"测试时可替换的数据库连接方式"（如 FastAPI dependency_overrides 替换 DB 连接），以支持集成测试隔离，避免测试间状态污染 |
| T-007 | WARN | DT-3 | 关键链路无可观测性设计：全文无 request_id、结构化日志、tracing 或 metrics。PRD GAC-002 要求响应 < 500ms，上线后无任何手段验证此目标是否持续满足。PRD 虽全局排除了监控平台，但连最小可观测手段（如耗时日志）也未声明。 | PRD GAC-002："GET /api/reports 响应时间 < 500ms（Chrome DevTools Network 面板测量）"；PRD 全局排除项："日志/监控/告警"；设计文档全文无任何 logging、metrics 或 tracing 内容 | 建议在接口设计中至少声明：后端对每次请求记录耗时到 stdout（结构化格式），以便在无完整监控平台时也能手动验证 GAC-002 |

### 关键问题（FAIL 项详述）

#### T-001 — 种子数据与验证步骤数量矛盾

设计文档在两个独立章节给出了相互矛盾的数字：

- **种子数据章节**（数据库 Schema 节）：`3 个预置用户 + 10 条 status=published 的周报`
- **验证步骤第 2 条**：`确认 12 条已发布周报分 2 页展示（每页 10 条，第 2 页 2 条）`

按 PRD 业务规则 R4（每页 10 条），10 条数据只能产生 1 页。"第 2 页 2 条"在 10 条记录的前提下是不可能成立的——第 2 页不存在。此外 10 ≠ 12，数字本身也矛盾。

独立核实：PRD 范围节明确写明"种子数据（3用户+10周报）"，与设计文档种子数据节一致，确认是 10 条而非 12 条。因此验证步骤中的"12 条"和"第 2 页"是设计内部的错误。

**测试后果**：若按验证步骤执行测试，在数据准备阶段就会发现数据与预期不符，测试无法通过。这个矛盾将导致上线前验证不可执行，或者导致开发者错误增加种子数据数量而未意识到设计矛盾。

**修复要求**：设计者必须在以下两个选项中明确选择并保持两处一致：
1. 保持种子数据 10 条 → 验证步骤改为"确认 10 条展示在第 1 页，total=10，total_pages=1"
2. 需要测试分页 → 将种子数据增加到 ≥ 11 条（例如 12 条），在种子数据节明确声明，并对齐验证步骤

#### T-002 — CORS 配置遗漏（PRD CON-004 未落地）

PRD CON-004 将 CORS 配置明确列为 Owner=design、状态=KNOWN 的前置约束，并给出了明确理由："FastAPI 默认拒绝跨域，React dev server 域不同"。设计文档的接口设计章节完整定义了 3 个 API endpoint（POST /api/auth/login、GET /api/reports、GET /api/auth/me），但对 CORS 约束的落地方案只字未提。

独立核实：检查设计文档全文，关键词"CORS"、"跨域"、"cross-origin"、"CORSMiddleware"均未出现。PRD CON-004 对此约束的 Owner 明确指向 design，设计文档应给出实现方案。

**测试后果**：在 CORS 未配置的情况下，任何从 React 前端（浏览器）发起的 HTTP 请求都会被浏览器的同源策略拦截，预检（OPTIONS）请求返回失败。这意味着：
- 登录测试（UNIT-1）无法在浏览器环境执行
- 首页列表测试（UNIT-2）无法在浏览器环境执行
- 路由守卫测试（UNIT-3）无法在浏览器环境执行

这是系统性阻断，而非边缘情形。Postman/curl 测试可以绕过，但完整的前后端集成测试将全部失败。

**修复要求**：接口设计章节需新增 CORS 配置节，明确声明：
- 允许的 origin（dev：localhost:3000/5173，prod：生产域名）
- `allow_credentials=True`（httpOnly cookie 要求此项，缺少则 Set-Cookie 无效）
- allowed methods：GET、POST、OPTIONS（最低限度）
- allowed headers：Content-Type、Authorization

### 改进建议（WARN 项）

**T-003**：`GET /api/reports` 的分页边界情形（page 超界、负数、非整数）需要在接口契约中明确定义错误码和行为。建议明确：`page < 1` 返回 400 或 clamp 到 1（选择其一并文档化）；`page > total_pages` 返回空列表且 total 仍准确；`page` 非整数返回 422。

**T-004**：`POST /api/auth/login` 应显式文档化 422 响应（请求体格式异常）。FastAPI 默认会返回 422，但这属于框架行为而非设计决策，必须在契约中声明才能成为测试可依赖的规范。

**T-005**：应在验证步骤中增加"使用格式非法 token"场景，与"使用过期 token"场景并列，覆盖 JWT 解析失败（vs. 验签失败/过期）的独立代码路径。两种情形在实现中通常是不同的异常分支，需要分别验证。

**T-006**：设计应描述集成测试的数据库隔离机制。推荐方案：通过 FastAPI 的 `dependency_overrides` 在测试时替换数据库连接，每个测试用例使用独立的 in-memory SQLite 实例，避免测试间数据污染。这是可测试性的基础设施要求，应在设计层面声明。

**T-007**：在 PRD 排除完整监控平台的前提下，设计应至少声明最小可观测手段：后端对每次 API 请求记录耗时到 stdout（JSON 结构化格式），字段至少包含 `method`、`path`、`duration_ms`、`status_code`。这样在无监控平台的情况下，仍可手动验证 GAC-002（< 500ms）是否持续满足。
