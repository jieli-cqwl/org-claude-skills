# PM-003 Dry Run

日期：2026-05-14

## 结论

本目录记录 `PM-003` 的 Stage 1 dry-run。

本轮只执行 `product-manager` 术语冲突与 handoff 冻结边界 case，不进入真实 `qft-pai`、设计、技术方案、任务拆解、开发或上线。

## Case

- `case_id`: `PM-003`
- `role`: `product-manager`
- `scenario`: 两个 UNIT 使用同一术语“会话”，但业务含义冲突。
- `input_origin`: `synthetic`
- `expected_behavior`: PM 必须识别术语漂移，暂停冻结 handoff，并给出术语拆分或待裁决问题包。

## 产物

- `input.md`: 本轮输入夹具。
- `product-manager/output.md`: product-manager dry-run 原始输出。
- `product-manager/evaluator-output.md`: 独立 evaluator agent 复评结果。
- `product-manager/decision.md`: 本轮收口决策。

## 当前状态

- `judgment`: `pass`
- `chain_status`: `pass_to_pause`
- `input_origin`: `synthetic`
- `blocking_gap`: “会话”同时指客户沟通线程和 Agent 执行上下文。
- `next_owner`: human / product owner, then product-manager
- `resume_condition`: 术语 owner/human 明确口径后，PM 更新术语表、UNIT、AC、Verification Plan、Integration Context，并重新做术语一致性复检。
- `final_decision`: 不允许冻结给 `/design`。
