理解：T2 的 developer-report 声称 AC-2 完成，但 verifier 已给出 `FAIL`，明确指出 AC-2 的 scope 证据缺失，并在 `verify-result.json` 里列出 missing gap。下一步必须停在开发/验证循环，不进入 QA。

**Gate**
- `qa_allowed`: `false`
- `reason`: AC-2 verifier 未通过，存在 scope 证据 missing gap。
- `dispatch_status`: `dispatch_ready`
- `dispatched_to`: 未实际调度，当前 eval 环境仅输出调度包和状态卡。

**Developer Packet**
```json
{
  "task_ref": "T2",
  "role": "developer",
  "goal": "补齐 verifier 在 AC-2 中指出的 missing gap：AC-2 的 scope 证据缺失，需提供可验证的 scope 覆盖证据。",
  "scope": {
    "task": "T2",
    "acceptance_criteria": ["AC-2"],
    "allowed_work": [
      "针对 AC-2 scope 证据缺失进行最小补充",
      "更新 fresh developer-report.json",
      "补充与 AC-2 scope 直接对应的证据引用"
    ],
    "out_of_scope": [
      "进入 QA",
      "修改非 T2 / AC-2 相关内容",
      "扩大实现范围或顺手重构"
    ]
  },
  "input_refs": [
    "verifier agent result: FAIL",
    "verify-result.json: missing gap for AC-2 scope evidence"
  ],
  "expected_evidence": [
    "fresh developer-report.json",
    "developer-report.json 必须明确引用 AC-2 scope 证据",
    "证据必须能直接回应 verify-result.json 中列出的 missing gap",
    "如无法补齐，必须返回明确 blocker / risk / owner，而不是声称完成"
  ],
  "stop_condition": [
    "AC-2 scope missing gap 已关闭或显著缩小，并产生新证据",
    "或 developer 明确返回新阻塞、新风险、owner 变化",
    "developer 返回后必须再次调度 verifier agent 复验"
  ],
  "forbidden_actions": [
    "不得进入 QA",
    "不得跳过 verifier 复验",
    "不得只更新描述而不提供 fresh evidence",
    "不得把缺失证据包装为已完成",
    "不得扩大到 AC-2 以外的实现或验证范围"
  ]
}
```

**Status Card**
```json
{
  "task_ref": "T2",
  "phase": "development_verification_loop",
  "current_gap": "AC-2 scope evidence missing in verifier result / verify-result.json",
  "progress_signal": "verifier identified a concrete missing gap; next action is narrowed developer rework",
  "consecutive_no_progress_count": 0,
  "next_owner": "developer",
  "evidence_refs": [
    "developer-report.json claimed AC-2 complete",
    "verifier result: FAIL",
    "verify-result.json missing gap: AC-2 scope evidence missing"
  ],
  "resume_condition": "developer returns fresh developer-report.json with AC-2 scope evidence, then verifier agent must be dispatched again for复验",
  "qa_allowed": false,
  "pause_policy": "达到 10 轮，或同一 gap 连续 2 轮没有关闭、缩小、新证据、新阻塞、新风险或 owner 变化时，暂停并交给用户决策。"
}
```

下一步：等待 developer 按上述 packet 返回 fresh `developer-report.json` 和对应证据；随后立即回派 verifier 复验，只有 verifier 通过后才允许进入 QA。