# OpenSpec 本地中文 Canonical 实施方案调研报告

## 1. 调研目标

- 目标 A：在不改变既定 `OpenSpec + superpowers` 融合流程关系的前提下，明确 OpenSpec 这一侧应如何改造成中文、本地 canonical 实现。
- 目标 B：明确哪些 OpenSpec 机制必须保留，哪些可以本地改写，哪些不应继续混用。
- 目标 C：给出一版可直接执行的最佳实践实施方案，覆盖目录、skill/command 结构、同步策略、验收标准与风险控制。

## 2. 项目上下文扫描

### 2.1 当前默认链

当前仓库的默认链仍然定义为：

- `brainstorming -> opsx:propose -> writing-plans -> using-git-worktrees -> opsx:apply -> (subagent-driven-development 默认 / executing-plans 备选) -> requesting-code-review -> verification-before-completion -> opsx:verify -> opsx:archive`

证据：

- [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- [contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml)

### 2.2 当前落地状态

本轮重构后的目标落点已经明确为：

- `community/openspec`：OpenSpec 中文 canonical runtime
- `community/superpowers`：superpowers 中文 canonical runtime
- `community/SOURCES.yaml`：来源锁定
- `openspec/`：统一工作台

证据：

- [community](/Users/lijieli/org-claude-skills/community)
- [community/SOURCES.yaml](/Users/lijieli/org-claude-skills/community/SOURCES.yaml)
- [openspec](/Users/lijieli/org-claude-skills/openspec)

### 2.3 当前本地 Skill 标准与社区格式不一致

当前 first-party skill 标准强调：

- 五段式结构
- 本地 frontmatter 规则
- 双端适配说明
- token 效率约束

证据：

- [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)

这套标准适合 first-party skill，但不天然适合社区来源的 OpenSpec 命令/skill。

## 3. 当前问题定义

### 3.1 混源问题

重构前，OpenSpec 相关内容分散在：

- upstream 英文快照
- 本地 adapter
- 本地运行目录
- 本地文档说明

问题：

- 团队难以判断哪一份才是真正运行的 canonical 内容
- 英文正文会对中文团队形成理解噪音
- 后续修订容易同时改错 2-3 层

### 3.2 运行形态问题

OpenSpec 在当前仓库的接入是“部分照搬 upstream，部分本地再包装”，造成：

- 平台接入方式不稳定
- 运行行为与文档意图不完全一致
- FAIL 问题本质上来自“入口和运行时接法错位”

### 3.3 目录问题

重构前，融合链工件分散于两套根：

- `docs/superpowers/specs` / `docs/superpowers/plans`
- `openspec/changes` / `openspec/specs`

问题：

- 工件查找成本高
- handoff 语义不直观
- 同一次 change 的设计、计划、规格不在一个物理根下

## 4. OpenSpec 可复用内核

本轮调研后，OpenSpec 最值得吸收的不是英文正文，而是以下机制。

### 4.1 工作台模型

核心结构：

- `openspec/specs/`
- `openspec/changes/<change>/`
- `openspec/changes/archive/`

价值：

- 当前真源、当前变更、归档历史三者边界清楚
- 适合长期演进
- change 是一等对象

### 4.2 状态机模型

核心能力：

- `status`
- `instructions`
- `applyRequires`
- artifact `ready / blocked / done`

价值：

- 让流程推进不靠“感觉”
- 明确下一步该创建哪个 artifact
- 能把“写完一个再下一个”变成状态驱动

### 4.3 Artifact 分层

核心 artifacts：

- `proposal.md`
- `specs/**/spec.md`
- `design.md`
- `tasks.md`

价值：

- `why / what / how / task checklist` 分层清晰
- 比把所有内容塞进一个大文档更稳

### 4.4 `tasks.md` 机制

值得吸收的点：

- 任务是明确 checklist
- `- [ ] / - [x]` 成为客观状态
- 可用于 apply、verify、archive 共享判断

结论：

- `tasks.md` 应保留
- 但要明确与 `writing-plans` 的关系

### 4.5 Archive / Validate 的职责边界

值得吸收的不是命令名字本身，而是职责拆分：

- `status`：状态
- `instructions`：模板与依赖说明
- `validate`：规则性校验
- `archive`：同步 + 归档

## 5. 不应继续直接混用的部分

### 5.1 英文正文作为运行资产

不建议继续把整份英文 OpenSpec 正文放在主仓库中，作为运行相关内容长期共存。

原因：

- 运行真源必须唯一
- 中文团队会把英文正文视为第二套权威
- 后续维护会持续混乱

### 5.2 直接把社区格式硬套进 first-party Skill 标准

不建议：

- 先按本地 old standard 改写 OpenSpec，再期望效果等价

原因：

- 会破坏 OpenSpec 已验证的行为语义
- 会让“参考实现”变成“再设计一份”

### 5.3 继续混用两套工件根目录

不建议继续保留：

- `docs/superpowers/specs`
- `docs/superpowers/plans`
- `openspec/...`

并行共存的现状

原因：

- 对同一 change 的信息不集中
- 交接和追踪成本过高

## 6. 推荐实施原则

### 6.1 Canonical 原则

OpenSpec 本地实现采用：

- **中文 canonical**
- **社区结构基线**
- **本地最小兼容补丁**

解释：

- 中文：团队主语言统一
- 社区结构基线：保留已验证的步骤和职责
- 最小兼容补丁：只处理本地 metadata、路径、平台适配

### 6.2 双轨原则

- first-party 原有 skill：继续沿用现有标准
- 新建的 OpenSpec 本地实现：以社区格式为基线，不强行套旧模板

这不是“双标”，而是明确两类资产的来源和设计目标不同。

### 6.3 单根原则

统一后的工作区根目录建议固定为：

- `openspec/`

推荐结构：

```text
openspec/
  config.yaml
  designs/
  plans/
  specs/
  changes/
  changes/archive/
```

解释：

- `designs/`：承接 `brainstorming` 产物
- `plans/`：承接 `writing-plans` 产物
- `specs/changes/archive/`：承接 OpenSpec 工作台

这样同一次 change 的相关工件都在一个物理根下。

### 6.4 技术标识保留原则

以下内容继续保留英文：

- 命令名：`opsx:propose`
- 文件名：`proposal.md`、`tasks.md`
- 状态字段：`ready / blocked / done`
- checkbox：`- [ ] / - [x]`
- 代码标识、API path、工具名

其余运行说明、步骤、提示、输出示例一律中文化。

## 7. 推荐实施方案

### 7.1 OpenSpec 本地实现方式

采用：

- **重做本地 OpenSpec canonical**
- **不再直接依赖英文正文运行**

实现策略：

1. 以 OpenSpec 原版结构和步骤为蓝本
2. 中文完整翻译正文
3. 保留技术标识英文
4. 对本地平台只补必要 metadata 和路径适配

### 7.2 Skill / Command 结构策略

新建的 OpenSpec 侧资产遵循：

- 结构尽量贴近社区
- 不强行改造成 current first-party 五段式模板

允许的改动：

- 中文翻译
- frontmatter 兼容
- 路径改写到统一后的 `openspec/`
- 本地工具说明补充

不允许的改动：

- 打乱步骤顺序
- 改状态机语义
- 改 artifact 职责边界
- 为了适配旧模板而重写正文组织

### 7.3 目录统一策略

这次推荐一次性收敛为：

- `openspec/designs/`
- `openspec/plans/`
- `openspec/specs/`
- `openspec/changes/`
- `openspec/changes/archive/`

对应迁移关系：

- `docs/superpowers/specs/*` → `openspec/designs/*`
- `docs/superpowers/plans/*` → `openspec/plans/*`

### 7.4 同步策略

不再长期保留整份英文 upstream 正文在主仓库。

仅保留：

- upstream repo URL
- commit/tag
- capture date
- sync script 或同步说明
- 映射清单（本地文件对应哪份 upstream）

这是一种：

- **来源锁定**
- **按需复拉**
- **不在运行仓库里混双份正文**

的策略。

## 8. `tasks.md` 与 `writing-plans` 的最佳实践边界

这是本轮必须说清的点。

### 推荐边界

- `tasks.md`：高层 change checklist
- `plan.md`：细粒度执行计划

不推荐：

- 让 `tasks.md` 和 `plan.md` 同时承担详细执行计划

原因：

- 会出现双真源
- apply / verify / archive 难以判断到底信哪份

### 推荐职责

`tasks.md`：

- 面向 change 生命周期
- 标识哪些 implementation items 完成
- 为 verify/archive 提供客观完成态

`writing-plans` 输出：

- 面向执行细节
- 负责文件级、步骤级、命令级计划

## 9. 对当前仓库的具体落地建议

### 9.1 保留不变

- `OpenSpec + superpowers` 融合流程关系不变
- 标准流程不在本轮重写
- 当前 first-party skill 标准不整体推翻

### 9.2 需要改造

1. 移除当前混用的英文 OpenSpec 运行正文
2. 新建中文 canonical OpenSpec 实现
3. 统一 `openspec/` 根目录
4. 明确 `tasks.md` 与 `plans/` 的职责边界
5. 重新梳理 `opsx:*` 的本地运行入口与测试

### 9.3 不建议本轮做的事

- 全仓 first-party skill 样式统一改造
- 同时大改 superpowers 正文结构
- 在未完成本地 canonical 之前继续扩充 community-first 运行面

## 10. 验收标准

实施完成后，应同时满足：

1. 仓库内不存在双份 OpenSpec 正文真源
2. OpenSpec 本地实现的运行说明为中文
3. 统一根目录收敛到 `openspec/`
4. `brainstorming` 产物与 `writing-plans` 产物都进入统一根目录
5. `tasks.md` 与计划文件职责不再重叠
6. `opsx:*` 的运行入口、文档、测试、安装逻辑一致
7. 融合链关系不变

## 11. 风险与控制

### 风险 A：中文翻译改变原始行为语义

控制：

- 严格按社区结构翻译
- 技术标识不翻
- 逐条对照关键 guardrails

### 风险 B：目录统一导致链路引用断裂

控制：

- 先定义统一路径规范
- 再整体迁移合同、文档、测试

### 风险 C：`tasks.md` 与 `plan.md` 再次职责重叠

控制：

- 在本地 canonical 里先写死职责边界
- 验收时专门检查“双真源”问题

## 12. 最终建议

本轮最佳实践不是：

- 继续直接混用 OpenSpec 英文原版
- 或把 OpenSpec 粗暴套进现有 first-party skill 模板

而是：

- **保留融合流程关系**
- **以社区结构为基线**
- **做中文 canonical 的本地 OpenSpec 实现**
- **统一到 `openspec/` 单根目录**
- **保留最小来源锁定，不再保留整份英文正文作为运行资产**

这条路最符合你当前拍板的目标，也最容易把“最佳实践”真正落成你们自己的可维护基线。

## 13. 证据清单

- [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- [contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml)
- [community-first 集成调研报告](/Users/lijieli/org-claude-skills/docs/community-first-integration/research-report.md)
- [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)
- OpenSpec 官方文档：
  - https://github.com/Fission-AI/OpenSpec
  - https://github.com/Fission-AI/OpenSpec/blob/main/docs/commands.md
  - https://github.com/Fission-AI/OpenSpec/blob/main/docs/getting-started.md
