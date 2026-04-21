# qa-report.md

> Phase 级 QA 汇总报告。`QA_A` 按 UNIT 执行并汇总到本报告；`qa-report.md` 的唯一权威落点为 `phase_dir/qa-report.md`。

> 强门禁固定跟踪 `QA_A / QA_B / QA_C / QA_D`，并同步写入 `qa-result.json.qa`。

执行范围: {full, 验证-A, 验证-B, 验证-C, 验证-D}
> 允许在执行范围后追加括号说明，例如 `full（含验证-A/B/C/D）`。
plan_version_ref: {当前消费的 plan.md#计划版本}
plan_version_value: {当前消费版本，如 v1 / v2}
release_recommendation: {放行, 条件放行, 阻塞}
<a id="residual-risk"></a>
residual_risk: {说明残余风险、风险接受边界与上线关注点}
uncovered_boundary: {仍未覆盖、未执行或只做条件承接的边界；无则写无}
conditional_release_basis: {条件放行时必填；放行/阻塞时写无或明确理由}
issue_ledger_anchor: {指向本报告 FAIL 详情的锚点}

> `plan_version_ref` 与 `plan_version_value` 必须成对更新；发生 `REPLAN` 后，旧版本结果不得继续作为 QA 结论基线。
> `issue_ledger_anchor` 固定填写为 `qa-report.md#fail-details`，并指向本报告 `## FAIL 详情`；即使当前没有 FAIL 记录，也保留空章节供 acceptance / pilot 抽查。

## 审查轮次记录
| 轮次 | 审查 commit SHA | FAIL 数 | delta |
|------|----------------|---------|-------|
| R1 | {commit SHA} | {N} | — |

## 输入分析
- Phase 输入：{brief.md 全局约束 + UNIT 列表 + phase_dir 共享 design/MOD 约束}
- QA_A 当前输入：{unit_work_dir + test_cases_ref}
- QA_B/C/D 输入：{覆盖的 UNIT 集合 + test_cases_refs[]}
- 交接契约：{来自 test_cases_ref 的 QA 交接契约}

## 决策
{验收方法：QA_A 按 UNIT 串行执行并持续回写 Phase 报告，Phase 汇总按 QA_A → QA_B → QA_C → QA_D 收敛}

## 产出
INFRA_ERROR: {yes, no}

## 验收汇总

> OK 阶段精简规则：阶段状态为 OK 且无 ISSUE 时，只保留结论行和汇总表行。禁止对 OK 阶段添加正面评述或详细叙述“为什么通过”。

| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | {OK, ISSUE, N/A} | 0 | {按 UNIT 聚合后的结论} |
| QA_B（E2E 旅程） | {OK, ISSUE, N/A} | 0 | {概述或未执行原因} |
| QA_C（回归验证） | {OK, ISSUE, N/A} | 0 | {概述或未执行原因} |
| QA_D（探索性测试） | {OK, ISSUE, N/A} | 0 | {概述或未执行原因} |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_B | {scope=验证-A，本轮未执行 / 未触发原因} |
| UX | {未被交接契约触发 / 延后原因} |

---

## 验证-A: AC 验收

### 服务启动
{启动命令 + 健康检查结果}

### 全局约束验证
| # | 约束 | 状态 | 证据 |

### QA_A UNIT 执行汇总
| UNIT | unit_work_dir | test_cases_ref | 状态 | issue_ids | 说明 |
|------|---------------|----------------|------|-----------|------|
| UNIT-1 | unit-1 | unit-1/test-cases.md | {OK, ISSUE} | {QAR-001} | {摘要} |

> `unit_work_dir` / `test_cases_ref` 若填写相对路径，必须相对当前 `phase_dir` 解析；若填写绝对路径，必须直接指向当前 Phase 的 UNIT 工件。

### QA_A 交接义务承接
| UNIT | test_obligation | qa_stage | requiredness | 状态 | evidence | not_executed_reason |
|------|-----------------|----------|--------------|------|----------|---------------------|
| UNIT-1 | 冒烟 | QA_A | REQUIRED | {DONE, ISSUE} | {证据} | {N/A} |
| UNIT-1 | API/接口 | QA_A | CONDITIONAL | {DONE, N/A} | {证据} | {未触发理由} |

### UNIT-N: {名称}
unit_work_dir: `unit-N`
test_cases_ref: `unit-N/test-cases.md`

| # | 规则 | 类型 | test_ref | 期望 | 实际 | 状态 |
|---|------|------|----------|------|------|------|

### MOD 实施约束验收（如存在）
| # | MOD | 约束 | 期望 | 实际 | 状态 |

### AC 追踪表
| UNIT | unit_work_dir | AC ID | AC 摘要 | test_ref | 验证方法 | 结果 | 证据摘要 |
|------|---------------|-------|---------|----------|---------|------|---------|

### 验证-A 结论
{QA_A_OK, QA_A_ISSUE}

---

## 验证-B: E2E 用户旅程
### 覆盖范围
- UNIT 集合: {UNIT-1, UNIT-2}
- test_cases_refs: {`{phase_dir}/unit-1/test-cases.md`, `{phase_dir}/unit-2/test-cases.md`}

### 旅程设计
| # | 旅程名称 | 类型 | 涉及 AC | execution_mode | 步骤数 |
|---|---------|------|---------|----------------|--------|

### 浏览器执行信息（仅当 test_cases_ref 的 QA 交接契约触发 `browser_required` 时必填）
browser_tool: {webapp-testing / Playwright / 项目浏览器插件}
entry_url: {http://localhost:3000/login}
browser_evidence: {screenshot=... | trace/video=... | browser_log=... | webapp-testing=...}
> 命中 `test_cases_ref` 的 `browser_required` 时，API/CLI 证据不能替代浏览器证据，也不能由 `qa-report.md` 自报 `non_browser_ok` 覆盖。

### 旅程执行
#### 旅程 1: {名称}
| 步骤 | 操作 | 输入 | 期望输出 | 实际输出 | 状态 |
|------|------|------|---------|---------|------|

#### 数据流转验证
| 步骤 | 前序输出 | 后续输入 | 一致性 |
|------|---------|---------|--------|

#### UX / 异常恢复检查点
| obligation | 检查点 | 状态 | 证据 | not_executed_reason |
|------------|--------|------|------|---------------------|
| UX | {反馈/可理解性/状态可见性} | {DONE, ISSUE, N/A} | {证据} | {原因} |
| 异常恢复 | {重试/幂等/补偿/恢复} | {DONE, ISSUE, N/A} | {证据} | {原因} |

### 验证-B 结论
{QA_B_OK, QA_B_ISSUE}

---

## 验证-C: 回归验证
### 覆盖范围
- UNIT 集合: {UNIT-1, UNIT-2}
- test_cases_refs: {`{phase_dir}/unit-1/test-cases.md`, `{phase_dir}/unit-2/test-cases.md`}

### 变更影响分析
| 修改文件 | 影响面 | 关联功能 | 风险级别 |
|---------|--------|---------|---------|

### 全量测试结果
TEST_CMD: <命令>
通过: N / 失败: N / 跳过: N

### 核心路径验证（如需手动）
| # | 功能 | 验证方式 | 状态 |
|---|------|---------|------|

### NFR / 影响面补充
| obligation | 状态 | 证据 | not_executed_reason |
|------------|------|------|---------------------|
| 性能 | {DONE, ISSUE, N/A} | {证据} | {原因} |
| 契约 | {DONE, ISSUE, N/A} | {证据} | {原因} |

### 验证-C 结论
{QA_C_OK, QA_C_ISSUE}

---

## 验证-D: 探索性测试
### 覆盖范围
- UNIT 集合: {UNIT-1, UNIT-2}
- test_cases_refs: {`{phase_dir}/unit-1/test-cases.md`, `{phase_dir}/unit-2/test-cases.md`}

### 探索章程
- 目标: {测试目标}
- 关注区域: {高风险区域列表}
- 时间盒: {预计时间}

### 探索发现
| # | 探索方向 | 操作描述 | 发现 | 严重度 | 状态 |
|---|---------|---------|------|--------|------|
| 1 | 异常输入组合 | {具体操作} | {发现描述} | {Critical, Major, Minor} | {BUG, OBSERVATION} |

### 验证-D 结论
{QA_D_OK, QA_D_ISSUE}

---

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|
| QAR-001 | QA_A | {S1, S2, S3} | {P0, P1, P2} | {核心旅程/边缘功能/单一 UNIT} | {用户影响} | {环境/构建号} | {yes, no} | {无/临时措施} | {developer/owner} | {期望} | {实际} | {命令} |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | {潜在问题} | {为何排除} | {命令/截图/输出摘要} |
| 2 | {潜在问题} | {为何排除} | {命令/截图/输出摘要} |

## 偏差自检
- 信任偏差 / 正常路径偏差 / 结果确认偏差

## 结果
RESULT: {PASS, FAIL}

<metadata>{"status":"{PASS, FAIL}","release_recommendation":"{放行, 条件放行, 阻塞}","qa":{"QA_A":"{OK, ISSUE, N/A}","QA_B":"{OK, ISSUE, N/A}","QA_C":"{OK, ISSUE, N/A}","QA_D":"{OK, ISSUE, N/A}"},"issue_ids":["QAR-001"],"units_total":N,"units_passed":N,"units_failed":N,"rules_total":N,"rules_passed":N,"rules_failed":N,"ac_total":N,"ac_passed":N,"ac_failed":N,"journeys_tested":N,"regression_tests_passed":N,"exploratory_findings":N}</metadata>

## 交接项
- 逐条 PASS/FAIL 与证据、FAIL 项复现命令、稳定 Issue ID（QAR-XXX）
- `release_recommendation` + `residual_risk` + `uncovered_boundary`
- `conditional_release_basis` + `issue_ledger_anchor`
- E2E 旅程测试摘要
- 回归测试结果
- 探索性测试发现
