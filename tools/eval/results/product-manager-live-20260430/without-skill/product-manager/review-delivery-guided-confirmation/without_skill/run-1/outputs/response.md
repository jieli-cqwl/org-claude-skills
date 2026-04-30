PM 裁决建议：继续推进，但不能直接跳到 M-S9 签收。先补齐 M-S7 扫描发现的 AC 缺失边界案例；M-S8 因 reviewer 无 FAIL，可以继续流转，但 tester 的 WARN 必须进入 `issue_ledger`，并指定承接目标。

**当前门禁**
- `M-S7`：补齐缺失边界案例到对应 AC，否则阻断 M-S9。
- `M-S8`：`reviewer=PASS/NO_FAIL` 可继续；`tester=WARN` 不阻断，但必须登记。
- `canonical`：必须先更新 `review_conclusion` 与 `issue_ledger`，形成唯一评审结论。
- `M-S9`：只有 canonical 更新后，才能请求用户确认、选择或修正 `delivery_confirmation`。

**应更新字段**
```json
{
  "review_conclusion": {
    "status": "continue_with_warn",
    "m_s7_action": "add_missing_ac_boundary_case",
    "m_s8_reviewer": "no_fail",
    "m_s8_tester": "warn_recorded"
  },
  "issue_ledger": [
    {
      "source": "M-S8 tester",
      "severity": "WARN",
      "status": "open",
      "handoff_target": "design",
      "resolution_expectation": "downstream design must consume and address this warning"
    }
  ],
  "delivery_confirmation": {
    "status": "pending_user_confirmation",
    "allowed_actions": ["confirm", "choose_alternative", "correct"]
  }
}
```

**M-S9 下一步话术**
请用户基于已补齐 AC、已登记 WARN 的 canonical 结论，确认、选择或修正 `delivery_confirmation`；不要开放式追问。

**交给 `/design`**
只交 canonical JSON 和下游必需消费字段：AC、边界案例、`review_conclusion`、`issue_ledger`、`delivery_confirmation`。不交聊天过程、草稿解释或非 canonical 结论。