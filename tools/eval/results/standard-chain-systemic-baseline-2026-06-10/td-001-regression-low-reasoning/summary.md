# Standard-Chain Local Skill Eval

- total expectations: 16
- failed expectations: 5
- infra failures: 0
- pass rate: 0.69

## Runs
- test-design / typed-gap-routes-to-owner: 3/5 passed
  - failed: 输出 DESIGN_GAP 或 TESTABILITY_GAP，引用 product/design 证据，说明无法形成数据一致性或回滚测试义务，给出 owner、required_artifact_ref、decision_needed 和 blocking 裁决。
  - failed: 引用产品和设计证据
- test-design / ac-boundary-exclusion-coverage: 1/4 passed
  - failed: 说明在 ac_coverage_matrix 中逐 AC 建立 positive、negative 和 boundary 覆盖
  - failed: 把本期排除项转成 exclusion guard 或 negative 用例，且不扩大产品 scope
  - failed: 测试用例必须连接 product_refs、design_refs、assertion_target 和 evidence_expectation
- test-design / vague-ac-blocks-test-design: 7/7 passed

## Optimization Findings
- 产品侧证据不清晰，未引用具体 product artifact/ref。 -> 补一条明确 product 引用，例如 AC/PRD 对“历史记录可回滚”的来源位点，并与 design 缺口并列。
- 没有把测试义务结构化连接到 assertion_target 和 evidence_expectation。 -> 显式写出：由于缺少哪些设计定义，当前无法确定 assertion_target 和 evidence_expectation，因此阻断。
- 缺少 `ac_coverage_matrix` 这一明确载体与逐 AC 的 positive/negative/boundary 映射。 -> 要求输出按 AC 行展开，并显式列出 `positive`、`negative`、`boundary` 字段。
- 本期排除项只被“排除”，没有转成 guard 型测试义务。 -> 要求把 exclusion 写成 `exclusion_guard` 或受控 negative case，并声明不扩 scope。
- 未把测试义务绑定到 refs、断言目标和证据期望。 -> 要求每条用例至少包含 `product_refs`、`design_refs`、`assertion_target`、`evidence_expectation` 四个字段。
