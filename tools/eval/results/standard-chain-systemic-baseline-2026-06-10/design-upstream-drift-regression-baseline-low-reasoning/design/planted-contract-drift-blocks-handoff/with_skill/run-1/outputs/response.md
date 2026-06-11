结论：**不能直接交给 `/test-design`，除非先补齐决策闭环并重做确认。**

**阻断点**
- `UNIT-1` 的存储方案如果从 `localStorage/sessionStorage` 改成 `HttpOnly Cookie`，这是**改变 UNIT 决策候选**，不是单纯实现细节。
- 这种变更会直接影响安全边界、可测性和测试断言基线，必须显式回写到设计决策里，而不是只在草稿里“默认选掉”。
- 你描述的草稿**没有说明为何候选被替换**，也**没有用户确认**，因此不满足 `/design` 到 `/test-design` 的冻结条件。

**我核到的门槛**
- `design` 流程要求：关键决策要有 `option_analysis`、`key_decisions`、`final_confirmation`，并且 review 闭合后才能交给 `/test-design`。
- 现有样例里虽然 `design.json` 已经有 `decision_state=已冻结` 和 `final_confirmation.status=confirmed`，但你指出的这版草稿并没有完成同等闭环，所以不能按已冻结设计下发。

**下一步**
1. 把 `HttpOnly Cookie` 明确写进 `UNIT-1` 的决策项，说明它替代了哪一个候选。
2. 补一条可验证的取舍理由，说明为什么这会优先于 `localStorage/sessionStorage`。
3. 让用户确认这次安全取舍是否接受，再交给 `/test-design`。