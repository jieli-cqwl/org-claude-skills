# rules-manager Skill 设计文档

## Why

项目级技术规则（Java+Spring Boot 分层约束、Vue 组件规范、MySQL 规范）需要带 `paths` 的条件加载，但手动创建规则文件缺乏标准化流程，且已有规则缺少健康检查机制。需要一个 skill 统一项目级规则的初始化（深度共创）和审计（健康检查）。

## Scope

- **In scope**：
  - init 模式：扫描项目技术栈 → 架构级提问 → 逐文件草稿共创 → 生成带 `paths` 的项目级规则文件
  - audit 模式：对已有项目规则执行 4 项检查（死规则、重复、盲区、质量），终端输出结果
  - 内置 3 个技术栈模板：Java+Spring Boot、Vue 2/3、MySQL
  - 双运行时支持：Claude Code（`项目 .claude/rules/（或 .codex/rules/）`）和 Codex CLI（`.codex/rules/`）
- **Out of scope**：
  - 不触碰全局 `{{RUNTIME_HOME}}/rules/`（行为约束层，源码在 `shared/rules/`）
  - 不生成 CLAUDE.md/AGENTS.md 或 reference/ 文件
  - 不覆盖跨域约束（Git 分支、CI/CD、API 版本管理——另行梳理归属）

## 项目集成

- **源码位置**：`shared/skills/rules-manager/`（first-party skill）
- **安装路径**：通过 `install.sh` 部署到 `~/.claude/skills/` 和 `~/.codex/skills/`
- **运行时占位符**：使用 `{{RUNTIME_HOME}}` 引用规则目录，安装时替换为实际路径
- **install.sh 注册**：加入 `local_manual_only_skills()`（用户显式调用，模型不自动触发）
- **Codex 适配**：install.sh 自动去掉 hooks frontmatter；规则文件格式（paths frontmatter）双运行时通用

## Approach

### 整体架构

一个 skill（`rules-manager`），两个模式（`init` / `audit`），通过参数区分。

```
shared/skills/rules-manager/          # 源码位置（first-party）
├── SKILL.md                          # 主流程（<=150 行）
└── references/
    ├── java-spring.md                # Java+Spring Boot 规则模板
    ├── vue-frontend.md               # Vue 2/3 前端规则模板
    ├── mysql-db.md                   # MySQL 规则模板
    └── audit-checklist.md            # 审计 4 项检查的详细逻辑
```

> 安装后运行时路径：`{{RUNTIME_HOME}}/skills/rules-manager/`

### init 模式流程（分层共创）

```
Step 1: 扫描项目结构
  ├── 检测技术栈（pom.xml/build.gradle → Java+Spring Boot，package.json + .vue → Vue，SQL/MyBatis mapping → MySQL）
  ├── 识别目录结构
  └── 读取已有 项目 .claude/rules/（或 .codex/rules/）（避免覆盖）

Step 2: 确认技术栈 + 架构级提问（3-5 个）
  ├── 展示检测结果让用户确认
  └── 问顶层决策问题（影响所有规则的，如分层策略、状态管理、数据访问模式）

Step 3: 逐文件草稿共创
  ├── 从 references/{tech}.md 模板生成草稿（基于 Step 2 答案定制）
  ├── 展示草稿 + 配套共创提问（每条规则附一个针对性问题）
  ├── 用户修正/补充 → 生成最终版
  ├── 写入 项目 .claude/rules/（或 .codex/rules/）{tech}.md（带 paths frontmatter）
  └── 重复，直到所有检测到的技术域完成（未检测到的跳过）

Step 4: 总结确认
  └── 列出所有生成的规则文件 + paths 覆盖范围
```

**共创设计要点**：
- 模板结构为"默认规则 + 共创提问"配对，利用"识别+修正"认知机制而非"冷启动回忆"
- 每个模板 5-8 条 MUST 级约束，不贪多
- paths 使用技术级 glob（`**/*.java`）而非目录级 glob，保证重构不失效
- Step 2 问架构级决策（影响草稿生成），Step 3 问规则级细节（修正草稿内容），两层不重叠

### audit 模式流程

```
Step 1: 扫描当前状态
  ├── 读取项目 项目 .claude/rules/（或 .codex/rules/）（不存在则提示运行 init 并结束）
  ├── 读取全局 ~/项目 .claude/rules/（或 .codex/rules/）（用于重复检测）
  └── 收集项目文件列表（用于 paths 匹配验证）

Step 2: 执行 4 项检查
  ├── 死规则：paths glob 匹配 0 个实际文件
  ├── 重复：关键词匹配候选重复项，展示给用户判断（不自动下结论）
  ├── 盲区：代码目录未被任何 paths 覆盖（警告级，非错误）
  └── 质量：规则是否可判定、是否缺少 paths frontmatter

Step 3: 终端输出
  ├── 按严重度排序：ERROR → WARN → INFO → OK
  └── 每项附修复建议
```

### HARD-GATE

1. 已有 `项目 .claude/rules/（或 .codex/rules/）` 中的同名文件，禁止覆盖，必须提示用户确认处理方式
2. 每个 init 生成的规则文件必须有 `paths` frontmatter
3. 未经用户确认的草稿禁止写入文件
4. audit 模式禁止修改任何文件，只读 + 输出

### 与全局 rules 的关系

- 全局 `{{RUNTIME_HOME}}/rules/`（4 个文件，源码在 `shared/rules/`）= 行为约束，始终加载，不需要 paths
- 项目级 `.claude/rules/` 或 `.codex/rules/` = 技术约束，条件加载，必须有 paths
- 两层互补不重叠，audit 模式负责检测重复
- 规则文件格式（YAML frontmatter + paths）在 Claude Code 和 Codex 中通用

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| A：串行共创（逐个技术域 3-5 问） | 简单可控 | 12-20 个问题，用户疲劳；冷启动回忆容易遗漏 | 否决 |
| **B：分层共创（架构问题 + 草稿激发）** | 问题少但精准；草稿激发比凭空回忆更有效 | 稍复杂 | **采纳** |
| C：Agent 并行共创 | 快 | 并行 Agent 无法逐个跟用户交互，违背深度共创目标 | 否决 |
| 两个独立 skill | 职责清晰 | 操作对象相同，知识域重叠，大量重复 context | 否决 |
| 通用型（支持所有技术栈） | 可分享、可复用 | 每个模板都浅、维护面爆炸、检测逻辑复杂 | 否决 |
| audit 输出到文件 | 可追溯 | 发现是"修完即废"型，报告文件变成过时文档 | 否决 |

## Key Decisions

- D1: 合并为一个 skill 而非两个 — 操作对象和知识域相同，避免重复
- D2: 绑定用户技术栈（Java+Spring Boot/Vue/MySQL）而非通用 — 模板做深不做广，流程做通用不做绑定
- D3: 分层共创（方案 B）而非串行提问 — "识别+修正"比"冷启动回忆"认知负担更低且更完整
- D4: audit 终端输出而非文件报告 — 发现是即时修复型，不需要持久化追踪
- D5: paths 使用技术级 glob 而非目录级 — 技术边界比目录结构更稳定
- D6: 每模板 5-8 条 MUST 约束 — 核心约束放 rules/，细节指南放 reference/，与全局二层模型一致
- D7: 不触碰全局 rules — 全局是行为底线，项目级是技术约束，互补不重叠
- D8: 源码放 shared/skills/（first-party） — 通过 install.sh 同时部署到 Claude Code 和 Codex
- D9: 使用 {{RUNTIME_HOME}} 占位符 — 安装时自动替换为正确的运行时路径

## Success Criteria

- SKILL.md <= 150 行，符合 D1-D6 质量标准
- init 模式：扫描项目后能正确检测技术栈，生成的每个规则文件都有 paths 且 glob 匹配到实际文件
- audit 模式：能检出死规则（paths 匹配 0 文件）、能检出与全局 rules 的关键词重复
- references/ 中 3 个技术栈模板各含 5-8 条 MUST 规则 + 配套共创提问
- 在一个 Java+Spring Boot 项目中端到端运行 init，能在 10 分钟内完成共创并生成规则文件
