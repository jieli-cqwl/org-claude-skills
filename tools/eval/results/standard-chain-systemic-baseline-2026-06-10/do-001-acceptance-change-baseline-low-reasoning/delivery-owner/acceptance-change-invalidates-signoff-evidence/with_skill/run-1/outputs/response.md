**状态卡**
- `current_stage`: `DO-S8b`
- `status`: `BLOCKED`
- `control_action`: `PAUSE_FOR_USER_DECISION`
- `blocker_id`: `TARGET_CHANGE_REQUIRED`
- `blocker_owner`: `user`
- `blocker_basis_refs`: `signoff-package.json` 已准备完成，但用户在 DO-S8b 明确修改了 `AC-3`
- `resume_stage`: `DO-S1`
- `next_action`: 生成 `target-change.json`，重新冻结基线后再重跑证据链
- `resume_condition`: 用户确认新 AC 文本并完成 rebaseline 后，产生 fresh proof

**结论**
不能写 `user-decision.json`，也不能直接进入最终准入或 `/commit`。  
原因很硬：用户不是在授权现有基线，而是在改基线。`AC-3` 从“导出明细行”变成“导出报表必须包含按门店分组的小计”，这会使当前 `signoff-package.json` 的结论失效，必须先做 `target-change.json`。

**必需裁决**
- 这不是提交授权问题，是**范围/AC 变更**问题。
- 需要写 `target-change.json`，至少包含：
  - `invalidates_refs`: 当前 `signoff-package.json` 及其关联证据矩阵
  - `superseded_evidence_refs`: 现有 `developer-report / verify-result / code-review-result / qa-result / consistency-audit-result`
  - `rebaseline_owner`: `product-manager`，随后由 `tech-lead` 重新冻结任务
  - `required_fresh_proof_after_rebaseline`: 新 AC 下的开发、验证、代码审查、QA、consistency-audit 全链路 fresh evidence

**下一步**
1. 先停在这里，不提交。
2. 走 `target-change` 重基线。
3. 重跑受影响的开发/验证/审查/QA 证据，重新生成 `signoff-package.json`。
4. 只有用户在新基线上明确授权后，才进入 `DO-S8c`。