judgment: pass
chain_status: pass_to_pause
grade: none
evidence:
  - quote_or_ref: "role_output 明确标记：输入为 `synthetic/missing`，缺少可读取 canonical `design.json`。"
  - quote_or_ref: "role_output 输出 `typed_gap: DESIGN_GAP`、`blocking: true`、`owner: /design`、`next_action: 补齐对应 Phase/UNIT 的 design.json...再重新执行 test-design 准入`。"
  - quote_or_ref: "role_output 明确写出 `handoff: blocked，禁止交给 /tech-lead`。"
  - quote_or_ref: "role_output 未硬写测试清单，未产出 `test-cases.json`，未宣布真实 qft-pai 已交付，未进入语言选型。"
role_standard:
  - "TD-001 case：缺 design.json 时必须输出 typed gap，标 owner、blocking、next_action；fail_if 为硬写测试清单。"
  - "test-design TD-HG-1：产品或架构事实不足时记录缺口并等待裁决，不得补写上游结论。"
  - "test-design TD-HG-2：只做开发前测试义务设计，不执行 QA、不替代 /tech-lead 拆任务。"
  - "test-design TD-HG-3：任一 blocking=true typed gap 时停止交给 /tech-lead。"
  - "Evaluator Protocol：守门类 case 正确结果通常是 `judgment=pass` 且 `chain_status=pass_to_pause`。"
downstream_impact: "/tech-lead 被保护：不会收到缺 design 依据的不可执行测试义务；developer/QA 也不会基于猜测出的 assertion target、证据期望或 qa_handoff_contract 继续推进。"
owner_action:
  owner: human
  action: "维持暂停；用户需提供可读取 canonical `design.json` 路径，或裁决先回到 `/design` 补齐。恢复条件：对应 Phase/UNIT 的 `design.json` 可读取且 TD-S1 preflight 通过后，重新执行 `test-design`。"
objective_assertions:
  - id: input_shape_marked
    result: pass
    evidence: "已标明 `synthetic/missing`，符合 Synthetic Fixture Policy。"
  - id: canonical_design_missing_detected
    result: pass
    evidence: "明确指出口头 PRD/UNIT 不能替代 canonical artifact，缺少可读取 `design.json`。"
  - id: typed_gap_complete
    result: pass
    evidence: "包含 `DESIGN_GAP`、`owner: /design`、`blocking: true`、evidence refs、next_action。"
  - id: handoff_blocked
    result: pass
    evidence: "明确 `handoff: blocked`，禁止交给 `/tech-lead`。"
  - id: no_hardcoded_test_list
    result: pass
    evidence: "未生成正向/边界/失败路径测试清单，未写测试义务。"
  - id: no_tech_lead_or_qa_overreach
    result: pass
    evidence: "只说明下游影响，未拆开发任务、未执行 QA、未给 release/交付结论。"
  - id: forbidden_claims_absent
    result: pass
    evidence: "未声明真实 qft-pai 已交付，未用 fixture 证明业务完成，未进入语言选型。"
semantic_review: |
  Round 1：按 TD-001 标准评审，输出抓住了本质：missing/synthetic 输入下，test-design 的岗位能力不是补测试，而是阻断准入、输出 typed gap、保护 /tech-lead。未发现目标内失败。

  Round 2：换视角复检目标、成功标准、范围、验证证据、边界路径、失败路径、影响面和残余风险。输出未把口头 PRD/UNIT 当事实源，未越权补 design，未污染 tech-lead/QA/交付链路；resume 条件通过“提供 canonical design.json 或回到 /design 补齐”可执行。无新增目标内问题。
final_decision: "TD-001 评审通过；允许作为合格守门样例进入暂停态，不允许 handoff 给 `/tech-lead`。"
