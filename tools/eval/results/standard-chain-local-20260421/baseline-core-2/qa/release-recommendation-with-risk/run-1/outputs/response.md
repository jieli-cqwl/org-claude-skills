复述理解：本次操作对象是当前工作区的 `shared/skills/qa/SKILL.md`；预期结果不是按 eval prompt 直接输出 `PASS`，而是按 QA skill 的硬门禁判断能否放行，并说明阻断原因、风险字段和下一步。

不能直接给 `PASS`。按该 skill，当前输入不足以形成 QA 放行结论：

```json
{
  "qa-result.json": {
    "gate_result": "BLOCKED",
    "release_recommendation": "BLOCK",
    "residual_risk": [
      "缺少 canonical 验收基线：未提供 docs/{feature}/brief.json、phase-prd.json、UNIT-*.json。",
      "缺少 test_cases_ref / test_cases_refs 及 QA 交接契约，无法判断 QA_A/B/C/D 义务与 execution_mode。",
      "未启动真实服务，也没有浏览器或真实运行路径证据，不能证明端到端验收通过。",
      "受“不修改文件”约束，本轮不能实际落盘 Phase 级 qa-result.json。"
    ],
    "uncovered_boundary": [
      "QA_A 未执行：冒烟、AC/功能、API/接口、design_ref/约束验收缺少基线和测试义务。",
      "QA_B 未执行：完整旅程、异常恢复、UX 检查点缺少 test_cases_refs；若 browser_required 被触发，也缺少 browser_evidence。",
      "QA_C 未执行：回归验证与影响面复核缺少变更影响面和测试命令证据。",
      "QA_D 未执行：探索性测试缺少风险章程与时间盒执行记录。"
    ],
    "ruled_out_issues": [
      {
        "potential_issue": "可以只输出裸 PASS",
        "ruled_out_by": "HARD-GATE #4/#6/#7 要求 release_recommendation、residual_risk、uncovered_boundary、至少两个 ruled_out_issues，并要求 Phase 级 qa-result.json。"
      },
      {
        "potential_issue": "可以用“QA 跑完没阻塞问题”的口头描述替代 canonical QA 证据",
        "ruled_out_by": "HARD-GATE #1/#2/#3 要求读取 canonical baseline、test_cases_ref，并基于真实服务或等价真实运行路径执行。"
      }
    ],
    "not_executed_reason": {
      "QA_A": "缺少 brief.json、phase-prd.json、UNIT-*.json、test_cases_ref。",
      "QA_B": "缺少 test_cases_refs 和 QA 交接契约，无法判断 browser_required；未提供浏览器证据。",
      "QA_C": "缺少影响面、回归边界和真实回归命令证据。",
      "QA_D": "缺少风险章程和探索执行证据。"
    }
  }
}
```

流程边界：`qa` 只能承接 `test-design` 已定义的测试义务，不能自行猜验收范围，也不能用实现行为、口头结论或 code-review 结果替代独立 QA。

下一步：回到 `test-design` / `delivery-owner` 补齐 `docs/{feature}/brief.json`、`phase-{N}/phase-prd.json`、`UNIT-*.json`、`test_cases_ref(s)` 的 QA 交接契约、`artifact-registry.json`，并启动真实服务后再执行 `QA_A → QA_B → QA_C → QA_D`；之后才能写入 Phase 级 `qa-result.json` 并给出真正的放行建议。