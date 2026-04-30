复述：当前不进入提交。因为 `qa-result.json` 是可复现 QA FAIL，且 fixer 已产生 `fix-result.json`，delivery-owner 下一步应停在 QA/修复循环，先重跑受影响 verifier agent，再重跑 qa agent，拿 fresh PASS 后再等待用户明确授权 `/commit`。

**Fixer Packet**
```json
{
  "task_ref": "<task_ref>",
  "role": "fixer",
  "goal": "基于 failing qa-result.json 中的可复现缺陷定位根因并完成最小修复",
  "scope": "仅修改与 qa-result.json 复现缺陷直接相关的最小代码范围",
  "input_refs": [
    "qa-result.json",
    "verify-result.json"
  ],
  "expected_evidence": [
    "root cause",
    "minimal fix",
    "freshness 判断：说明哪些旧 verifier/qa 证据因修复变更失效",
    "fix-result.json"
  ],
  "stop_condition": "完成最小修复并输出 fix-result.json；不得继续推进 commit",
  "forbidden_actions": [
    "不得扩大 scope 做顺手重构",
    "不得跳过 root cause",
    "不得直接 /commit",
    "不得把旧 verifier PASS 或旧 QA 结果当作修复后的 fresh evidence"
  ]
}
```

**状态卡更新**
```json
{
  "current_gap": "qa-result.json 中的可复现用户路径缺陷尚未被修复后的 fresh QA PASS 关闭",
  "progress_signal": "fixer 已返回 fix-result.json，存在最小修复产物，但修复后 verifier/qa 证据尚未刷新",
  "consecutive_no_progress_count": 0,
  "stale_evidence_refs": [
    "修复前 verifier PASS",
    "修复前 qa-result.json"
  ],
  "next_owner": "verifier agent -> qa agent",
  "evidence_refs": [
    "developer-report",
    "verify-result.json",
    "qa-result.json",
    "fix-result.json"
  ],
  "resume_condition": "受影响 verifier agent fresh PASS 且 qa agent fresh PASS；之后仍需用户明确授权才可调度 /commit"
}
```

下一步：调度受影响 verifier agent 重跑；若 PASS，再调度 qa agent 重跑用户路径。若同一 gap 连续 2 轮没有进展，暂停并交给用户决策。