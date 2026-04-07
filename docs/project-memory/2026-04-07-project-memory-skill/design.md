# project-memory skill 设计

## Why

当前缺少项目冷启动阶段为 AI 编码工具生成入口文档的共创工具。现有 `claude-md-improver` 只做审计改进，`/revise-claude-md` 只做会话末增量捕获，二者都不解决"从零开始为项目创建 CLAUDE.md/AGENTS.md"的问题。用户需要一个类似 `rules-manager` 的分层共创模式，通过扫描+提问+草稿修正的方式，为项目生成高质量的入口文档。

## Scope

- In scope：
  - `init` 模式：扫描项目 → 架构级提问 → 分组共创 → 写入 CLAUDE.md + AGENTS.md
  - `audit` 模式：过时检测 + 完整性检测 + 一致性检测 → 终端输出
  - 通用模板 + 动态检测（不按技术栈绑定模板）
  - 同源生成（CLAUDE.md 和 AGENTS.md 仅标题不同）
- Out of scope：
  - 全局 `~/.claude/CLAUDE.md` 管理（由 `shared/assistant.md` + `install.sh` 负责）
  - `.claude/rules/` 管理（由 `rules-manager` 负责）
  - 已有文件的改进建议（由 `claude-md-improver` 负责）

## Approach

### 文件结构

```
shared/skills/project-memory/
├── SKILL.md                    # <=150 行（standalone skill）
├── agents/
│   └── openai.yaml             # Codex 展示元数据
└── references/
    ├── section-template.md     # 章节草稿模板 + 扫描信号 + 共创提问
    └── audit-checklist.md      # 3 项检查逻辑
```

### 部署

注册到 `install.sh` 的 `local_manual_only_skills()` — 手动调用（`disable-model-invocation: true`），部署到 `~/.claude/skills/` 和 `~/.codex/skills/`。

### HARD-GATE

1. **NO 覆盖 without 用户确认** — 已有 CLAUDE.md 或 AGENTS.md 时停止，提示用 audit
2. **NO 写入 without 用户确认** — 未经确认的草稿禁止写入文件
3. **NO 修改 without init 模式** — audit 模式只读，禁止修改任何文件

### init 模式流程

**Step 1：扫描项目结构**

检测信号：
- `package.json` → npm/yarn/pnpm 命令
- `pom.xml`/`build.gradle` → mvn/gradle 命令
- `go.mod` → go 命令
- `Cargo.toml` → cargo 命令
- `pyproject.toml`/`requirements.txt` → pip/poetry 命令
- `Dockerfile` → 容器构建命令
- `Makefile` → make targets
- `.github/workflows/` → CI 配置
- `.eslintrc`/`.prettierrc`/`editorconfig` → 代码风格
- `.env.example` → 环境变量清单
- 已有 `CLAUDE.md`/`AGENTS.md`/`.claude/rules/`

若发现已有入口文档 → 停止，提示 audit（HARD-GATE #1）。

**Step 2：架构级提问（3 个固定 + 至多 2 个扫描特定）**

固定问题（写入 `references/section-template.md`）：
1. "这个项目的核心职责是什么？（一句话概括）"
2. "主要协作模式？（个人项目 / 小团队 / 开源社区）"
3. "有哪些不看代码就不知道的重要约定或陷阱？"

扫描特定问题由模型根据 Step 1 结果动态生成，至多追加 2 个。

**Step 3：分组共创（3 组）**

| 组 | 章节 | 共创焦点 | 共创提问方向 |
|---|------|---------|------------|
| 基础组 | Commands + Environment | "怎么跑这个项目" | "扫描到了这些命令和环境依赖，是否正确？有遗漏吗？" |
| 架构组 | Architecture + Code Style + Workflow | "这个项目怎么组织的" | "目录结构和风格配置已扫描到，有什么隐含约定或流程是配置文件看不出来的？" |
| 质量组 | Testing + Gotchas | "怎么保证不出问题" | "测试配置已扫描到。有什么测试约定？你踩过哪些坑希望下一个人不要再踩？" |

每组流程：
1. 读取 `references/section-template.md` 中对应组的扫描信号和草稿模板
2. 基于 Step 1 扫描结果 + Step 2 答案，填充草稿
3. 展示草稿 + 1-2 个共创提问
4. 用户修正 → 确认

分组设计理由（方案 C）：项目知识按主题域组织而非按章节组织。基础组回答"怎么跑"、架构组回答"怎么组织"、质量组回答"怎么不出问题"——对齐用户心智模型，每组内章节共享上下文，减少上下文切换。相比逐章节共创（方案 A）减少交互轮次；相比全草稿一次出（方案 B）保留共创深度。

**Step 4：总结确认 + 写入**

- 展示完整文档预览
- 默认同时生成 CLAUDE.md + AGENTS.md（用户可选择只生成其中一个）
- 用户最终确认后写入

### audit 模式流程

**Step 1：扫描当前状态**

读取项目根目录的 CLAUDE.md 和 AGENTS.md。若都不存在 → 提示用 init。同时扫描项目结构（同 init Step 1），用于对比。

**Step 2：执行 3 项检查**（读取 `references/audit-checklist.md`）

| # | 检查 | 严重度 | 逻辑 |
|---|------|--------|------|
| 1 | 过时检测 | ERROR | 文档中引用的命令/路径/依赖是否与项目实际一致。深度 L2：检测路径存在性 + 命令/框架名称一致性（解析 package.json/Makefile 等），不做版本级检查 |
| 2 | 完整性检测 | WARN | 是否覆盖 7 个建议章节（Commands/Architecture/Code Style/Environment/Testing/Gotchas/Workflow），缺失章节报 WARN |
| 3 | 一致性检测 | ERROR | CLAUDE.md 和 AGENTS.md 内容是否同步（排除标题行后 diff，不同步报 ERROR）。若只有一个文件存在，报 WARN |

**Step 3：终端输出**

按严重度 ERROR → WARN → OK 排序，每项附修复建议。audit 只诊断不治疗——修复需要用户判断。

```
[ERROR] CLAUDE.md: Commands 章节引用 `npm test` 但 package.json scripts 中无 test 命令
  → 建议：更新为 `npx vitest`
[WARN]  CLAUDE.md: 缺少 Gotchas 章节
  → 建议：运行 `/project-memory init` 补充（需先备份现有文件）
[ERROR] AGENTS.md: 与 CLAUDE.md 内容不一致（差异 12 行）
  → 建议：从 CLAUDE.md 同步到 AGENTS.md（保留标题行差异）
[OK]    2 个入口文档，5/7 章节覆盖，2 个错误，1 个警告
```

### 输出格式

CLAUDE.md（AGENTS.md 仅标题行改为 `# AGENTS.md`）：

```markdown
# CLAUDE.md

## Commands
| 命令 | 用途 |
|------|------|
| `npm run dev` | 启动开发服务器 |
| `npm test` | 运行测试 |

## Architecture
项目采用 {框架} 构建。
{目录树}
- `src/components/` — UI 组件
- `src/services/` — 业务逻辑层

## Code Style
- 命名：组件 PascalCase，工具函数 camelCase
- {其他约定}

## Environment
- Node.js >= 18
- 必需环境变量：`DATABASE_URL`, `API_KEY`（从 .env.example 复制）

## Testing
- 框架：vitest
- 运行：`npm test`
- 策略：{测试策略描述}

## Gotchas
- {坑 1}
- {坑 2}

## Workflow
- 分支策略：{描述}
- PR 流程：{描述}
```

每章节 3-10 行，快速定向而非替代代码探索。Commands 章节用表格（高频查阅，可扫描性强），其余用 bullet list。

### 与现有工具的边界

| 工具 | 职责 | 阶段 |
|------|------|------|
| `/project-memory init` | 冷启动共创 | 项目接手 |
| `/project-memory audit` | 健康检查 | 维护期 |
| `claude-md-improver` | 已有文件改进建议 | 维护期（互补） |
| `/revise-claude-md` | 会话末尾增量学习 | 每次会话 |
| `/rules-manager` | 项目级技术约束规则 | 独立领域 |

注意：`project-memory` 操作的是项目根目录的 CLAUDE.md/AGENTS.md，与 Claude 的 auto-memory 系统（`~/.claude/projects/*/memory/`）是不同的概念。前者是项目入口文档（AI 工具和团队共享），后者是 Claude 个人的会话间记忆。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| A：逐章节共创 | 每章节精细打磨，复用 rules-manager 原版模式 | 7 章节 × 各 1 轮交互，用户疲劳；相关章节割裂 | 淘汰 |
| B：全草稿一次出 | 交互轮次最少（~3 轮） | 退化为"生成+审阅"，丧失共创核心价值 | 淘汰 |
| **C：分组共创** | **3 组 × 1-2 提问，平衡深度和效率；对齐用户心智模型** | **分组标准需验证** | **选中** |

## Key Decisions

- **D1**: Skill 命名 `project-memory` — 用户选择，与其"项目级记忆"心智模型一致。需在文档中明确与 Claude auto-memory 的区别
- **D2**: 同源生成 — CLAUDE.md 和 AGENTS.md 内容一致（仅标题不同），因为两个工具都可能做设计和执行，不应硬编码职责分工
- **D3**: 通用模板 + 动态检测 — 不按技术栈绑定模板。项目入口文档的章节结构与技术栈无关，扫描信号在 references/ 中列出，模型动态填充
- **D4**: 分组共创（方案 C）— 3 组共创对齐用户心智模型（"怎么跑/怎么组织/怎么不出问题"），平衡交互深度和用户疲劳
- **D5**: 架构级提问：固定 3 + 动态 2 — 核心体验一致，同时保留灵活性
- **D6**: 已有文件停止提示 — 不覆盖、不融合、不备份，最安全的策略
- **D7**: audit 只读不修复 — 过时内容的正确答案需要用户判断，自动修复可能引入错误
- **D8**: 过时检测深度 L2 — 路径存在性 + 命令/框架名称一致性，不做版本级检查（噪音大）
- **D9**: 双文件同步为默认行为而非 HARD-GATE — 用户可在确认时选择只生成其中一个

## Success Criteria

- init 模式能在 5 轮交互内（Step 2 + Step 3 × 3 组 + Step 4）完成共创并写入两个文件
- 生成的 CLAUDE.md 覆盖 7 个章节，每章节 3-10 行
- audit 模式能检出文档与项目状态的不一致（命令/路径/框架名称）
- SKILL.md <= 150 行
- 通过 Skill 质量标准 L2 评级
