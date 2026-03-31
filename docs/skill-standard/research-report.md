# Skill 语言、格式与 Community 协作方式调研报告

## 调研背景
- 调研触发：仓库已经完成 `community-first` 落地，但对 skill 应该用中文还是英文、当前 `SKILL.md` 标准是否是最佳实践、以及 `superpowers` 与 `OpenSpec` 的协作方式，团队认知仍不统一。
- 决策目标：明确本仓库 skill 的语言策略、格式策略和分层协作模型，避免后续继续在“统一成一种格式”或“全部翻译/全部重写”上反复。
- 关键约束：
  - 仓库同时服务 Claude 与 Codex 双端。
  - 用户与团队主要以中文协作。
  - 已引入 `third_party/community/` 与 `community-adapters/`，上游正文需要保持 source of truth。
  - 现有 first-party skill 已形成一套本地质量标准和安装/测试体系。

## 项目上下文
- 技术栈：
  - 仓库核心是 `SKILL.md` + `agents/openai.yaml` + 安装器 `install.sh` + 测试脚本。
  - 默认入口已切到 `community-first`，见 [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)。
- 已有相关实现：
- first-party skill 规范在 [shared/skills/new-skills/references/description-spec.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/references/description-spec.md) 和 [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)。
  - community upstream 快照在 `third_party/community/`。
  - community 适配边界在 [community-adapters/README.md](/Users/lijieli/org-claude-skills/community-adapters/README.md)。
- 约束条件：
  - first-party local skill 追求短、可控、跨端适配。
  - community skill 追求 upstream 语义不失真。
  - 两者目标不同，不能强行统一成一套文件风格。

## 核心概念图

```text
skill 设计
├── machine-facing metadata
│   ├── name
│   ├── description
│   ├── short_description
│   ├── default_prompt
│   └── disable-model-invocation / openai.yaml
├── human-facing body
│   ├── HARD-GATE
│   ├── 流程 / checklist
│   ├── 输出 / 完成条件
│   └── references/
└── source-of-truth layering
    ├── first-party local skills
    ├── upstream community snapshots
    └── community adapters
```

## 问题本质

这个问题表面上是“skill 用中文还是英文、格式怎么写”，本质上其实是 3 个对象混在了一起：

1. 给模型看的 metadata 怎么写，才能更容易被正确发现和调用。
2. 给人看的 skill 正文怎么写，才能更容易维护、协作和审计。
3. 不同来源的 skill，是否应该共享同一份格式标准。

如果不把这 3 层拆开，就会出现两个典型误区：

- 误区 A：把“模型发现效果”归因到整份 `SKILL.md` 的语言，而忽略真正高影响的是 `name / description / openai.yaml` 这类 metadata。
- 误区 B：把 first-party local skill 和 upstream community skill 当成同一种资产，强行要求它们长得一样。

## 解法谱系

### 流派 A：统一语言、统一格式
- 设计哲学：所有 skill 都按同一模板、同一语言重写，便于仓库整齐。
- 代表方案：把 upstream skill 翻译后塞进本地模板。
- 优势：
  - 表面一致性高。
  - 仓库视觉上整齐。
- 局限：
  - upstream 同步成本高。
  - 一旦改写正文，就失去“上游就是 source of truth”的意义。
  - 机器面和人面诉求被混在一起，容易为了格式一致牺牲发现效果或语义完整性。

### 流派 B：按来源分层，按受众分层
- 设计哲学：对模型的字段和对人的正文分开设计；first-party 和 upstream 不强行统一外观，只统一边界与适配规则。
- 代表方案：本仓库当前的 `shared/` + `third_party/community/` + `community-adapters/` 三层模型。
- 优势：
  - upstream 可持续同步。
  - first-party 可针对团队语言与双端运行面优化。
  - source of truth 边界清晰。
- 局限：
  - 需要团队理解“双标准并存”。
  - 文档和测试必须明确哪些规则只约束 first-party。

### 流派 C：完全 upstream 优先，本地只安装不建模
- 设计哲学：尽量不定义本地标准，全部信 upstream。
- 代表方案：把 community skill 直接装到运行面，本地只做极少修改。
- 优势：
  - 与 upstream 最一致。
  - 本地维护最少。
- 局限：
  - 无法很好承接本仓库现有的双端安装、manual-only、first-party skill 治理需求。
  - 不适合已经存在大量本地技能和既有工作流的仓库。

## 最佳实践

### 1. 语言最佳实践

#### 结论
- **first-party local skill**：正文中文为主，技术术语和 machine-facing 关键短语保留英文。
- **upstream community skill**：保持原文，不做整篇翻译。
- **不建议整篇双语并排写**。

#### 为什么

1. machine-facing metadata 与 human-facing body 的受众不同。
   - `description`、`short_description`、`default_prompt` 是给模型路由和平台 UI 用的。
   - 正文主体是给维护者、协作者和未来的自己看的。

2. 在中文团队里，正文中文更利于高密度约束表达。
   - 本仓库当前规范已明确 `description` 使用中文能力陈述 + `Use when ...` 英文锚点，见 [description-spec.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/references/description-spec.md)。
   - 这类“中文主体 + 英文触发锚点”的模式，本质是在兼顾团队阅读和模型路由。

3. upstream community 正文不应翻译。
   - `superpowers` 的 `brainstorming`、`writing-plans` 等正文不是简单提示词，而是方法论文档。
   - 翻译后会立刻带来 3 个问题：语义漂移、同步成本、证据链断裂。

4. 全文双语不是最佳实践。
   - token 成本直接翻倍。
   - 两套文字极易漂移。
   - 真正影响自动发现的不是整篇双语，而是 metadata 是否稳定、短、动作化。

#### 对本仓库的建议
- 保持现有策略：
  - first-party：中文正文 + 英文技术术语/触发短语
  - community：保留英文原文
- 如果后续要补中文说明，只补在：
  - `README`
  - `community-adapters/README.md`
  - RFC / 总览文档
- 不要在 upstream 正文里插入中文翻译段。

### 2. Skill 格式最佳实践

#### 结论
- **当前本地 `SKILL.md` 标准适合 first-party local skill，且整体上是好的工程实践。**
- **但它不是“所有 skill 的统一最佳格式”。**
- 更准确地说，它是：
  - `first-party local workflow skill` 的最佳实践
  - 不是 `upstream community skill` 的最佳实践

#### 为什么当前标准是合理的

本仓库当前标准有 4 个明显优点：

1. **路由字段明确**
   - `name + description + openai.yaml/manual-only` 这层机器契约很清楚。

2. **运行契约完整**
   - `HARD-GATE / 角色 / 流程 / 输出 / 完成校验` 让 skill 具备闭环能力，见 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)。

3. **token 预算有意识**
   - 标准把 `<=150 行`、详情拆到 `references/`、reference 一层深都写成了显式约束。
   - 这比把所有方法论堆进正文更适合 first-party skill 长期演化。

4. **双端适配被纳入设计**
   - Codex `openai.yaml`
   - Claude `disable-model-invocation`
   - manual-only 的运行时策略
   - 这些都已经被标准显式建模。

#### 为什么它不是统一最佳格式

因为 first-party 和 community 的目标不同。

1. first-party local skill 追求的是：
   - 运行时稳定
   - 跨端一致
   - 易维护
   - 易测试

2. upstream community skill 追求的是：
   - 方法论完整
   - 上下文自洽
   - 原义不失真
   - 能被原始作者持续演进

`superpowers/brainstorming` 的正文达到 164 行，而 `test-driven-development` 达到 371 行；本仓库本地 skill 多数在 79-136 行之间。  
这不代表 upstream 写得差，而是它承担的是“完整方法论文档”，不是“本地受控运行契约”。

#### 真正的最佳格式应该怎么定义

最佳实践不是“一种模板吃遍所有 skill”，而是分成 3 层：

1. **Layer A: Metadata**
   - `name`
   - `description`
   - `short_description`
   - `default_prompt`
   - `disable-model-invocation`
   - `openai.yaml`

2. **Layer B: Runtime Contract**
   - HARD-GATE
   - 关键流程
   - 输出/完成条件

3. **Layer C: Deep Methodology**
   - 长方法论
   - 例外说明
   - 丰富案例
   - 放在 `references/` 或 upstream snapshot

对于本仓库：
- first-party 适合把 Layer A + B 放进 `SKILL.md`，Layer C 放 `references/`
- community skill 适合保留 upstream 的 Layer B + C 原貌，本地只补 Layer A 的运行面适配

#### 对当前标准的判断
- **对 first-party local skill：是合适的，而且目前比“重写成 upstream 风格”更好。**
- **对整个仓库：还不是完整最佳实践，因为还缺一个“按 skill 类型分模板”的显式分轨标准。**

建议把标准正式拆成两轨：

1. first-party local skill standard
   - 继续沿用当前五段式
   - 强调 token 效率、机械校验、双端适配

2. community skill standard
   - 不重写正文
   - 只约束 adapter 边界
   - 只验证来源、同步、安装与暴露行为

### 3. superpowers 和 OpenSpec 的配合方式

#### 结论
- `superpowers` 管 **怎么改**
- `OpenSpec` 管 **改什么**
- 两者不是竞争关系，而是分层关系

#### 具体怎么配合

最容易理解的方式是按“对象层”和“行为层”分：

1. **OpenSpec = 对象层**
   - 管 change
   - 管 proposal/specs/design/tasks
   - 管 verify/archive
   - 目标是把“这次变更到底是什么”沉淀下来

2. **superpowers = 行为层**
   - 管 brainstorming
   - 管 writing-plans
   - 管 using-git-worktrees
   - 管 subagent-driven-development / executing-plans
   - 管 requesting-code-review / verification-before-completion
   - 目标是把“agent 应该如何有纪律地工作”约束住

#### 在本仓库里的实际协作链

当前仓库已经把它们串成这条默认链，见 [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)：

`brainstorming -> opsx:propose -> writing-plans -> using-git-worktrees -> opsx:apply -> (subagent-driven-development 默认 / executing-plans 备选) -> requesting-code-review -> verification-before-completion -> opsx:verify -> opsx:archive`

可以按下面方式理解：

1. `brainstorming`
   - 负责人机澄清、方案比较、设计收口
   - 这是 superpowers 的“设计对话层”

2. `opsx:propose`
   - 把澄清结果落进 OpenSpec change/workspace
   - 这是 OpenSpec 的“变更建模层”

3. `writing-plans`
   - 把已收口的设计和 change 变成可执行计划
   - 这是 superpowers 的“实施规划层”

4. `using-git-worktrees` + `opsx:apply` + 执行 skill
   - 进入实现
   - 这是 superpowers 的“执行纪律层”与 OpenSpec 的“change 落地层”交汇

5. `requesting-code-review` + `verification-before-completion` + `opsx:verify`
   - 前两者验证“实现过程和结果是否可信”
   - 后者验证“实现是否和 artifacts 一致”

6. `opsx:archive`
   - 把 change 正式归档回长期真源
   - 这是 OpenSpec 的“知识回收层”

#### 为什么你会觉得它们容易混

因为两边都提到了：
- spec
- design
- tasks
- verify

但它们语义不一样：

- `OpenSpec` 的 `design/tasks` 是 change artifact
- `superpowers` 的 `brainstorming/writing-plans` 是 agent workflow

一句话记忆：

- `OpenSpec` 在回答：**这次到底改什么**
- `superpowers` 在回答：**agent 应该怎么把它做对**

## 常见陷阱

| 陷阱 | 表现 | 规避方式 |
|------|------|---------|
| 把全文语言当成路由核心 | 纠结正文中文/英文，却不管 `description/openai.yaml` | 先区分 metadata 和 body |
| 强行统一模板 | 要求 upstream community skill 全部改写成本地五段式 | 采用双轨标准：first-party vs community |
| 翻译 upstream 正文 | 为了中文可读性直接改写 community skill | 保留 upstream 原文，在总览文档补中文说明 |
| 把 OpenSpec 当执行框架 | 认为 `opsx:*` 会替代 brainstorming/plan/review | 把 OpenSpec 视为 change/spec 层 |
| 把 superpowers 当 spec 真源 | 只跑流程，不落 proposal/spec/archive | 把 superpowers 视为 workflow/discipline 层 |

## 对我们的启示

1. 不要再追求“全仓库 skill 长得一模一样”。
2. 要追求的是：
   - machine-facing metadata 一致
   - source of truth 边界清晰
   - first-party 与 community 各用各的最佳形式
3. 当前仓库的方向是对的：
   - first-party 用本地标准
   - community 保持 upstream
   - adapter 只做薄适配
4. 当前标准还能再向前一步：
   - 把“first-party 标准”和“community 适配标准”拆成两份正式文档，不再只靠例外条款说明。

## 实践落地指南

1. **语言策略正式化**
   - first-party：中文正文 + 英文技术术语/触发锚点
   - community：保留 upstream 原文
   - 禁止整篇双语并排

2. **格式策略正式化**
   - first-party：继续沿用当前 `SKILL.md` 标准
   - community：只校验来源、adapter 边界、暴露策略，不重写正文

3. **职责边界正式化**
   - `OpenSpec`：change/spec/archive
   - `superpowers`：brainstorming/plan/execution/review/verification
   - 本地标准链：大需求强治理

4. **文档体系补强**
   - 补一份正式“skill authoring policy”
   - 明确三种资产：
     - first-party local skill
     - upstream community skill
     - adapter

## 证据索引

1. Anthropic Claude Code sub-agents 文档：强调 `name` 与 `description` 是关键 metadata，并建议 description 使用清晰、动作导向的说明。  
   https://docs.anthropic.com/en/docs/claude-code/sub-agents

2. Agent Skills open standard：强调 skill 的核心是 manifest + instructions，description 是路由和发现的重要组成。  
   https://agentskills.io/specification

3. superpowers 官方仓库：把 `brainstorming -> writing-plans -> subagent-driven-development -> review -> verification` 定义为核心工作流。  
   https://github.com/obra/superpowers

4. OpenSpec 官方 OPSX 文档：明确 `OpenSpec` 是 action-based 的 change/spec workflow，核心命令为 `propose/apply/archive` 等。  
   https://github.com/Fission-AI/OpenSpec/blob/main/docs/opsx.md

5. 本仓库 description 规范：`description` 采用 `{能力陈述}。Use when {场景}`，中文为主、技术术语英文保留。  
   [description-spec.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/references/description-spec.md)

6. 本仓库 skill 质量标准：定义 first-party local `SKILL.md` 的质量维度、token 约束与 dual-platform 适配规则。  
   [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)

7. 本仓库 community-first 默认链：明确 `brainstorming -> opsx:* -> writing-plans -> ... -> archive` 的分层协作方式。  
   [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)

8. 本仓库 community 适配边界：明确 adapter 只做 metadata、命令落位与安装映射，不改 upstream 正文。  
   [community-adapters/README.md](/Users/lijieli/org-claude-skills/community-adapters/README.md)
