结论：`test-design` 会把“成功提交、必填校验、重复提交防护、明确不做审批流”收口成一张可追踪的测试义务矩阵，而不是直接把需求口号写进用例。  
但就当前 canonical 输入看，`UNIT-1` 只明确了 `catalog and canonical tree exist`，没有把你说的那组提交/校验/防重/排除审批流写进 `phase-prd.json` 或 `UNIT-1.json`，所以这部分不能被我伪装成已冻结测试覆盖。

**应收口的结构**
- `ac_coverage_matrix`
  - `positive`：成功提交路径
  - `negative`：必填项缺失、重复提交被拦截
  - `boundary`：最小合法输入、重复触发临界点、失败闭合文案
- `test_case_shape`
  - 每条义务都要带 `product_refs`、`design_refs`、`assertion_target`、`evidence_expectation`
- `exclusion_guard`
  - “不做审批流”必须转成明确 guard
  - 验证点是：测试里不出现审批态、不依赖审批节点、不把审批作为通过条件

**在这个场景里，怎么落到测试设计**
- 成功提交
  - 断言对象：提交结果、状态变更、持久化或回显结果
  - 证据期望：提交前后状态对比、返回结果、记录落点
- 必填校验
  - 断言对象：缺字段时的阻断结果、错误提示、失败闭合
  - 证据期望：错误码/文案、字段定位、提交未生效
- 重复提交防护
  - 断言对象：第二次提交被拒绝或幂等处理
  - 证据期望：重复请求日志、状态未重复变更、唯一性约束命中
- 排除审批流
  - 断言对象：流程里不存在审批步骤
  - 证据期望：路径图、状态机、验证脚本都不含审批态

**阻断条件**
- 现在不能把“成功提交/必填校验/重复提交防护”直接冻结为测试义务，因为它们不在当前 canonical JSON 里。
- 需要上游补到 `UNIT-1.json#acceptance_criteria` 或 `phase-prd.json`，否则这是 `TESTABILITY_GAP`。

```json
{
  "gap_type": "TESTABILITY_GAP",
  "product_refs": [
    "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/units/UNIT-1.json#acceptance_criteria",
    "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/phase-prd.json#feature_inventory"
  ],
  "design_refs": [
    "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json#verification_mapping",
    "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json#interfaces"
  ],
  "missing": [
    "observable outcome",
    "assertion target",
    "evidence expectation"
  ],
  "owner": "product-manager",
  "required_artifact_ref": "UNIT-1.json#acceptance_criteria 或 phase-prd.json",
  "decision_needed": "请明确成功提交、必填校验、重复提交防护的可观察结果、断言对象和证据口径，并把“本期不做审批流”写成显式排除项",
  "blocking": true
}
```

下一步只有两条：
1. 你补齐 canonical JSON，我按上述结构继续收口成可执行测试设计。
2. 你确认当前只需要方法说明，不要求冻结产物，我就停在这里。  
等待用户裁决。