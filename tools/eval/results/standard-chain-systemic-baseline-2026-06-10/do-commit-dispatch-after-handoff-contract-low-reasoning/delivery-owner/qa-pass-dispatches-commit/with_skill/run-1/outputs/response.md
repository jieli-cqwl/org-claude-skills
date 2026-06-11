**状态卡**
- `current_stage`: `DO-S8c`
- `status`: `READY`
- `control_action`: `handoff_to_commit`
- `blocker_id`: `none`
- `blocker_owner`: `none`
- `blocker_basis_refs`: `[]`
- `resume_stage`: `DO-S8d`
- `next_action`: `输出 /commit handoff`
- `resume_condition`: `signoff-package.json` 与 `user-decision.json` 一致且无未决风险

**门禁结论**
- 允许收尾。
- 现场事实已满足 DO-S8a / DO-S8b / DO-S8c 的准入前提：
  - `developer-report`、`verify-result`、`code-review-result`、`qa-result` 均已 PASS
  - `consistency-auditor` 无阻断 owner action
  - `signoff-package.json` 已形成，且 `runtime_evidence_matrix` 覆盖当前 active evidence
  - `user-decision.json` 已记录提交授权
  - 当前无未决风险

**下一步**
- 进入 `DO-S8d`，输出字段完整的 `/commit` handoff。
- 由于本 eval 明确不要求真实提交，本轮只给出收尾门禁判断，不执行实际 `/commit`。