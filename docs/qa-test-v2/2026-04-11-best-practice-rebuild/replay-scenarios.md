# QA/Test v2 Replay Scenarios

## 用途
用历史高风险模式回放，判断 `test-design -> qa -> project-manager` 是否能在当前链路中被显式捕获，而不是靠经验兜底。

## 场景 1：接口字段变更导致旧客户端失败
- 风险模式：API 返回结构变化，但 happy path 手工验证仍然通过
- `test-design` 触发：`API/接口` + `契约/NFR`
- 预期 `qa` 承接：`QA_A` 执行接口验收，`QA_C` 执行回归/影响面验证
- 预期 `QAR-*`：`QAR-001`，`severity=S1`，`priority=P0`，`impact_scope=共享接口`
- 预期放行建议：`阻塞`

## 场景 2：核心流程成功，但失败后重试会重复提交
- 风险模式：正常路径通过，异常恢复路径缺陷逃逸
- `test-design` 触发：`E2E` + `异常恢复`
- `execution_mode` 预期：`browser_required`（Web/H5 登录后失败重试与状态恢复）
- 预期 `qa` 承接：`QA_B`
- 预期 `QAR-*`：`QAR-002`，`severity=S1`，`priority=P0`，`impact_scope=核心旅程`
- 预期放行建议：`阻塞`

## 场景 3：页面功能可用，但错误提示不可理解导致用户无法自救
- 风险模式：功能通过，UX 状态反馈差
- `test-design` 触发：`UX`
- `execution_mode` 预期：`browser_required`（错误提示与页面反馈决定是否通过验收）
- 预期 `qa` 承接：`QA_B`
- 预期 `QAR-*`：`QAR-003`，`severity=S2`，`priority=P1`，`impact_scope=关键交互`
- 预期放行建议：`条件放行` 或 `阻塞`

## 场景 6：登录/重定向正常，但路由守卫失效导致越权进入
- 风险模式：API 返回成功，后端状态也正确，但浏览器入口与路由行为错误
- `test-design` 触发：`E2E` + `UX`
- `execution_mode` 预期：`browser_required`（登录/权限/重定向/路由守卫）
- 预期 `qa` 承接：`QA_B`
- 预期 `QAR-*`：`QAR-006`，`severity=S1`，`priority=P0`，`impact_scope=核心入口`
- 预期放行建议：`阻塞`

## 场景 7：多步骤表单可提交，但中途返回后状态丢失
- 风险模式：接口提交成功，但多步骤页面状态、步骤导航与恢复体验错误
- `test-design` 触发：`E2E` + `UX` + `异常恢复`
- `execution_mode` 预期：`browser_required`（多步骤表单/向导/下单流）
- 预期 `qa` 承接：`QA_B`
- 预期 `QAR-*`：`QAR-007`，`severity=S2`，`priority=P1`，`impact_scope=关键流程`
- 预期放行建议：`阻塞`

## 场景 4：功能新增后破坏了相邻模块的查询结果
- 风险模式：变更点本身可用，但影响面回归缺失
- `test-design` 触发：`回归`
- 预期 `qa` 承接：`QA_C`
- 预期 `QAR-*`：`QAR-004`，`severity=S1`，`priority=P0`，`impact_scope=受影响面`
- 预期放行建议：`阻塞`

## 场景 5：高风险路径没有触发专项测试，但团队打算先上线观察
- 风险模式：存在未执行义务与风险接受
- `test-design` 触发：`NFR`
- 预期 `qa` 承接：在对应阶段记录 `not_executed_reason`
- 预期 `QAR-*`：允许无缺陷，但必须有 `residual_risk`
- 预期放行建议：`条件放行`

## 通过标准
- 每个场景都能映射到 `test-design` 的 `QA 交接契约`
- 每个场景都能映射到 `qa` 的唯一阶段或 `NFR` overlay
- 每个场景都能解释 `acceptance-summary` 如何承接 `QAR-*` 与 `release_recommendation`

## 本次 replay 执行记录

| 场景 | 执行方式 | 证据 | 结果 | 结论 |
|------|---------|------|------|------|
| 场景 1：接口字段变更 | 静态链路回放 + shell contract tests | `test-cases-template.md` 的 `API/接口` 义务、`qa-report-template.md` 的 triage 字段、`bash tests/test-skill-output-and-gate-contract.sh` | PASS | 能显式触发 `QA_A/QA_C`、形成 `QAR-*`、并进入放行判断 |
| 场景 2：失败后重试重复提交 | 静态链路回放 + shell contract tests | `test-cases-template.md` 的 `异常恢复` 义务、`qa-stage-obligation-matrix.md`、`e2e-journey-methodology.md` | PASS | 能显式落到 `QA_B`，并通过 `release_recommendation` 支撑阻塞 |
| 场景 3：错误提示不可理解 | 静态链路回放 + shell contract tests | `test-cases-template.md` 的 `UX` 义务、`e2e-journey-methodology.md` 的 UX 检查点、`qa-report-template.md` 的 `user_impact` | PASS | UX 已进入可追责 QA 证据链，而不是可选备注 |
| 场景 4：新增功能破坏相邻模块 | 静态链路回放 + shell contract tests | `test-cases-template.md` 的 `回归` 义务、`regression-methodology.md`、`project-manager/completion_check.sh` 的 `AC->TC` 闭环校验 | PASS | 回归风险能显式落到 `QA_C`，并被 acceptance 签收链消费 |
| 场景 5：高风险专项未执行但先上线观察 | 静态链路回放 + shell contract tests | `QA 交接契约` 的 `NFR`、`qa-report-template.md` 的 `not_executed_reason`、`release-decision-methodology.md` | PASS | 能明确记录未执行原因、残余风险与条件放行边界 |
| 场景 6：登录/重定向/路由守卫 | 静态链路回放 + shell contract tests | `test-cases-template.md` 的 `execution_mode`、`e2e-journey-methodology.md` 的浏览器 E2E 定义、`qa/completion_check.sh` 的浏览器证据门禁 | PASS | 登录/权限/重定向/路由守卫已被显式判定为 `browser_required`，不能再被 API-only 验证替代 |
| 场景 7：多步骤表单 / 向导 / 下单流 | 静态链路回放 + shell contract tests | `test-cases-template.md` 的 `browser_required` 默认场景、`e2e-journey-methodology.md` 的浏览器 E2E 规则、`qa-report-template.md` 的浏览器证据字段 | PASS | 多步骤页面状态与恢复体验已纳入浏览器 E2E replay 范围 |

### 实际证据
- proving command 1：`bash tests/test-skill-output-and-gate-contract.sh` → `[PASS] skill output/gate contract`
- proving command 2：`bash tests/test-project-manager-phase3-contract.sh` → `[PASS] project-manager phase3 contract`

### 结论
- replay 场景总数：`7`
- 通过：`7`
- 失败：`0`
- 结论：`当前 QA/Test v2 已具备 pilot 所需的 replay 证据`
