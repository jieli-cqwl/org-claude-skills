结论：不接受“先 mock 打通就算完成”。原因很简单：TL-003 的验收目标是守住 mock 与真实验收边界；mock 只能证明替身链路可跑，不能证明真实三方回调、真实前置处理、真实 agent 调度、真实响应回写和真实链路证据成立。把 mock-only 标成完成，按本轮规则是验收伪造。

执行策略：不启用协作、不派发 developer、不写代码、不写真实提交计划。本次只输出 Stage 1 synthetic dry-run 的 tech-lead gate 判断。

**Mock 边界**
允许用途：
- 开发隔离不可控外部依赖。
- 构造异常、超时、失败路径。
- 开发前预检：验证字段形状、流程编排、错误处理、日志结构。
- demo-only 展示“替身返回”，但必须标注 `precheck_only / mock_only`。

禁止用途：
- 禁止作为最终完成证据。
- 禁止把 mock 三方回调、mock bot、mock chain_record 串起来后标成 Phase 1 完成。
- 禁止用“老板看到有返回”替代真实链路验收。
- 禁止把 mock-only evidence 写成 signoff、上线、完成或可交付。

**Task / Evidence Gate**
可作为预检证据：
- mock callback contract/parser 通过。
- fake bot / fake agent 调度路径可运行。
- fake chain_record 写入格式预检。
- 异常路径、超时、重试、错误提示的构造性测试。
- schema、脚本、局部单测、mock 集成测试结果。

必须作为最终 gate 的真实路径证据：
- 真实三方消息回调，或已授权、可复验的集成路径。
- 真实前置处理、上下文构建、agent 调度、响应回写全链路。
- 真实链路证据记录：trace id、输入输出摘要、状态、时间、错误信息、持久化记录。
- 证据必须能逐条对应 PM/Design/Test-design 的 Phase 1 最终验收要求。

**给 Delivery-owner 的验收边界**
- 任一最终验收项只有 mock-only evidence：状态必须是 `BLOCKED / NEEDS_REAL_EVIDENCE`。
- mock 证据只能挂在预检项，不能挂在 final acceptance gate。
- 不得把 `有返回`、日志输出、局部脚本绿灯、mock 链路截图标成上线成功。
- 进入下一阶段前，必须看到真实路径 evidence ref；没有就暂停并回流 owner。
- 若用户坚持先展示，只能定义为 demo/precheck，不改变完成状态。

**Stage 1 Synthetic 边界**
本结论只证明 TL-003 中 tech-lead 角色守门口径正确，不证明真实业务交付、不证明 `qft-pai` 可用、不替代 Stage 2 真实集成、灰度、回滚和上线验收。不得进入 `/Users/lijieli/project/qft-pai`，不得派发 developer，不能产生真实提交计划。

依据已核对：tech-lead hard-gate 禁止 Mock-only 最终验收；TL-003 明确要求真实路径证据作为 gate；Stage 1 charter 明确不证明真实交付、不用 mock 替代 Stage 2 真实验收。