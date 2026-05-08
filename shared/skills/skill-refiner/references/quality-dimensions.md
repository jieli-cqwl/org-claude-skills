# Skill 质量维度

Skill 让 agent 在特定任务上可观测地比无 skill 时更好。不符合的 Skill 增加触发入口、上下文成本和维护负担。本文件承载最低标准和 skill-refiner、scan 使用的评估维度。

## 存在判据

创建 skill 前，确认满足以下条件：

- 同一指令或流程被重复粘贴 ≥3 次，或 CLAUDE.md 的某段从事实长成了流程。
- 不属于其他机制的更优范畴：

| 需求 | 该用 |
| --- | --- |
| 每次对话都需要的事实 | CLAUDE.md |
| 确定性动作（格式化、校验、转换） | Hook |
| 外部服务连接 | MCP |
| 按需加载的专业流程 | Skill |

## 最低要求

| 维度 | 要求 | 验证方式 |
| --- | --- | --- |
| 效果增值 | with-skill 比 without-skill 在目标行为上可观测地更好 | with/without 对照 + 可验证断言 + 人工审查 |
| 触发准确 | description 能让 runtime 判断何时使用、何时不使用 | eval query（正反例）测试 trigger rate |
| 结构合理 | SKILL.md < 500 行；大量参考材料按需加载 | 行数 + 渐进披露检查 |
| 安全边界 | 有副作用的操作有对应权限控制 | invocation control + allowed-tools 审查 |

## 验证方式

- **效果对比**：with-skill vs without-skill 同一任务各跑一遍，用可观察的断言衡量差异。
- **触发测试**：eval query 覆盖正例、反例和近似场景，计算 trigger rate，迭代优化直到收敛。
- **迭代循环**：Draft → Test → Review → Improve → Repeat。

## 生命周期信号

| 信号 | 条件 |
| --- | --- |
| retain | 效果对比正向，成本可接受 |
| optimize | 方向成立但证据不足，或有明显优化点 |
| retire | 无增益、可被替代或成本 > 收益 |

## 准入门禁

| 门禁 | 判断标准 |
| --- | --- |
| G0 | 目录、`SKILL.md` 和必要 frontmatter 可被定位和解析 |
| G1 | 目标 runtime 能找到该 Skill，启用状态不冲突 |
| G2 | 主流程依赖的 reference、script、schema、template 存在且路径正确 |

## 运行质量维度

| 维度 | 判断标准 |
| --- | --- |
| S1 Discovery & Trigger | description 能说明何时使用、何时不使用，并能与相邻 Skill 分流 |
| S2 Task Contract | 目标、输入、输出、范围、完成标准和阻塞条件清楚 |
| S3 Professional Workflow | 流程贴近真实办事顺序，步骤之间有因果关系 |
| S4 Resource Architecture | 主体、reference、script、schema、template、eval、test 各守职责，按需加载 |
| S5 Runtime Fit & Safety | 工具、权限、运行时入口和外部影响与任务匹配 |
| S6 Artifact Contract | 产物的路径、格式、字段和消费者清楚 |
| S7 Verification Loop | 前置校验、目标测试和完成验证都有可执行入口 |
| S8 Evolution & Integration | 改动能同步到消费者、eval、tests、adapter 和文档入口 |

## 效果信号

G0-G2 和 S1-S8 闭合后，E1-E5 才能支撑更高价值。

| 信号 | 判断标准 |
| --- | --- |
| E1 Baseline 对比 | 能与裸模型、旧 Skill 或相邻 Skill 对比 |
| E2 任务成功率 | 代表性场景能证明成功标准的达成质量 |
| E3 成本收益 | token、时间和维护成本与收益匹配 |
| E4 稳定性 | 不同输入、任务规模或 runtime 下保持核心行为 |
| E5 反证样本 | 能说明哪些场景无收益或应交给其他能力 |

## HARD-GATE 编写口径

一条规则进入 `HARD-GATE` 前必须满足至少一项：

- 准入边界：上游基线或必要输入不成立时，继续会错阶段。
- 裁决权边界：当前 Skill 会替用户或上下游 owner 做决定。
- 阶段推进边界：未确认或未冻结时继续会错误 handoff 或伪完成。
- 证据边界：缺可复验证据时会声称完成。
- 副作用边界：未授权写文件、提交或调用外部系统。
- 收敛边界：循环无进展或需要用户裁决。

每条 HARD-GATE 必须能改变下一步动作：停止、回退、等待用户或禁止写入/交接/完成声明。

## 正文执行价值

`SKILL.md` 每句话必须属于：执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why。

分析维度、消费者解释、历史说明、工具边界说明、写作约束和测试意图不得直接进入正文。

## 确定性校验

可枚举、可复验的判断必须落到脚本、schema、hook、gate 或测试。看四项：触发者、执行入口、执行时机、失败结果。
