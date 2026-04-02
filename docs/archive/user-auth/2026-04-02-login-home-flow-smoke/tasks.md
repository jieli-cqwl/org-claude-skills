# Tasks — login-home-flow-smoke

创建日期: 2026-04-02
关联 plan: ./plan.md

## 验收清单

- [x] T1 构建登录成功跳首页的模拟数据与校验能力
  - AC: 运行 `python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case success --expect-status success --expect-route /home` 返回 PASS。
  - AC: `simulation/login-home-cases.json` 中成功分支的 `route_after_login` 为 `/home`。
- [x] T2 构建登录失败留在登录页的模拟数据与校验能力
  - AC: 运行 `python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case failure --expect-status failure --expect-route /login --expect-error "invalid credentials"` 返回 PASS。
  - AC: `simulation/login-home-cases.json` 中失败分支包含 `route_after_login=/login` 与 `error_message=invalid credentials`。
- [x] T3 产出流程执行证据并完成验收
  - AC: `implementation.md` 记录 T1/T2 的执行命令与结果。
  - AC: `verify-report.md` 结论为 PASS 且 CRITICAL 为 none。

## 完成定义

所有 task 勾选完成 = 可进入 verify 阶段。
