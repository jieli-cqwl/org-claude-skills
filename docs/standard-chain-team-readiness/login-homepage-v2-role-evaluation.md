# login-homepage-v2 角色评估

## 评估范围

本评估使用 `docs/login-homepage-v2/phase-1` 的完整标准链实跑结果，目标是判断标准链每个角色是否该存在，以及本次被触发角色是否符合预期或超预期。

整体裁决：PASS。

`fix` 未触发。本次没有 review、verify、QA 或 consistency FAIL 后的修复闭环，所以只评价它的存在合理性，不评价本次胜任度。

## 证据来源

| 证据 | 用途 |
| --- | --- |
| `contracts/standard-chain.yaml` | 角色清单、输入、输出、消费者和 authority 边界 |
| `contracts/small-chain.yaml` | 路由边界：低风险、小范围、单点变更由 `small-chain` 承接 |
| `docs/login-homepage-v2/phase-1/evidence/role-capability-evidence.json` | 角色输入、输出、下游消费者和噪音控制线索 |
| `docs/login-homepage-v2/phase-1/code-review-result.json` | review 发现并关闭的真实问题 |
| `docs/login-homepage-v2/phase-1/qa-result.json` | 浏览器 CDP 验收和用户视角发布判断 |
| `docs/login-homepage-v2/phase-1/consistency-audit-result.json` | L1-L6 trace 和漂移审计 |
| `docs/login-homepage-v2/phase-1/signoff-package.json` | goal、AC、phase goal 签收闭环 |
| `bash tests/test-standard-chain-login-homepage-v2.sh` | 12 个 HTTP 测试、phase validation、readiness、replay 和 role output 检查 |
| `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_login_homepage_v2_app.py'` | 登录、首页、退出、旧 cookie 拒绝等真实 HTTP 单测 |
| Chromium CDP 浏览器验收 | 登录页、首页、退出后登录页截图与 stale route 断言 |

不能把 role evidence 自报 PASS 当作最终依据。本次 smoke 脚本已改成先检查 review、verify、QA、consistency 和 delivery-owner 的具体输出工件，再接受 role evidence。

## 汇总表

| 角色 | 是否该存在 | 存在分数 | 本次胜任度 | 胜任分数 | 关键证据 | 调整动作 |
| --- | --- | ---: | --- | ---: | --- | --- |
| `product-director` | 保留 | 12 | 符合预期 | 10 | `brief.json` 与 `phase-prd.json` 保留 Director lock；PM refined 后 locked fields 未漂移 | 保留 |
| `product-manager` | 保留 | 12 | 符合预期 | 10 | UNIT-1..UNIT-3、AC、排除项、phase exit conditions 被 design/test-design/tech-lead 消费 | 保留 |
| `design` | 保留 | 11 | 符合预期 | 9 | `design.json` 给出接口、运行事实、验证与回滚；历史 pilot 只作为模式输入 | 保留 |
| `test-design` | 保留 | 12 | 符合预期 | 10 | 三个 `test-cases.json` 分别覆盖 UNIT AC、等价类和 QA handoff | 保留 |
| `tech-lead` | 保留 | 12 | 符合预期 | 10 | `plan.json` 与 `tasks.json` 明确 scope freeze、文件范围、真实 proving command | 保留 |
| `developer` | 保留 | 12 | 符合预期 | 9 | T1/T2/T3 developer-report 含 RED/GREEN；后续被 review 纠正 stale evidence 和边界遗漏 | 保留并强化证据门禁 |
| `review` | 保留 | 12 | 超预期 | 14 | `code-review-result.json` 关闭 6 个问题：自报 PASS、stale evidence、readiness 缺口、session/logging 风险等 | 保留为强角色 |
| `verify` | 保留 | 11 | 符合预期 | 11 | 三个 `verify-result.json` 均映射 AC、plan/tasks active refs 和 developer-report refs | 保留并工具化门禁 |
| `qa` | 保留 | 12 | 超预期 | 14 | `qa-result.json` 记录 Chromium CDP 浏览器验收，覆盖登录、首页、退出、旧 cookie 拒绝 | 保留为强角色 |
| `consistency-auditor` | 条件保留 | 9 | 符合预期 | 11 | `consistency-audit-result.json` L1-L6 PASS，trace matrix 三个 UNIT 全 CLOSED | 保留并强化自动化 |
| `fix` | 条件保留 | 9 | N/A | N/A | 本次无 FAIL 后 fix-result；存在价值来自标准链 FAIL 后根因修复职责 | 条件启用 |
| `delivery-owner` | 保留 | 12 | 符合预期 | 12 | `delivery-state.json`、`artifact-registry.json`、`signoff-package.json`、`user-decision.json` 完成闭环 | 保留 |

## 角色判断

### `product-director`

存在合理。它拥有根问题、目标、范围、Phase 边界和 Director lock 的独立责任。删除后，PM、design 和 tech-lead 会缺少统一约束源。

本次符合预期。证据是 `brief.json` 和 `phase-prd.json` 的 `director_confirmation`、`locked_fields` 和 digest 被下游保持。

### `product-manager`

存在合理。它把 Director 基线转成 UNIT、AC、排除项和 phase exit conditions。该职责不能由 Director 直接承担，否则上游战略边界会混入执行细节。

本次符合预期。UNIT 定义被 design、test-design 和 tech-lead 消费，未改写 Director locked fields。

### `design`

存在合理。它负责技术方案、接口边界、复用判断、验证与回滚。删除后，developer 会直接从 PRD 跳实现，设计取舍缺少可审计依据。

本次符合预期。`design.json` 将历史 pilot 限定为模式输入，同时声明 v2 独立实现路径。

### `test-design`

存在合理。它在开发前把 AC 转成测试矩阵和 QA handoff，能压住“实现后补测”的风险。

本次符合预期。三份 `test-cases.json` 分离 UNIT 责任，减少一个大杂烩测试报告带来的上下文噪音。

### `tech-lead`

存在合理。它把需求、设计和测试转换成 AI 可执行的 `plan.json` 与 `tasks.json`，并声明文件范围、依赖、proving command 和 guardrail。

本次符合预期。T1/T2/T3 的范围、依赖、测试命令和 evidence target 清晰，支撑 delivery-owner 调度。

### `developer`

存在合理。它承担 TDD 实现、代码变更和 developer-report 证据。

本次符合预期，但不是超预期。它完成了 v2 app、真实 HTTP 测试和 smoke 支撑；同时初始证据存在 stale commit、旧测试次数和边界遗漏，后续由 review/verify 拉回。

### `review`

存在合理。它负责实现质量、风险、回归和证据完整性审查。删除后，stale evidence、自报 PASS 和 readiness 缺口会直接进入签收包。

本次超预期。它发现并关闭 6 个真实问题，尤其是 role evidence 自报 PASS、developer-report stale evidence、T3 readiness 缺口、session store 边界和认证日志缺失。

### `verify`

存在合理。它负责 Task 级 AC 覆盖、active refs、developer-report refs 和质量检查。

本次符合预期。T1/T2/T3 的 `verify-result.json` 均能把 AC 映射到文件、行号、测试或脚本边界。该角色适合继续强化为自动化门禁，但不能删除。

### `qa`

存在合理。它代表用户视角和发布质量，不等同于 verify。verify 看 Task 级 AC，QA 看用户旅程、发布风险和未覆盖边界。

本次超预期。QA 执行了 Chromium CDP 浏览器路径，证明登录表单、成功登录、首页、退出和旧 cookie 拒绝，而不是停在 API 或单测层。

### `consistency-auditor`

存在合理，但属于 advisory sidecar。它负责跨工件漂移、trace 和引用完整性，不拥有签收权。

本次符合预期。`consistency-audit-result.json` L1-L6 全 PASS，三个 UNIT trace 全 CLOSED。该职责适合脚本化增强，失败时再展开人工判断。

### `fix`

存在合理，条件启用。它不在每次标准链中都触发；只有 review、verify、QA 或 consistency 发现 FAIL 后，才承接 Observe -> Hypothesize -> Test -> Fix 的根因修复。

本次未触发，所以不评价胜任度。不能因为未触发就删除该角色。

### `delivery-owner`

存在合理。它是交付控制面，负责消费专家证据、维护交付状态、签收包、registry 和 user decision。

本次符合预期。它完成了 `delivery-state.json`、`artifact-registry.json`、`signoff-package.json` 和 `user-decision.json`，并把 review、QA、consistency、readiness、replay 汇入最终签收边界。

## 组织结论

本次标准链角色体系成立。没有角色需要删除。

调整方向如下：

- `review`、`qa` 保持强角色，不下沉为纯脚本。
- `verify`、`consistency-auditor` 保留角色边界，同时增强自动化门禁。
- `fix` 保持条件角色，只在 FAIL 后触发。
- `developer` 继续保留 TDD 强约束，不能作为单点可信源。
- `delivery-owner` 保持完整交付控制面，不吸收专家 SOP，不替用户签收。

下一次真实需求复跑时，用本报告作为 baseline，重点观察 `developer` 证据质量和 `verify`/`consistency-auditor` 自动化覆盖能否继续降低上下文噪音。
