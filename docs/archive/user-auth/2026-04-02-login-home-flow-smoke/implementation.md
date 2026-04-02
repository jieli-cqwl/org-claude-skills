# Implementation Evidence — login-home-flow-smoke

日期: 2026-04-02

## T1: 登录成功跳首页

命令:

```bash
python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case success --expect-status success --expect-route /home
```

输出:

```text
[PASS] case=success status=success route=/home
```

文件检查:

```bash
rg -n '"success"|"route_after_login": "/home"' simulation/login-home-cases.json
```

```text
2:  "success": {
3:    "status": "success",
4:    "route_after_login": "/home",
```

## T2: 登录失败保留原交互

命令:

```bash
python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case failure --expect-status failure --expect-route /login --expect-error "invalid credentials"
```

输出:

```text
[PASS] case=failure status=failure route=/login error=invalid credentials
```

文件检查:

```bash
rg -n '"failure"|"route_after_login": "/login"|"error_message": "invalid credentials"' simulation/login-home-cases.json
```

```text
7:  "failure": {
8:    "status": "failure",
9:    "route_after_login": "/login",
10:    "error_message": "invalid credentials"
```

## T3: 验收准备

- `design.md` / `tasks.md` / `plan.md` 已齐备。
- `check_task_plan_consistency.py` 已执行通过（见 `verify-report.md`）。
