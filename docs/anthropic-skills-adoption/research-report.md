# Anthropic Skills 引入与替换调研报告

日期基线：`2026-04-02`
调研对象：`anthropics/skills`、本地 `new-skills` / `mcp-builder`
报告模式：`analysis`
范围假设：按 `docs/anthropic-skills-adoption/` 作为本次调研 feature 目录

## 1. 当前结论

### 1.1 一句话结论

**可以安装官方 skills 使用，但不建议直接删除本地 `new-skills`；本地 `mcp-builder` 也不建议无条件删除。**

更稳的模式是：

- 官方 `anthropics/skills` 作为**上游内容源 / 试点能力包**
- 当前仓库继续作为**真源、质量门禁、双运行时适配层**

### 1.2 决策收口

| 对象 | 当前判断 | 理由 |
|------|----------|------|
| 官方 skills 本地安装 | **建议试点安装** | 官方仓库确实覆盖不少日常常用 skill，适合个人或小范围先试用 |
| 真源继续维护在当前仓库 | **建议保留** | 你们仓库已承载安装链、质量门禁、Codex 适配、运行时验收 |
| 删除本地 `new-skills` | **不建议** | 它不是官方 `skill-creator` 的等价物，而是你们 first-party 规范入口 |
| 删除本地 `mcp-builder` | **暂不建议** | 官方更完整，但本地版本承担了轻量入口与双端适配职责 |

### 1.3 推荐动作

1. 先安装官方 skills 试点使用，但**不要删除本地 skill**
2. `skill-creator`：可装官方，用于创作与评测；本地 `new-skills` 继续保留为组织门禁
3. `mcp-builder`：先保留本地薄适配层；如果要吸收官方内容，走 vendoring / pin 版本，而不是裸替换
4. 若后续要替换，先完成：
   - source pin
   - Codex adapter
   - 安装链接入
   - 回滚与验收

## 2. 项目上下文画像

本次判断基于本地实际扫描，而不是抽象讨论：

- `[install.sh](/Users/lijieli/org-claude-skills/install.sh)` 明确同时构建并安装到 `~/.claude` 和 `~/.codex`
- `[docs/runtime-acceptance-sop.md](/Users/lijieli/org-claude-skills/docs/runtime-acceptance-sop.md)` 明确写了：允许额外系统 skills，但不得遮蔽仓库托管的 skills
- `[shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)` 明确写了 `/new-skills` 被用于 first-party skill 评估基线
- `[shared/skills/new-skills/agents/openai.yaml](/Users/lijieli/org-claude-skills/shared/skills/new-skills/agents/openai.yaml)` 和 `[shared/skills/mcp-builder/agents/openai.yaml](/Users/lijieli/org-claude-skills/shared/skills/mcp-builder/agents/openai.yaml)` 说明你们本地 skill 已接入 Codex 暴露面
- 工作树当前存在无关未提交改动：`shared/skills/design/*`、`shared/skills/product/*`、`tests/test-skill-output-and-gate-contract.sh`；本次调研未触碰这些文件

这意味着：你们当前讨论的不是“哪份文档更好”，而是**哪一层负责 canonical truth，哪一层负责上游内容复用，哪一层负责本地安装和适配**。

## 3. 检索路径与覆盖证明

### 3.1 名称归一化

本次覆盖的对象变体：

- `anthropics/skills`
- `Anthropic skills`
- `skill-creator`
- `new-skills`
- `mcp-builder`
- `plugin marketplace`
- `Agent Skills`

### 3.2 对象类型覆盖

已覆盖对象类型：

- GitHub 仓库
- Claude Code 插件文档
- Claude Help Center 技能创建/使用文档
- Claude API Agent Skills 文档
- Agent Skills 规范与 client implementation 文档
- 本地仓库中的 skill、reference、install、runtime-acceptance 文档

### 3.3 已排除的错误收敛

- 把官方仓库当成 Agent Skills 标准真源：**已排除**
  - `spec/agent-skills-spec.md` 已将标准跳转到 `agentskills.io`
- 把官方 `skill-creator` 视作本地 `new-skills` 的直接等价替代：**已排除**
- 把官方 `mcp-builder` 视作本地 `mcp-builder` 的无损替代：**已排除**

## 4. 官方 skills 到底能不能装

### 4.1 能装，而且官方明确支持

基于官方 README 与文档，可确认 3 条路径：

1. **Claude Code**
   - 可通过 `/plugin marketplace add anthropics/skills`
   - 可安装 `document-skills` / `example-skills`

2. **Claude.ai**
   - 支持上传技能 ZIP
   - Team / Enterprise 支持组织级 provision

3. **Claude API**
   - 通过 `container.skills` 指定 `skill_id` + `version`
   - 支持 Anthropic-managed skills 和 custom skills

### 4.2 但这不等于“适合直接当你们运行时真源”

官方文档同时给出几个关键限制：

- Claude Code 文档明确区分：
  - standalone `.claude/`：适合个人/项目快速迭代
  - plugins：适合共享、版本化和市场分发
- Agent Skills client implementation 文档明确要求处理：
  - scope 扫描
  - name collision
  - trust gating
  - permission allowlisting
  - skill context 保护
- API 文档明确限制：
  - 每次请求最多 `8` 个 skills
  - skills 列表变化会影响 prompt caching
  - 无网络访问
  - 不能运行时装包
  - 每次请求 fresh container

所以“能装”与“适合直接取代你们本地 canonical chain”是两回事。

## 5. 重叠度分析

### 5.1 `skill-creator` vs `new-skills`

#### 当前判断

**不是替代关系，而是“部分重叠 + 上下位关系”。**

- 官方 `skill-creator`：通用 skill 创作、测试、benchmark、description 优化工作台
- 本地 `new-skills`：first-party skill 的组织规范、模板、门禁和脚手架入口

#### 关键证据

- 官方 `skill-creator`
  - `18` 个文件
  - `SKILL.md` 约 `485` 行
  - 含 `scripts/`、`agents/`、`assets/`、`eval-viewer/`
- 本地 `new-skills`
  - `7` 个文件
  - `SKILL.md` 约 `60` 行
  - 含 `scripts/init_skill.sh`
  - 含 `openai.yaml`
  - 绑定 `[shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)`

#### 删除本地会丢什么

- 你们自己的 skill 结构模板与门禁
- `/new-skills` 在质量标准里的显式引用
- 本地脚手架 `init_skill.sh`
- Codex 侧自动暴露元数据 `openai.yaml`

#### 结论

**`skill-creator` 可以装，但不该删 `new-skills`。**

### 5.2 官方 `mcp-builder` vs 本地 `mcp-builder`

#### 当前判断

**不是无损替代，而是“部分重叠”。**

- 官方 `mcp-builder`：完整领域方法论 + TS/Python 双栈参考 + evaluation
- 本地 `mcp-builder`：仓库内的薄入口 + 组织默认值 + 双端暴露面

#### 关键证据

- 官方 `mcp-builder`
  - `10` 个文件
  - `SKILL.md` 约 `236` 行
  - 含 `reference/` 和 `scripts/`
- 本地 `mcp-builder`
  - `2` 个文件
  - `SKILL.md` 约 `58` 行
  - 含 `agents/openai.yaml`
  - 指向 `[shared/reference/mcp-server开发.md](/Users/lijieli/org-claude-skills/shared/reference/mcp-server开发.md)`

#### 删除本地会丢什么

- 本地默认硬门禁：
  - TypeScript/Zod 优先
  - annotations 必填
  - MCP Inspector 必过
- Codex 适配元数据
- 现有安装链内的受控入口

#### 结论

**官方 `mcp-builder` 可作为上游内容源，但本地 `mcp-builder` 不应直接删除。**

## 6. 对用户观点的双重挑战

### 6.1 工程治理挑战

被挑战观点：

- “官方 skill-creator / mcp-builder 可以直接替代本地实现”
- “既然想用官方，就应该删本地”
- “官方安装到本地 + 当前仓库继续维护真源，不会增加复杂度”

#### 反方结论

**直接删本地会同时失去 canonical truth、双运行时适配和现有回滚/验证链。**

#### 成立条件

- 当前仓库仍是唯一真源
- 仍要支持 Claude + Codex
- 本地 skill 仍承载规范、安装、适配、测试职责
- 官方与本地 skill 存在同名或半重叠关系

#### 失效条件

- 只做 Claude-only 个人试用
- 先把官方内容 vendoring 到当前仓库
- 再补：
  - `openai.yaml`
  - 安装链
  - 测试
  - 回滚

### 6.2 组织落地挑战

被挑战观点：

- “官方看起来常用，所以直接装起来就有明显收益”
- “删本地更省心”

#### 反方结论

**省掉的主要是‘内容维护感’，不一定省掉真正麻烦的部分，反而可能把问题转移成 owner、培训、信任、排障和版本漂移。**

#### 成立条件

- 没有 usage 数据
- 没有 baseline 对比
- 没有明确 owner
- 团队成员需要额外理解上游来源、脚本依赖、平台差异

#### 失效条件

- 先小范围试点
- 有人负责 pin 版本、培训、回滚
- 被替换对象只是薄壳，且未被测试/安装链/质量规范依赖

## 7. 适配度判断

### 7.1 适合安装官方的场景

- 个人在 Claude Code 内日常使用官方常见 skill
- 先验证官方 `skill-creator` 与 `mcp-builder` 的实际体验
- 把官方内容当“上游知识源”，而不是“本地真源”

### 7.2 不适合直接替换本地的场景

- 需要继续维护 Claude/Codex 双运行时
- 需要唯一真源和统一安装链
- 需要 runtime acceptance、quick check、state 管理
- 需要 Codex 自动暴露的 `openai.yaml`

## 8. 推荐方案

### 方案 A：官方试点 + 本地保留治理壳

#### 做法

- Claude Code 本地安装官方 `example-skills`
- 当前仓库继续维护 `new-skills`、本地 `mcp-builder`
- 收集实际使用数据，再决定是否吸收官方内容

#### 优点

- 风险最低
- 不破坏当前安装链
- 能尽快获得官方 skill 使用体验

#### 缺点

- 会短期存在概念重叠
- 需要明确“官方是试点，不是 canonical”

#### 当前推荐

**推荐先走这个方案。**

### 方案 B：官方内容 vendoring 到当前仓库

#### 做法

- 选定 commit / release
- 把官方 `skill-creator` / `mcp-builder` 收编到当前仓库某个上游目录
- 由本地 wrapper 暴露给 Claude/Codex

#### 优点

- 统一真源
- 可 pin 版本
- 可接入现有 install / test / rollback

#### 缺点

- 维护成本高于方案 A
- 需要写 adapter、测试和更新策略

#### 适用时机

试点证明官方内容确实比当前本地版本更有价值时。

### 方案 C：直接删本地，全面改用官方

#### 当前判断

**不推荐。**

#### 主要风险

- canonical truth 断裂
- Codex 适配缺口
- 命名冲突
- 版本漂移
- 排障复杂度上升

## 9. 最终建议

### 必须保留

- 当前仓库作为真源
- 本地 `new-skills`
- 本地 `mcp-builder` 至少作为薄适配层保留

### 可以试点

- Claude Code 安装官方 `example-skills`
- 实测官方 `skill-creator`
- 实测官方 `mcp-builder`

### 暂不建议

- 删除本地 `new-skills`
- 删除本地 `mcp-builder`
- 直接跟踪官方默认分支作为运行时真源

## 10. 后续动作

1. 在 Claude Code 中安装官方 `example-skills`，仅作为试点
2. 不改动当前 `install.sh` 和本地 skill 真源
3. 对 `skill-creator`、`mcp-builder` 做一轮真实任务对比：
   - 本地版本
   - 官方版本
   - 输出质量
   - 触发准确性
   - 维护成本
4. 若官方版本明显更优，再设计 vendoring / wrapper 方案

## 11. 主要来源

- Anthropic 官方仓库：<https://github.com/anthropics/skills>
- Claude Code plugins 文档：<https://code.claude.com/docs/en/plugins>
- Claude Help Center, create custom skills：<https://support.claude.com/en/articles/12512198-how-to-create-custom-skills>
- Claude Help Center, use skills：<https://support.claude.com/en/articles/12512180-use-skills-in-claude>
- Claude API, using skills：<https://platform.claude.com/docs/en/build-with-claude/skills-guide>
- Agent Skills best practices：<https://agentskills.io/skill-creation/best-practices>
- Agent Skills client implementation：<https://agentskills.io/client-implementation/adding-skills-support>

## 12. 待验证项

- 官方 `skill-creator` 在你们真实 skill 创作任务上的实际收益是否明显优于本地 `new-skills` + 现有 reference
- 官方 `mcp-builder` 在你们真实 MCP server 任务上的实际收益是否足以覆盖适配成本
- 官方 skill 安装到 Claude Code 后，是否会与本地托管 skill 形成实际触发歧义
