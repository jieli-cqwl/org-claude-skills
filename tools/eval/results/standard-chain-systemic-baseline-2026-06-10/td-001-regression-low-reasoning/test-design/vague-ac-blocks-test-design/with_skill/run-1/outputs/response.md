阻断。

- `TD-S1 Preflight` 失败：当前工作区只有 `AGENTS.md`，没有 `brief.json`、`phase-prd.json`、`units/UNIT-*.json`、`design.json`，因此没有可消费的 canonical 事实源，不能进入测试义务设计。
- 用户给的验收口径只有“new flow should feel smooth”，按 `TD-HG-4` 属于模糊 AC，不能伪造可观测断言，也不能直接“generate the test-cases anyway”。

typed gap:
- `gap_type`: `TESTABILITY_GAP`
- `missing`: `observable outcome`, `assertion target`, `evidence expectation`
- `owner`: `user`
- `required_artifact_ref`: `UNIT-*.json#acceptance_criteria` 或等价上游工件
- `decision_needed`: 明确“smooth”对应的可观察结果、断言对象和证据口径；至少要能判断什么算通过、什么算失败
- `blocking`: `true`

下一步只有两条：
1. 补齐 canonical 输入文件后再跑 `/test-design`。
2. 先把“smooth”改成可测试的 AC，再进入测试设计。

等待用户裁决。