# Design — login-home-flow-smoke

创建日期: 2026-04-02

## Why

需要用一个最小需求对 small-chain 进行全流程系统测试，验证从设计、计划、执行、验收到归档的闭环是否稳定可复现。登录成功跳首页、登录失败留在登录页是边界清晰且易验证的样本。

## Scope

- 范围内: 用模拟工件验证“成功跳转 `/home`、失败保留 `/login` + 错误提示”并跑完 small-chain 全流程。
- 不做: 修改真实业务代码；引入真实前后端接口或 UI 页面实现。

## Approach

在变更目录中创建 `simulation/login-home-cases.json` 和 `scripts/validate_login_home.py`，用命令行校验成功/失败两个分支，再把执行证据落到 `implementation.md`。最后通过 `verify-change` 报告并归档。

## Alternatives Considered

| 方案 | 优势 | 劣势 | 结论 |
|------|------|------|------|
| 在真实业务代码中改登录逻辑 | 最贴近生产实现 | 本仓库不是业务工程，改动面不真实 | 不采用 |
| 用模拟工件做流程验收 | 可控、可重复、与仓库定位一致 | 只能验证流程，不验证真实业务代码 | 采用 |

## Key Decisions

- D1: 以“流程验收样本”方式完成本次测试，不触碰业务代码。
  - 理由: 本仓库目标是技能链路与交付流程验证。
- D2: 成功/失败分支都由脚本命令校验，避免主观判断。
  - 理由: 保证 AC 可执行、可复现。

## Success Criteria

- 成功分支校验命令通过，且路由结果为 `/home`。
- 失败分支校验命令通过，且路由保持 `/login` 并保留错误提示。
- `tasks.md` 全部勾选完成，`verify-report.md` 为 PASS 且无 CRITICAL。
