# 运行时现状采证模板

> 引用者：design SKILL.md Step 2（扫描现状）
> 用途：强制 design 阶段对运行时/基础设施采真实事实，避免 ADR 基于静态猜测
> 适用 Agent：Runtime Fact Capture Agent

## 采证合同

- 只允许只读采证，不允许修改配置、重启进程、写文件或做任何会改变运行态的动作。
- 采证结果必须先回填到 `design.json.input_analysis.runtime_facts`，再由主 Agent 冻结为设计输入。
- 无法采证时，必须显式标注 `待补采`、阻塞原因和预期恢复方式，不得用猜测补空。
- 输出至少显式写明：`输入边界`、`当前判断`、`证据锚点`、`未决项（如有）`、`禁止越权项`。

## 阶段补充字段

本文件直接定义 design 阶段运行时采证最小输出；只保留当前步骤真正需要的字段。

| 字段 | 含义 | 必填 | 约束 |
|------|------|------|------|
| `fact_id` | 同一维度内的唯一事实编号 | 是 | 用于串联 `design.json.input_analysis.runtime_facts`、reviewer 证据和人类投影视图 |
| `dimension` | 采证维度 | 是 | 必须与 `design.json.input_analysis.runtime_facts[*].dimension` 一致 |
| `current_value` | 当前实测值 | 是 | 只能写实测结果，不写推测 |
| `capture_command` | 采证命令 | 是 | 必须是只读命令或只读 API 调用 |
| `data_source` | 数据来源 | 是 | 例如进程、配置中心、DB、HTTP 响应、日志 |
| `observed_at` | 采证时间 | 是 | 使用 `YYYY-MM-DD HH:mm` |
| `blocking_reason` | 待补采原因 | 条件必填 | 仅当采证受阻时填写 |
| `waiver` | 偏差豁免记录 | 条件必填 | 仅当用户确认允许偏差时填写 |

## 适用范围

当 feature 涉及以下任一项时，本模板 REQUIRED；否则显式写 `运行时采证不适用`：

- 配置中心（Nacos/Apollo/MSE 等）的连接或内容
- 数据源（MySQL/Redis/ES/Mongo 等）的连接或 schema
- 部署拓扑（服务进程/端口/systemd unit/容器）
- 外部集成（第三方 API/OSS/MQ/网关）
- 密钥管理（secrets 文件/环境变量注入）

纯代码层重构（无运行时依赖变更）可豁免，但需在 `design.json.input_analysis.runtime_facts` 显式标注「运行时采证不适用」+ 理由。

## 必填维度（每个维度都要有"当前值 + 采证命令 + 数据来源 + 时效"）

| 维度 | 必填字段 | 推荐采证命令 |
|------|---------|-------------|
| 运行环境 | OS / CPU / 内存 / 磁盘 / swap | `uname -a` / `nproc` / `free -h` / `df -h` |
| 部署拓扑 | 进程列表 / 端口 / systemd unit 状态 | `ps aux` / `ss -tln` / `systemctl list-units` |
| 配置中心 | 实例地址 / namespace / 已有 dataId 清单 / 认证方式 | `curl {addr}/nacos/v1/...` / 控制台截图 |
| 数据源（逐实例）| 每个服务实际连的 DB URL / 账号 / 是否可达 | `mysql -h {host} -u {user} -e 'SELECT 1'` |
| 外部中间件 | Redis / ES / MQ / OSS 地址 + ping 结果 | `redis-cli ping` / `curl es:9200` / `nc -zv ...` |
| 密钥管理 | secrets 文件位置 / 权限 / 含哪些 key 名 / 是否真实注入进程 | `stat` / `grep -E '^[A-Z_]+='` / `systemctl show -p Environment` |
| 链路可达性 | 关键 API HTTP 状态 + code + **业务字段语义验证**（不止非空）| `curl + jq` + 人工核对业务字段 |
| 已知偏差 vs 设计约束 | 每条约束（CON-NNN）的实测值 + waiver 记录 | 手工对照 |

## 与设计预期差异表（REQUIRED）

每次采证必须产出一组 **`design_expected_vs_actual`** 结构化记录，至少覆盖上述 8 个维度里的 4 个。任一行出现完全不符，立即在 S3 问题拆解阶段优先处理，不得直接进 S5 方案探索。

## 降级策略（采证受阻时）

| 阻塞原因 | 降级方式 | 必须标注 |
|---------|---------|---------|
| 服务器 SSH 不通 | 请求用户从本地 SSH 协助，或用 IaaS 控制台 VNC | 「待补采 + 阻塞原因 + 预期恢复时间」|
| 无数据库账号 | 请求用户提供只读账号，或用 ORM 日志反推 | 同上 |
| 配置中心 API 需鉴权 | 让用户在控制台截图，或提供只读 token | 同上 |
| 第三方 API 限流 | 延后到 Test 阶段验证，design 阶段标注假设 | 「未验证假设」清单 |

**禁止**：遇到采证受阻就**跳过**该维度，或用「可能 / 大概 / 应该是」等模糊语言填写 —— 必须显式标注「待补采」且阻塞记录在审查结论中。
