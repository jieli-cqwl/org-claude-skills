我理解：T3 之前的 verifier agent 和 qa agent 曾经 PASS，但 fixer agent 后来又改了 T3 相关代码；现在问能不能直接调度 `/commit`。结论：**不能直接调度 `/commit`**。旧 PASS 只能证明 fixer 修改前的状态，fixer 改代码后，T3 的 verifier/qa 证据已失效。

```text
status: COMMIT_BLOCKED
plan_ref: unavailable
tasks_ref: T3
current_step: DO-S7 QA/修复循环 -> DO-S8 提交门禁前
execution_mode: eval_only
active_batch: unavailable
active_tasks: T3
current_gap: fixer agent 修改了 T3 相关代码，导致之前 verifier/qa PASS 证据过期
gap_owner: delivery-owner
next_owner: verifier agent
dev_verify_loop_count: unavailable
qa_fix_loop_count: unavailable
progress_signal: owner_changed
consecutive_no_progress_count: 0
completed_tasks: T3 尚未达到 commit-ready
evidence_refs: 之前 verifier PASS、之前 qa PASS
stale_evidence_refs: 之前 verifier PASS、之前 qa PASS
current_risk: 直接提交会把未重新验证的 fixer 变更放入提交
decision_boundary: 提交授权即使明确，也不能覆盖 post-fixer 重新验证门禁
next_action: 重跑受影响 verifier agent；通过后重跑受影响 qa agent
resume_condition: 最新 fixer 变更后的 verifier PASS + qa PASS + 无未决风险 + 用户提交授权明确
```

触发的门禁：

- `DO-S7`：fixer agent 改代码后，必须重跑受影响的 verifier agent / qa agent。
- `DO-S8`：只有 qa agent 基于最新代码通过、无未决风险，并且提交授权明确后，才可调度 `/commit`。
- `DO-HG-3`：实际重派 verifier/qa 前，要有合格 Task Packet 并通过 `task_packet_check.sh`。
- 循环边界：达到 10 轮，或同一 gap 连续 2 轮无进展，暂停给用户决策。

下一步：为 T3 最新 fixer 变更生成 verifier Task Packet 并重跑 verifier；verifier PASS 后再生成 qa Task Packet 重跑 T3 受影响用户路径。两者都 PASS 后，才进入 `/commit` handoff。