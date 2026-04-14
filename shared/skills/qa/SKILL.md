---
name: qa
description: 端到端功能验收测试。Use when code-review 通过后需要从用户视角验证功能是否满足 PRD 验收标准。
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# /qa -- 提测后质量验收与放行建议

## Standard-Chain Canonical Lane

运行时只消费 canonical JSON + active registry，不再把 legacy QA markdown 投影视图当运行时真源。

标准链路 qa 真源：
- `contracts/canonical/templates/runtime/qa-result.template.json`

标准输入/输出：
- `artifact-registry.json`
- `docs/{feature}/phase-{N}/qa-result.json`

Canonical override:
- 下文若仍出现 legacy markdown 工件名，只表示历史章节语义。
- standard-chain lane 一律以 `brief.json / phase-prd.json / units/UNIT-*.json / design.json / plan.json / test-cases.json / qa-result.json` 与 `artifact-registry.json` 为唯一运行时输入输出。

## HARD-GATE
1. NO verification without reading `brief.json` + `phase-{N}/phase-prd.json` + `phase-{N}/units/UNIT-*.json` as the acceptance baseline.
   - Why: QA 验收必须对齐业务真源，不能被实现行为反向定义。
2. NO QA run without required `test_cases_ref` / `test_cases_refs`; browser_required 只能由 test_cases_ref 的 QA 交接契约触发，browser E2E evidence is mandatory.
   - Why: `test-design` 负责定义测试义务与触发条件，`qa` 负责承接执行，触发源必须以引用的 QA 交接契约为准，不能靠 QA 自己猜或自报降级。
3. NO test execution without starting the real service first (or equivalent for CLI/lib).
   - Why: 最终验收必须基于真实依赖与真实运行路径。
4. NO PASS/FAIL verdict without `release_recommendation` + `residual_risk` + `uncovered_boundary` + at least 2 ruled-out potential issues.
   - Why: 只给 PASS/FAIL 不足以支撑真实团队的缺陷分级与放行判断。
5. NO FAIL item without `QAR-XXX` + `severity` + `priority` + `impact_scope` + `user_impact` + `environment_or_build` + `regression_flag` + `temporary_workaround` + `owner_hint` + expected/actual/reproduction.
   - Why: 缺陷不可分级、不可复现、不可分派，就不是可操作的 QA 结论。
6. NO PASS without Phase 级 `qa-result.json`.
   - Why: QA 结果是 Phase 级 canonical 交付物，必须能被 `delivery-owner` 的 active registry 和 readiness gate 直接消费。
7. NO PASS in full run without executing `QA_A + QA_B + QA_C + QA_D`; scoped runs MUST mark non-target stages `N/A` and record `not_executed_reason`.
   - Why: 缺少明确未执行原因会制造“好像测过”的假象。

## 前置条件
- `docs/{feature}/brief.json` 必须存在
- `docs/{feature}/phase-{N}/phase-prd.json` 必须存在
- `docs/{feature}/phase-{N}/units/UNIT-*.json` 必须存在
- `docs/{feature}/phase-{N}/plan.json` 建议存在；存在且可解析时用于继承当前消费版本与 gate 基线
- `docs/{feature}/phase-{N}/design.json` 与 `design/MOD-*.md` 为辅助输入
- `docs/{feature}/phase-{N}/unit-{N}/test-cases.json` 必须以 `test_cases_ref` 形式传入；跨 UNIT 的 `QA_B/QA_C/QA_D` 必须额外传入 `test_cases_refs`
- `test_cases_ref / test_cases_refs` 的 `## QA 交接契约` 必须带 `execution_mode`

## Scope 参数
通过 `scope` 参数指定执行范围：

| scope | 执行内容 |
|-------|---------|
| 验证-A | `QA_A`：冒烟 + AC/功能 + API/接口 + MOD/约束验收 |
| 验证-B | `QA_B`：完整旅程 + 异常恢复 + UX 检查点；命中 `browser_required` 时必须走浏览器 E2E |
| 验证-C | `QA_C`：回归验证 + 影响面复核 |
| 验证-D | `QA_D`：探索性测试 + 风险章程 |

> 缺省时执行全部（`QA_A → QA_B → QA_C → QA_D`）。
> `NFR` 不是独立阶段，由 `test_cases_ref` 中的 `QA 交接契约` 触发并挂到对应阶段执行；未执行必须记录 `not_executed_reason`。

## 角色
你是提测后的独立质量判断 owner，负责把 `test-design` 已定义的测试义务落到真实执行证据上，并输出 `baseline_plan_version_ref`、`baseline_tasks_version_ref`、`gate_result`、`release_recommendation`、`residual_risk` 与相关浏览器/风险证据。
你可以承接 `delivery-owner` 发起的升级验证范围，但结论保持独立；你不负责用户 sign-off，也不接受业务风险。

## 流程

### 验证-A: QA_A（冒烟 + AC/功能 + API/接口 + 约束验收）
1. 读取 `brief.json + phase-{N}/phase-prd.json + phase-{N}/units/UNIT-*.json` 建立验收事实基线。
2. 读取 `test_cases_ref` 的 `## QA 交接契约`，确认哪些义务属于 `QA_A`。
3. 读取 `design.json` 获取接口格式、实施约束与错误路径。
4. 启动真实服务并完成冒烟检查。
5. 按顺序执行：反例 → 边界 → 正例 → 排除项。
6. 对 `API/接口`、`MOD/约束`、`NFR` 中分配给 `QA_A` 的义务逐条验收。
7. 输出 `QA_A UNIT 执行汇总` 与 `AC 追踪表`。

### 验证-B: QA_B（旅程 + 异常恢复 + UX）
当设计和执行 E2E 旅程时：
→ 读取 `references/qa-stage-obligation-matrix.md`
→ 读取 `references/e2e-journey-methodology.md`

1. 基于 `test_cases_refs` 组合核心旅程与异常旅程。
2. 读取 `test_cases_ref / test_cases_refs` 的 QA 交接契约；当 `QA_B` 义务命中 `browser_required` 时，必须使用浏览器执行，不能用 API/CLI 替代，也不能让 `qa-result.json` 自报 `non_browser_ok` 绕过。
3. 浏览器执行默认使用 `webapp-testing` / Playwright 能力；允许项目浏览器插件替代，但证据强度必须等价。
4. 当 `execution_mode=browser_required` 时，必须在 `qa-result.json` 写入 `browser_tool`、`entry_url`、`browser_evidence`。
5. 覆盖至少 1 条完整旅程，并验证跨步骤数据流转。
6. 执行 `UX` 与 `异常恢复` 检查点；若被触发的义务未执行，必须记录 `not_executed_reason`。

### 验证-C: QA_C（回归 + 影响面）
当执行回归验证时：
→ 读取 `references/qa-stage-obligation-matrix.md`
→ 读取 `references/regression-methodology.md`

1. 基于变更影响面和 `test_cases_refs` 判断回归边界。
2. 执行回归命令或手工核心路径验证。
3. 对影响面中的高风险区域追加验证。

### 验证-D: QA_D（探索）
当执行探索性测试时：
→ 读取 `references/qa-stage-obligation-matrix.md`
→ 读取 `references/exploratory-testing-methodology.md`

1. 基于 `test_cases_refs` 制定风险章程。
2. 沿高风险路径做时间盒探索。
3. 记录发现、证据与未命中的探索理由。

### 放行判断
当输出放行结论时：
→ 读取 `references/release-decision-methodology.md`

1. 汇总 `QAR-*` 缺陷、`waiver`、`residual_risk`、`uncovered_boundary`、`not_executed_reason`。
2. 输出 `release_recommendation: 放行 | 条件放行 | 阻塞`。

## FORBIDDEN
- Do NOT 修改任何代码文件
- Do NOT 用 implementation code 当验收标准
- Do NOT 读取 `developer-report.json` 或 `code-review-result.json` 代替独立 QA 判断
- Do NOT 把 `ux.md` 当成唯一 UX 来源；它只是不补充输入

## 输出
输出到 `{phase_dir}/qa-result.json`（Phase 级）。
运行时模板：`contracts/canonical/templates/runtime/qa-result.template.json`

必填内容：
- `审查分级: 轻量|标准|完整|未指定`
- `执行范围: full|验证-A|验证-B|验证-C|验证-D`
- `baseline_plan_version_ref`
- `baseline_tasks_version_ref`
- `gate_result`
- `release_recommendation`
- `residual_risk`
- `uncovered_boundary`
- `conditional_release_basis`（`release_recommendation=条件放行` 时必填）
- `browser_tool`（命中 `browser_required` 时必填）
- `entry_url`（命中 `browser_required` 时必填）
- `browser_evidence`（命中 `browser_required` 时必填，至少包含 screenshot / trace/video / browser log / 明确的 Playwright 或 webapp-testing 输出锚点之一）
- `## 验收汇总`
- `### QA_A UNIT 执行汇总`
- `### AC 追踪表`
- `## 非执行项记录`（存在 `N/A` 或未执行义务时必填）
- `## 已排除潜在问题`（至少 2 条）
- `## FAIL 详情（如有）`
- `RESULT: PASS | FAIL`

`FAIL` 项必须使用稳定 `QAR-XXX`，并带完整 triage 字段。

## 完成校验
- [ ] 已读取 `brief.json + phase-{N}/phase-prd.json + phase-{N}/units/UNIT-*.json + test_cases_ref`
- [ ] `QA_A` 已承接冒烟、AC/功能、API/接口、MOD/约束，以及被触发的 `NFR`
- [ ] `QA_B` 已承接旅程、异常恢复、UX 检查点
- [ ] 命中 `browser_required` 的 `QA_B` 义务已使用浏览器执行，并写入 `browser_tool`、`entry_url`、`browser_evidence`
- [ ] `QA_C` 已承接回归与影响面复核
- [ ] `QA_D` 已承接探索章程与发现记录
- [ ] `qa-result.json` 为 Phase 级 canonical 报告，且包含 `baseline_plan_version_ref`、`baseline_tasks_version_ref`、`gate_result`、`release_recommendation`、`residual_risk`、`not_executed_reason`
- [ ] `FAIL` 项均包含完整 triage 字段与复现证据
