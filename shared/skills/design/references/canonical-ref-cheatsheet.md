# design.json 引用约束速查表

用途：S4/S7/S9/S11 写入或自检 `design.json` 时快速对照 `validate_canonical_rules.py` 的高频硬约束。这里是执行速查，不替代 schema、template 或 reviewer 结论。

## 1. Manager 引用

- `verification_mapping[*].manager_vp_ref` 只允许 `phase-prd.<field>[<index>]`。
- 可用字段来自 `phase-prd.json` 的数组字段，例如 `exit_conditions[0]`、`business_flows[1]`、`rule_mappings[2]`。
- 不要把 AC 编号、设计决策、中文说明塞进 `manager_vp_ref`；这些语义写到 `design_validation`。

常见 FAIL：
- `unsupported manager ref`
- `manager ref out of range`

## 2. Handoff 引用

- `product_handoff.accepted_refs[*]` 只允许 `brief.json#...` 或 `phase-prd.json#...`。
- 支持 JSON Pointer，例如 `brief.json#/scope/primary_goal`。
- 支持字段锚点，例如 `phase-prd.json#unit_index`。
- 不允许 `UNIT-*`、`design.json#...` 或省略 `.json`。

常见 FAIL：
- `unsupported handoff ref`
- `handoff ref does not resolve`

## 3. 设计引用白名单

- `unit_coverage[*].design_refs` 只引用 `modules[*].module_id` 或 `interfaces[*].interface_id`。
- `impact_scope[*].affected_modules` 只引用 `modules[*].module_id`。
- 不要把决策 id、验证 id、数据库表名或接口说明写进上述引用数组。

常见 FAIL：
- `unit_coverage references unknown design refs`
- `impact_scope references unknown modules`

## 4. AC 引用

- `unit_coverage[*].ac_refs` 必须来自同一个 UNIT 文件里的 `acceptance_criteria[*].ac_id`。
- 不允许跨 UNIT 引用 AC。
- UNIT 没覆盖到的 AC 先回 PM/测试设计澄清，别在 design 里临时发明。

常见 FAIL：
- `unit_coverage references unknown ACs`

## 5. Verification 闭环

- 先写 `verification_mapping[*].evidence_ref`。
- 再让下面字段的 `verification_refs[*]` 只引用这些 `evidence_ref`：
  - `quality_attributes[*].verification_refs`
  - `cross_cutting_concerns[*].verification_refs`
  - `impact_scope[*].verification_refs`
  - `risk_response[*].verification_refs`
- 不要引用 `verification_plan` id、数组下标或自然语言描述。

常见 FAIL：
- `verification_refs unresolved refs`

## 6. Risk / WARN 闭环

- 每个 `risks[*].risk_id` 都必须有对应 `risk_response[*].risk_id`。
- 每个 `risk_response` 至少有 `verification_refs` 或 `escalation_path`。
- reviewer WARN 的 `finding_refs` 必须进入 `warn_followups[*].finding_id`。
- `warn_followups[*].target` 只允许：
  - `design.json#planning_constraints`
  - `design.json#risk_response`
  - `design.json#verification_mapping`
  - `design.json#product_handoff`

常见 FAIL：
- `risk_response missing risk ids`
- `missing warn_followups`
- `warn_followups target unsupported`

## 7. 必须集合

- reviewer 必须覆盖 `architecture / product / test` 三类。
- `co_creation_summary.covered_steps` 覆盖 S2-S8。
- `cross_cutting_concerns` 覆盖当前 phase 涉及的 auth、error、logging、config、data、security、observability 等横切面；确实不适用时在 summary 说明。
- `runtime_facts[*]` 必须包含 `evidence=` 和 `observed_at=`。

## 8. S9 自检清单

- `manager_vp_ref` 均为 `phase-prd.<field>[<index>]`。
- `design_refs` 只含 MOD/IF。
- `affected_modules` 只含 MOD。
- `verification_refs` 全部能在 `verification_mapping[*].evidence_ref` 找到。
- `risk_response` 覆盖全部 risks。
- WARN finding 均有 followup，target 属于 4 个允许值。
- `co_creation_summary` 覆盖 S2-S8。
- 运行 schema、rules、digest、reference integrity、phase validator；任一 FAIL 只做最小修正。
