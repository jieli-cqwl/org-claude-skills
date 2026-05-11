# Skill 质量标准

Skill 只有在让 agent 对特定任务可观测地比无 skill 更好时才成立；否则只是新增触发入口、上下文成本和维护负担。

## 存在判据

创建或保留 Skill 前先确认：

- 同一指令或流程被重复粘贴 >=3 次，或 CLAUDE.md 的事实段已经长成流程。
- 该需求不应改由其他机制承载：每次对话都需要的事实放 CLAUDE.md；确定性动作放 Hook/script；外部服务连接放 MCP；按需加载的专业流程才放 Skill。

## 最低要求与生命周期

- 效果增值：with-skill 比 without-skill 在目标行为上更好；用对照实验、可验证断言和人工审查证明。
- 触发准确：description 能说明何时使用、何时分流；用正反例 eval query 验证。
- 结构合理：SKILL.md < 500 行，长材料按需加载；用行数和渐进披露检查验证。
- 安全边界：有副作用的操作有权限控制；用 invocation control 和 allowed-tools 审查验证。
- 验证循环：Draft -> Test -> Review -> Improve -> Repeat。
- 生命周期：retain = 效果正向且成本可接受；optimize = 方向成立但证据不足或有明显优化点；retire = 无增益、可替代或成本 > 收益。

## 诊断维度

根基维度有问题时先修根基，再看后续。

| 层级 | 维度 | 判断口径 |
| --- | --- | --- |
| 准入 | Directory / Reachability / Resource | 目录、入口、运行可达、主流程依赖资源完整 |
| 根基 | Trigger | description 能说明何时使用、何时不使用，并能与相邻 Skill 分流 |
| 根基 | Responsibility | 目标、输入、输出、范围、完成标准和阻塞条件清楚 |
| 根基 | Flow | 流程贴近真实办事顺序，步骤之间有因果关系 |
| 边界 | Input | 输入对象来自真实流程，足以启动当前职责 |
| 边界 | Output | 默认产物、消费者和验证方式清楚 |
| 内功 | Resource | SKILL.md、reference、script、schema、template、eval、test 各守职责，按需加载 |
| 内功 | Determinism | 可枚举判断由脚本、schema、hook 或测试执行 |
| 保障 | Eval | eval/test 覆盖核心行为和回归风险 |
| 保障 | Runtime | 运行入口、权限和有效性记录与当前职责一致 |

别名：Professional Workflow = Flow；Artifact Contract = Output；Verification Loop = Eval。

## 效果信号

准入和运行质量闭合后，再看：Baseline 对比、任务成功率、成本收益、稳定性、反证样本。

## HARD-GATE 编写口径

一条规则进入 `HARD-GATE` 前至少命中一类边界：准入、裁决权、阶段推进、证据、副作用、收敛。

每条 HARD-GATE 必须能改变下一步动作：停止、回退、等待用户、禁止写入、禁止交接或禁止完成声明。

## 正文执行价值

`SKILL.md` 每句话必须属于：执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why。分析维度、消费者解释、历史说明、工具边界说明、写作约束和测试意图不得直接进入正文。

## 确定性校验

可枚举、可复验的判断必须落到脚本、schema、hook、gate 或测试。看四项：触发者、执行入口、执行时机、失败结果。
