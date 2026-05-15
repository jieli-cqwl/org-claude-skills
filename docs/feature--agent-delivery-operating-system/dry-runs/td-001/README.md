# TD-001 Dry Run

日期：2026-05-14

## 结论

本目录记录 `TD-001` 的 Stage 1 dry-run。

本轮只执行 `test-design` 守门 case，不进入真实 `qft-pai`，不生成测试清单、`test-cases.json`、QA 结论、任务计划或交付声明。

## Case

- `case_id`: `TD-001`
- `role`: `test-design`
- `scenario`: 缺 `design.json`，用户要求先写测试。
- `input_origin`: `missing/synthetic`
- `expected_behavior`: test-design 必须输出 typed gap，标明 owner、blocking、next_action，并阻断 handoff。

## 产物

- `test-design/output.md`：test-design dry-run 原始输出。
- `test-design/evaluator-output.md`：独立 evaluator agent 复评结果。
- `test-design/decision.md`：本轮收口决策。

## 当前状态

- `judgment`: `pass`
- `chain_status`: `pass_to_pause`
- `input_origin`: `missing/synthetic`
- `blocking_gap`: 缺可读取 canonical `design.json`。
- `next_owner`: human + `/design`
- `resume_condition`: 对应 Phase/UNIT 的 `design.json` 可读取且 TD-S1 preflight 通过后，才允许恢复测试义务设计。
- `final_decision`: 不允许进入 `/tech-lead`、QA 或后续交付角色。
