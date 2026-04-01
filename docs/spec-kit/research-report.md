# github/spec-kit 调研报告

日期基线：`2026-04-01`

## 1. 当前结论

### 1.1 一句话判断

`github/spec-kit` 不是“帮你写代码的库”，而是一套把 **constitution → spec → clarify → plan → tasks → analyze → implement** 固化为项目内工作流的 **Spec-Driven Development 启动器和运行脚手架**。

### 1.2 适用判断

- 适合：缺少稳定需求澄清、计划拆解和任务落盘习惯的团队；greenfield；边界清晰的 brownfield 增量需求。
- 不适合：已经有成熟 workflow contract、文档真源和执行收口机制的仓库，尤其是已经明确“不依赖上游 runtime，只吸收概念”的体系。

### 1.3 对当前仓库的裁决

对 `org-claude-skills` 的最佳策略不是“引入 spec-kit runtime”，而是：

1. 吸收它已经被验证有效的做法。
2. 明确拒绝会与你们现有真源和链路冲突的部分。
3. 只在小范围试点它的某些机制，不把它当新的主编排层。

裁决：**有条件成立，适合学习，不适合整套接管。**

## 2. 项目上下文画像

当前仓库不是普通业务应用，而是组织级 AI 工程工作流资产库。

- 仓库目标：统一维护 Claude/Codex 的 `skills / rules / reference / hooks / agents`，并以 `superpowers` 为方法论基线，以 `small-chain` 为本地默认编排链路。[README](../../README.md)
- 当前定位：`community/openspec` 只保留为兼容库存或迁移过渡资产，**不再作为未来默认编排真源**。[README](../../README.md)
- 当前链路：`using-superpowers -> brainstorming -> writing-plans -> using-git-worktrees -> subagent-driven-development -> verify-change -> archive`。[contracts/small-chain.yaml](../../contracts/small-chain.yaml)
- 当前已确认原则：执行收口在 `superpowers`，OpenSpec 只吸收概念不依赖 runtime，`tasks.md` 是独立验收真源，`plan.md` 通过 `task-id` 引用 `tasks.md`。[best-practice-implementation-plan](../best-practice-implementation-plan.md)

这意味着：你们当前问题不是“有没有流程”，而是“哪些外部方法值得吸收，哪些会造成重复编排和真源冲突”。

## 3. spec-kit 到底解决什么问题

根据官方 README、Quick Start 和文档站，spec-kit 试图解决 4 类问题：

1. **把自然语言需求从一次性 prompt 变成多阶段工件。**
   先定义 constitution，再写 spec，再 clarify，再 plan、tasks、analyze、implement，而不是一句话直接让 agent 开干。

2. **把“what/why”和“how”拆开。**
   官方 Quick Start 明确要求在 `/speckit.specify` 阶段聚焦 what/why，不要先讲 tech stack；技术栈放到 `/speckit.plan`。

3. **把 AI 的过度自信和一次成稿倾向压回去。**
   官方流程把 `/speckit.clarify`、`/speckit.analyze`、`/speckit.checklist` 放在实现前，目的是减少遗漏、歧义和跨工件漂移。

4. **把这一套流程变成项目内可安装、可升级、跨 agent 复用的资产。**
   `specify init` 会在项目内安装模板、脚本、命令文件/skills 和 `.specify` 目录，支持不同 agent、extensions、presets 和 overrides。

## 4. 核心机制

### 4.1 官方主链

官方 Quick Start 的最小主链是：

1. `specify init`
2. `/speckit.constitution`
3. `/speckit.specify`
4. `/speckit.clarify`
5. `/speckit.plan`
6. `/speckit.tasks`
7. `/speckit.analyze`
8. `/speckit.implement`

### 4.2 它的强项不在“模板多”，而在“流程顺序被固化”

- 先有治理原则，再有需求，再有澄清，再有技术计划。
- 分阶段落盘，减少“需求说的是 A，计划写成 B，实现做成 C”。
- 对 Codex CLI 也提供 skills 形态，而不仅是 slash commands。

### 4.3 它的 brownfield 叙事

官方 README 把 brownfield 明确列为一个发展阶段，并给出多个 brownfield demo，试图证明这套流程不仅能从 0 到 1，也能用于在现有大项目中增量扩展。

但这不是自动成立的能力，而是**有条件成立**：前提是你能把 brownfield 需求切成清晰 feature 边界，并且允许 agent 先补一层规范工件。

## 5. 优点与缺点

### 5.1 优点

| 维度 | 判断 | 证据与说明 |
|------|------|-----------|
| 一致性 | 强 | 把 constitution/spec/clarify/plan/tasks/analyze 分阶段固化，天然比“一次 prompt 直接实现”更容易保留链路。 |
| 需求澄清 | 强 | 官方把 clarify 设为 plan 前的推荐步骤，显式压制“先做再说”。 |
| 工件化 | 强 | 项目内生成脚本、模板、命令和 `specs/` 目录，便于团队复用。 |
| 多 agent 兼容 | 中强 | 官方 README 明确支持多类 agent，对 Codex 还支持 `--ai-skills`。 |
| 可定制性 | 中强 | extensions / presets / project-local overrides 的优先级分层设计很清晰。 |
| 质量前置 | 中 | `analyze` 和 `checklist` 把一致性检查前置到实现前，而不是事后补。 |

### 5.2 缺点

| 维度 | 判断 | 证据与说明 |
|------|------|-----------|
| runtime 耦合 | 高 | `specify init` 会向项目内写入脚本、模板、命令文件和 `.specify` 资产，升级时也要刷新这些文件。 |
| 升级风险 | 高 | 官方 Upgrade Guide 明确写出已知问题：升级会覆盖 `.specify/memory/constitution.md`，自定义模板也会被覆盖。 |
| 流程表演风险 | 中高 | 如果团队只是“把文档写全”，却没有把 clarify/analyze/checklist 当成门禁，最后会变成更贵的仪式。 |
| brownfield 成本 | 中高 | 旧系统没有稳定 feature 边界时，先补 spec/plan/tasks 可能很重；README 的 brownfield demo 是有前提的，不等于任意遗留系统都适合。 |
| 工具链维护成本 | 中 | 官方 issue 已承认 shell/PowerShell 脚本测试和兼容性存在真实维护压力。 |
| 真源冲突风险 | 高 | 对已有成熟工作流仓库，`constitution/specs/templates/scripts/commands` 的另一套 runtime 很容易与现有规则源、文档源和执行收口发生冲突。 |

## 6. 对 org-claude-skills 的帮助

### 6.1 可能带来的增量价值

1. **把“clarify before plan”做得更显式。**
   你们已有 brainstorming，但 spec-kit 的 clarify 和 checklist 更像专门针对需求完整性做一次结构化追问和自检。

2. **把跨工件一致性检查做成独立动作。**
   你们当前强调 `tasks.md` 与 `plan.md` 的单真源关系；spec-kit 的 `analyze` 值得借鉴为“设计/计划/任务/验收”一致性检查层，而不一定要照搬原命令。

3. **定制层级设计值得学。**
   core / extensions / presets / overrides 的分层很清楚，适合借鉴到你们的 `shared -> community -> platform adapter -> project-local` 叠加模型里。

4. **对 Codex 的安装方式有参考价值。**
   官方已考虑 Codex skills 模式，这对你们维护 Claude/Codex 双运行时有现实参考。

### 6.2 不能直接搬的地方

1. **你们已经明确“OpenSpec 只吸收概念，不依赖 runtime”。**
   如果再引入 spec-kit runtime，相当于又加一层上游 runtime 依赖，和现有裁决冲突。

2. **你们已经有自己的工件真源和目录规范。**
   当前方案要求 `docs/{feature}/YYYY-MM-DD-{change}/design.md/tasks.md/plan.md`，而 spec-kit 默认围绕 `.specify/`、`specs/<feature>/`、slash commands/skills 组织。

3. **你们已有明确执行收口。**
   当前执行收口在 `subagent-driven-development`，不是让另一套 `/implement` 接管。

### 6.3 最合理的引入方式

只建议吸收以下 4 项：

1. `clarify` 的结构化追问机制
2. `analyze/checklist` 的跨工件一致性与完整性检查
3. extensions / presets / overrides 的定制优先级设计
4. Codex/Claude 多运行时适配经验

不建议引入：

1. `specify init` 对当前仓库的 runtime 写入
2. `.specify/` 目录作为新真源
3. `/speckit.implement` 作为执行收口
4. 以 spec-kit 的 feature 目录和分支约定替代当前 docs/openspec/contracts 体系

## 7. 两条 Challenger 线

### 7.1 Challenger A：流程设计 / 架构治理视角

| 命题 | strongest challenge | 成立条件 | 失效条件 | 对 org-claude-skills 的警告 |
|------|---------------------|----------|----------|-----------------------------|
| spec-kit 能显著提升需求到实现的一致性 | 它提升的是“工件数量”和“顺序约束”，不自动等于一致性；如果 clarify/analyze 没成为真正门禁，只会把漂移从对话挪到文档。 | 团队把 spec/clarify/plan/tasks 当成持续回链的真源，而不是一次生成后不再维护。 | 文档生成后不再更新，或实现绕过工件直接改代码。 | 你们已经有 rules/reference/contracts；再引入一套文档 runtime，很容易出现“双重真源”。 |
| 它适合 brownfield | brownfield 的难点通常不是“没有 spec 模板”，而是边界不清、历史债重、改动半径未知；spec-kit 只能在边界已可切分时帮忙。 | 改动能切成 feature，且允许先补 spec 与 plan。 | 牵一发动全身、隐式耦合多、没有稳定 feature 边界。 | 不要被官方 brownfield demo 误导成“对所有遗留系统都适配”。 |
| 它值得当前 org-claude-skills 学习 | 值得学习的是机制，不是 runtime 全套；否则会和你们已确认的“去 runtime 依赖”方向打架。 | 只吸收 clarify、analyze、preset layering 等高价值机制。 | 把它当下一代主编排层来接入。 | 你们最需要防的是重复编排，而不是缺少流程。 |

### 7.2 Challenger B：交付 / 验证 / adoption 视角

| 命题 | strongest challenge | 可观察风险信号 | 最小验证实验 |
|------|---------------------|----------------|--------------|
| spec-kit 会提升交付效率 | 前期工件变多会先变慢；只有返工明显下降时，总效率才会上升。 | 需求很小却仍强制走完整套工件；团队开始抱怨“写文档比做事还久”。 | 选一个中等复杂度 change，对照“现有 small-chain”与“新增 clarify/analyze”两种流程，比较返工次数与总耗时。 |
| 它会降低返工 | 降低返工的前提是 clarify 真能暴露歧义，analyze 真能拦截跨工件矛盾；如果只是自动生成文档，返工不会少。 | 计划和任务看起来完整，但实现阶段仍频繁改口径。 | 对同一 change 记录“需求变更点数、计划改写次数、实现回滚次数”。 |
| 它对非专家团队友好 | 它对“有纪律但流程弱”的团队友好；对“流程理解弱、上下文管理弱”的团队，可能先制造更高认知负担。 | 新人不知道哪个文件是真源，不知道该改 spec 还是改 tasks，或把 constitution 当静态摆设。 | 让一名不熟悉仓库的新同学只看指南完成一个试点 change，记录卡点。 |

## 8. 我们应该学习的最佳实践

### 8.1 建议吸收

1. **what/why 与 how 分离**
   这个是高价值做法，不是形式主义。

2. **clarify before plan**
   在 planning 前强制解决需求歧义，能直接压低返工率。

3. **独立的一致性检查层**
   在实现前做跨工件 coverage/consistency check，而不是只检查格式。

4. **可组合的定制层级**
   核心模板、扩展能力、预设方案、项目局部覆盖要分层，不要混成一锅。

5. **对快速变化技术栈的定向研究，而不是泛泛研究**
   官方示例里强调“把研究拆成具体问题并并行处理”，这比泛泛调研更实用。

### 8.2 不建议迷信

1. 不是所有项目都值得走完整主链。
2. 文档多不等于质量高。
3. 有 brownfield demo 不等于 brownfield 普适。
4. 上游官方出品不等于适合当前仓库。

## 9. 最终建议

### 9.1 建议动作

1. 保持当前 `small-chain + superpowers + OpenSpec concepts` 主方向不变。
2. 从 spec-kit 吸收 `clarify` 和 `analyze/checklist` 两个机制，设计成你们现有链路中的补强步骤。
3. 研究它的 extensions / presets / overrides 分层，映射到你们当前的 shared/community/adapter 体系。
4. 不把 `specify init`、`.specify/`、`/speckit.implement` 引入当前仓库主运行时。

### 9.2 一句话落地建议

**把 spec-kit 当“可拆解的方法论样本”，不要把它当“需要整体安装的新内核”。**

## 10. 主要证据

### 官方来源

- GitHub 仓库：<https://github.com/github/spec-kit>
- 文档首页：<https://github.github.com/spec-kit/>
- Quick Start：<https://github.github.com/spec-kit/quickstart.html>
- Upgrade Guide：<https://github.github.com/spec-kit/upgrade.html>
- 已知维护问题示例：<https://github.com/github/spec-kit/issues/1049>

### 当前仓库来源

- [README](../../README.md)
- [contracts/small-chain.yaml](../../contracts/small-chain.yaml)
- [best-practice-implementation-plan](../best-practice-implementation-plan.md)
