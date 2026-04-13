# 活跃文档上下文契约细则

Created: 2026-04-13
Updated: 2026-04-13

## Why

`design.md` 冻结的是主判断、边界和取舍；本文件承接字段级、层级级和引用级细则，避免主设计被运行细节和大表污染，同时为后续 hooks / scripts / CI 提供稳定 contract 输入。

## Scope

- In scope:
  - `worklog.md` 的字段、状态机、模式映射、读取方式和更新纪律
  - feature / phase / unit 三层的目录骨架与现有工件兼容矩阵
  - 标准场景目录的放置规则
  - 辅助文档命名与 `supporting/` 约束
  - 生命周期状态机、归档执行流程与引用处理
- Out of scope:
  - hooks / scripts / CI 的具体代码实现
  - rollout 批次与门禁升档策略

## Contract

### C1. `worklog.md` 是唯一接手入口

每个活跃 feature 根目录必须且只能有一个 `worklog.md`。

它负责：

- 作为接手入口，告诉人和 AI“当前在哪、下一步该看什么”
- 记录最近一次有效推进或阻塞转换
- 指向真实状态工件和下一步工件

它不负责：

- 定义 feature 目标
- 承载完整设计
- 维护任务完成状态
- 充当审查、QA 或签收报告

### C2. `worklog.md` 字段固定

`worklog.md` 每条记录最小字段固定为：

- `time`
- `actor`
- `owner`
- `mode`
- `stage`
- `scope_ref`
- `action`
- `status`
- `state_ref`
- `next`
- `next_ref`
- `blocker`（仅 `status=blocked` 时）
- `handoff_to`（发生接手切换时）
- `waiting_on`（仅 `status=blocked` 时）
- `unblock_condition`（仅 `status=blocked` 时）
- `decision_needed`（仅需要人工或上游裁决时）

字段语义：

- `actor`
  - 谁写了这条记录
- `owner`
  - 当前谁对这条主线推进负责
- `handoff_to`
  - 本次记录如果发生接手切换，下一位接手人是谁
- `scope_ref`
  - 当前主线工作范围，必须能回答“这条记录服务哪条 lane”
  - `small-chain` 示例：`tasks.md#T2`
  - `full-chain` 示例：`phase-1`、`phase-1/unit-2`

### C3. `worklog.md` 状态机与模式映射

`mode` 仅允许：

- `small-chain`
- `full-chain`

`stage` 仅允许：

- `bootstrap`
- `product`
- `design`
- `test-design`
- `planning`
- `delivery`
- `review`
- `qa`
- `signoff`

`status` 仅允许：

- `doing`
- `blocked`
- `done`

`status` 的语义对象固定为：

- 当前 `scope_ref` 对应的主线 handoff item 状态
- 不是整个 feature 的全局状态

状态机：

- `doing`
  - 当前主线正在推进，且不存在外部阻断
- `blocked`
  - 当前主线必须等待外部决策、前置条件、环境修复或上游工件变化，不能继续推进
- `done`
  - 当前主线 handoff item 已收口，下一步必须伴随新的 `next_ref`

允许迁移：

- `doing -> blocked`
- `blocked -> doing`
- `doing -> done`
- `done -> doing`
  - 仅允许在 `scope_ref` 切换或新 handoff item 启动时出现，必须写明新的 `state_ref / next_ref`

补充规则：

- `bootstrap` 只允许出现在 feature 首条记录、legacy adopt、或显式 mode 切换后的重建记录中
- 一旦进入 `product / design / planning` 等正式阶段，不允许无说明回退到 `bootstrap`

模式映射：

1. `small-chain`
   - `state_ref` 通常指向 `tasks.md`、`plan.md`、`design.md`
   - 默认状态优先读 `tasks.md`

2. `full-chain`
   - `product` → `brief.md` / `phase-{N}/prd.md` / `units/UNIT-*.md`
   - `design` → `phase-{N}/design.md`
   - `test-design` → `phase-{N}/unit-{M}/test-cases.md`
   - `planning` → `phase-{N}/plan.md`
   - `delivery`
     - 主引用：`phase-{N}/plan.md#Task-*`
     - 若对应 `dev-report.md` 已存在，可引用 `phase-{N}/unit-{M}/dev-report.md#...`
   - `review`
     - 仅在 `code-review-report.md` 已存在时允许进入该阶段
   - `qa`
     - 仅在 `qa-report.md` 已存在时允许进入该阶段
   - `signoff`
     - 仅在 `acceptance-summary.md` 已存在时允许进入该阶段
### C3A. `scope_ref` 语法固定
`scope_ref` 不能自由书写，必须落在可解析 grammar 内。
Phase 1 允许的最小语法：

- feature 级：
  - `feature`
- small-chain task 级：
  - `tasks.md#T{N}`
- phase 级：
  - `phase-{N}`
- unit 级：
  - `phase-{N}/unit-{M}`

补充规则：

- `scope_ref` 表示“当前主线 lane”，不是一般性阅读建议
- `state_ref / next_ref` 可以更细到具体文件和锚点，但 `scope_ref` 必须保持稳定、可聚合、可审计
- 若当前工作跨多个 unit，必须提升到 `phase-{N}`，而不是在 `scope_ref` 中拼接多个 unit

### C4. `state_ref / next_ref` 是接手锚点
`state_ref` 表示“当前状态以哪份工件为准”，`next_ref` 表示“下一步先看哪份工件”。
引用粒度要求：

- `state_ref / next_ref` 优先使用 `path#anchor`
- 如果目标工件暂时没有稳定锚点，可使用 `path`，但必须在 `action` 或 `next` 中写明目标节名
- `state_ref / next_ref` 允许的目标默认限于主干工件、阶段报告和当前受管场景目录中的辅助材料
- `supporting/` 只能作为 `next_ref` 的补充阅读，不得成为长期 `state_ref` 真源

Why：

- `worklog.md` 不应自己解释完整状态，而应把状态锚定到真实工件。
- `state_ref / next_ref` 能显著降低“凭聊天记忆或模糊描述接手”的风险。

### C5. `worklog.md` 采用倒序阅读与 append-only 更新
`worklog.md` 采用“最新记录在最上方”的倒序排列。
统一约束：

- `time` 使用 `YYYY-MM-DD HH:mm`
- 接手者默认先读第一条记录；只有需要回溯时才向下翻阅旧记录
- `worklog.md` 采用 append-only 方式，不回写历史语义

只在以下事件发生时更新：

- 进入新阶段
- 当前主状态变化（`doing / blocked / done`）
- 当前可信状态引用发生变化
- 下一步引用发生明确切换
- AI / human 接手人发生切换

不要求更新的情况：

- 同一阶段内继续推进，但接手路径没变
- 纯文字润色、typo 修复
- 补充 `supporting/` 文档但不影响接手判断

补充约束：

- 先更新真实发生变化的工件，再追加 `worklog.md`
- 如果写不出新的 `state_ref` 或 `next_ref`，就不要更新 `worklog.md`

写入责任：

- feature 根 `worklog.md` 只允许由当前 `owner` 或其指定的协调 agent 更新
- 子 agent、并行 worker、探索 agent 可以提供候选内容，但不直接写根 `worklog.md`
- 若发生人工接管，接手的人必须在首次有效推进前补写一条记录，完成 `owner / handoff_to` 切换
- `mode` 对单个 feature 默认固定；若需要从 `small-chain` 升级到 `full-chain`，必须由一条显式 handoff 记录完成切换，并写明升级原因与新的主干入口
- Phase 1 的工程化门禁只对 `owner` 链路一致性与 handoff 证据做强校验；若运行面提供稳定 `principal_id`，才开启“实际写入者权限”阻断检查
- 若运行面缺失 `principal_id`，实际写入者授权降级为 integrate/audit 控制，不在 runtime gate 上伪装成可认证能力
- 该 integrate/audit 控制的最小承载是 `owner acknowledgement`：优先使用 PR/merge approval；无 PR 流时，必须落入 `branch-finalization` 的批准记录

## Structure

### C6. 目录骨架与层级真值表
Phase 1 的目录策略是：

- 根目录保留真实主干工件
- 其他辅助材料进入标准场景目录

标准场景目录：
- `research/`
- `debug/`
- `verification/`
- `supporting/`
这些目录是“允许使用的标准目录类型”，不是要求在 `feature / phase / unit` 每层都提前建齐；只有真的产生该类材料时才创建。
`small-chain` 兼容桥接：
- Phase 1 允许在 `docs/{feature}` 下存在且仅存在一个 active workset 子目录：`YYYY-MM-DD-<change>/`
- 该 workset 承载 `design.md / tasks.md / plan.md`；feature 根目录继续承载 `worklog.md` 与受管作用域信息
- registry `layout=dated-workset` 时，`design.md / tasks.md / plan.md` 只能出现在 active workset，不允许与 feature 根同名并存
- registry `layout=phase-tree` 时，feature 根仅承载 `brief.md / phase-* / worklog.md / contract-waivers.md`，不承载 `design.md / tasks.md / plan.md`
- `brief.md` 只在 `full-chain` 或显式需要跨链 brief 时存在；`small-chain` bootstrap 不强制生成 `brief.md`

层级真值表：

| 层级 | 允许直接出现的核心工件 | 允许出现的子目录 | 不允许直接散落的内容 |
|------|------------------------|------------------|----------------------|
| `docs/{feature}` | `worklog.md`、`contract-waivers.md`、`brief.md`、`phase-*` | `research/`、`debug/`、`verification/`、`supporting/`、`YYYY-MM-DD-*`（仅 `small-chain` active workset） | 非标准命名的平级辅助文档；`layout=dated-workset` 时禁止根级 `design.md / tasks.md / plan.md` |
| `phase-{N}` | `prd.md`、`design.md`、`plan.md`、`code-review-report.md`、`qa-report.md`、`acceptance-summary.md`、`preflight-evidence.md` | `units/`、`unit-*`、`research/`、`debug/`、`verification/`、`supporting/`、`design/` | 自由命名的平级说明文件 |
| `unit-{M}` | `test-cases.md`、`dev-report.md` | `debug/`、`verification/`、`supporting/` | 与 unit 无关的调研/规划材料 |

### C7. 现有工件兼容矩阵

| 工件 | 层级 | artifact producer | 角色 | 是否归入场景目录 |
|------|------|------------------|------|------------------|
| `design/MOD-*.md` | phase | `/design` | 设计拆分补充真源 | 否，保留在 `design/` |
| `design/adr/ADR-*.md` | phase | `/design` | 关键设计裁决记录 | 否，保留在 `design/adr/` |
| `test-cases.md` | unit | `/test-design` | 测试设计真源 | 否 |
| `dev-report.md` | unit | `/delivery-owner` | 执行报告 | 否 |
| `code-review-report.md` | phase | `/delivery-owner` | 审查报告 | 否 |
| `qa-report.md` | phase | `qa` | 质量验收报告 | 否 |
| `acceptance-summary.md` | phase | `/delivery-owner` | 签收收口 | 否 |

规则：

- 现有主干/报告型工件继续留在原生路径，不强制塞入 `research/debug/verification/supporting`
- 场景目录只承接“补充材料”，不重新承接已有主干或报告型真源
- `contract-waivers.md` 是 feature 级例外记录文件，默认不存在，只有发生 contract 例外时才创建

### C8. 场景目录按服务对象就近放置
材料应放在离它服务对象最近的层级：

- 服务整个 feature 的材料，放 `docs/{feature}/<scene>/`
- 服务某个 phase 的材料，放 `phase-{N}/<scene>/`
- 服务某个 unit 的材料，放 `unit-{M}/<scene>/`

目录职责：

1. `research/`
   - 用于方案比较、外部实践调研、设计输入
   - 常见于 feature 级、phase 级

2. `debug/`
   - 用于复现、观察、根因、修复思路
   - 常见于 phase 级、unit 级

3. `verification/`
   - 用于 prove、验证证据、QA 前后补充验证
   - 常见于 phase 级、unit 级

4. `supporting/`
   - 用于暂时放不进前三类、但又确实服务当前活跃工件的辅助材料
   - 可出现在 feature / phase / unit 任一层

## Naming

### C9. 辅助文档命名：`YYYY-MM-DD-<topic>.md`
场景目录下的辅助文档统一使用 `YYYY-MM-DD-<topic>.md`。
约束：

- 日期是文档创建/定稿日期，不是最后修改日期
- `<topic>` 只表达主题，不重复目录语义
- 禁止 `fix-1.md`、`v2-*.md`、`temp-*.md`、`misc.md`、只含日期无主题的文件名

Why：

- 时间可排序，主题可辨识，路径稳定。
- 与核心入口文件的“固定文件名、不带日期”形成清晰区分。

### C10. `supporting/` 必须自解释
`supporting/` 下的每份文档都必须在开头说明：

- `purpose`
- `serves`
- `reason_here`
- `promotion_signal`

晋级与清理规则：

- 若同一层级下，连续出现 `>= 3` 份同类 `supporting/` 文档，且服务对象与结构稳定，应触发“是否升格为正式场景目录”的评审
- `supporting/` 的晋级决策人是该层级对应的 `owner`
  - feature 级 → feature `owner`
  - phase 级 → phase `owner`
  - unit 级 → unit 对应执行 `owner`
- 若 `supporting/` 文档在当前主线结束后不再被 `state_ref / next_ref` 引用，应在归档前标记为“可归档随迁”或“可删除”
- `supporting/` 不允许长期承担当前状态真源；若连续两轮 handoff 都依赖同类 supporting 文档作为主入口，应优先考虑晋级或回归主干工件

## Lifecycle

### C11. 生命周期状态机
Phase 1 只定义三种运行态：

- `active`
  - 位于 `docs/{feature}`
- `blocked`
  - 仍位于 `docs/{feature}`，具体阻塞写入真源与 `worklog.md`
- `archived`
  - 整目录迁移到 `docs/archive/{feature}`

不额外引入 `paused / stale / draft` 等目录状态。

### C12. 触发器、责任与归档流程

- `active -> blocked`
  - 触发条件：当前 `scope_ref` 无法继续推进，且必须等待外部决策、前置条件满足、环境修复或上游工件变化
  - 执行动作：更新 `worklog.md`，填写 `blocked / waiting_on / unblock_condition / decision_needed`
  - 责任人：当前 `owner`

- `blocked -> active`
  - 触发条件：`unblock_condition` 已满足，或新的 `owner` 接手并确认可继续推进
  - 执行动作：追加一条新的 `doing` 记录，更新 `state_ref / next_ref`
  - 责任人：恢复推进的 `owner`

- `active|blocked -> archived`
  - small-chain：
    - 所有 `tasks.md` 任务已完成
    - 最终验证已通过
    - 变更已完成集成或被明确关闭
  - full-chain：
    - `acceptance-summary.md` 已确认签收
    - 当前 phase 交付已完成集成或被明确关闭
  - 执行动作：
    - 整目录迁移到 `docs/archive/{feature}`
    - 执行归档后一致性检查
  - 批准人：
    - 当前 sign-off owner 或仓库维护 owner

归档后一致性检查：

- `worklog.md` 保留历史记录，不重写语义
- `state_ref / next_ref` 默认保留原相对路径语义，且归档后校验这些路径在归档目录内仍可解析
- 若归档导致原引用失效，必须在归档动作中同步修正相对路径
- `docs/archive/**` 永远不再参与 active validators，只参与 archive consistency audit

历史 `docs/` 边界：

- `docs/archive/**` 始终视为历史区
- `docs/{feature}` 只有在被识别为 `managed active scope` 时才视为活跃区
- 其他未纳管的旧目录默认按 `legacy / unmanaged` 处理，只参与 audit，不参与阻断式门禁

### C13. owner 边界按层级冻结
`worklog.md` 中的 `owner` 表示当前主线 handoff owner，不等于仓库维护者，也不自动等于某份工件的 producer。
层级责任矩阵：

| 层级 | owner | Must Own | May Update | Must Escalate |
|------|-------|----------|------------|---------------|
| feature | feature `owner` | 根 `worklog.md`、feature 级场景目录、`contract-waivers.md`、`active/blocked` 运行态切换、归档申请 | feature 级 `state_ref / next_ref`、feature 级 `supporting/` 晋级决策 | `mode` 变更、归档批准、跨 phase 主线切换、超过时限的 contract 例外 |
| phase | phase `owner` | phase 主干工件引用、phase 级场景目录、phase 级 `supporting/` 晋级决策 | phase 级 `state_ref / next_ref` 候选、phase 级辅助证据 | 跨 phase 依赖、phase 关闭条件、需要 feature 级裁决的阻塞 |
| unit | unit `owner` | unit 级 `debug/verification/supporting`、unit 级证据引用完整性 | unit 级 `state_ref / next_ref` 候选、局部补证据 | 跨 unit 影响、phase gate 变化、需要升级到 phase 的阻塞 |
| repo contract `owner` | 仓库维护 owner | validator 真源、hook/CI 接入、README 口径、rollout 状态、全局例外策略 | `managed active scope` 配置、audit 报告格式 | 破坏兼容的 contract 变更、需要用户裁决的长期例外 |

补充规则：

- feature / phase / unit 的路径 owner 由真实流程 owner 承担，不要求引入新角色名
- `contract-waivers.md` 只接受 feature 级 owner 发起，repo contract owner 或明确批准人确认后生效
- `worklog.md` 可记录 `handoff_to`，但不能绕过上表把长期 owner 责任静默转移出去
- `artifact producer` 只回答“谁产出/维护这份工件”，不自动等于 feature / phase / unit 的运行态 owner
