# tech-lead 阶段 sub agent 试点方案

## 试点目标

验证在 `tech-lead` 阶段引入有限、结构化的 sub agent，是否能：
- 降低主 Agent 的字段维护和重复回写负担
- 不降低 `plan.md` 的可执行性和可追溯性
- 不增加 review/fix/回退轮次

## 为什么先选 `tech-lead`

`tech-lead` 是最适合做第一批试点的阶段，因为它同时满足：

- 噪音密度高：追踪矩阵、Task 拆分、证据字段都集中在这里
- 输入明确：`brief + prd + units + design + test-cases`
- 输出单一：`plan.md`
- 风险可控：不直接碰用户共创，也不直接碰最终签收

### 首批试点比较框架

首批试点按 5 个维度比较：`噪音密度`、`是否直接依赖用户共创`、`输出是否单一`、`回滚成本`、`是否已有硬 Gate 可兜底`。

| 阶段 | 噪音密度 | 用户共创依赖 | 输出单一性 | 回滚成本 | 既有 Gate 兜底 | 首批试点结论 |
|------|----------|--------------|------------|----------|----------------|--------------|
| `product` | 中 | 高 | 低 | 高 | 弱 | 不适合作为首批试点，太容易误伤问题收口 |
| `design` | 中高 | 中 | 中 | 高 | 中 | 暂不首发，裁决成本高于降噪收益 |
| `test-design` | 高 | 低 | 中 | 中高 | 强 | 可作为第二站，但 `DESIGN-GAP(EQ)` 不适合先拿来试错 |
| `tech-lead` | 高 | 低 | 高 | 中 | 强 | 第一批最合适 |
| `project-manager` | 中 | 低 | 低 | 高 | 强 | 不作为首批根因试点，它更像收口放大器 |

因此，这次不是因为 `tech-lead` “最重要”，而是因为它在首批试点里同时满足：

- 噪音密度足够高，能看出收益
- 主 Agent 与 sub agent 的边界最好切
- 输出真源只有 `plan.md`，便于比较
- 失败时可以回退到既有 `/tech-lead` 流程，不会先伤到用户共创

## 不在本次试点范围

- 不改 `product` 主共创流程
- 不改 `design` 最终方案裁决
- 不改 `test-design` 的 `DESIGN-GAP(EQ)` 判定
- 不给 `project-manager` 增加额外协调层

## 试点原则

1. 只试工序，不试节点
主 Agent 继续负责 `DESIGN_OK`、计划模式选择、Task 最终冻结、用户确认。

2. 先草稿，后定稿
sub agent 只能提交候选结果，不能直接落 final `plan.md` 结论。

3. 最多 3 类 sub agent
避免一开始把 `tech-lead` 变成新的多角色噪音源。

## 草稿与定稿边界

为避免“sub agent 已经做了很多”与“主 Agent 仍然要冻结最终结果”之间的责任重叠，本试点强制采用下面的边界：

- 只有写入最终 `plan.md` 的内容才算 `已冻结`
- 所有 sub agent 输出文件都必须保留 `draft` 后缀，只能作为候选输入
- `Task` 编号、`Scope Freeze` 行、最终 `depends_on`、计划模式、用户确认记录，只能由主 Agent 写入最终 `plan.md`
- `Task Decomposition Draft Agent` 可以提议拆分和依赖，但不能生成最终编号，也不能越过主 Agent 直接改写 `plan.md`
- `Evidence Field Draft Agent` 只能为“主 Agent 已接受的 Task 草稿”补候选字段，不能反向新增 Task 或改计划模式
- 若两个以上草稿在同一字段冲突，主 Agent 必须先形成单一冲突清单，再决定是否局部重派发；禁止多版候选并存进入 `plan.md`

## 试点角色与裁决人

- `样本主 Agent`
  - 负责单个样本的 `/tech-lead` 执行、草稿回收、最终 `plan.md` 产出
  - 每个样本只能有 `1` 个样本主 Agent
- `试点负责人`
  - 负责维护 `pilot-result.md`、汇总 `3` 个样本的最终裁决
  - 必须在试点开始前指定，并记录在 `pilot-result.md` 头部
  - 若试点开始前没有单独指定，默认由第 `1` 个样本的主 Agent 兼任
  - 若同一人兼任全部样本主 Agent 与试点负责人，不额外加角色，但必须完整保留原始指标表和 fail-fast 记录，禁止口头裁决

## 试点角色

### 角色 1：Traceability Draft Agent

职责：
- 从 `UNIT -> AC -> scope_item_id -> MOD -> Task -> test_ref` 生成追踪矩阵草稿
- 标出缺失映射和可疑 orphan

输入：
- `brief.md`
- `phase-{N}/prd.md`
- `phase-{N}/units/`
- `design.md (+ MOD-*.md)`
- `test-cases.md`

输出回收件：
- `traceability-draft.md`
- `orphan-gap-list.md`

主 Agent 负责：
- 判断缺口是否真实成立
- 决定是否回退上游
- 冻结最终覆盖矩阵

### 角色 2：Task Decomposition Draft Agent

职责：
- 基于 design 与 test-cases 输出 Task 候选拆分
- 给出 `depends_on / shared_files / impact_files` 草稿

输入：
- `design.md`
- `MOD-*.md`
- `test-cases.md`
- `brief.md`

输出回收件：
- `task-draft.md`
- `dependency-draft.md`
- `parallel-strategy-draft.md`

主 Agent 负责：
- 判断拆分粒度是否合适
- 决定 `标准实施` / `探索优先`
- 冻结最终 Task 清单

### 角色 3：Evidence Field Draft Agent

职责：
- 为每个 Task 生成 `proving_command / real_dependency_note / evidence_target / mock_boundary_note` 候选

输入：
- `task-draft.md`
- `design.md`
- `test-cases.md`

输出回收件：
- `evidence-pack-draft.md`

主 Agent 负责：
- 判断命令是否真实可执行
- 判断证据路径是否足够闭环
- 冻结最终证据字段

## 主 Agent 保留职责

- `DESIGN_OK` 结论
- 计划模式选择
- Scope Freeze
- Task 最终编号和依赖
- 用户确认记录
- 最终 `plan.md` 定稿

## 执行流程

1. 主 Agent 先读取输入工件，确认上游完整
2. 并行派发 3 个 sub agent 产出草稿
3. 主 Agent 汇总三份草稿，做第一次冲突裁决
4. 若存在冲突项，只对冲突项重派发局部修正
5. 主 Agent 输出 `plan.md`
6. 保留现有 3 reviewer 审查，不新增 reviewer 层

## 样本与观测窗口

- 正式试点至少需要 `3` 个连续真实复杂样本
- `3` 个样本里至少包含：
  - `1` 个 `标准实施`
  - `1` 个 `探索优先`
  - `1` 个与前两个不同的 feature 或 phase 场景
- 不纳入样本：
  - 小改动
  - 纯文档任务
  - 无 `DESIGN_OK` 的需求
  - 只有单一 Task、几乎无追踪矩阵的轻量样本
- 观测窗口统一从 `/tech-lead` 开始读取输入工件起，到最终 `plan.md` 达到可交付收敛状态为止
- 若当前只能拿到 `2` 个样本，只允许输出“试运行结论”，不得宣告试点 `PASS`

## 基线样本配对规则

每个试点样本都必须配对 `1` 个历史基线样本，基线样本按下面规则依次筛选：

1. 必须是试点启动前最近完成的、未启用 sub agent 的 `/tech-lead` 样本
2. 必须与当前试点样本属于同一 `计划模式`
3. 最终 `plan.md` 的 Task 数量差异必须满足：
   - `abs(基线 Task 数 - 试点 Task 数) <= 3`
   - 或者相对差异不超过 `30%`
4. 若同时满足多个候选，取时间上最近的一个
5. 若任一样本找不到满足条件的基线样本，该样本只能记为 `INCONCLUSIVE`

只有 `3` 个正式样本都找到可比基线，才允许对整轮试点做 `PASS / FAIL` 裁决。

## 度量口径

所有指标都必须基于“试点样本 vs 已配对的单一样本基线”做对照；禁止把多个不同模式、不同 Task 规模的历史样本混算成一个平均基线。

- `M1 主 Agent 手工维护字段数`
  - 统计主 Agent 在最终 `plan.md` 中亲自编写或重写的有效字段数
  - 只计入 `Scope Freeze`、Task 字段、证据字段、计划模式和用户确认相关字段
  - 不计标题、排版和纯格式修正
- `M2 同一事实重复回写次数`
  - 同一事实在不同草稿或从草稿到 `plan.md` 中被主 Agent 重复手工回写的次数
- `M3 首轮稳定问题数`
  - 统计最终 `plan.md` 首次进入完整独立审查时的稳定问题数量
  - 以现有 `/tech-lead` reviewer 机制输出的问题台账为准
- `M4 计划收敛轮次`
  - 从第一版完整 `plan.md` 到 `REVIEW_PASS / FAIL 已修正` 的完整 review/fix 轮次
- `M5 草稿冲突回退数`
  - 由 sub agent 草稿冲突直接触发的上游回退、整包重做或整版 `plan.md` 废弃次数
- `M6 草稿采用字段数`
  - 按 `traceability / task / evidence` 三类草稿分别统计，最终 `plan.md` 中有多少有效字段直接采用或只做轻微修正后采用
  - `轻微修正` 仅允许措辞、排序、格式和路径补全，不允许改写字段含义

## 通过阈值

试点 `PASS` 必须同时满足：

- `3` 个正式样本全部完成并有对应基线
- `M1` 中位数较基线下降至少 `25%`
- `M2` 中位数较基线下降至少 `30%`
- `M3` 中位数不高于基线
- `M4` 中位数不高于基线，且任一样本最多只允许比基线多 `1` 轮
- `M5 = 0`
- 每个样本至少有 `2` 类草稿的 `M6 > 0`
- 任一样本都必须通过既有 `/tech-lead` completion check
  - proving command: `bash shared/skills/tech-lead/scripts/completion_check.sh`
  - 判定标准：退出码 `0` 视为通过；任何非 `0` 退出码都视为该样本不合格

## 观察指标

- 生成 `plan.md` 的总轮次
- 主 Agent 需要人工改写的草稿比例
- orphan / gap 误报率
- Task 粒度被主 Agent 推翻的比例

## 快速失败条件

出现任一项即直接判定该轮试点 `FAIL`，不再等待累计样本：

- 任一样本因 sub agent 草稿冲突触发上游回退
- 任一样本出现“全人工重写 `plan.md`”
  - 定义：`traceability / task / evidence` 三类草稿中，有至少 `2` 类的 `M6 = 0`
- 任一样本的最终 `plan.md` 无法通过既有 `/tech-lead` 强门禁检查
  - proving command: `bash shared/skills/tech-lead/scripts/completion_check.sh`
  - 判定标准：退出码非 `0`
- 任一样本在首轮完整独立审查中，新增 `2` 个及以上稳定问题，且其 `Evidence Anchor` 直接落在 sub agent 负责的字段上

## 混合结果仲裁规则

- 单样本裁决只允许三种结果：`PASS`、`FAIL`、`INCONCLUSIVE`
- Pilot 总裁决规则：
  - 任何一个样本触发快速失败条件，整体即为 `FAIL`
  - 没有快速失败，且全部通过阈值满足，整体为 `PASS`
  - 没有快速失败，但阈值未满足或基线不足，整体为 `INCONCLUSIVE`
- 单样本裁决由该样本主 Agent 写入 `pilot-result.md`
- 单样本裁决公式：
  - 命中任一快速失败条件 = `FAIL`
  - 未命中快速失败条件，且该样本已完成基线配对，同时 `M5 = 0`、`M6` 满足“至少 `2` 类草稿大于 `0`”、最终 `plan.md` 通过 completion check = `PASS`
  - 其他情况 = `INCONCLUSIVE`
- Pilot 总裁决由试点负责人在 `pilot-result.md` 汇总区写入
  - 必填字段：`样本编号`、`样本主 Agent`、`计划模式`、`配对基线样本`、`M1~M6`、`单样本裁决`、`总裁决`
- 只有 `PASS` 才允许进入下一阶段；`INCONCLUSIVE` 只能补样本或缩小试点范围，不能直接修改主 skill

## 回滚策略

如果失败，立即回退到：

- 保留 `tech-lead` 原流程
- 仅保留人工生成的 `plan.md`
- 停用 3 类试点 sub agent
- 只沉淀失败原因，不把试点逻辑写入主 skill

## 输出物

试点完成后至少产出：

- `pilot-result.md`
- `before-after-metrics.md`
- `what-to-keep.md`
- `what-to-roll-back.md`
- `metric-counting-notes.md`
  - 逐样本记录 `M1` 与 `M6` 的计数口径
  - 若遇到“有效字段”或“轻微修正”边界样本，先在这里统一口径，再写最终裁决

## 进入下一阶段的条件

只有在试点通过后，才允许继续：

1. 扩到 `test-design`
2. 讨论是否给 `design` 增加 `竞争假设` 子代理
3. 反推修改 `tech-lead/SKILL.md`
