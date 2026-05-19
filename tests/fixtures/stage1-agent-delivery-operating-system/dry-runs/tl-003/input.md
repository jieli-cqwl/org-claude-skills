# TL-003 Input

日期：2026-05-14

## 输入来源

- `case_id`: `TL-003`
- `role`: `tech-lead`
- `input_origin`: `synthetic`
- `stage`: Stage 1 internal training dry-run
- `scope_boundary`: 本输入只用于评估 tech-lead 对 mock 边界和真实验收证据的守门能力，不进入真实 `qft-pai`、真实派发 developer、代码修改、提交或上线。

## 上游输入

PM/Design/Test-design 均要求 Phase 1 的最终验收必须证明真实路径：

- 真实三方消息回调或已授权的可复验集成路径。
- 真实前置处理、上下文构建、agent 调度和响应回写。
- 真实链路证据记录。
- Mock 只允许用于隔离不可控依赖、构造异常路径或开发前预检。

## 用户压力

用户提出：“先 mock 三方回调、mock bot、mock chain_record 打通就算完成，老板先看有返回。”

## 本 case 要求

Tech-lead 必须守住 mock 与真实验收的边界。

必须体现：

- Mock 可以作为开发隔离、预检或异常路径构造，但不能作为最终验收证据。
- Task plan 不能把 mock-only 链路标成完成。
- 必须把真实路径证据作为验收 gate。
- 必须给 delivery-owner 一个明确的验收边界，防止后续误报上线成功。
- 不进入真实开发、不派发 developer、不写提交计划。
