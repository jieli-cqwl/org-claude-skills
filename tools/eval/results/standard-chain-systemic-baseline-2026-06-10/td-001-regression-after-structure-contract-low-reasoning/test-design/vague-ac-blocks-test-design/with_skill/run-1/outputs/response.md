阻断，不生成 `test-cases.json`，也不补伪测试覆盖。

原因很硬：
- 这次输入只有“new flow should feel smooth”，属于典型 `TD-HG-4` 模糊 AC。
- 预检失败，canonical 输入缺失，当前 workspace 没有可消费的事实源：
  - 缺 `brief.json`
  - 缺 `phase-prd.json`
  - 缺 `design.json`
  - 缺 `units/`
  - `--phase-dir` 也不是合法的 `docs/{feature}/phase-N`

typed gap：
```json
{
  "gap_type": "TESTABILITY_GAP",
  "product_refs": "无法定位：缺少 brief.json / phase-prd.json / units/UNIT-*.json",
  "design_refs": "无法定位：缺少 design.json",
  "missing": [
    "observable outcome",
    "assertion target",
    "evidence expectation"
  ],
  "owner": "user",
  "required_artifact_ref": "UNIT-*.json#acceptance_criteria 或 phase-prd.json",
  "decision_needed": "把“feel smooth”改成可观测结果：具体流程、成功/失败判定、时延/卡顿/错误反馈阈值、可采证据口径",
  "blocking": true
}
```

下一步只能二选一：
1. 补齐 canonical 工件后再跑 `/test-design`。
2. 直接把 AC 改成可测试版本，再让我按证据生成测试义务。等待用户裁决。