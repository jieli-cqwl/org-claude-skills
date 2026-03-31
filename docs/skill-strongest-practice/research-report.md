# Skill 规范“最强实践”系统调研报告

## 1. 调研目标

- 回答核心问题：本仓库当前本地 skill 规范，是否已经接近“最强实践”？如果不是，差在哪里？
- 纠正一个容易混淆的前提：`Skill 规范`、`工作流规范`、`变更工件规范` 不是同一层的东西，不能混为一谈。
- 输出一套适配本仓库的升级方案，目标不是“更像某个上游”，而是“在本仓库上下文中达到更强的正确性、约束力、可维护性和跨平台适配能力”。

## 2. 项目上下文扫描

### 2.1 当前仓库的真实结构

本仓库当前不是单一 skill 仓库，而是一个多层运行体系：

1. `shared/`：first-party 真源，承载本地 rules / reference / skills / agents。
2. `third_party/community/`：community upstream 快照，承载 `superpowers` 与 `OpenSpec` 上游正文。
3. `community-adapters/`：薄适配层，只做平台 metadata、路径归一化、安装映射与命令落位。
4. `contracts/` + `tests/`：用合同和脚本测试约束运行面行为。

证据：
- [README.md](/Users/lijieli/org-claude-skills/README.md)
- [docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md)
- [community-adapters/README.md](/Users/lijieli/org-claude-skills/community-adapters/README.md)
- [docs/capability-matrix.md](/Users/lijieli/org-claude-skills/docs/capability-matrix.md)

### 2.2 当前本地 skill 规范在追求什么

本地 first-party skill 标准的重心不是“写出最像 upstream 的 `SKILL.md`”，而是：

- 机械可验收
- 任务闭环
- 双端适配（Claude / Codex）
- token 预算受控
- 运行面可治理

证据：
- [shared/skills/new-skills/references/description-spec.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/references/description-spec.md)
- [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)
- [tests/test-skill-output-and-gate-contract.sh](/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh)
- [tests/test-codex-skill-adapter.sh](/Users/lijieli/org-claude-skills/tests/test-codex-skill-adapter.sh)

### 2.3 当前判断的前置结论

当前仓库真正存在的不是“本地 skill 标准太弱”这么简单，而是三个对象被放进了同一个词里：

1. `技能发现规范`：模型如何知道何时该用一个 skill。
2. `运行时行为规范`：skill 一旦被调用，应该如何执行、何时停止、输出什么。
3. `流程/工件规范`：一次变更如何沉淀 proposal / design / tasks / verify / archive。

`superpowers`、`OpenSpec`、`AGENTS.md`、本地 `SKILL.md`，分别擅长的层不同。把这些层混为一谈，是当前质疑感最主要的来源。

## 3. 什么叫“最强实践”

本次调研采用 7 个评估维度来定义“最强实践”。只有同时兼顾这些维度，才配叫强实践；只在一个维度极强，不足以成为总体系最优。

| 维度 | 要回答的问题 | 为什么重要 |
| --- | --- | --- |
| 发现精度 | 模型能不能在该触发时触发、不该触发时不触发 | skill 先要被找到，后面才谈得上执行 |
| 上下文效率 | skill 是否以最小代价进入上下文 | skill 体系一多，context 预算会变成硬约束 |
| 运行约束力 | skill 一旦被加载，是否有明确门禁、步骤、输出和完成条件 | 这是行为一致性的核心 |
| 工程可维护性 | 规范是否能长期演化、同步、审计、分层维护 | “一时可用”不等于“长期强” |
| 跨平台可移植性 | 是否能在不同 agent/runtime 中稳定工作 | 本仓库天然是双端场景 |
| 证据与治理 | 能否验证 skill 真被正确执行，而不是“写得好看” | 没有证据链，就没有强治理 |
| 分层清晰度 | AGENTS / skill / hook / OpenSpec artifact 是否各司其职 | 分层不清会导致规范内耗 |

### 3.1 本次结论中的“最强实践”定义

对本仓库而言，“最强实践”不是“一种统一模板”，而是：

- 用开放标准保障 discoverability 与 portability
- 用 workflow contract 保障 execution discipline
- 用 artifact/state model 保障变更可追溯
- 用 tests/hooks/contracts 保障 enforceability
- 用明确分层避免把四类东西写进一份 `SKILL.md`

结论先行：**最强实践是“分层混合体系”，不是“把所有 skill 重写成某一种上游风格”。**

## 4. 外部一手资料拆解

## 4.1 Agent Skills open standard / 官方生态

### 它解决什么问题

它解决的是“skill 如何被不同 agent 发现、装载和复用”。重点是跨客户端的统一目录结构、metadata、渐进式装载和附属资源组织方式。

### 它怎么解决

OpenAI Codex 官方文档明确给出以下机制：

- skill 是一个目录，核心文件是 `SKILL.md`，可附带 `scripts/`、`references/`、`assets/`、`agents/openai.yaml`
- 启动时只读 metadata；真正命中后才加载全文
- 隐式触发主要依赖 `description`
- `description` 需要有明确边界，否则会过触发或漏触发

证据：
- OpenAI Codex 文档指出：Codex 使用 progressive disclosure，启动时只读取 `name`、`description`、文件路径和可选 `openai.yaml` metadata，命中后才读完整 `SKILL.md`；并要求 skill 聚焦单一职责、描述边界清晰。<https://developers.openai.com/codex/skills>
- OpenAI 官方 `openai/skills` 仓库把 skills 定义为“instructions + scripts + resources”的目录化能力包，并直接链接 OpenAI 文档与 Agent Skills open standard。<https://github.com/openai/skills>
- Anthropic 官方 `anthropics/skills` 仓库同样要求 skill 至少有 `name` + `description`，强调 skill 本质是最小 frontmatter + Markdown 指令体。<https://github.com/anthropics/skills>
- GitHub Copilot 官方文档也采用相同模型，并明确区分“skills vs custom instructions”：前者用于按需加载的详细任务指令，后者用于几乎每个任务都适用的全局仓库规则。<https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills>

### 它的边界

这个体系擅长的是：

- 发现与装载
- skill 打包方式
- 附属脚本/文档组织
- 跨客户端兼容

它**不直接定义**：

- 一个复杂 workflow 应该如何分阶段执行
- proposal / design / tasks / archive 的状态机
- 如何做组织级合同测试

### 对本仓库的启发

外部 open standard 里最值得吸收的，不是“把正文写得更像英文上游”，而是这三条：

1. **description 是一等公民**。触发正确率不是正文长短决定的，主要由 metadata 决定。
2. **progressive disclosure 必须围绕 skill 类型设计**。不是所有 skill 都应把大段方法论塞进 `SKILL.md`。
3. **scripts 需要 agent-friendly 设计**。官方建议脚本输出结构化、stdout/stderr 分离、幂等、支持 dry-run、错误信息可诊断。<https://agentskills.io/skill-creation/using-scripts>

## 4.2 superpowers

### 它解决什么问题

`superpowers` 解决的是“agent 如何按纪律完成软件开发工作”。它的核心价值不是 skill 文件格式，而是 workflow discipline。

### 它怎么解决

它通过一组强流程 skill 约束 agent：

- 先 `brainstorming`
- 再 `writing-plans`
- 再 `using-git-worktrees`
- 再 `subagent-driven-development` 或 `executing-plans`
- 中间插入 `requesting-code-review`
- 结束前走 `verification-before-completion`

证据：
- `superpowers` README 把自己的定位明确为完整的软件开发 workflow，强调从 brainstorming 到 code review / verification 的一整套 mandatory workflow。<https://github.com/obra/superpowers>

### 它的边界

`superpowers` 非常强，但它强在：

- 流程纪律
- 工作分解
- TDD / review / verification 方法论
- 自动 skill 检查的元规则

它不强在：

- 跨平台 metadata 细节标准化
- 组织级 artifact state machine
- 本地双端安装与适配治理
- 合同测试与安装器验证

### 对本仓库的启发

`superpowers` 应该被当成 **workflow methodology source**，不是全仓 skill 规范模板。盲目“照它重写本地 skill”，通常会把方法论层和运行契约层混在一起，造成：

- 上下文成本变高
- 与本地 outputs / completion checks 脱节
- 与 OpenSpec / local contracts 重叠

## 4.3 OpenSpec

### 它解决什么问题

`OpenSpec` 解决的是“如何把一次 AI 驱动的变更建模成可追踪、可归档、可验证的 spec-driven process”。

### 它怎么解决

OpenSpec 的核心不是 `SKILL.md`，而是：

- slash commands / prompts
- proposal / design / tasks / verify / archive 这类 artifact
- 面向 change 的工作台与状态推进

证据：
- OpenSpec README 将自己定义为 spec-driven development for AI coding assistants，并用 `/opsx:propose` 等命令驱动 proposal / design / tasks / verify / archive。<https://github.com/Fission-AI/OpenSpec>

### 它的边界

OpenSpec 本质上不是“通用 skill 格式标准”，而是“change/workspace/artifact/workflow 标准”。

因此它回答的是：

- 这次改什么
- 变更如何被分解和沉淀
- 工件如何组织和归档

它不直接回答：

- `description` 怎么写触发更准
- `SKILL.md` 多长合适
- 跨客户端 metadata 如何统一

### 对本仓库的启发

把 OpenSpec 当成“skill 规范对手”来比较，本身就有类别错误。更准确的关系是：

- `Agent Skills open standard` 解决 skill packaging / discovery
- `superpowers` 解决 how-to-work discipline
- `OpenSpec` 解决 change artifacts / state machine

## 4.4 GitHub Copilot / OpenAI Codex 官方区分

这是本次调研里最容易直接落地的一条：**官方都明确区分“始终适用的全局指令”和“按需加载的技能”。**

证据：
- GitHub Copilot 官方建议：简单且几乎每个任务都适用的规则，放 custom instructions；只有在特定任务 relevant 时才需要的详细指令，放 skills。<https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills>
- OpenAI Codex 官方则通过 `AGENTS.md` 构建 always-on 指令链，通过 skills 解决按需能力包。<https://developers.openai.com/codex/guides/agents-md> 与 <https://developers.openai.com/codex/skills>

对本仓库的直接含义是：

- `shared/assistant.md`、`rules/`、一部分长期规则，应该属于 always-on
- `product/design/review/developer` 这类应属于 on-demand workflow skills
- `opsx:*` 更像 stateful process commands，不应硬纳入同一 skill 模板标准

## 5. 对本地规范的系统判断

## 5.1 哪些顾虑是成立的

### 顾虑 A：当前“Skill质量标准”被说成了通用标准，但其实只适合部分 skill

这个顾虑成立，而且是当前最核心的问题。

当前 [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 的很多规则，本质上只适合：

- first-party
- manual-only 或强流程型
- 需要明确输出工件和完成校验的 workflow skill

它**不适合作为以下对象的统一标准**：

- upstream community snapshot
- auto-trigger 的轻量工具 skill
- OpenSpec `opsx:*` 这类命令式状态机
- 纯 adapter metadata

换句话说：**不是标准太弱，而是标准命名过宽、作用域定义不够精确。**

### 顾虑 B：当前规范在“发现精度”上的投入不够系统

这个顾虑成立。

本地规范已经对 `description` 做了格式要求，这是正确方向；但外部官方标准更进一步，明确要求：

- 用 `description` 作为 primary trigger mechanism
- 用 query/eval 持续测试 trigger accuracy
- 避免 under-specified / over-broad 描述

证据：
- Agent Skills 官方文档明确指出：`description` 是 skill 触发的 primary mechanism，描述过窄会漏触发，过宽会误触发。<https://agentskills.io/skill-creation/optimizing-descriptions>

而本仓库目前的强项是：

- description 写法规范
- Codex `openai.yaml` / manual-only 策略

目前相对缺的是：

- 正负样本 prompt 集
- 触发准确率评估
- auto / manual-only 的量化准入规则

### 顾虑 C：当前规范把平台差异写进了 canonical 标准里

这个顾虑部分成立。

当前标准已经很注意把 platform adapter 放到 `community-adapters/`；但在 first-party standard 中，仍然能看到不少 runtime-specific 约束直接进入共享标准，例如：

- `disable-model-invocation`
- `agents/openai.yaml`
- Codex runtime note
- Claude hooks 语义

这不代表做错了，但说明 **canonical spec 与 runtime adapter 还可以再分干净一层**。

### 顾虑 D：当前规范是不是比 upstream 差很多

这个顾虑不成立，至少不能笼统成立。

如果比较的是：

- 发现标准化
- 目录结构 portability

外部 open standard 更成熟。

但如果比较的是：

- 运行契约
- completion evidence
- 双端安装治理
- contract tests
- manual-only 暴露策略

本地体系其实比纯 upstream 更强，甚至明显更强。

## 5.2 哪些地方本地反而是优势

### 优势 A：本地有真实的治理闭环

外部很多 skill 体系解决的是“怎么写一个 skill”；本地已经在解决“怎么保证 skill 真能长期可用”。

本地优势体现在：

- 安装器
- runtime capability matrix
- adapter-specific 测试
- contract-based completion checks
- source-of-truth layering

这一层在大量社区 skill 仓库里并不常见。

### 优势 B：本地把“workflow skill”做成了可审计 contract

`product/design/tech-lead/project-manager/developer/review/verify` 这些 skill 已经不是普通提示词，而是接近“可检查的运行合同”。

这是一个强点，不应因为“看起来没 upstream 那么简洁”而被误判为落后。

### 优势 C：本地已经隐含采用了正确的分层方向

从 `shared/assistant.md`、`community-first` 文档、`third_party/community`、`community-adapters` 的组合看，本地其实已经走在正确方向上：

- 把 upstream 语义保留成 source of truth
- 把本地运行面控制放进 adapter 和 contracts
- 把组织规则放进 assistant / rules

现在真正缺的是：**把这套分层正式写成规范，而不是继续让它隐含存在。**

## 6. 结论：什么才是本仓库的“最强实践”

## 6.1 最强实践不是单模板，而是五层模型

建议正式把本仓库的规范定义为五层，而不是继续让一个“Skill质量标准”同时试图解释所有对象。

### Layer 0: Always-on 指令层

承载对象：

- `AGENTS.md` / `assistant.md`
- `rules/`
- 极少数始终适用的 org 约束

职责：

- 定义长期行为边界
- 约束语言、协作方式、风险红线
- 不承载具体 task workflow

### Layer 1: Skill Discovery 层

承载对象：

- `name`
- `description`
- `short_description`
- `default_prompt`
- `allow_implicit_invocation`
- `disable-model-invocation`
- `agents/openai.yaml`

职责：

- 决定 skill 能否被找到
- 决定 auto / manual-only 策略
- 决定客户端暴露面

规范重点：

- 描述边界清晰
- 单 skill 单职责
- 必须可评估触发准确率

### Layer 2: Runtime Contract 层

承载对象：

- HARD-GATE
- 核心流程
- 输出定义
- 完成校验
- Stop/completion checks

职责：

- 让 skill 一旦被激活，就按一致方式运行
- 保障审计性与机械判定

规范重点：

- 只给 workflow-critical skill 使用强闭环模板
- 不要求所有 skill 都套五段式

### Layer 3: Methodology / Resources 层

承载对象：

- `references/`
- `scripts/`
- `assets/`
- templates

职责：

- 承载长方法论、脚本和示例
- 降低主 `SKILL.md` 负担

规范重点：

- progressive disclosure
- 结构化输出
- 脚本幂等 / dry-run / stderr 分离 / 明确 exit code

### Layer 4: Process / Artifact 层

承载对象：

- `OpenSpec`
- `opsx:*`
- proposal / design / tasks / verify / archive

职责：

- 管这次变更的状态与工件
- 不与 skill discovery 混用

### Layer 5: Governance / Evidence 层

承载对象：

- contract tests
- install-time checks
- runtime validation
- capability matrix
- trigger evals

职责：

- 把规范从“文档”变成“可验证系统”

## 6.2 对 skill 分类，才是当前规范应升级的主线

建议将本仓库 skill 明确分成 4 类，并分别定义模板，而不是一套标准覆盖全部。

| 类型 | 典型对象 | 触发策略 | 推荐规范 |
| --- | --- | --- | --- |
| A. Auto-discover capability skill | 轻量工具 skill、窄任务 skill | implicit 优先 | 强 metadata + 短正文 + eval cases |
| B. Manual workflow skill | `product/design/review/developer/verify` | manual-only 或显式入口 | 强 runtime contract + outputs + completion check |
| C. Community upstream skill | `superpowers` upstream 正文 | 保留 upstream 规则 | 不重写正文，只做 adapter |
| D. Stateful process command | `opsx:*` / OpenSpec | command-driven | 不纳入通用 skill 质量模板 |

这是本次调研最关键的建议。只要这个分类落下来，很多当前“看起来不统一”的地方会自动变得合理。

## 7. 对本仓库的可执行升级建议

## 7.1 P0：必须做

### 1. 把“Skill质量标准”重命名并拆轨

建议：

- 现有 [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 重命名为：`First-Party Workflow Skill 标准`
- 新增：
  - `Auto Skill 标准`
  - `Community Adapter 标准`
  - `Process Command（OpenSpec）边界说明`

目标：先解决“标准命名过宽”的根问题。

### 2. 新增“技能发现评估”体系

建议新增：

- 每个 auto skill 维护 `evals/activation-cases.yaml`
- 至少包含：
  - 应触发 query
  - 不应触发 query
  - 边界 query
- 把 description accuracy 纳入 CI 或至少本地测试命令

目标：补上当前最明显的缺口，让 `description` 从“格式正确”升级为“触发准确”。

### 3. 明确 `AGENTS / rules / skills / hooks / opsx` 的职责决策表

建议新增文档：

- `shared/reference/instruction-layering.md`

内容至少回答：

- 什么放 `AGENTS.md`
- 什么放 `rules/`
- 什么做 skill
- 什么必须做 hook / script / test
- 什么属于 OpenSpec artifact/process

目标：减少“同一条规则到底放哪”的持续摩擦。

### 4. 为 manual-only / auto 暴露建立准入规则

建议明确：

- 只有满足高触发精度、低副作用、窄职责的 skill，才允许 implicit
- 强流程、大副作用、强共创、强人工确认 skill 默认 manual-only

目标：把当前经验判断变成明确治理标准。

## 7.2 P1：应该做

### 5. 把脚本接口规范化

建议对 `scripts/` 补统一规则：

- stdout 输出结构化数据
- stderr 输出诊断信息
- 幂等优先
- 支持 `--help`
- 高风险操作支持 `--dry-run`
- exit code 语义化

这是外部 open standard 中最值得吸收且最容易落地的一条。<https://agentskills.io/skill-creation/using-scripts>

### 6. 把行数限制从“统一上限”调整成“按类型预算”

当前 `<=150 行` 对 workflow skill 合理，但不应硬套全部 skill。

建议：

- A 类 auto skill：目标 `<80` 行
- B 类 workflow skill：目标 `80-200` 行，以 contract 完整为先
- C 类 upstream：不按本地行数约束
- D 类 process command：独立规范，不走此约束

目标：避免把“token 效率”变成机械主义。

### 7. 将 runtime-specific 注释进一步外移

建议：

- 保留共享 canonical 内容
- 平台差异尽量通过 adapter、安装生成、runtime note 注入
- 减少在共享 first-party `SKILL.md` 中直接出现过多平台实现噪音

## 7.3 P2：可选增强

### 8. 为关键 skill 增加 evaluation cases 与反模式库

L3 标准里已经提到 evaluation case，但当前还没有形成普遍落地。建议先从：

- `product`
- `design`
- `developer`
- `review`
- `verify`

这 5 个关键 skill 开始。

### 9. 为 upstream snapshot 增加更显式的版本锚点

README 已声明“冻结到明确 commit”，但建议把 commit pin 与最近同步时间显式落到清单或 manifest，降低长期认知成本。

## 8. 最终结论

### 8.1 一句话判断

**你当前的质疑是对的，但问题不在“本地 skill 规范整体不如 superpowers / OpenSpec / 官方”，而在于当前规范缺少“按层、按类型”显式建模。**

### 8.2 更精确的判断

- 如果问“当前本地 workflow skill contract 是否弱”——不是，反而偏强。
- 如果问“当前标准是否能作为所有 skill / command / adapter 的统一最佳实践”——不能。
- 如果问“真正的最强实践是什么”——是 `开放技能标准 + workflow contract + artifact state machine + governance tests` 的分层混合体系。

### 8.3 对本仓库的推荐路线

不建议做的事：

- 把 first-party 全部重写成 superpowers 风格
- 把 OpenSpec 当成通用 skill 模板
- 把 upstream 正文翻译后塞进本地模板
- 继续用一份“Skill质量标准”覆盖 skill / adapter / command / upstream snapshot 全部对象

建议做的事：

1. 保留当前四层结构方向：`shared` / `third_party` / `community-adapters` / `contracts`
2. 把 first-party workflow skill 标准正式限定作用域
3. 增加 auto-skill 的 activation eval 体系
4. 新建分层职责决策表
5. 明确 skill taxonomy 与不同模板

## 9. 可执行结论摘要

| 结论 | 判断 |
| --- | --- |
| 当前本地规范是不是一无是处 | 否 |
| 当前本地规范是不是“统一最强模板” | 否 |
| 是否应全面回退到 upstream 风格 | 否 |
| 是否应保留本地 workflow contract 能力 | 是 |
| 当前最该补的短板是不是 trigger eval 与分层建模 | 是 |
| 最强实践是不是分层混合体系 | 是 |

## 10. 关键来源

### 外部一手来源

- OpenAI Codex Skills: <https://developers.openai.com/codex/skills>
- OpenAI Codex AGENTS.md: <https://developers.openai.com/codex/guides/agents-md>
- OpenAI Skills Catalog: <https://github.com/openai/skills>
- Anthropic Skills Repository: <https://github.com/anthropics/skills>
- Agent Skills Best Practices / Description / Scripts:
  - <https://agentskills.io/skill-creation/best-practices>
  - <https://agentskills.io/skill-creation/optimizing-descriptions>
  - <https://agentskills.io/skill-creation/using-scripts>
- GitHub Copilot Agent Skills: <https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills>
- Superpowers: <https://github.com/obra/superpowers>
- OpenSpec: <https://github.com/Fission-AI/OpenSpec>

### 本仓库内部证据

- [README.md](/Users/lijieli/org-claude-skills/README.md)
- [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- [docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md)
- [shared/skills/new-skills/references/description-spec.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/references/description-spec.md)
- [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)
- [tests/test-skill-output-and-gate-contract.sh](/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh)
- [tests/test-codex-skill-adapter.sh](/Users/lijieli/org-claude-skills/tests/test-codex-skill-adapter.sh)

## 11. 细节补充一：`graph TD` vs `digraph brainstorming`

### 11.1 这不是单纯的“哪个好看”，而是两套 DSL

这两个写法不属于同一语法体系：

- `graph TD` 属于 Mermaid flowchart 语法
- `digraph brainstorming { ... }` 属于 Graphviz DOT 语法

证据：

- Mermaid 官方文档把 flowchart 定义为 `flowchart TD` / `graph TD`，其中 `graph` 只是 `flowchart` 的别名；`TD/TB/LR/...` 负责方向声明。<https://mermaid.js.org/syntax/flowchart.html>
- Graphviz 官方 DOT 语法规定图必须声明为 `graph` 或 `digraph`；`digraph` 代表有向图，边操作符必须用 `->`。<https://graphviz.org/doc/info/lang.html>

所以这不是“同一种图语言里的两个写法”，而是：

- 一个是 Mermaid Markdown-native 图
- 一个是 Graphviz DOT 图

### 11.2 对本仓库的最佳实践判断

结合本仓库现状，最佳实践不是继续混用，而是按运行面分轨：

1. **first-party 本地 skill / template / docs 默认统一用 Mermaid**
   - 原因：当前本地文档实际使用的是 fenced `mermaid` block，而不是 `dot` block。
   - 证据：`product/design/project-manager/overview` 等 first-party 文档都在用 Mermaid。

2. **community upstream 保持上游原样**
   - `superpowers` 上游当前使用的是 fenced `dot` + `digraph ...`。
   - 对 upstream snapshot 不应做本地语义改写。

3. **在 Mermaid 内部，推荐从 `graph TD` 统一升级为 `flowchart TD`**
   - Mermaid 官方明确说 `graph` 可以作为 `flowchart` 的别名，这说明 `graph TD` 是合法的，但不是最显式的写法。
   - 从“最强实践”角度，`flowchart TD` 比 `graph TD` 更好，原因是：
     - 语义更显式，读者一眼知道这是 flowchart，不是泛指 graph
     - 避免和 Graphviz 的 `graph/digraph` 产生心智混淆
     - 更利于仓库内 grep / lint / 风格统一

### 11.3 精确结论

如果问题是：

- “在 Mermaid block 里，`graph TD` 和 `digraph brainstorming` 哪个更好？”  
  结论：**`digraph brainstorming` 不该出现在 Mermaid block 里。**

- “在本仓库 first-party 文档里，`graph TD` 和 `digraph brainstorming` 哪个更符合最佳实践？”  
  结论：**`graph TD` 更接近当前正确方向，但若追求最强实践，应进一步统一为 `flowchart TD`。**

- “在 Graphviz / DOT 环境里呢？”  
  结论：**`digraph ...` 才是正确语法。**

### 11.4 建议新增的图语法规范

建议在规范里显式写成：

- first-party Markdown 文档中的流程图默认使用 fenced `mermaid`
- Mermaid flowchart 统一使用 `flowchart TD`
- Graphviz DOT 仅用于：
  - upstream snapshot 保留原文
  - 确实需要 DOT 特性（如 `cluster`、更细粒度 rank/layout 控制）的少数场景
- 同一类文档中禁止混用 Mermaid flowchart 与 DOT 作为默认流程图表达

## 12. 细节补充二：`## 输出` 与模板章节重复声明

### 12.1 当前问题是什么

以 `test-design` 为例，当前写法同时做了两件事：

1. 在 `## 输出` 中声明模板路径：
   - `模板详见 references/templates/test-cases-template.md`
2. 又在同一节里重复列出模板中的章节标题：
   - `## 用例统计`
   - `## UNIT 覆盖视图`
   - `## AC 覆盖矩阵`
   - `## 等价性对照矩阵`
   - `## Design 问题报告`
   - `## 测试用例`
   - `## 专项测试触发依据与展开策略`
   - `## 审查结论`

这会形成两个问题：

1. **source of truth 重复**
   - 模板已经定义了章节结构，`SKILL.md` 再重复一遍，就形成了双真源。
2. **维护漂移风险**
   - 以后模板改了章节，`SKILL.md` 的这串清单很容易漏改。

### 12.2 外部最佳实践怎么说

Agent Skills open standard 的最佳实践非常明确：

- 大 skill 应该依赖 progressive disclosure
- 详细参考材料应移到 `references/`
- 当需要输出特定格式时，短模板可以 inline，长模板应放到 `assets/` / `references/`，由 `SKILL.md` 告诉 agent 何时加载

证据：

- Agent Skills best practices 明确建议：长内容移到 `references/`，`SKILL.md` 保留核心指令，并告诉 agent 何时去读哪个文件。<https://agentskills.io/skill-creation/best-practices>
- Agent Skills 规范明确把 templates / assets / references 视为按需加载资源，并强调 progressive disclosure。<https://agentskills.io/specification>

通用文档写作规范也支持这一方向：

- Google 文档风格指南要求 heading 必须有清晰职责，不要做空 heading 或层级重复，若要引出下一层内容，应先用一小段说明连接。<https://developers.google.com/style/headings>
- Microsoft 风格指南明确指出：避免两个 heading 连在一起没有内容，这通常说明组织有问题或 heading 冗余。<https://learn.microsoft.com/fr-fr/style-guide/scannable-content/headings>
- Divio 对 reference 文档的要求是：结构一致、只描述、不要把 how-to 和 reference 混在一起。<https://docs.divio.com/documentation-system/reference/>

### 12.3 对本仓库的最佳实践判断

这里真正需要的不是“删掉所有 `## 输出`”，而是**重新划清 authority boundary**。

最强实践应该是：

1. **`SKILL.md -> ## 输出` 负责：**
   - 输出哪些 artifact
   - artifact 路径在哪里
   - authoritative template 是哪个文件
   - 哪些是条件规则 / 例外规则 / 交付约束

2. **`references/templates/*.md` 负责：**
   - 章节结构
   - 字段顺序
   - 占位格式
   - 示例内容

3. **`completion_check.sh` / tests 负责：**
   - 哪些 section 必填
   - 哪些条件字段必须出现
   - 哪些枚举值或格式必须通过

### 12.4 哪些重复是坏重复，哪些不是

**坏重复：**

- 模板已经完整定义了章节清单，`## 输出` 再原样枚举一遍
- 模板已经给出字段和顺序，`SKILL.md` 再复制相同结构

**好重复：**

- `SKILL.md` 只强调模板里不容易被忽略的条件规则
- `SKILL.md` 补充“何时必须读模板”“什么条件下必须包含某节”“WARN/FAIL 承接到哪里”

例如，下面这些信息继续留在 `SKILL.md` 是合理的：

- 当 `专项测试` 数量 > 0 时，必须填写 `专项测试触发依据与展开策略`
- `WARN` 必须承接到 `审查结论`
- 设计缺口为空时，`Design 问题报告` 必须明确写“无设计缺口”

但章节总表本身，应该只在模板里维护。

### 12.5 对 `test-design` 的精确建议

`test-design/SKILL.md` 的 `## 输出` 最佳实践写法应收缩为：

- 输出路径：`{work_dir}/test-cases.md`
- 权威模板：`references/templates/test-cases-template.md`
- 条件规则：
  - 若专项测试计数 > 0，必须填写 `专项测试触发依据与展开策略`
  - 无设计缺口时，`Design 问题报告` 明确写“无设计缺口”
  - WARN 在 `审查结论` 中承接
- 跨职能审查输出：`testdesign-cross-review.md`

而不应再把模板的整套章节名逐条复述。

### 12.6 应升级成通用规范的一条规则

建议新增一条统一规则：

> **单一真源原则：文档结构只在模板中维护；`SKILL.md` 只声明 artifact、模板入口和不能从模板静态结构中直接推导出的条件约束。**

这样做的收益是：

- 减少双真源
- 降低模板演进成本
- 让 `SKILL.md` 更短，更符合 progressive disclosure
- 让 template / contract / skill 三层职责更清晰

## 13. 与前次结论的统一收口

这次补充的两个细节问题，实际上都证明了上一次的核心结论：

1. `graph TD` vs `digraph ...` 的问题，本质是 **图 DSL 与运行面的分层问题**
2. `## 输出` 与模板章节重复的问题，本质是 **artifact schema authority 的分层问题**

所以你最初的直觉是对的：当前规范不是“单点写得不优雅”，而是**若干层的 authority boundary 还没有被显式写成规范**。

把这些细节统一起来后，本仓库更完整的“最强实践”可以收敛成三条：

1. **一层一职责**
   - AGENTS / rules / skills / templates / hooks / opsx 不混权
2. **一类一模板**
   - workflow skill、auto skill、community adapter、process command 分开建模
3. **一处一真源**
   - 图 DSL 有默认规范
   - 文档结构只在模板维护
   - 条件规则与机械校验分开落位

## 14. “更强” 的二维定义：内容强度 x 结构治理

你提出的理解很接近核心：`最少的上下文解决更多的问题，LLM 理解更准确，责任划分清晰`。  
如果把它提升成可操作的客观标准，建议正式拆成两个维度，而不是继续混成一个“好不好”的总体感觉。

### 14.1 维度一：内容强度（Content Strength）

这个维度回答的是：

> **同样的上下文预算下，这份内容能不能让模型更容易选对、读对、做对。**

它关注的是内容本身的质量，而不是内容放在什么文件里。

#### 内容强度的 5 个子指标

1. **信息密度**
   - 单位 token 传达的有效约束是否足够多
   - 是否存在空话、同义复述、装饰性内容、无动作价值的说明

2. **歧义控制**
   - 指令、边界、输出格式、触发条件是否低歧义
   - 模型是否容易把说明、例子、例外、上下文混淆

3. **路由可判定性**
   - 模型是否容易判断“这时该不该调用这个 skill / 规则 / 模板”
   - `description` 是否清楚说明该触发和不该触发的边界

4. **执行稳定性**
   - 同类任务下，模型执行路径是否收敛
   - 是否需要模型大量自主补全隐含规则

5. **上下文效率**
   - 是否通过 progressive disclosure 把“默认必读”和“按需再读”分开
   - 是否避免把长参考、长模板、长方法论全部塞进主上下文

#### 外部证据

- OpenAI 官方将 prompt 视为可版本化、可评估、可复用的中心对象，并明确建议：
  - 总体角色指导放 system message
  - task-specific 细节和 examples 放 user messages
  - few-shot 示例整理成易扫描的 YAML / bullet block
  - 每次发布都重新跑 eval  
  这说明“更强”不是单纯更长，而是更容易扫描、复用和验证。<https://developers.openai.com/api/docs/guides/prompting>

- Anthropic 官方明确指出：
  - 在混合 instructions / context / examples / variable inputs 时，用 XML tags 分隔可以减少误解
  - 对复杂多阶段任务，应在需要时显式 chaining，而不是把一切塞进一个 prompt  
  这说明“更强”强调的是结构化内容带来的理解准确率，而不是堆更多字。<https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices>

- Agent Skills open standard 将 progressive disclosure 作为核心原则，明确区分：
  - 启动时只读 metadata
  - 激活后再读 `SKILL.md`
  - 需要时再读 `references/assets/scripts`  
  这直接支持“最少上下文解决更多问题”的目标。<https://agentskills.io/specification>

#### 结论

所以，“内容更强”不是：

- 更长
- 更严厉
- 更像 checklist 堆砌

而是：

> **高信息密度、低歧义、易路由、易执行、按需加载。**

### 14.2 维度二：结构治理（Structural Governance）

这个维度回答的是：

> **这些内容是否被放在正确的位置，并且未来不会因为重复定义而漂移。**

它关注的是 authority boundary，而不是具体文案写得漂不漂亮。

#### 结构治理的 5 个子指标

1. **职责边界清晰**
   - `AGENTS.md`、`rules/`、`skills/`、`templates/`、`hooks/`、`opsx` 是否各司其职

2. **单一真源**
   - 同一规则、同一结构、同一字段要求，是否只在一个地方 authoritative

3. **层级正确**
   - always-on 指令、按需 skill、artifact schema、机械校验是否分层

4. **局部可演进**
   - 改一个模板，是否不需要同步改 3 份文档
   - 改一个 skill 的输出结构，是否不会破坏 unrelated 规则

5. **可验证性**
   - 结构是否可通过 grep / tests / completion_check / contracts 客观验证

#### 外部证据

- GitHub Copilot 官方明确区分：
  - custom instructions 用于几乎所有任务都相关的简单规则
  - skills 用于只有在相关时才加载的详细任务说明  
  这说明“更强”需要把 always-on guidance 和 on-demand workflows 分开。<https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills>

- GitHub Copilot 官方还明确警告：
  - 如果 path-specific instructions 与 repository-wide instructions 冲突，模型对冲突指令的选择是 non-deterministic  
  这说明重复 authority 会直接损害确定性，不是“文档洁癖问题”。<https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions>

- OpenAI Codex 官方说明：
  - `AGENTS.md` 是按目录链合并的
  - 越靠近当前目录的文件优先级越高
  - 总字节数有上限，超出需要拆分或分层  
  这说明结构治理直接影响上下文预算和优先级正确性。<https://developers.openai.com/codex/guides/agents-md>

- OpenAI Prompting 官方文档强调：
  - 中心化 prompt 对象、版本管理、eval、clear folder names  
  这其实就是“单一真源 + 可演进 + 可验证”的结构治理实践。<https://developers.openai.com/api/docs/guides/prompting>

- Divio 文档体系强调：
  - reference 只做描述
  - how-to 不要和 reference 混写  
  这正是结构分层的通用原则。<https://docs.divio.com/documentation-system/reference/>

#### 结论

所以，“结构更强”不是：

- 目录更多
- 文件更碎
- 看起来更整齐

而是：

> **边界清晰、单一真源、分层正确、演进成本低、可以机械验证。**

## 15. 二维模型下的正式定义

基于上面两个维度，可以把“更强”正式定义为：

> **在不损失理解准确率与边界清晰度的前提下，用最小必要上下文，让模型更稳定地产生正确结果，并让这套规则体系更易维护、验证和演进。**

换句话说：

- `最少上下文` 不是绝对目标
- `理解更准确` 是第一目标
- `责任更清晰` 是系统级保障
- `上下文更少` 必须建立在前两者不受损的前提上

这也意味着一个常见误区需要被排除：

> **更短 ≠ 更强。**

如果压缩导致：

- 路由边界变模糊
- 条件规则丢失
- 模板 authority 不清
- completion 校验失效

那只是“更短”，不是“更强”。

## 16. 二维模型的评估表

后续评估任意一份 `SKILL.md`、模板、规则或流程文档时，可以直接用下面这张表。

| 维度 | 评估问题 | 强的表现 | 弱的表现 |
| --- | --- | --- | --- |
| 内容强度 / 信息密度 | 同样长度是否传递更多有效约束 | 少废话，约束可执行 | 大量解释性废话 |
| 内容强度 / 歧义控制 | 模型是否容易误解边界 | 触发边界清晰，条件明确 | 例子、规则、例外混在一起 |
| 内容强度 / 路由可判定性 | 模型是否知道何时用它 | `description` 边界明确 | 描述宽泛或泛能力化 |
| 内容强度 / 执行稳定性 | 模型是否稳定收敛到同一路径 | 有门禁、步骤、输出 | 靠模型自由发挥 |
| 内容强度 / 上下文效率 | 是否按需加载 | 主体短，细节外移 | 模板、参考、长说明都塞主文 |
| 结构治理 / 职责边界 | 内容是否放在正确层级 | AGENTS/rules/skill/template 各司其职 | 混权 |
| 结构治理 / 单一真源 | 同一结构是否只定义一次 | 模板定义结构，skill 定义规则 | 多处复述同一结构 |
| 结构治理 / 层级正确 | always-on 与 on-demand 是否分开 | 全局规则和局部工作流分离 | 统一塞进一份 skill |
| 结构治理 / 局部演进 | 改一处是否少连锁修改 | 局部可改 | 改模板要改 skill/测试/说明多处 |
| 结构治理 / 可验证性 | 是否能客观验证 | 有 tests/checks/evals | 靠人工感觉 |

## 17. 映射回本仓库的判断

在这个二维框架下，本仓库的现状可以更客观地描述为：

### 17.1 内容强度层

强项：

- first-party workflow skills 的执行约束很强
- `description` 已有统一格式
- 关键 skill 有明确 outputs 和 completion checks

弱项：

- 一些 `SKILL.md` 存在“模板路径 + 模板章节总表”双写，拉低信息密度
- 一些图语法和表达方式没有统一，增加理解噪音
- 目前缺少 activation eval，导致“路由准确率”还没有被实证化

### 17.2 结构治理层

强项：

- 已经有 `shared / third_party / community-adapters / contracts` 四层结构
- 已经有 manual-only / auto 暴露策略
- 已经有 contract tests 和 completion_check

弱项：

- `Skill质量标准` 的作用域还过宽
- `workflow skill`、`auto skill`、`community upstream`、`process command` 还没有正式分轨
- authority boundary 还没有写成仓库级通用规则

## 18. 对“最强实践”的最终补充定义

如果只保留一句最实用的话，我建议定义成：

> **最强实践 = 高信息密度 + 低歧义 + 单一真源 + 按需加载 + 可机械验证。**

如果保留一组优先级，我建议是：

1. **理解准确**
2. **责任清晰**
3. **上下文最小化**
4. **演进可控**
5. **验证客观**

这组优先级比单纯说“简洁”更准确，也更适合拿来审查本仓库后续的规范升级。

## 19. Claude Code 官方 Skill 体系：到底好在哪里

本节聚焦 Anthropic / Claude Code 官方 skill 体系本身，而不是泛指 Agent Skills open standard。

## 19.1 官方定义与创建方式

Claude Code 官方把 skill 定义成：

- 一个带 `SKILL.md` 的目录
- 可附带 supporting files、scripts、examples、reference docs
- 既可以自动触发，也可以 `/skill-name` 显式触发
- 可按用户级、项目级、插件级共享

证据：

- Claude Code 文档明确说明：创建一个 `SKILL.md` 文件后，Claude 会把 skill 加入自己的 toolkit，并在相关时自动使用，也可以显式通过 `/skill-name` 调用。<https://code.claude.com/docs/en/skills>
- Claude Code 文档给出技能存放层级：`~/.claude/skills/`、`.claude/skills/`、插件目录；并支持 nested discovery。<https://code.claude.com/docs/en/skills>
- Anthropic Help Center 说明：skills 是“instructions + scripts + resources”的目录化能力包，Claude 会动态加载它们以提升 specialized tasks 的表现。<https://support.claude.com/en/articles/12512176-what-are-skills>

## 19.2 它“好”的核心，不是格式，而是 5 个机制同时成立

### 机制 A：文件系统原生 + 分层共享

Claude Code 的 skill 不是塞进一个全局 UI 文本框，而是原生目录资产：

- 个人级：`~/.claude/skills/`
- 项目级：`.claude/skills/`
- 插件级：`<plugin>/skills/...`
- 子目录自动发现

为什么这很强：

- 直接进入版本控制与代码审查流
- 支持 monorepo 局部 skill
- 技能和代码、模板、脚本能天然共址
- 团队共享、个人覆盖、插件分发三种模型都成立

最强支持证据：

- Claude Code 文档不仅给出多级目录，还支持 nested `.claude/skills/` 自动发现，这说明它不是“能存文件”而已，而是把 skill 当成 repo-native 资产。<https://code.claude.com/docs/en/skills>

最强反方挑战：

- 文件系统原生也带来分散管理问题，尤其跨平台不自动同步。

失效边界：

- 如果团队没有版本控制、代码审查和目录规范，这个优势会大幅下降。

当前判断：

- **成立。** 这是 Claude Code 相比很多“上传一段 prompt”的实现更强的地方。

### 机制 B：渐进加载做到了产品级，而不是概念级

Claude Code / Anthropic 官方 skill 体系把 progressive disclosure 做成了真实机制：

- 启动时只读 metadata
- 相关时才读完整 `SKILL.md`
- 细节文件按需再读
- 脚本执行时只消耗输出，不必把脚本全文塞进上下文

为什么这很强：

- 直接提升上下文效率
- 让大量 skills 共存仍可管理
- 让 skill 可以既强大又不默认污染主上下文

最强支持证据：

- Agent Skills quickstart 明确说明：Claude 启动时加载的是每个 skill 的 metadata，这是 progressive disclosure 第一层；相关时再加载完整技能说明。<https://platform.claude.com/docs/en/agents-and-tools/agent-skills/quickstart>
- Claude Code 文档明确要求：`SKILL.md` 保持聚焦，supporting files 放到外部按需加载；脚本是 executed, not loaded。<https://code.claude.com/docs/en/skills>
- Anthropic best practices 进一步要求：`SKILL.md` under 500 lines，详细参考外移。<https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>

最强反方挑战：

- 渐进加载只有在 metadata、导航和引用写得足够好时才成立；否则 Claude 可能找不到或不去读关键文件。

失效边界：

- 如果 supporting files 没有被清晰引用，或者结构信号弱，渐进加载会退化成“内容明明存在，但模型没用到”。

当前判断：

- **成立，而且这是官方体系最值得吸收的核心优势之一。**

### 机制 C：调用权和副作用边界被显式建模

Claude Code 官方 skill 不是只有 `name/description`，还把“谁可以触发、触发后可用什么工具、是否在隔离上下文中跑”做成 frontmatter：

- `disable-model-invocation`
- `user-invocable`
- `allowed-tools`
- `context: fork`
- `agent`
- `paths`

为什么这很强：

- 自动触发和手动触发的边界清晰
- 带副作用的动作可以强制人工显式触发
- 只读/只查/只修的 skill 可以限制工具权限
- 技能可以按文件路径范围自动启用，减少全局噪音

最强支持证据：

- Claude Code 文档明确说明：
  - `disable-model-invocation: true` 用于 `/commit`、`/deploy` 这类不希望 Claude 自己决定时机的技能
  - `user-invocable: false` 用于 background knowledge
  - `allowed-tools` 限制技能运行期可用工具
  - `paths` 用于限定自动激活范围  
  <https://code.claude.com/docs/en/skills>

最强反方挑战：

- frontmatter 变多后，作者更容易把“能配置”误用成“应该全配”，导致复杂度膨胀。

失效边界：

- 如果团队没有 skill 类型分类和命名规范，这些前置项会从“治理能力”变成“配置噪音”。

当前判断：

- **成立。** 它把权限、触发、上下文隔离从隐式经验变成了显式机制。

### 机制 D：Skill 不只是知识包，还能成为可执行工作单元

Claude Code 官方能力里，skill 可以：

- 通过 `!command` 预先注入动态上下文
- 用 `$ARGUMENTS`、`${CLAUDE_SESSION_ID}`、`${CLAUDE_SKILL_DIR}` 等替换
- 用 `context: fork` + `agent` 在子代理里隔离执行

为什么这很强：

- skill 从“静态参考文档”升级成“可执行任务包装”
- 动态上下文减少复制粘贴
- skill 可以把 live data、repo state、session state 注入执行 prompt
- 与 Explore/Plan 等官方 subagent 联动，解决上下文污染问题

最强支持证据：

- Claude Code 文档明确说明 `!command` 是 preprocess：先执行命令，再把输出替换进 skill 内容。<https://code.claude.com/docs/en/skills>
- Claude Code 文档说明 `context: fork` 会让 skill 在隔离 subagent 中运行，skill 内容本身成为 subagent 的任务 prompt。<https://code.claude.com/docs/en/skills>
- Claude Code subagents 文档强调：subagent 有独立 context window，可保留主线程上下文、限制工具、甚至控制成本。<https://code.claude.com/docs/en/sub-agents>

最强反方挑战：

- 动态上下文和预处理命令提升能力的同时，也提升了安全风险、可重现性风险和调试难度。

失效边界：

- 如果命令注入不受约束、skill 没有 tool restriction 或审计手段，这种强能力会反噬治理。

当前判断：

- **成立，但这是必须配合治理的“强能力”，不能无约束扩散。**

### 机制 E：官方 best practice 是“评估优先”，不是“模板优先”

Anthropic 官方 skill authoring best practices 最强的一点，不是某个模板长什么样，而是它明确要求：

- concise
- focused
- 先做真实用例和 eval
- 观察 Claude 实际如何使用技能
- 基于真实失败迭代 description、结构和 supporting files

为什么这很强：

- 它避免“先写一大篇规范，再希望模型听懂”
- 它把 skill 优化目标回绑到真实任务成功率
- 它天然支持你前面定义的两个维度：内容强度和结构治理

最强支持证据：

- Anthropic 官方 best practices 明确给出：
  - the context window is a public good
  - `description` 对 selection 特别关键
  - 先基于真实任务做评估，再迭代 skill
  - 观察 Claude 是否走了意外探索路径、忽略了哪些支持文件  
  <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>

最强反方挑战：

- eval-first 在组织中更难落地，因为它要求团队建立测试样本和观察回路。

失效边界：

- 如果团队没有时间做基线和回归，只写规范不做验证，那官方最佳实践的关键优势就会丢掉。

当前判断：

- **成立。** 这是官方体系真正“强”的方法论根部。

## 19.3 为什么 Claude Code 官方 skill 在这个场景里特别值得学

对于你现在这个场景，Claude Code 官方 skill 体系最值得学的不是“照抄它的文案”，而是这 4 个组合能力：

1. **本地文件系统原生**
   - 非常适合 repo 内治理、版本控制、review、monorepo 局部技能

2. **触发与加载是分开的**
   - 允许技能很多，但不默认把所有正文都塞进上下文

3. **调用权与副作用被建模**
   - 非常适合把你们当前 manual-only / auto 的经验判断升级成显式规范

4. **可以和 subagent / dynamic context 联动**
   - 这让 skill 不只是“知识条目”，而是 agent workflow 的真实执行节点

## 19.4 但它不替你解决什么

这里要非常清楚地收边界。

Claude Code 官方 skill 很强，但它不自动替你解决：

- 组织级 artifact schema
- 多阶段正式交付流程
- PRD / design / test-cases / plan 的跨工件一致性
- contract tests 与组织级验收口径

也就是说：

- **Claude Code skill 强在 capability packaging + invocation governance + context management**
- **你们当前体系还需要 OpenSpec / templates / completion checks / contracts 来补 governance 和 artifact discipline**

## 20. 回绑到我们体系：怎样实现“当前最强实践”

结合前面全部调研，当前最合理的收敛不是“全面改成 Claude Code 风格”，而是：

## 20.1 采用 Claude Code 官方作为 first-party skill 的核心基线

建议把以下内容视为 first-party skill 的核心规范基线：

- skill 是目录资产，不是单文件 prompt
- `SKILL.md` + supporting files + scripts 的组织方式
- `description` 作为 primary trigger
- `disable-model-invocation / user-invocable / allowed-tools / context / agent / paths` 作为核心 frontmatter 语义
- `SKILL.md` 主体保持聚焦，详细内容外移
- eval-first / observe-refine-test 作为 authoring 主流程

## 20.2 继续保留我们体系里比官方更强的治理层

这些不应丢：

- 模板作为 artifact schema 真源
- `completion_check.sh` 和 contract tests
- OpenSpec / `opsx:*` 的 change state machine
- capability matrix / runtime audit
- 本地中文 canonical 的团队协作适配

换句话说：

- **Claude Code 官方 skill 解决“技能如何被更好地发现、加载、执行、隔离”**
- **我们本地治理层解决“技能如何在组织里长期稳定落地”**

## 20.3 当前最强实践的目标架构

建议正式收敛成下面这个结构：

1. **Layer 0: AGENTS / Rules**
   - always-on 规则

2. **Layer 1: Claude Code skill core**
   - `SKILL.md`
   - frontmatter invocation semantics
   - supporting files
   - scripts
   - subagent execution

3. **Layer 2: Artifact schema**
   - templates
   - schema authority

4. **Layer 3: Workflow / state**
   - OpenSpec / `opsx:*`

5. **Layer 4: Governance**
   - completion checks
   - contract tests
   - evals
   - runtime validation

## 20.4 现在最该做的 3 件事

### P0-1：把 first-party skill 标准改成“Claude Code core + 本地治理扩展”

做法：

- 以 Claude Code 官方 frontmatter 和 skill 组织方式为主干
- 把当前本地特有的 outputs / template / completion_check 规则作为治理扩展层，而不是混在“通用 skill 定义”里

### P0-2：把 skill 按官方内容类型重新分类

Claude Code 文档其实已经隐含给了一个很好的分法：

- `Reference content`
- `Task content`
- `Forked task content`（subagent execution）

建议结合你们体系改成：

- Reference skill
- Task skill
- Forked workflow skill
- Community upstream skill
- Process command

### P0-3：把 authoring 流程改成 eval-first

建议以后新增/修改 skill 时，不再先写一份长规范，而是：

1. 先找 3-5 个真实失败样例
2. 建最小 activation / execution eval
3. 写最小必要 `SKILL.md`
4. 观察 Claude 实际导航
5. 再决定哪些内容应进入 references / templates / scripts

## 20.5 最终推荐结论

如果用一句话总结：

> **当前最强实践不是“本地体系替换成 Claude Code 官方”，而是“以 Claude Code 官方 skill 机制为 first-party skill 基线，以我们现有的 template / OpenSpec / contract / runtime audit 作为治理增强层”。**

这条路线的优点是：

- 保住官方在 discoverability、progressive disclosure、invocation control、subagent orchestration 上的强项
- 保住我们当前在 artifact discipline、组织治理、可审计性上的强项
- 避免“只学上游形式”或“只守本地旧规范”这两种极端
