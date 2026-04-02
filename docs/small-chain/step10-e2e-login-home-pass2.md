# Step 10 E2E Acceptance — login + home (pass 2)

Date: 2026-04-02
Scenario: 用户登录成功后跳转首页，登录失败保持登录页并显示错误提示
Run type: small-chain 全流程系统测试（流程样本，不改业务代码）

## Chain Walkthrough

1. brainstorming
   - 产出: `docs/user-auth/2026-04-02-login-home-flow-smoke/design.md`
   - 设计约束明确为流程样本，不触碰业务代码。
2. writing-plans
   - 产出: `tasks.md` + `plan.md`
   - `tasks.md` 为唯一完成状态真源，`plan.md` 仅保留编号步骤和 `[T*]` 引用。
3. subagent-driven-development（手动等价执行）
   - 落地: `simulation/login-home-cases.json` + `scripts/validate_login_home.py`
   - 产出执行证据: `implementation.md`
   - `tasks.md` 全部勾选为 `[x]`
4. verify-change
   - 产出: `verify-report.md`
   - 结论: PASS，无 CRITICAL/WARNING/SUGGESTION
5. archive
   - 归档到: `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/`
   - 追加 changelog: `docs/user-auth/CHANGELOG.md`

## Acceptance Artifacts

- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/design.md`
- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/tasks.md`
- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/plan.md`
- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/simulation/login-home-cases.json`
- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/scripts/validate_login_home.py`
- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/implementation.md`
- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/verify-report.md`
- `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/archive-result.md`

## Verification Commands

- pre-archive（在 `docs/user-auth/2026-04-02-login-home-flow-smoke/` 执行）:
  - `python3 ../../../community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py tasks.md plan.md`
- post-archive（在 `docs/archive/user-auth/2026-04-02-login-home-flow-smoke/` 执行）:
  - `python3 ../../../../community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py tasks.md plan.md`
- `python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case success --expect-status success --expect-route /home`
- `python3 scripts/validate_login_home.py --file simulation/login-home-cases.json --case failure --expect-status failure --expect-route /login --expect-error "invalid credentials"`

## Result

PASS. small-chain 在登录/首页需求样本上完成二次端到端闭环验证。
