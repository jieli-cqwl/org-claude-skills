# product-director + product-manager 能力与结构治理

## 背景

product-director 和 product-manager 是从单体 /product skill 拆分而来的两个产品阶段 skill，负责大需求标准流程的前置产品思考环节。

拆分动机：大需求上下文溢出导致 AI 注意力稀释、产出质量下降。拆分后 eval 显示 split 0.70 vs monolith 0.38（6 个真实案例，已知局限见 deep-validation-report.md）。

本次治理目标：在拆分结构不变的前提下，审视两个 skill 的能力定义和结构表达是否符合业界最佳实践，确保产出对下游 AI 消费者足够清晰友好。

## 设计原则

### P1 每层只回答下一层自己无法回答的问题

层间冗余导致"指令诅咒"——信息堆积时 AI 遵从度反而下降（Osmani）。Director 不重复 Manager 能从代码推断的信息，Manager 不重复 Design 能自己发现的信息。

### P2 AI 下游消费者需要的是约束，不是方案

人的工作是创造性视觉和设计判断，AI 放大这个视觉但无法生成它（Kent Beck）。Director 和 Manager 的价值在于表达 intent + constraints，而不是预设实现路径。

### P3 模糊性在哪一层就在哪一层消灭

一个模糊需求会在下游裂变成几十种不同实现（Osmani 的"复合模糊性"失败模式）。Director 层消灭方向模糊，Manager 层消灭行为模糊。

## 方案对比

评估了两个方案：

**方案 A（选定）：增强纯 WHY 层。** Director 做厚 WHY（加 appetite、风险、用户画像），不加解决方案方向。保持 WHY/WHAT/HOW 的干净分离。

**方案 B（未选）：Shape Up 式 Director。** 在方案 A 基础上加入"fat marker"级粗方向草图和 rabbit holes。优点：下游 Manager 认知跳跃更小。缺点：与 /design 阶段重叠——Director 给了粗方向，design 可能推翻它造成返工；在 AI-coding 语境下不给方向有时反而让 AI 探索出更好的设计。

**选择 A 的理由：** SVPG 和 Product Coalition 指出 AI 负责实现时产品层应聚焦"什么需要成立"而非"怎么做"。链路下游有独立的 /design skill 处理 HOW，Director 保持纯 WHY 是更干净的关注点分离。Double Diamond 框架（Design Council）也验证了问题空间与方案空间分离的合理性。

## 标准链路架构

拆分结构保持不变。五层递进，每层回答不同维度：

| 阶段 | 角色 | 回答 | 产出 |
|------|------|------|------|
| product-director | 产品总监 | WHY — 解决谁的什么问题、目标、范围、节奏 | brief.json + phase-prd.json 骨架 |
| product-manager | 产品经理 | WHAT — 业务流程、场景、UNIT、验收标准 | phase-prd.json 填充 + UNIT-*.json |
| design | 架构师 | HOW (设计) — 架构、模块、接口 | design.json |
| writing-plans | 规划者 | HOW (任务) — 实现步骤 | tasks.json + plan.json |
| dev | 开发者 | DO — 写代码 | 代码 |

WHY → WHAT → HOW → DO 的递进与 Double Diamond 框架一致。两 skill 拆分在结构层面合理，不需要推翻。

## product-director 能力重定义

### Director 必须回答的 9 个核心问题

| # | 问题 | 来源 | 变化 |
|---|------|------|------|
| Q1 | 我们在解决谁的什么问题？ | D-S2 | 加厚：补充用户画像——谁、什么场景、现在怎么绕过 |
| Q2 | 成功长什么样？ | D-S3 | 保持：基线、方向、观测窗口、数据来源 |
| Q3 | 业务语言统一 | D-S4 | 保持：术语、业务对象、流程收口 |
| Q4 | 做什么、不做什么？ | D-S5 | 加厚：增加显式 Non-goals 清单，与 Scope 同等重要 |
| Q5 | 分几期交付？ | D-S6 | 保持：Phase 按交付价值拆分 |
| Q6 | 这件事值多少投入？ | 新增 | Shape Up 的 Appetite："2 周的事还是 2 个月的事"，约束下游方案复杂度 |
| Q7 | 已知的技术/资源约束？ | 新增 | 可行性边界："必须基于现有 X"、"不能引入 Y"。Manager/Design 无法自行判断 |
| Q8 | 最大的风险和未知项？ | 新增 | Shape Up 的 Rabbit Holes："如果 X 不成立，整个方案要推翻" |
| Q9 | 为什么选这个范围？ | 显式化 | 决策推演：关键范围取舍的理由，让下游理解边界背后的 WHY |

不增加解决方案方向——SVPG 和 Product Coalition 指出，AI 负责实现时产品层应聚焦"什么需要成立"而非"怎么做"。链路下游有 /design 专门处理 HOW。

### Director 流程步骤

| 步骤 | 名称 | 交互模式 | 变化 |
|------|------|---------|------|
| D-S1 | 静默信息收集 | 静默 | 保持 |
| D-S2 | 问题与用户澄清 | 全共创 | 扩展：原"根问题澄清"，融入 Q1 用户画像 |
| D-S3 | 目标、成功标准与 Appetite | 全共创 | 扩展：融入 Q6，成功标准同时收口投入边界 |
| D-S4 | 业务语义收口 | 草案修正 | 保持 |
| D-S5 | 范围、Non-goals 与可行性约束 | 草案修正 | 扩展：增加 Q4 显式 Non-goals、Q7 可行性约束、Q9 决策理由 |
| D-S5.5 | 风险与未知项 | 草案修正 | 新增：Q8，在 Phase 规划前完成，风险可能影响 Phase 拆法 |
| D-S6 | Phase 规划 | 草案修正 | 保持，输入更丰富（有 appetite 和风险信息） |
| D-G1 | 总监确认门 | 全共创 | 保持，确认范围扩大到包含新增字段 |

### 保持不变的 Director 机制

- 全共创/草案修正交互模式
- Director 确认门 D-G1
- 不产出 UNIT/AC（Manager 职责）
- locked_field_digest 锁定机制
- canonical JSON 输出格式
- 验证脚本 validate_standard_chain_phase.py

## product-manager 能力重定义

### Manager 必须回答的 8 个核心问题

| # | 问题 | 来源 | 变化 |
|---|------|------|------|
| Q1 | 用户从头到尾怎么操作？ | M-S1 + M-S2 | 保持 |
| Q2 | 业务规则怎么映射到功能？ | M-S3 | 保持 |
| Q3 | 拆成哪些可独立交付的 UNIT？ | M-S4 | 保持 |
| Q4 | 每个 UNIT 的验收标准？ | M-S5 | 增强：升级为示例驱动 AC |
| Q5 | 有哪些待设计决策？ | M-S6 | 增强：结构化格式 |
| Q6 | 每个 UNIT 的边界和失败模式？ | M-S5 覆盖不足 | 新增显式要求：解决 AI 的"70%问题" |
| Q7 | 每个 UNIT 怎么验证完成？ | 缺失 | 新增：Verification Plan |
| Q8 | 每个 UNIT 在代码库中的落点和约束？ | 缺失 | 新增：Integration Context |

### AC 增强（Q4 + Q6）

从"描述性 AC"升级为"示例驱动 AC"。每条 AC 包含：

- AC 描述：可观察、可验证的行为陈述
- 示例输入：具体的输入数据
- 预期结果：具体的输出或可观察状态变化
- 边界情况：边界值和特殊条件下的预期行为
- 失败模式：异常输入或状态下应如何处理

示例驱动 AC 对 AI 下游更友好——给具体的输入输出样本，而不是只给抽象描述。

### 待设计决策增强（Q5）

从松散的"待定"记录改为结构化格式：

- 决策名称
- 候选选项（2-3 个）
- 约束条件
- 影响的 UNIT
- 建议由 /design 裁决

### Verification Plan（Q7）

每个 UNIT 定义具体的验证方式：

- 验证类型：自动测试 / 手动验证 / 混合
- 验证命令或操作步骤
- 预期的成功信号

不是笼统的"测试通过"，而是下游 AI 可以直接执行的验证方案。

### Integration Context（Q8）

每个 UNIT 标注代码落点信息：

- 预期的文件/目录位置
- 应遵循的现有模式或约定
- 禁止修改的区域
- 相关的现有代码引用

帮助下游 AI 避免架构漂移（Martin Fowler："LLM 放大好的和坏的设计决策"）。

### 三方评审焦点调整

保持 3 视角 × max 10 轮机制，在产品视角中增加 **AI 可执行性**检查维度：

- 规格是否足够明确，AI 不需要猜测？
- 边界/异常是否已枚举，还是留了"AI 自己想"的空间？
- AC 是否有具体示例，还是只有抽象描述？

### Manager 流程步骤

| 步骤 | 名称 | 交互模式 | 变化 |
|------|------|---------|------|
| M-S0 | 工件接收与验证 | 静默 | 扩展：增加内容完整性检查 |
| M-S1 | 详细业务流程分析 | 全共创 | 保持 |
| M-S2 | 用户场景路径 | 全共创 | 保持 |
| M-S3 | 业务规则映射 | 全共创 | 保持 |
| M-S4 | UNIT 拆解 | 全共创 | 扩展：每个 UNIT 增加 Integration Context |
| M-S5 | AC 细化 | 草案修正 | 增强：示例驱动 AC + 边界/失败模式枚举 |
| M-S5.5 | 验证计划 | 草案修正 | 新增：每个 UNIT 定义验证方式 |
| M-S6 | 待设计决策 | 条件共创 | 增强：结构化格式 |
| M-S7 | 完整性扫描 | 条件共创 | 扩展：增加 AI 可执行性检查项 |
| M-S8 | 三方评审 | 评审模式 | 焦点调整：增加 AI 可执行性维度 |
| M-G1 | PM 裁决门 | 裁决门 | 保持 |
| M-S9 | 用户确认与输出 | 全共创 | 保持 |

### 保持不变的 Manager 机制

- M-HG-0 准入三条件
- UNIT 闭环定义（输入→行为→可观察结果）
- 字段所有权约束（不改写 Director 锁定字段）
- canonical JSON 输出格式
- 三方评审 3 视角 × max 10 轮
- 验证脚本

## Director → Manager 衔接契约

### 信息流

Director 产出分三类被 Manager 消费：

**直接消费（不可改写）：**
- 根问题 + 用户画像 — Manager 用来校验 UNIT 是否对准问题
- 成功标准 — Manager 用来校验 AC 是否能证明成功
- 范围 + Non-goals — Manager 用来判断 UNIT 是否越界
- 业务语义 — Manager 用来统一 UNIT/AC 术语
- Phase 目标 + 入口/出口条件 — Manager 用来约束每期 UNIT 范围

**参考消费（作为约束输入）：**
- Appetite — 约束 UNIT 粒度和方案复杂度
- 可行性约束 — 约束 UNIT 的技术前提假设
- 风险与未知项 — 影响 UNIT 优先级排序和验证计划
- 决策理由 — 帮助 Manager 理解边界背后的 WHY

**不消费：**
- D-S1 候选线索、共创过程记录

### M-S0 内容完整性检查

Manager 准入时增加 Director 产出完整性校验：

| 检查项 | 通过条件 |
|--------|---------|
| 根问题 | 非空，一句话可复述 |
| 用户画像 | 有具体的"谁"和"场景" |
| 成功标准 | 有基线 + 方向 + 观测方式 |
| Non-goals | 至少 1 条显式 non-goal |
| Appetite | 有投入框架（量级而非精确数字） |
| 可行性约束 | 有或显式声明"无特殊约束" |
| 风险 | 有或显式声明"无已识别风险" |
| Phase 骨架 | Phase 目标 + 入口/出口条件非空 |

缺失项不由 Manager 补齐，而是提示回到 /product-director 补完。

## Skill 结构优化

### 依据

Agent Skills 规范（agentskills.io）和 Anthropic 提示工程指南要求：

- SKILL.md < 500 行 / < 5000 token
- 有序步骤用编号列表
- 用 XML 标签分区
- 约束附 WHY
- 正面指令优于禁止性指令
- Opus 4.7 字面化解读，指令需自包含无歧义

### 当前结构问题

1. 流程用密集表格（4-6 列）表达，步骤间顺序依赖不清晰
2. HARD-GATE 规则缺少 WHY 解释
3. 约束分散在 4+ 个独立段落（HARD-GATE / Runtime Authority / 运行边界 / 异常与暂停边界 / 字段所有权约束）
4. "流程使用点引用"增加元复杂度，应内联到对应步骤
5. 缺少流程总览和流程图

### 目标结构

```
# /skill-name -- 一句话定位

> ultrathink

## <HARD-GATE>
编号规则，每条附 Why

## 角色与边界
负责什么、不负责什么

## 流程总览
编号 checklist（快速扫描全流程）

## 流程图
Graphviz dot（决策分支和暂停点可视化）

## 流程细节
每步用编号标题 + 叙述段落：
### 1. 步骤名称
- 交互模式：...
- 做什么：...
- 约束：...（引用文件内联在此）
- 暂停条件：...

## 输出合同
产物清单、写入边界

## 完成校验
Checklist

## 流程导航
上下游衔接
```

### 与当前结构的变化

| 维度 | 当前 | 目标 |
|------|------|------|
| 流程表达 | 4-6 列密集表格 | 编号 checklist 总览 + 叙述段落展开 |
| 约束组织 | 4+ 个独立段落 | HARD-GATE 集中前置 + 步骤内联约束 |
| HARD-GATE | 只有规则 | 规则 + WHY |
| 总览 | 无 | 编号 checklist + graphviz 流程图 |
| 引用文件 | 独立"流程使用点引用"段 | 内联到对应步骤 |

## 完整变更清单

| 变更项 | 影响 skill | 类型 |
|--------|-----------|------|
| Q1 用户画像加厚 | product-director | D-S2 扩展 |
| Q4 Non-goals 显式化 | product-director | D-S5 扩展 |
| Q6 Appetite 新增 | product-director | D-S3 扩展 |
| Q7 可行性约束新增 | product-director | D-S5 扩展 |
| Q8 风险与未知项新增 | product-director | 新步骤 D-S5.5 |
| Q9 决策理由沉淀 | product-director | D-S5 扩展 |
| Director 产出字段扩展 | product-director | output-contract 更新 |
| AC 升级为示例驱动 | product-manager | M-S5 增强 |
| 边界/失败模式枚举 | product-manager | M-S5 增强 |
| Verification Plan 新增 | product-manager | 新步骤 M-S5.5 |
| Integration Context 新增 | product-manager | M-S4 扩展 |
| 待设计决策结构化 | product-manager | M-S6 增强 |
| 评审增加 AI 可执行性维度 | product-manager | M-S7/M-S8 扩展 |
| M-S0 增加内容完整性检查 | product-manager | M-S0 扩展 |
| 衔接信息流明确化 | 两者 | 文档更新 |
| SKILL.md 结构重组 | 两者 | 结构优化 |

## 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 能力扩展导致 SKILL.md 超过 500 行 / 5000 token 预算 | AI 渐进式加载时截断关键指令 | 结构优化同步进行：用编号列表替代密集表格、内联引用替代独立段落，控制总量 |
| 新增字段（appetite、风险、non-goals）增加用户共创负担 | 简单需求被迫回答不必要的问题 | 草案修正模式下，简单需求可快速确认"无特殊约束/无已识别风险" |
| 示例驱动 AC 增加 Manager 阶段耗时 | 标准流程变慢 | 示例和边界枚举的投入在下游实现阶段回收——AI 实现时少猜测、少返工 |
| 结构重组导致现有 eval 用例失效 | 需要重新标定 benchmark | 能力变更和结构变更分批执行，每批验证后再进入下一批 |
| output-contract 变更影响 validate_standard_chain_phase.py | 验证脚本需同步更新 | 在变更清单中已包含 output-contract 更新，验证脚本作为关联变更一并处理 |

## 不变项（显式确认）

- 两 skill 拆分结构
- WHY → WHAT → HOW → DO 链路递进
- 全共创/草案修正交互模式
- locked_field_digest + 锁定机制
- D-G1 / M-G1 确认门
- canonical JSON 输出格式
- 三方评审 3 视角 × max 10 轮（焦点调整）
- 验证脚本 validate_standard_chain_phase.py
- references/ 目录组织方式

## 参考来源

- Shape Up (Basecamp): Appetite、Rabbit Holes、Shaping 概念
- Double Diamond (Design Council): 问题空间与方案空间分离
- Opportunity Solution Tree (Teresa Torres): Outcome → Opportunity → Solution 层级
- SVPG: AI 时代产品管理聚焦问题定义
- Osmani (Google): AI 规格框架、70%问题、指令诅咒、示例驱动 AC
- Kent Beck: AI 放大创造性视觉
- Martin Fowler: 架构是 AI coding 的前提
- Agent Skills 规范 (agentskills.io): SKILL.md 格式标准
- Anthropic Prompting Best Practices: 编号列表、XML 标签、约束附 WHY
