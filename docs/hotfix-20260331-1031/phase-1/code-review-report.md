## Code Review

### 摘要
复审范围：当前工作树对上一轮 `REQUEST_CHANGES` 报告的修复增量，主看 `shared/hooks/lib/common.sh`、`shared/skills/product/references/templates/prd-template.md`、`shared/skills/project-manager/scripts/completion_check.sh`、`shared/skills/tech-lead/scripts/completion_check.sh`、`tests/test-phase-context-resolution.sh`、`tests/test-constraint-closure-contract.sh`、`tests/test-skill-output-and-gate-contract.sh`、`tests/run-all.sh`。

上一版报告中的 4 条阻断问题已修复。follow-up review 又识别出 4 条 residual issue：D2.1 前置约束 pair 仍按正则匹配、D13 acceptance 闭环仍按正则匹配、空 current phase 会跨 phase fallback、以及 product gate 侧 contract 测试缺口；这些问题均已修复并完成 fresh 回归。当前无未解决正式 finding，结论为 `APPROVE`。

### 亮点（可选，1-3 条）
| # | 位置 | 模式描述 | 推广价值 |
|---|------|---------|---------|
| 1 | `shared/hooks/lib/common.sh:269-299` | 把换行列表“等值匹配/前缀过滤”统一抽成字面比较 helper | 后续 shell 门禁可复用，避免路径和自由文本继续落入正则误判 |
| 2 | `shared/skills/project-manager/scripts/completion_check.sh:824-837`; `shared/skills/project-manager/scripts/completion_check.sh:1546-1549` | 把 plan 闭环和 acceptance 闭环统一收口到字面 pair 比较 | 前置约束 contract 在 Phase 2 与 Phase 3 口径一致 |
| 3 | `tests/test-phase-context-resolution.sh:73-80`; `tests/test-constraint-closure-contract.sh:90-108` | 新增空 phase fallback 与 acceptance regex-like pair 的最小回归 | 把本轮最隐蔽的 residual issue 真正锁进 CI |

### 审查-A: 安全与正确性

#### Findings
无未解决正式 finding。

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| EP-001 | 路径含 `[`、`]`、`.` 时，当前 Phase 的 UNIT 路径仍会被误判为“不属于当前 Phase” | `shared/hooks/lib/common.sh:269-299` 新增字面匹配 helper，`shared/skills/project-manager/scripts/completion_check.sh:1283-1373` 已改用 helper；`bash tests/test-phase-context-resolution.sh` fresh 通过。 |
| EP-002 | D13 acceptance 闭环仍把官方模板里的 `[` `]` 当正则解释，导致 `grep: invalid character range` | `shared/skills/project-manager/scripts/completion_check.sh:1546-1549` 已改成 `newline_list_contains_literal "$acceptance_constraint_pairs" "$plan_pair"`；`tests/test-constraint-closure-contract.sh:92-108` 已覆盖 acceptance regex-like pair，fresh 通过。 |
| EP-003 | 当前 phase 已锁定、但当前 phase 没有 `unit-*` 时，`common.sh` 仍会串到旧 phase | `shared/hooks/lib/common.sh:348-352` / `shared/hooks/lib/common.sh:409-416` 已停止跨 phase fallback；最小复现现为 `current=phase-2, all=, unit=phase-2`；`tests/test-phase-context-resolution.sh:73-80` fresh 通过。 |

#### 结论
REVIEW_A_OK

---

### 审查-B: 设计与可维护性

#### Findings
无未解决正式 finding。

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| EP-004 | 官方 PRD 模板仍输出 `## 约束`，继续与 product gate 冲突 | `shared/skills/product/references/templates/prd-template.md:71-77` 已切到 `## 前置约束`；`tests/test-skill-output-and-gate-contract.sh:122-127` 同时锁模板侧和 gate 侧，fresh 通过。 |
| EP-005 | 前置约束闭环只校验 `type/scope_item_id/preflight_ref/test_ref`，`description/owner/affected_unit` 仍会静默漂移 | `shared/skills/tech-lead/scripts/completion_check.sh:875-925` 与 `shared/skills/project-manager/scripts/completion_check.sh:790-837` 已校验并闭环新增字段；`tests/test-constraint-closure-contract.sh:47-72` 对 identity drift 做了行为回归。 |
| EP-006 | 新增回归测试没有接入全量链路，导致局部绿、总链路不覆盖 | `tests/run-all.sh:18-21`、`tests/run-all.sh:44-47`、`tests/run-all.sh:93-96` 已把 `tests/test-constraint-closure-contract.sh` 纳入 syntax/shellcheck/执行三个阶段；fresh `bash tests/run-all.sh` 通过。 |

#### 结论
REVIEW_B_OK

---

### 审查-C: 性能与可观测性

#### Findings
无置信度 >= 80 的正式 finding。

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| EP-007 | 新增 helper 会把原本一次 `grep` 的判断放大成明显性能热点 | `shared/hooks/lib/common.sh:269-299` 与 `shared/hooks/lib/common.sh:284-299` 只在线性遍历当前已解析的换行列表，没有引入全仓库放大扫描；fresh `bash tests/run-all.sh` 无异常。 |
| EP-008 | 修复后错误定位信息变差，门禁失败时不再知道是哪条约束/哪条路径出错 | `shared/skills/project-manager/scripts/completion_check.sh:827-829`、`shared/skills/project-manager/scripts/completion_check.sh:1548-1549`、`shared/skills/project-manager/scripts/completion_check.sh:1283-1285` 仍保留具体 `Constraint ID` / `unit_work_dir` / `UNIT-AC` 对象信息。 |

#### 结论
REVIEW_C_OK

---

### 最终结论
APPROVE

## 覆盖自评

### 已充分覆盖
| 维度 | 检查内容 | 证据 |
|------|---------|------|
| CS-1 正确性 | 复核当前 Phase 路径解析、D2.1/D13 前置约束 pair 闭环和空 phase fallback | `shared/hooks/lib/common.sh:348-352`; `shared/skills/project-manager/scripts/completion_check.sh:824-837`; `shared/skills/project-manager/scripts/completion_check.sh:1546-1549` |
| CS-2 安全性 | 检查 shell 变更未引入 `eval`、未引用变量执行或新的外部输入拼接面 | `shared/hooks/lib/common.sh:269-299`; `shared/skills/tech-lead/scripts/completion_check.sh:863-925`; `shared/skills/project-manager/scripts/completion_check.sh:781-837` |
| CS-3 错误处理 | 复核非法 `Constraint ID`、缺字段、非法 `test_ref`、非法状态仍显式失败 | `shared/skills/tech-lead/scripts/completion_check.sh:866-905`; `shared/skills/project-manager/scripts/completion_check.sh:784-820` |
| CS-4 并发/状态 | 复核修复未改变 `CURRENT_PHASE_*`、`MAPPED/VERIFIED` 的状态语义，只修正匹配与 fallback 策略 | `shared/hooks/lib/common.sh:399-416`; `shared/skills/project-manager/scripts/completion_check.sh:28-33` |
| CM-1 设计 | 复核前置约束最小对象已在模板、tech-lead、project-manager、acceptance 四处一致 | `shared/skills/product/references/templates/prd-template.md:71-77`; `shared/skills/tech-lead/scripts/completion_check.sh:875-925`; `shared/skills/project-manager/scripts/completion_check.sh:824-837`; `shared/skills/project-manager/scripts/completion_check.sh:1546-1549` |
| CM-2 测试覆盖 | 复核新增行为测试已覆盖空 phase fallback、plan pair、acceptance pair，并接入总链路 | `tests/test-phase-context-resolution.sh:73-80`; `tests/test-constraint-closure-contract.sh:90-108`; `tests/run-all.sh:93-96` |
| CM-3 注释准确性 | 复核模板引导文案与门禁真实消费标题一致 | `shared/skills/product/references/templates/prd-template.md:73-77`; `tests/test-skill-output-and-gate-contract.sh:122-127` |
| CM-4 向后兼容 | 复核官方模板、gate、contract test 已统一到 `前置约束` 真源 | `shared/skills/product/references/templates/prd-template.md:71-77`; `shared/skills/product/scripts/completion_check.sh:58-82`; `tests/test-skill-output-and-gate-contract.sh:122-127` |
| PF-1 性能 | 复核 helper 只在已有结果集上线性工作，不引入仓库级扫描 | `shared/hooks/lib/common.sh:269-299`; fresh `bash tests/run-all.sh` |
| PF-2 可观测性 | 复核关键失败仍带门禁编号和对象标识，定位粒度足够 | `shared/skills/project-manager/scripts/completion_check.sh:1283-1285`; `shared/skills/project-manager/scripts/completion_check.sh:1548-1549` |

### 覆盖盲区（coverage_gaps）
无。

> 本次 `APPROVE` 建立在 fresh 验证之上：`bash tests/test-phase-context-resolution.sh`、`bash tests/test-constraint-closure-contract.sh`、`bash tests/test-project-manager-phase3-contract.sh`、`bash tests/test-skill-output-and-gate-contract.sh`、`bash tests/run-all.sh` 均已重新执行并通过。

## 审查轮次

| 轮次 | 类型 | 新增发现数 | 收敛状态 |
|------|------|-----------|---------|
| Round 1 | 广度复审 | 2 | - |
| Round 2 | 深度聚焦 | 2 | - |
| Round 3 | 对抗复审 | 0 | 收敛 |

### Delta 声明（Round 2+ 必填，Round 1 写"首轮审查"）
- 新增发现: 0 条
- 经 Round 2 确认：Round 1/2 发现的 regex/literal 风险、空 current phase fallback 和模板/gate contract 漂移已全部消解，Round 3 对抗复扫维持 0 条新增 finding，审查收敛。
- Round 1 记录：新增发现 2 条，识别 D2.1 pair 字面匹配缺口，以及 product gate 侧 contract test 缺口。
- Round 2 记录：新增发现 2 条，识别 D13 acceptance pair 字面匹配缺口，以及空 current phase 跨 phase fallback/其测试缺口。
- Round 3 记录：新增发现 0 条，围绕 regex/literal 风险、空 phase fallback、模板/gate 一致性和全量测试接入做对抗复扫。

## Verification 汇总

| 轮次 | 送检数 | Verified | False Positive | Inconclusive |
|------|--------|----------|---------------|-------------|
| R1 | 2 | 2 | 0 | 0 |
| R2 | 2 | 2 | 0 | 0 |
| R3 | 0 | 0 | 0 | 0 |
