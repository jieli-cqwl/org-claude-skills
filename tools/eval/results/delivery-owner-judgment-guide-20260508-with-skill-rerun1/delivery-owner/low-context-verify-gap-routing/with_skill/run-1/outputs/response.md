```text
status: DISPATCH_READY
plan_ref: frozen plan path=unavailable in eval
tasks_ref: T2 path=unavailable in eval
current_step: DO-S5 开发/验证循环 - verifier FAIL 回派
execution_mode: serial
active_batch: T2
active_tasks: T2
current_gap: AC-2 只有完成结论，缺 scope evidence，verify-result=FAIL
gap_owner: developer agent
next_owner: developer agent
dev_verify_loop_count: unknown
qa_fix_loop_count: 0
progress_signal: owner_changed
consecutive_no_progress_count: unknown
completed_tasks: none for QA gate; T2 不可视为验证完成
evidence_refs: developer-report:T2 path=unavailable; verify-result:T2/AC-2 path=unavailable
stale_evidence_refs: developer-report:T2 AC-2 conclusion-only evidence
current_risk: 证据不可判定，不能证明 AC-2 在 T2 scope 内完成
decision_boundary: verifier PASS 前不得提测、不得 QA、不得 /commit；若同一 gap 连续 2 轮无进展或循环达 10 轮，暂停给用户
next_action: 回派 developer agent 补 AC-2 scope evidence，随后重跑 verifier
resume_condition: developer 提供可独立核验的 AC-2 scope evidence，verifier 对 AC-2 PASS
```

结论：不能推进 QA，也不能把 T2 记为完成。当前是 DO-S5 的 verifier FAIL，原因是证据缺口，不是用户验收或提交阶段。

回派包如下：

```text
task_ref: T2 / AC-2 evidence remediation
role: developer
goal: 补齐 T2 中 AC-2 的 scope evidence，使 verifier 能独立判断 AC-2 是否在冻结 scope 内完成；不得只给结论。
expected_scope: T2 冻结任务范围；本轮优先补 developer-report 的证据，不默认扩大代码变更。
forbidden_scope: 冻结 plan/tasks/AC 定义；其他 task scope；QA 结论；提交、发布、合并相关操作。
input_refs: developer-report:T2 path=unavailable；verify-result:T2/AC-2 FAIL path=unavailable，失败原因为“只有结论，没有 scope evidence”。
expected_evidence: AC-2 条款到实现位置/行为的映射；T2 scope 内相关文件/函数/路径引用；对应测试或验证命令结果；若有超出 expected_scope 的变更，说明原因和影响面；若无法提供证据，明确报告是实现缺口、scope 不清还是环境阻塞。
stop_condition: AC-2 scope evidence 可被 verifier 独立核验，或输出精确 blocker；不得自行声明验证通过。
forbidden_actions: 禁止修改 AC/验收标准；禁止用主观结论替代证据；禁止跳过 verifier；禁止推进 QA 或 /commit；禁止扩大范围后不声明影响面。
```

下一跳：developer 补证据后，只重跑 T2/AC-2 的 verifier。若 verifier PASS，T2 才能进入 QA 候选；若再次同一 gap 无新证据、未缩小、无新阻塞或风险，则触发“同 gap 连续 2 轮无进展”暂停，交给用户裁决。