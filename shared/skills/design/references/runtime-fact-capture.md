# 运行时现状采证模板

## Resource Contract

| 字段 | 内容 |
| --- | --- |
| Trigger | S2 涉及配置中心、数据源、部署拓扑、外部集成、密钥管理或链路可达性 |
| Read | `references/runtime-fact-capture.md` |
| Expect | 只读采证边界、必填维度、待补采策略和差异记录要求 |
| Consume | 顶层 `design.json.runtime_facts`，并支撑 `input_analysis`、`data_architecture`、`risks` |
| Evidence | runtime_facts 有 dimension/current_value/capture_command/data_source/observed_at 或待补采阻塞记录 |
| Sync | 同步 `design/SKILL.md`、design schema/gate、semantic validator 和 fixtures |

## 采证合同

- 只允许只读采证；禁止改配置、重启进程、写文件或改变运行态。
- 采证结果先回填 `design.json.runtime_facts`，再由主 Agent 冻结为设计输入。
- 无法采证时标注 `待补采`、阻塞原因和恢复方式，不得用猜测补空。
- 输出至少写明：`输入边界`、`当前判断`、`证据锚点`、`未决项（如有）`、`禁止越权项`。

## 最小字段

| 字段 | 约束 |
| --- | --- |
| `fact_id` | 同一维度内唯一事实编号 |
| `dimension` | 与 `design.json.runtime_facts[*].dimension` 一致 |
| `current_value` | 只能写实测结果，不写推测 |
| `capture_command` | 只读命令或只读 API 调用 |
| `data_source` | 进程、配置中心、DB、HTTP 响应、日志等 |
| `observed_at` | `YYYY-MM-DD HH:mm` |
| `blocking_reason` | 采证受阻时必填 |
| `waiver` | 用户确认允许偏差时必填 |

## 必填维度

触及运行态时至少覆盖相关维度：运行环境、部署拓扑、配置中心、数据源、外部中间件、密钥管理、链路可达性、已知偏差 vs 设计约束。

推荐只读采证：`uname -a`、`ps aux`、`ss -tln`、`systemctl list-units`、`curl`、`mysql -e 'SELECT 1'`、`redis-cli ping`、`nc -zv`、`stat`。

纯代码层重构可豁免，但必须在 `design.json.runtime_facts` 写明「运行时采证不适用」和理由。

## 差异与降级

- 每次采证都要记录“设计预期 vs 运行时实际”的差异；出现关键不符时，S3 优先拆解，不得直接进入方案探索。
- SSH、账号、鉴权或第三方限流导致采证受阻时，写 `待补采 + 阻塞原因 + 预期恢复方式`；第三方受限可标为未验证假设并交给后续验证。
- 禁止用“可能 / 大概 / 应该是”填充事实字段。
