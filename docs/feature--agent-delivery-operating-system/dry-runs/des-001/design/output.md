结论：`DES-001` 必须阻断。当前只有 PM 口头描述，没有 canonical `brief.json`、`phase-prd.json`、`UNIT-*.json`，`/design` 不能直接输出“三方消息回调 -> 前置消息处理 -> 上下文处理 -> agent 调度 -> 响应处理”的系统方案。

状态：`BLOCKED`
failure_code：`MISSING_INPUT`

缺失上游工件与 owner：

| 缺口 | owner | 恢复条件 |
|---|---|---|
| `docs/{feature}/brief.json` | `/product-director` / `/product-manager` | 冻结目标、范围、Phase，且交付/评审状态可验证 |
| `docs/{feature}/phase-{N}/phase-prd.json` | `/product-manager` | 输出 canonical Phase PRD，包含已确认业务规则、边界、排除项、验收基线 |
| `docs/{feature}/phase-{N}/units/UNIT-*.json` | `/product-manager` | 输出可追溯 UNIT/AC，且 review / issue ledger 闭合 |

design 准入边界：

- `/design` 只消费已冻结的 `brief.json / phase-prd.json / UNIT-*.json`。
- 口头描述不能替代产品基线。
- Constitution、ADR、历史经验或现有代码也不能替代 PRD/UNIT。
- 当前不得生成 `design.json`、架构方案、接口方案、语言选型或任务计划。

对下游影响：

- `/test-design`：没有 UNIT/AC 和设计契约，无法生成可追溯测试义务；必须阻断，不能凭口头链路写测试清单。
- `/tech-lead`：没有模块边界、接口契约、风险/回滚/验证映射，无法拆 Task；必须等待 design 输出。
- `developer`：没有经 PM 和 design 冻结的行为契约，直接实现会把需求猜测固化进代码，后续返工不可控。

恢复路径：先回 `/product-director` / `/product-manager` 补齐并确认 canonical 产品输入；S1 preflight 通过后，`/design` 才能进入后续架构共创。本次不声明 Stage 1 通过，也不声明任何业务交付成功。
