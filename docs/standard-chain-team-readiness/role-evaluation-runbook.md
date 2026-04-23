# Standard-Chain Role Evaluation Runbook

## 使用时机

标准链签收后执行角色评估。这里的签收后是指 `signoff-package.json`、`user-decision.json`、`delivery-state.json`、`qa-result.json`、`code-review-result.json`、`verify-result.json` 和 `developer-report.json` 已经存在，并且对应 fresh proving commands 已经通过。

低风险、小范围、单点变更仍由 `small-chain` 承接。进入本 runbook 的对象必须已经走完整 `contracts/standard-chain.yaml` 链路。

## 输入

必读输入：

- `contracts/standard-chain.yaml`
- `contracts/small-chain.yaml`
- 当前 feature 的 `brief.json`
- 当前 phase 的 `phase-prd.json`
- 当前 phase 的 `artifact-registry.json`
- 当前 phase 的 `plan.json`
- 当前 phase 的 `tasks.json`
- 当前 phase 的 `developer-report.json`
- 当前 phase 的 `verify-result.json`
- 当前 phase 的 `code-review-result.json`
- 当前 phase 的 `qa-result.json`
- 当前 phase 的 `consistency-audit-result.json`
- 当前 phase 的 `delivery-state.json`
- 当前 phase 的 `signoff-package.json`
- 当前 phase 的 `user-decision.json`
- `docs/standard-chain-team-readiness/role-evaluation-rubric.md`

样例输入：

- `docs/standard-chain-team-readiness/login-homepage-v2-role-evaluation.md`

## 禁止动作

- 不修改 upstream canonical artifacts。角色评估是签收后复盘，不回写 PRD、design、plan、task、review、QA 或 signoff 结论。
- 不把 role evidence 自报 PASS 当作最终依据。
- 不新增 JSON fact source，除非先记录机器消费者、读取目的、验证命令和废弃条件。
- 不把低风险、小范围、单点变更重新拉入标准链角色评估。
- 不用未运行的命令、旧 pilot 证据或主观判断替代 fresh proving output。

## 执行步骤

1. 先运行 fresh proving commands。
   - 至少运行本 phase 的 smoke 命令。
   - 运行与实现直接相关的单测或集成测试。
   - 运行 readiness、replay 或当前标准链要求的 closeout 命令。
2. 读取 `contracts/standard-chain.yaml`，提取本次角色清单、输入、输出、消费者和 authority 边界。
3. 读取 `contracts/small-chain.yaml`，确认本次对象不是 small-chain 低风险变更。
4. 按 `role-evaluation-rubric.md` 先评估角色存在合理性。
5. 对本次被触发的角色评估胜任度。
6. 对未触发的条件角色标记 `N/A`，只记录触发条件，不评价表现。
7. 每个结论必须绑定证据来源。
8. 输出角色评估报告。
9. 将报告路径写入 `docs/standard-chain-team-readiness/worklog.md`。

## 报告要求

报告必须包含：

- 评估范围
- 证据来源
- 汇总表
- 每个角色的存在判断
- 每个被触发角色的胜任度判断
- `fix` 等条件角色的触发状态
- 组织结论
- 调整动作

每个角色至少包含这些字段：

- 角色
- 是否该存在
- 存在分数
- 本次胜任度
- 胜任分数
- 证据来源
- 关键判断
- 调整动作

## 判定边界

符合预期表示角色完成职责内产物，并且产物被下游消费。

超预期表示角色发现并推动关闭职责内真实风险，或补上原流程缺失的证据闭环，或显著降低下游消费成本并有证据支撑。

不符合预期表示角色产物缺失、越权、证据不足、未被下游消费，或导致上下文噪音回流。

## 完成条件

角色评估完成必须同时满足：

- fresh proving commands 已通过。
- 评估报告引用 `role-evaluation-rubric.md`。
- 评估报告没有把 role evidence 自报 PASS 当作最终依据。
- 评估报告区分 `standard-chain` 与 `small-chain` 路由。
- 条件角色未触发时使用 `N/A`，不强行评分。
- worklog 记录评估报告路径。
