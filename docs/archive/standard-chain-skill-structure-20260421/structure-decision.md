# Standard-Chain Skill Structure Decision

## 背景

标准流程 Skill 的结构治理目标是提升产出质量，而不是统一版式。`shared/reference/Skill质量标准.md` 已定义本地裁判口径：质量判断评价触发、加载、artifact、权限、流程、验证、演化和复用上的运行时合同。结构调整只有在降低运行时噪音、减少合同漂移、提升下游可消费性时才成立。

本次裁决覆盖 `shared/skills` 标准流程 10 个 main skill：`product-director`、`product-manager`、`design`、`test-design`、`tech-lead`、`developer`、`review`、`verify`、`qa`、`delivery-owner`，并覆盖交付期 sidecar / expert：`fix` 与 `consistency-audit`。结构治理以产出质量为目标：让每个 skill 的入口只保留当前运行必须知道的事实源、职责边界、输入、流程、输出和完成证明。

## 裁决

大块 `Canonical Runtime Contract` 不作为标准流程 Skill 的最终结构。它可以短期保护 canonical 工件迁移，但会把模板、输入、输出、validator 和 legacy 说明集中到一个高噪音区块，导致模型在具体步骤执行时无法直接看到当前动作需要读取什么、产出什么、如何证明完成。

标准流程 Skill 采用以下运行时结构：

1. `HARD-GATE` 放不可违反的阻断规则。
2. `角色` 定义负责、不负责、上游和下游边界。
3. `前置条件` 定义输入、状态、授权范围、缺失时终止或追问行为。
4. `运行边界` 或各流程步骤定义 canonical 真源、人类投影视图限制和下游控制边界。
5. `流程` 承载步骤顺序、暂停条件和写入目标。
6. `流程使用点引用` 把 reference 挂到实际步骤，并显式说明 Trigger、Read、Expect、Consume、Evidence、Sync。
7. `输出` 定义路径、格式、模板和下游消费者。
8. `完成校验` 映射到 validator、fresh proving command 和 artifact 状态。

允许表达变化：各 skill 可以按自身工作流命名流程段落，例如 `流程`、`固定主流程`、`Scope 参数`；可以把使用点引用直接写在步骤内，也可以在 `流程使用点引用` 中用步骤 ID 精确绑定。必须保留的语义是 Trigger、Read、Expect、Consume、Evidence、Sync 都可追踪，且引用路径存在。

运行时权限由 frontmatter、`HARD-GATE`、`前置条件`、`运行边界` 与流程步骤限制共同表达；不得新增单独运行时权限板块。

禁止语义：不得把合同模板清单、运行时输入清单、运行时输出清单、validator 命令、脚本 manifest、hook adapter 生命周期、迁移历史、角色拆分解释或 `producer` 口头解释塞进主入口的集中权限区块。这些内容分别进入 `输出`、`前置条件`、`完成校验`、`references/`、`contracts/` 或迁移文档。

信息分层裁决：

- 主入口只保留单一职责、当前事实源、派发/消费边界和完成证明。
- 运行时真源只落在 canonical JSON + active registry；Markdown 只能作为人类投影视图。
- 方法论、长示例、字段说明进入 `references/`；机器可校验结构进入 `contracts/canonical/`；脚本行为进入 `scripts/manifest.json`。
- 模板只负责可填写结构，不承载隐藏规则、hook 指令、流程 SOP 或质量门禁解释。
- 专家 skill 保留自己的办事 SOP；`delivery-owner` 只做交付控制面和团队负责人，不复制专家方法。
- 旧流程兼容不进入 standard-chain runtime；需要负例或迁移材料时放在 eval fixture、archive 或显式 migration 文档。

## 放置规则

保留在主入口的内容必须直接影响当前运行：触发、硬门禁、角色边界、前置条件、流程骨架、输出合同和完成校验。低频方法论、长示例、schema、模板字段细节和评审细则进入 `references/`、`contracts/` 或 `scripts/`。

权限与真源放置规则：

- 工具权限只放 frontmatter。
- 当前运行事实源、投影视图限制和下游控制输入限制，放在最接近消费点的 `HARD-GATE`、`前置条件`、`运行边界`、`流程`、`输出` 或 `完成校验` 中。

以下内容不放入主入口的集中权限区块：

- 合同模板清单。
- 运行时输入清单。
- 运行时输出清单。
- validator 命令。
- 单一步骤才需要的 reference。

## 质量指标

全链路通过的客观标准是结构变化不破坏现有 standard-chain 合同，同时更清楚地把资源加载绑定到使用点。

验证面包括：

- 10 个 standard-chain main skill 不再保留大块 `Canonical Runtime Contract`。
- 每个 skill 都不保留单独运行时权限板块。
- direct reference 通过 Trigger、Read、Expect、Consume、Evidence、Sync 在使用点声明。
- canonical 模板路径、artifact 路径和 validator 命令仍可被现有 cutover/readiness 测试发现。
- sidecar agent 必须注册 advisory authority；不得升级为 gate owner 或 sign-off owner。
- agent 入口必须要求标准流程派发合同与 active refs，不能靠宽泛 `Proactively` 触发进入专家行为。
- context budget 不回退，`SKILL.md` 行数仍在本地质量标准预算内。

## 全链路门禁

`tests/test-standard-chain-skill-structure.sh` 从 `contracts/standard-chain.yaml` 读取 10 个 main skill，逐个验证：

- 不存在 `Canonical Runtime Contract` 或 `Standard-Chain Canonical Lane`。
- 不存在单独运行时权限板块。
- 标题、HARD-GATE、角色、前置条件、流程、输出、完成校验的顺序不回退。
- 使用点引用若出现 `Trigger:`，必须同时包含 `Read / Expect / Consume / Evidence / Sync`，且 `references/` 路径可达。
- active skill 中不得出现 `v1 catalog`、`角色拆分`、`authoritative fields`、`producer` 口头解释、`legacy projection lane` 或旧 sidecar 同步口径。

## Rollout Matrix

| skill | 状态 | 结构门禁 |
| --- | --- | --- |
| product-director | 已收敛 | full gate |
| product-manager | 已收敛 | full gate |
| design | 已收敛 | full gate |
| test-design | 已收敛 | full gate |
| tech-lead | 已收敛 | full gate |
| developer | 已收敛 | full gate |
| review | 已收敛 | full gate |
| verify | 已收敛 | full gate |
| qa | 已收敛 | full gate |
| delivery-owner | 已收敛 | full gate |
| fix | 已收敛 | sidecar/expert runtime gate |
| consistency-audit | 已收敛 | advisory sidecar gate |
