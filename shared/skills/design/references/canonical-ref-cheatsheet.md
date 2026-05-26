# design.json 引用约束速查表

用途：写入或自检 `design.json` 时快速定位高频引用错误。先按 template/schema 写字段，再用本表修正 validator 报错。

## 1. Manager 引用

- `verification_mapping[*].manager_vp_ref` 只允许 `phase-prd.<field>[<index>]`。
- 可用字段来自 `phase-prd.json` 数组字段，例如 `exit_conditions[0]`、`business_flows[1]`、`rule_mappings[2]`。
- AC 编号、设计决策和中文说明写入 `design_validation`。

常见 FAIL：
- `unsupported manager ref`
- `manager ref out of range`

## 2. Handoff 引用

- `product_handoff.accepted_refs[*]` 只允许 `brief.json#...` 或 `phase-prd.json#...`。
- 支持 JSON Pointer，例如 `brief.json#/scope/primary_goal`。
- 支持字段锚点，例如 `phase-prd.json#unit_index`。
- Handoff ref 写完整文件名和锚点；`UNIT-*`、`design.json#...` 和省略 `.json` 会被 gate 拒绝。

常见 FAIL：
- `unsupported handoff ref`
- `handoff ref does not resolve`

## 3. 设计引用白名单

- `unit_coverage[*].design_refs` 只引用 `modules[*].module_id` 或 `interfaces[*].interface_id`。
- `impact_scope[*].affected_modules` 只引用 `modules[*].module_id`。
- 决策 id、验证 id、数据库表名和接口说明写入对应说明字段。

常见 FAIL：
- `unit_coverage references unknown design refs`
- `impact_scope references unknown modules`

## 4. AC 引用

- `unit_coverage[*].ac_refs` 必须来自同一个 UNIT 文件里的 `acceptance_criteria[*].ac_id`。
- 每条覆盖记录只引用自己的 UNIT。
- UNIT 未覆盖到的 AC 停止冻结；输出 owner、缺失 AC、影响字段和恢复条件。

常见 FAIL：
- `unit_coverage references unknown ACs`

## 5. Verification 闭环

- 先写 `verification_mapping[*].evidence_ref`。
- 再让下面字段的 `verification_refs[*]` 只引用这些 `evidence_ref`：
  - `quality_attributes[*].verification_refs`
  - `cross_cutting_concerns[*].verification_refs`
  - `impact_scope[*].verification_refs`
  - `risk_response[*].verification_refs`
- `verification_plan` id、数组下标和自然语言描述写入说明字段。

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
- `design_stage_confirmations` 覆盖全部设计确认语义阶段。
- `cross_cutting_concerns` 固定覆盖 auth、error、log、config；data、security、observability 的设计写入对应数据、安全或验证字段。
- `runtime_facts[*]` 必须包含 `evidence=` 和 `observed_at=`。

## 8. Owner Self-Check 清单

- `manager_vp_ref` 均为 `phase-prd.<field>[<index>]`。
- `design_refs` 只含 MOD/IF。
- `affected_modules` 只含 MOD。
- `verification_refs` 全部能在 `verification_mapping[*].evidence_ref` 找到。
- `risk_response` 覆盖全部 risks。
- WARN finding 均有 followup，target 属于 4 个允许值。
- `design_stage_confirmations` 覆盖全部设计确认语义阶段。
- 运行 schema、rules、digest、reference integrity、phase validator；任一 FAIL 只做最小修正。
