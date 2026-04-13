# 活跃文档上下文契约的工程兜底与 rollout

Created: 2026-04-13
Updated: 2026-04-13

## Why

本文件承接“如何把契约从设计判断落到工程机制”的问题，覆盖可机检约束、触发时机、失败合同和渐进 rollout。它不替代主设计，只回答“工程怎么兜底、什么时候兜底、失败后怎么反馈”。

## Scope

- In scope:
  - Phase 1 优先工程化的检查项
  - enforcement layer、触发事件、失败级别和输出位置
  - 运行能力矩阵与 fallback
  - failure contract
  - rollout phases、兼容策略、迁移与回退原则
- Out of scope:
  - 具体 hook / script / workflow 的代码实现
  - 深语义一致性推理

## Enforcement Principles

本设计明确采用：

`LLM 负责产出，工程机制负责兜底。`

因此，结构、命名、唯一性、可达性、边界这些可机械判断的约束，必须优先通过 hooks / scripts / CI 实现，而不是写在提示词里期待 LLM 自觉。

Phase 1 优先工程化的检查项：

- feature 目录名符合 `<前缀>--<场景>--<主题>`
- feature 模式可识别（`small-chain` 或 `full-chain`）
- 核心入口文件唯一且命名固定
- `worklog.md` 唯一存在
- 活跃根目录无非法散落文件
- 场景目录名合法
- 场景目录下辅助文档名带日期
- `worklog.md` 的 `mode / stage / status` 枚举合法
- `worklog.md` 的 `state_ref / next_ref` 路径存在

暂不在 Phase 1 工程化的内容：

- `next` 描述是否足够好
- 阶段判断是否最优
- 主题 slug 是否最贴切
- `worklog.md` 与真源之间的深语义一致性

Why：

- 结构规则最稳定、收益最高、误报最低，应先落工程。
- 语义质量仍需要设计评审与人工审阅。

## Enforcement Matrix

| 规则类型 | enforcement layer | 触发事件 | 失败级别 | 输出位置 |
|----------|-------------------|----------|----------|----------|
| feature 目录命名、场景目录命名、辅助文档日期命名、根目录非法散落文件 | `pre-commit` | `git commit` 前 | `block` | 本地终端 stderr |
| `worklog.md` 字段齐全、枚举合法、`state_ref / next_ref` 可达、写入后模式仍可识别 | `repo hook` | Claude: `PostToolUse(Edit/Write)`；Codex: `Stop` gate | `block current turn` | runtime stop message / 脱敏 JSON |
| `worklog.md` 唯一性、active/archive 路径冲突、README/contract 漂移、规则回归测试 | `CI` | `push / pull_request` | `fail job` | GitHub annotations + job summary + artifact |
| `supporting/` 滥用、长期 blocked 未归档、目录升格信号、legacy 目录漂移 | `periodic audit` | `cron / workflow_dispatch` | `report-only` | workflow summary + audit artifact |

## Trigger Matrix

| 动作 | 检测面 | 必跑检查 | 失败处理 |
|------|--------|----------|----------|
| 新建或重命名 `docs/{feature}` 到受管 active scope | `pre-commit` + `CI` | feature 命名、模式可识别、根目录允许项、`worklog.md` 是否存在、registry 是否有对应条目 | `block` |
| 首次创建 managed feature 的最小骨架 | bootstrap script + `pre-commit` | 名称合法、`mode` 已声明、`worklog.md` stub 可解析、首条记录 `stage=bootstrap`、registry upsert 成功、未预建空场景目录 | `block` |
| 编辑 `worklog.md` | runtime gate + `pre-commit` + `CI` | 字段齐全、枚举合法、`state_ref / next_ref` 可达、owner 链路一致、根级唯一性；若存在 `principal_id` 再检查实际写入权限；否则在 integrate/audit 检查 owner acknowledgement（PR/merge approval 或 `branch-finalization` 批准记录） | `block current turn` / `block commit` / `fail job` |
| 新增 `research/debug/verification/supporting` 文档 | `pre-commit` + `CI` | 目录是否合法、命名是否带日期、是否放在正确层级、`supporting/` 是否带自解释头 | `block` |
| 移动或删除被 `state_ref / next_ref` 引用的目标工件 | `pre-commit` + `CI` | 反向引用可达性、是否同步修正 `worklog.md` 或归档路径 | `block` |
| 执行 archive move | `pre-commit` + `CI` | active/archive 冲突、归档后引用仍可解析、archive consistency audit | `block` |
| 修改 `contracts/active-doc-scope.yaml` | `repo hook` + `CI` | registry schema、状态/布局枚举、scope 冲突、与 README / contract 的口径一致性 | `block current turn` / `fail job` |
| 修改 README、validator 真源、hook 注册或 rollout 配置 | `CI` | README 与 contract 口径一致、validator 回归、hook 接线一致、managed scope 漂移 | `fail job` |
| 定时巡检 | `periodic audit` | 过期 `contract-waivers.md`、长期 blocked、`supporting/` 晋级信号、legacy 漂移 | `report-only` |

补充原则：

- 只有“动作会改变接手路径或门禁判断”时，才需要进入阻断式检查
- `periodic audit` 不负责兜底即时正确性，只负责暴露长期腐烂趋势

## Validator Contract

context contract validator 必须是单一规则真源；不同运行面只做事件适配，不得各写一套判断。

最小输入：

- `repo_root`
- `trigger`
  - `runtime-stop` / `pre-commit` / `ci` / `audit`
- `changed_paths[]`
- `target_feature`
  - 可为空；若为空则由 `changed_paths` 推导
- `runtime_context`
  - 可选：`session_id`、`tool_name`、`cwd`、`active_skill`、`principal_id`
- `approval_context`
  - 可选：`approval_source`、`approved_by`、`approved_at`、`approval_ref`

最小输出对象：

- `validator_id`
- `contract_version`
- `decision`
  - `allow` / `warn` / `block`
- `scope`
  - `feature` / `phase` / `unit` / `repo`
- `findings[]`
  - `rule_id`
  - `severity`
  - `path`
  - `message`
  - `expected`
  - `actual`
  - `fix_hint`
- `report_relpath`
  - 可选；CI / audit 产物路径

退出语义：

- `0`
  - 通过；`decision=allow`
- `2`
  - 阻断；`decision=block`
- `3`
  - 仅告警；`decision=warn`
- `>=10`
  - validator 自身故障；阻断式场景按 fail-closed 处理，audit 场景记为 validator error

适配要求：

- `pre-commit`
  - 消费 `decision + findings`，以 stderr 输出首要错误
- runtime gate
  - 保留脱敏 stop reason，只展示首个阻断 finding 的用户可读摘要
  - 若 `principal_id` 缺失，不推断真实写入者身份，只校验 owner 链路一致性
  - 无 `principal_id` 时不得宣称已完成“实际写入者认证”；该控制降级到 integrate/audit
- `CI`
  - 将 `findings` 渲染为 annotations，并输出完整 report artifact
  - 若 `worklog.md` 变更且 `principal_id` 缺失，必须消费 `approval_context` 或等价 PR review 元数据
- `periodic audit`
  - 汇总 `warn + expired waiver + unmanaged drift`

## Active Scope Registry & Precedence

`managed active scope` 的运行时判定不能靠 README 文案或目录名猜测，必须有显式真源。

Phase 1 建议冻结单一 registry 文件：

`contracts/active-doc-scope.yaml`

最小字段：

- `feature_path`
- `mode`
  - `small-chain` / `full-chain`
- `status`
  - `legacy` / `managed` / `migrated`
- `rollout_phase`
- `layout`
  - `dated-workset` / `phase-tree`
- `primary_workset_relpath`
  - `small-chain` 兼容布局时必填
- `owner`
  - 指 feature runtime owner，不等于 registry owner

判定优先级：

- `active-doc-scope.yaml`
- validator 实际解析结果
- README 摘要说明

补充规则：

- 目录名合法不等于自动纳管
- `worklog.md` 存在也不等于自动纳管
- 任何 legacy -> managed 的切换，必须显式写入 registry
- README 只描述原则，不作为运行时判定真源
- bootstrap 与 adopt 都必须包含 registry upsert；没有入册动作就不能进入 managed
- registry 只允许由 bootstrap / adopt / archive 流程写入；手工修改属于 break-glass 例外，需 repo contract `owner` 批准
- runtime active scope 只包含 registry 中 `status in [managed, migrated]` 的条目；`legacy` 条目只用于 rollout 跟踪与 audit

## Exception Mechanism

feature 级 contract 例外必须落盘到固定文件：

`docs/{feature}/contract-waivers.md`

该文件默认不存在；只有发生时间盒化例外时才创建。

记录格式固定为表格，字段最小集：

- `Waiver ID`
  - `CCW-001` 风格稳定编号
- `Rule ID`
- `Scope`
- `Path / Ref`
- `Reason`
- `Risk`
- `Compensating Control`
- `Approver`
- `Approved At`
- `Expires At`

例外规则：

- 只允许豁免可机械判断但可临时承受的规则
- 必须写明补偿控制和到期时间
- 到期后若未续签，阻断式检查自动恢复
- 例外不是“永久关闭检查”的开关

不可豁免项：

- 非法 feature 目录名
- 受管 active scope 缺失 `worklog.md`
- active/archive 路径冲突
- validator 自身故障

批准边界：

- feature `owner` 发起
- repo contract `owner` 审核并批准
- 超过 `7` 天或影响 README / rollout / 全局 validator 的例外，必须升级到仓库维护 owner

## Runtime Capability Matrix

| 入口 | 支持的即时检查能力 | fallback |
|------|-------------------|----------|
| Claude | `PostToolUse(Edit/Write)` + stop gate | 无需额外 fallback |
| Codex | 无 `Write/Edit` 拦截，仅 `Stop` gate | 将即时结构校验收敛到 stop gate + pre-commit + CI |
| Human git workflow | `pre-commit` + `CI` | 无 runtime hook |

## Failure Contract

- 本地 `pre-commit`
  - 输出：`相对路径 + 违反规则 + 期望格式`
  - 行为：阻断 commit
- runtime stop gate
  - 输出：复用现有脱敏 stop reason，不直接裸露内部实现路径或上下文堆栈
  - 行为：阻断当前回合继续推进
- CI
  - 输出：annotations + job summary，必要时附 `context-contract-report.md`
  - 行为：阻断合并
  - 特例：`worklog.md` 在无 `principal_id` 运行面被修改时，缺失 `owner acknowledgement` 必须阻断
- periodic audit
  - 输出：report artifact
  - 行为：不阻断，只告警和追踪趋势

补充失败策略：

- 阻断式场景默认 fail-closed
  - 只要 validator 无法给出可信结论，就不能静默放行
- `warn` 只能出现在显式允许的 audit 或 rollout 观察阶段
- 任何使用 `contract-waivers.md` 的放行，仍必须在输出中显示“本次放行依赖有效 waiver”

## Ownership & Rule Source

- 契约规则真源：本设计落地后收敛为单一 contract / validator 真源，避免 hooks、CI、文档各写一套
- hook adapter owner：维护 `shared/hooks/registry.json` 与运行时适配
- validator owner：维护命名、目录、引用校验脚本
- CI / audit owner：维护 workflow 与报告输出
- feature `owner`：维护当前 feature 的 `worklog.md` 与局部例外说明
- registry owner：repo contract `owner`；负责 `contracts/active-doc-scope.yaml` 的 schema、bootstrap/adopt/archive 写入路径与 break-glass 审批

## Bootstrap Protocol

bootstrap 的目标不是替代真实主干工件生成，而是确保新 feature 一进入 managed active scope 就具备最小 contract 骨架。

最小产物：

- 合法的 `docs/{feature}` 根目录
- 一个可解析的 `worklog.md`
- 已声明的 `mode`
- 一条成功写入的 registry 记录
- 未预建的场景目录

不在 bootstrap 阶段生成：

- 空的 `research/debug/verification/supporting`
- 与当前模式不匹配的主干工件
- `contract-waivers.md`

触发方式：

- `small-chain`
  - 用户批准设计后，由 entry/plan 侧脚本先创建 feature 根、`worklog.md`、registry 记录和 `YYYY-MM-DD-<change>/` active workset，再进入 `writing-plans`
- `full-chain`
  - 首次 `/product` 或上游创建受管 feature 时，先确保 feature 根、`worklog.md` 与 registry 记录存在，写入首条 `stage=bootstrap` 记录，再继续生成 `brief.md / phase-*`

模式选择与切换：

- mode 在 bootstrap 时确定
- `small-chain`
  - 适用于直接进入 `design/tasks/plan` 的轻量链
- `full-chain`
  - 适用于需要 `brief/prd/units/phase-*` 的完整链
- mode 默认冻结
- mode 切换必须同时满足：
  - `worklog.md` 显式 handoff 记录
  - registry 同步更新
  - 旧 `state_ref / next_ref` 已重定向到新主干入口

责任分工：

- bootstrap script / template owner：repo contract `owner`
- 触发人：发起新 feature 的上游 skill 或明确的人类维护者
- 验证人：`pre-commit` + runtime gate + `CI`
- 无稳定 `principal_id` 的运行面，`worklog.md` 实际写入者授权由 integrate gate / audit 复核，不在 runtime gate 假装强认证
- `owner acknowledgement` 的优先来源是 PR/merge approval；无 PR 流时，`finishing-a-development-branch` 产出的 `branch-finalization` 必须记录 `approved_by / approved_at`
- 上述 acknowledgement 必须带稳定引用：优先用 PR review URL / ID；无 PR 流时用 `branch-finalization#anchor` 作为 `approval_ref`

迁移约束：

- 旧的 `legacy` 目录不会被 bootstrap 自动接管
- 任何 legacy -> managed 的切换，必须是显式 adopt 动作，并同步写入 registry，而不是“目录正好长得像”就自动纳管

## README & Scope Alignment

README 与 contract 的口径必须同时成立，不能一个说“`docs/` 都是历史”，另一个又默认把 `docs/{feature}` 当活跃区。

Phase 1 对齐口径：

- `docs/` 默认仍是历史/非运行时文档根
- 例外是被 rollout 纳入的 `managed active scope`
- 该例外必须在 README 中显式写出

落地要求：

- 在进入 `Phase 1: pilot` 前，README 与 `contracts/small-chain.yaml` 必须先完成兼容口径更新
- CI 必须把 README、`contracts/small-chain.yaml`、`contracts/active-doc-scope.yaml` 与 validator 文案漂移当作阻断项
- runtime docs、contracts、validator 文案必须引用同一口径，不允许各自发明解释

## Rollout Principles

- 新建优先
- 存量渐进
- 先告警后阻断
- 单 feature 试点
- 可回退

## Rollout Phases

1. `Phase 0: inventory`
   - 盘点现有 `docs/` 目录，区分 `archive / legacy / active candidates`
   - 不阻断，只生成 inventory 报告

2. `Phase 1: pilot`
   - 仅覆盖已完成 README / small-chain contract 兼容更新的新增 feature
   - 额外选 `1` 个 `small-chain` 和 `1` 个 `full-chain` 活跃 feature 进入试点
   - `pre-commit` / runtime hook 先以最小规则集运行

3. `Phase 2: expand`
   - 将试点验证通过的规则扩展到 `managed active scope`
   - CI 采用“changed-feature 增量扫描 + 夜间全量 audit”双轨运行

4. `Phase 3: enforce`
   - 将已验证稳定的规则从 `warn` 升级为 `block`
   - README、contracts、runtime docs 统一更新到新口径

## Compatibility Strategy

- `legacy`
  - 旧目录，默认不受阻断式 contract 约束，只参与 audit
- `managed`
  - 已纳入 rollout 的活跃 feature，受新 contract 约束
- `migrated`
  - 已完成最小骨架与 `worklog.md` 补齐的 feature

## Bootstrap & Migration Protocol

- 新 feature：创建时直接生成最小骨架、`worklog.md` 与 registry 记录；`small-chain` 同时生成 active workset
- 试点老 feature：先补 `worklog.md` 与 registry 记录，再按需补场景目录和命名收口
- 非试点老目录：保持 `legacy`，不被阻断式门禁强制改造

## Rollback & Exception Policy

- 误报或性能问题触发时，可从 `block` 临时降回 `warn`
- 例外必须落盘到受控例外记录，不能靠口头约定
- 任何长期例外都应在 audit 中可见
