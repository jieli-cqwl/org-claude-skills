# 活跃文档上下文管理契约设计

Created: 2026-04-13
Updated: 2026-04-13

## 一页对齐摘要

### 最初场景

- 下游反馈文档名称混乱，不知道哪些有效、哪些无效。
- AI 跨天、跨会话或切换接手者后，不知道“现在做到哪了、下一步该干什么”。
- 人机协作是常态，AI 卡住时人类也需要快速介入。
- 真实仓库中同时存在 `small-chain` 与 `full-chain` 两套工件链路，不能脱离现实另造一套抽象文档树。

### 当前问题定义

本次要解决的不是“文档太多”，而是“活跃文档的上下文管理契约不清”。

更具体地说，是以下边界缺失导致了接手成本高、误读风险高：

- 哪些文档是当前活跃真源
- 哪些文档只是执行记录或辅助材料
- feature 目录该怎样命名和组织
- 接手时第一跳应该看什么
- 哪些约束需要工程机制兜底，而不是依赖 LLM 自觉

### 本次明确要做

- 只治理当前活跃 feature 的文档契约
- 统一活跃 feature 的目录命名、接手入口、标准场景目录和辅助材料命名
- 让 `small-chain` 与 `full-chain` 都能用同一套接手方式
- 明确 `worklog.md` 的职责边界
- 明确哪些规则必须工程化

### 本次明确不做

- 不处理历史 `docs/` 的全量迁移和清理
- 不先做跨 feature 全局总览
- 不替换现有 `brief.md / prd.md / UNIT / design.md / test-cases.md / plan.md / tasks.md`
- 不依赖“提示词写得更好”替代 hooks / scripts / CI

### 已冻结决策

- 活跃 feature 继续位于 `docs/{feature}`
- feature 目录命名使用 `<前缀>--<场景>--<主题>`
- 每个活跃 feature 仅有一个稳定入口：`worklog.md`
- 核心入口文件名固定，不带日期；辅助文档带日期
- 标准场景目录为 `research / debug / verification / supporting`
- `supporting/` 是受控兜底目录，不是垃圾桶
- `worklog.md` 只做接手导航，不做第二状态真源
- 可机检约束必须工程化

### 当前不是遗漏、而是留给后续实现的内容

- hooks / scripts / CI 的具体实现细节
- feature 模式识别的脚本算法
- `worklog.md` 的最终模板与生成器
- 目录规则如何渐进 rollout 到现有活跃 feature

## 偏离检查

### 与最初目标对照

- 目标“解决命名混乱”仍然保留，但已上升为“上下文管理契约”的一部分，不再被误当成纯命名美化。
- 目标“第二天知道从哪推进”已被收敛成 `worklog.md -> state_ref / next_ref -> 真实工件` 的接手链路。
- 目标“人机协作低成本介入”已被收敛成统一第一跳、稳定目录命名、工程化兜底三件事。

### 当前刻意收窄、不是跑偏

- 没有设计全局总览：因为当前优先级是降低单个 feature 的接手成本，避免过早引入高维护成本对象。
- 没有重构历史 `docs/`：因为本次聚焦活跃 contract，历史文档治理单独处理更安全。
- 没有替换仓库真实链路：因为本次目标是承接 `small-chain / full-chain`，而不是重写流程。

## Why

当前仓库已经形成了较完整的 `product -> design -> test-design -> tech-lead -> delivery-owner` 与 `small-chain` 两条链路，但“活跃文档如何组织、如何接手、哪些当前有效、哪些只是历史材料”没有形成统一契约。结果是人和 AI 在跨会话、跨天、切换接手者时，都要重新判断应该信哪份文档、先看哪里、下一步该做什么。

这次变更的目标不是发明一套新的主干工件，而是在不破坏现有流程工件的前提下，加一层低维护成本、可机检、便于人机协作的上下文管理契约。

## Scope

- In scope:
  - 统一活跃 feature 的目录骨架、命名规范、接手入口和场景目录约束。
  - 为 `small-chain` 与 `full-chain` 定义同一套接手与上下文恢复方式。
  - 定义 `worklog.md` 的职责边界、更新原则和引用约束。
  - 定义哪些约束必须由 hooks / scripts / CI 工程化兜底。
- Out of scope:
  - 历史 `docs/` 的全量迁移、清理、重命名和归档补录。
  - 全局跨 feature 总览面板或新的状态数据库。
  - 替换现有 `brief.md / prd.md / UNIT / design.md / test-cases.md / plan.md / tasks.md` 主干工件。
  - 用 LLM 约定替代工程机制；语义质量仍需人工审阅。

## Context

### 现状工件与真实链路

仓库当前至少存在两种真实工作模式：

1. `full-chain`
   - `/product` 产出 `docs/{feature}/brief.md`、`phase-{N}/prd.md`、`phase-{N}/units/UNIT-*.md`
   - `/design` 在 `phase-{N}/design.md` 落盘
   - `/test-design` 在 `phase-{N}/unit-{M}/test-cases.md` 落盘
   - `/tech-lead` 在 `phase-{N}/plan.md` 落盘
   - `/delivery-owner` 继续产出 `dev-report.md`、`code-review-report.md`、`qa-report.md`、`acceptance-summary.md`

2. `small-chain`
   - `design.md`
   - `tasks.md`
   - `plan.md`

因此，设计目标不能是假设“每个 feature 只有 3 个固定主干文档”，而是要承接这两种真实模式。

### 已确认的设计原则

- 文档命名与目录结构是核心约束，不是附属细节。
- 稳定入口文件必须尽可能少，且文件名固定。
- 时间信息需要保留，但不能让核心入口路径漂移。
- 人类与 AI 都会接手，因此路径、命名和接手链路必须同时对机器和人友好。
- 能机械判断的约束必须优先工程化，不能把正确性建立在 LLM 自觉上。

### 参考输入与取舍

- [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)
  - 借鉴点：`AGENTS.md` 应是目录而非百科全书；仓库知识应成为 system of record；关键约束应可机检。
  - 未直接照搬：不引入额外仓库级知识平台或全局运行对象。
- [OpenSpec](https://openspec.dev/)
  - 借鉴点：多轮会话依赖持久化工件接续，而不是依赖聊天记忆。
  - 未直接照搬：不把 proposal/spec 体系直接覆盖到当前仓库已有 `product/full-chain` 工件上。
- [OpenClaw Docs Hubs](https://docs.openclaw.ai/start/hubs)
  - 借鉴点：深层文档需要稳定入口导航，而不是要求接手者自己猜路径。
  - 未直接照搬：不引入额外 hub 平台，用 `worklog.md` 承担最小导航职责。
- [Hermes Agent Context Files](https://github.com/NousResearch/hermes-agent)
  - 借鉴点：项目上下文文件应稳定、低歧义、长期存在。
  - 未直接照搬：不引入新的通用 memory 层；继续依赖仓库真实工件。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| 仅依赖现有真源文档，不新增导航层 | 结构最干净，不多养文件 | 接手者必须自己在多份工件中推断“现在在哪、下一步做什么” | Rejected |
| `worklog.md` + 现有真源工件 | 维护成本低，符合人先看执行记录再跳真源的习惯，也能给 AI 稳定第一跳 | 必须严控边界，否则会变成第二套状态真源 | Chosen |
| `快照文件` + `worklog` + 真源工件 | 接手体验最好 | 维护成本最高，最容易过期，与真源形成竞争解释 | Rejected for Phase 1 |
| 新建 `features/` 根目录彻底隔离活跃工件 | 概念最整齐 | 与现有 `docs/{feature}` 真实输出路径冲突，迁移成本过高 | Rejected |
| 用“辅助文件白名单”限制所有补充文档 | 简单粗暴，便于初期约束 | 难以承接真实场景变化，长期可演化性差 | Rejected |

## Approach

### D1. 契约覆盖层：统一的是入口、命名与读取方式，不是主干工件形态

本设计不改写 `full-chain` 和 `small-chain` 的真实工件集，而是在两者之上增加统一契约：

- 每个活跃 feature 都有一个稳定入口：`worklog.md`
- 每个活跃 feature 都遵守同一套目录命名规则
- 接手者都先看 `worklog.md`，再跳到该模式下的真实状态工件

统一契约回答的是：

- 当前 feature 属于哪种模式
- 当前状态该信哪份工件
- 下一步应先打开哪份工件

它不回答主干工件本身长什么样。

### D2. 活跃 feature 目录命名：`<前缀>--<场景>--<主题>`

活跃 feature 根目录统一命名为：

`<前缀>--<场景>--<主题>`

约束如下：

- 组间使用 `--`
- 组内使用 ASCII `kebab-case`
- 不带日期、版本、状态、phase、人名或临时语义

Why：

- `--` 让“前缀 / 场景 / 主题”的边界显式可见，避免长路径难切分。
- 日期和状态属于时点信息，应进入文档元信息或辅助文档名，而不是污染 feature 根目录名。
- 稳定目录名能保证跨天推进、多人接手和脚本引用都不漂移。

### D3. 活跃作用域解析：继续沿用 `docs/{feature}`，但只把受管子集视为 active scope

Phase 1 保持：

- 活跃 feature 继续位于 `docs/{feature}`
- 已归档内容继续位于 `docs/archive/...`
- 历史 `docs/` 不做本次迁移

为避免与现有 README 中“`docs/` 默认是历史/非运行时文档”的口径冲突，本设计增加一层显式作用域约束：

- `managed active scope`
  - 仅包含命名符合 `<前缀>--<场景>--<主题>`、且被 rollout 纳入管理范围的 `docs/{feature}` 目录
- `legacy / unmanaged docs`
  - `docs/` 下其他历史目录或尚未纳入 rollout 的目录
- `archived`
  - `docs/archive/**`

Phase 1 的 `managed active scope` 运行时真源不靠 README 推断，而由单一 registry 承担：

- `contracts/active-doc-scope.yaml`

Why：

- 避免同时改动技能输出路径、既有工件引用和团队使用习惯。
- 通过 `active scope` 显式解析，可以在不迁移历史目录的前提下引入渐进式治理。

### D4. 稳定入口文件：`worklog.md`

每个活跃 feature 根目录必须且只能有一个 `worklog.md`。

职责：

- 作为接手入口，告诉人和 AI“当前在哪、下一步该看什么”
- 记录最近一次有效推进或阻塞转换
- 指向真实状态工件和下一步工件

非职责：

- 不定义 feature 目标
- 不承载完整设计
- 不维护任务完成状态
- 不充当审查、QA 或签收报告

Why：

- `changelog.md` 在仓库里天然表示发布/历史变更，不适合作为接手入口。
- `worklog.md` 更贴近“执行记录 + 接手导航”的语义，同时能覆盖人类先看日志的习惯。

`worklog.md` 的字段、状态机、更新纪律与模式映射细则，见 [contract-details.md](./contract-details.md)。

### D5. 目录骨架与标准场景目录

Phase 1 的目录策略是：

- 根目录保留真实主干工件
- 其他辅助材料进入标准场景目录

标准场景目录：

- `research/`
- `debug/`
- `verification/`
- `supporting/`

其中 `supporting/` 是受控兜底目录，不是 `misc/` 或 `temp/`。

设计原则：

- 这些目录是“允许使用的标准目录类型”
- 不是要求在 `feature / phase / unit` 每层都提前建齐
- 只有真的产生该类材料时才创建

层级真值表、现有工件兼容矩阵与场景目录落位细则，见 [contract-details.md](./contract-details.md)。

### D6. 辅助文档命名与 `supporting/` 边界

场景目录下的辅助文档统一使用：

`YYYY-MM-DD-<topic>.md`

并遵守：

- 日期表示创建/定稿日期，不表示最后修改时间
- `<topic>` 只表达主题，不重复目录语义
- `supporting/` 只能承接暂时无法归入前三类、但仍服务当前活跃工件的材料
- `supporting/` 不能长期承担当前状态真源

辅助文档命名细则、`supporting/` 自解释字段与晋级规则，见 [contract-details.md](./contract-details.md)。

### D7. 生命周期与工程兜底原则

Phase 1 只定义三种运行态：

- `active`
- `blocked`
- `archived`

更细执行状态继续留给主干工件与 `worklog.md` 表达。

工程原则固定为：

`LLM 负责产出，工程机制负责兜底。`

因此，结构、命名、唯一性、可达性、边界这些可机械判断的约束，必须优先通过 hooks / scripts / CI 实现，而不是写在提示词里期待 LLM 自觉。

补充冻结：

- 例外不是口头约定；任何 feature 级 contract 例外都必须时间盒化并落盘到 `contract-waivers.md`
- bootstrap 只生成 contract 最小骨架，不预建空场景目录，不替代真实主干工件生成

生命周期细则、归档规则、工程兜底矩阵、触发矩阵、例外机制与 rollout 策略，见 [enforcement-rollout.md](./enforcement-rollout.md)。

## Key Decisions

- D1: 统一契约覆盖在既有 `small-chain / full-chain` 之上，而不是发明新的主干工件体系。 — Reason: 避免脱离仓库现实，降低迁移成本。
- D2: 活跃 feature 继续位于 `docs/{feature}`，不新建 `features/` 根目录。 — Reason: 既有技能与工件路径已建立在 `docs/{feature}` 上。
- D3: 每个活跃 feature 仅保留一个稳定入口文件 `worklog.md`。 — Reason: 低成本接手需要唯一第一跳。
- D4: feature 目录名使用 `<前缀>--<场景>--<主题>`。 — Reason: 既可读又便于脚本解析，边界清晰。
- D5: 核心入口文件名固定且不带日期；辅助文档带日期。 — Reason: 同时满足稳定入口与时间可追溯。
- D6: 采用标准场景目录 + `supporting/` 受控兜底目录。 — Reason: 先覆盖高频场景，同时保留演化空间。
- D7: `worklog.md` 只在接手信息变化时更新。 — Reason: 控制维护成本，防止日志膨胀为第二状态真源。
- D8: 可机检约束必须工程化，不以 LLM 自觉为前提。 — Reason: 命名与结构规范长期可持续的前提是 hooks / scripts / CI 兜底。
- D9: feature 级 contract 例外必须时间盒化并落盘到 `contract-waivers.md`。 — Reason: 例外必须可审计、可过期、可回收，不能靠口头默契。
- D10: `managed active scope` 必须有显式 registry 真源。 — Reason: 目录名合法或 `worklog.md` 存在都不足以表达“已纳管”。

## Success Criteria

- 人或 AI 进入任一活跃 feature 后，可以先读 `worklog.md`，并在一次跳转内到达当前可信状态工件。
- 活跃 feature 的路径、核心入口和辅助材料命名能被脚本稳定解析，无需依赖隐含约定。
- `small-chain` 与 `full-chain` 都能在不改写主干工件的情况下接入同一套上下文恢复契约。
- 活跃目录中的自由命名文件显著减少，新增辅助材料能够被稳定归类到标准场景目录。
- 关键结构约束能够通过 hooks / scripts / CI 机械检测，不需要依赖 LLM 自觉维持。
- 任何阻断式例外都能在固定位置被看见、被审计，并具备批准人、补偿控制和到期时间。
