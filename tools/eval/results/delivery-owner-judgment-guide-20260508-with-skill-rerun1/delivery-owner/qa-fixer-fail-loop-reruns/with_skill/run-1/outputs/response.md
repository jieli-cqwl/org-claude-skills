```text
status: DISPATCH_READY
plan_ref: unavailable(eval prompt only)
tasks_ref: unavailable(eval prompt states all tasks completed dev+verifier)
current_step: DO-S7 QA/修复循环
execution_mode: serial
active_batch: post-fix-rerun-1
active_tasks: affected task(s) from qa-result.json / fix-result.json, path=unavailable
current_gap: QA FAIL 已由 fixer 最小修复，但 post-fix verifier PASS 与 post-fix QA PASS 尚未刷新，提交门禁未满足
gap_owner: verifier agent
next_owner: verifier agent
dev_verify_loop_count: pre-fix all PASS; post-fix rerun=0
qa_fix_loop_count: 1
progress_signal: new_evidence
consecutive_no_progress_count: 0
completed_tasks: all tasks have developer-report + pre-fix verifier PASS
evidence_refs: developer-report:all(path=unavailable), verifier-result:all-PASS-pre-fix(path=unavailable), qa-result.json:FAIL(path=unavailable), fix-result.json(path=unavailable)
stale_evidence_refs: pre-fix verifier PASS for affected scope, pre-fix QA evidence
current_risk: fixer 修复后影响面未经过独立 verifier 与用户路径 QA 复验
decision_boundary: 不可进入 DO-S8；若复验缺 executor/环境则 NEEDS_RESOURCE；若 scope/AC/风险接受不清则暂停给用户；同一 gap 连续 2 轮无进展或 QA/修复循环达 10 轮必须暂停
next_action: 回派受影响 verifier agent，PASS 后再回派 qa agent 重跑失败用户路径与受影响回归路径
resume_condition: post-fix verify-result.json PASS 且 post-fix qa-result.json PASS，且无未决风险后，才进入 READY_FOR_COMMIT
```

**Task Packet: verifier**

```text
task_ref: post-fix-verification:affected-task(s)-from-qa-fail
role: verifier
goal: 基于 fix-result.json 独立核验 QA FAIL 对应缺陷已被最小修复，且受影响 task 的 AC 与 scope 仍满足
scope: 只验证 frozen tasks 中受 fix-result.json 影响的 Task file_range；真实 file_range path=unavailable；不得修改文件
input_refs:
  - tasks:all(path=unavailable)
  - qa-result.json:FAIL 可复现缺陷(path=unavailable)
  - fix-result.json 最小修复结果(path=unavailable)
  - developer-report:affected-task(s)(path=unavailable)
expected_evidence:
  - AC 验收结论
  - scope 范围核验结论
  - fix-result 影响面核验
  - verify-result.json，明确 PASS 或 missing gap
stop_condition: 受影响 AC/scope 全部 PASS；或输出精确 missing gap / blocker
forbidden_actions:
  - 范围边界：禁止修改 scope/file_range 以外任何文件，verifier 本轮不得写实现代码
  - baseline/AC 边界：禁止修改 plan/tasks、AC、验收标准或测试基线
  - commit/release 边界：禁止 git commit/push、发布、合并或调用 /commit
  - 角色边界：禁止代替 QA 判定用户路径最终通过
```

**Conditional Task Packet: qa**

仅在上一个 verifier packet 返回 post-fix PASS 后派发。

```text
task_ref: post-fix-qa-rerun:failed-user-path
role: qa
goal: 重跑 qa-result.json 中失败的用户路径，并覆盖 fix-result.json 影响范围的回归路径
scope: qa_handoff_contract 与 cross_unit_obligations 覆盖的用户路径；真实路径引用 unavailable；不修改文件
input_refs:
  - qa_handoff_contract(path=unavailable)
  - cross_unit_obligations(path=unavailable)
  - verify-result.json:post-fix-PASS(path=pending)
  - qa-result.json:previous-FAIL(path=unavailable)
  - fix-result.json(path=unavailable)
expected_evidence:
  - QA_A 用户路径证据
  - QA_B 失败路径复验
  - QA_C 受影响回归路径
  - QA_D 风险/阻塞记录
  - qa-result.json，明确 PASS 或可复现缺陷
stop_condition: 必测路径全部 PASS；或返回可复现缺陷、环境阻塞、scope/AC 不清
forbidden_actions:
  - 范围边界：禁止修改实现文件或扩大 QA 范围到 handoff 之外
  - baseline/AC 边界：禁止修改 AC、qa_handoff_contract、验收标准或测试基线
  - commit/release 边界：禁止 git commit/push、发布、合并或调用 /commit
  - 角色边界：禁止代替 verifier 判定代码级 AC/scope 通过
```

结论：下一步不是提交，也不是直接收口；按 delivery-owner 必须在 DO-S7 内先刷新修复后的 verifier 证据，再刷新 QA 证据。当前可推进到 `verifier agent` 回派，QA PASS 前 `/commit` 门禁保持关闭。