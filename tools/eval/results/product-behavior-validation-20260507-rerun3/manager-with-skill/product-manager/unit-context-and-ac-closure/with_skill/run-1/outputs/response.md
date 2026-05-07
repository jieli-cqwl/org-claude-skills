已按 `product-manager` skill 执行本次 eval：基于已确认 handoff，把 Phase 1 的 `UNIT-1` 收口成一个闭环 UNIT，产物写入 [UNIT-1.json](/Users/lijieli/org-claude-skills/tools/eval/results/product-behavior-validation-20260507-rerun3/manager-with-skill/_workspaces/with_skill/product-manager/shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/outputs/docs/request-review-flow/phase-1/units/UNIT-1.json:23)。

已冻结事实：Director confirmation 已通过，Phase 1 目标是一个 closed-loop request review flow。PM 结论：`UNIT-1` 作为 P0 闭环，覆盖“请求提交 → 授权 reviewer 审核 approve/reject/needs-information → requester 可见状态、原因、下一步”。理由是它直接解决 ownership、required information、approval outcome 不清的问题。会改变结论的业务假设：Phase 1 的业务结果仍限定在 approved / rejected / needs-information correction；若不成立，需要回到 M-S4/M-S5 重收口。

本次改动：
- 明确 `closure_definition` 的输入/触发、核心行为、可观察结果。
- AC 从 1 条扩展为 4 条，覆盖 approve、reject、missing required information、unauthorized reviewer failure。
- 补强 `integration_context`，只写业务模块、不可破坏行为、跨 UNIT 依赖和业务约束，不写技术路径。
- 补强 `verification_plan`，映射到 AC、brief 成功标准和风险项。

验证已通过：
- `preflight_check.sh --brief ... --phase-prd ...`：PASS
- `jq . UNIT-1.json`：JSON 合法
- `validate_product_closure.py --artifact UNIT-1.json`：PASS
- `validate_product_closure.py --artifact phase-prd.json --require-review`：PASS
- `validate_product_closure.py --artifact brief.json --require-review --require-delivery`：PASS

边界与下一步：本次只完成 eval 要求的 UNIT/AC/Verification Plan 收口，没有联网、没有启动服务、没有提交，也没有执行三方 review agent。若要声明完整 Manager handoff，下一步必须补跑/闭合 M-S7/M-S8/M-G1/M-S9，并执行完整 PM handoff gate；当前可交给 `/design` 消费 Integration Context，交给 `/test-design` 消费 AC 与 Verification Plan。