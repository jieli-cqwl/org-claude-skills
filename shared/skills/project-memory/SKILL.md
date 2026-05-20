---
name: project-memory
description: "项目级入口文档共创初始化与健康审计。Use when 需要为项目创建入口文档或检查已有入口文档健康度。"
argument-hint: init | audit
user-invocable: true
disable-model-invocation: true
---

# /project-memory — 项目级入口文档的共创初始化与健康审计

Goal: 为项目根目录入口文档建立或审计团队共享入口。Completion boundary: `init` 只在用户确认后写入根目录 `CLAUDE.md` / `AGENTS.md`；`audit` 只读输出健康检查结果并证明未修改文件。

## HARD-GATE

1. NO 覆盖 without 用户确认 — 已有项目入口文档时停止，提示用 audit
2. NO 写入 without 用户确认 — 未经确认的草稿禁止写入文件
3. NO 修改 without init 模式 — audit 模式只读，禁止修改任何文件
4. NO 忽略冲突声明 — 用户明确说“已有入口文档”，但根目录未扫描到 `CLAUDE.md` / `AGENTS.md` 时，停止 init；先报告冲突，再要求用户指出现有文件或确认从零初始化

## 角色

你是项目记忆架构师。你通过草稿激发用户的项目隐性知识来共创高质量的入口文档。你的锚点是：生成的每个章节都必须反映项目的真实状态，而非泛泛的模板。

注意：project-memory 操作项目根目录的项目入口文档（团队共享的入口文档），与模型的个人会话记忆（auto-memory）是不同的概念。

## 入口文档真源

- 主入口文档固定为项目根目录 `CLAUDE.md`
- 镜像入口文档固定为项目根目录 `AGENTS.md`
- `init` / `audit` 只允许读取或写入这两个文件；禁止把 `README.md`、`docs/**/*.md`、skill 文档或其他 Markdown 当作入口文档
- 用户选择只生成一个时，只允许保留 `CLAUDE.md` 或 `AGENTS.md` 其中一个，必须在写入前明确指定

## 流程

状态表：

| 状态 | 动作 | 停止/转移 |
| --- | --- | --- |
| Parse Mode | 解析 `init/audit` 或询问用户选择 | 模式不明则暂停 |
| Init Scan | 扫描项目结构和根目录入口文档 | 已有入口或冲突声明则停止 |
| Co-create | 按模板提问、展示草稿、等待用户确认 | 未确认不得写入 |
| Write | 写 `CLAUDE.md` / `AGENTS.md` | 写入失败或目标未确认则 BLOCK |
| Audit | 只读检查入口文档健康度 | 不存在则提示 init；不得修改 |

流程产物合同：每一步必须形成 output，并写清 consumer、acceptance、failure_state、proof。`init` 的 consumer 是用户确认后的根目录入口文档；`audit` 的 consumer 是终端健康报告。缺确认、冲突未解或 proof 不足时停止。

### 参数解析

- `init`：执行共创初始化流程
- `audit`：执行健康检查
- 无参数：AskUserQuestion 让用户选择模式

### init 模式

1. **扫描项目结构** — Trigger: init 扫描；Read: `references/section-template.md`；Expect: 扫描信号列表、章节模板和入口文档真源约束；Consume: 检测结果、草稿章节和用户确认问题；Evidence: 技术栈/目录/配置文件/入口文档存在性；Sync: 更新 section template、init gate 和 fixture。检测技术栈、目录结构、配置文件；只检查项目根目录 `CLAUDE.md` / `AGENTS.md` 是否存在；任一存在即视为已有项目入口文档并停止，提示先用 audit；若用户口头声明已有入口文档但扫描未命中这两个文件，视为冲突：不得直接继续 init，必须先说明当前真源定义、要求用户指出现有文件，并提示若用户指的是 `CLAUDE.md` / `AGENTS.md` 则改用 audit
2. **架构级提问（3+2）** — Trigger: init 扫描通过；Read: `references/section-template.md`；Expect: 3 个固定问题和至多 2 个项目特定问题；Consume: 共创回答和草稿修正；Evidence: 用户回答、扫描依据和待确认项；Sync: 更新 section template 与 init checklist。
3. **分组共创（3 组）** — Trigger: 用户完成架构级回答；Read: `references/section-template.md`；Expect: 每组草稿模板和共创提问方向；Consume: 最终入口文档草稿；Evidence: 每组用户修正确认；Sync: 更新 section template 与完成校验。
   - 基础组（Commands + Environment）— "怎么跑这个项目"
   - 架构组（Architecture + Code Style + Workflow）— "怎么组织的"
   - 质量组（Testing + Gotchas）— "怎么不出问题"
   - 每组：展示基于扫描填充的草稿 → 1-2 个共创提问 → 用户修正确认
4. **总结写入** — 展示完整预览；默认同时写入 `CLAUDE.md` 与 `AGENTS.md`（标题行分别为 `# CLAUDE.md` / `# AGENTS.md`，正文完全一致）；用户可选只生成其中一个

### audit 模式

1. **扫描当前状态** — 只读取项目根目录 `CLAUDE.md` / `AGENTS.md`；若都不存在提示 init；禁止把其他 Markdown 识别为入口文档；扫描项目结构用于对比
2. **执行 3 项检查** — Trigger: audit 模式且入口文档存在；Read: `references/audit-checklist.md`；Expect: 过时检测（ERROR）、完整性检测（WARN）、一致性检测（ERROR）；Consume: 终端健康报告；Evidence: 文件路径、章节覆盖、差异和项目结构对比；Sync: 更新 audit checklist、输出格式和 fixture。
3. **终端输出** — 按 ERROR → WARN → OK 排序，每项附修复建议；不修改任何文件

## 输出

Artifact contract: path 为项目根目录 `CLAUDE.md` 和/或 `AGENTS.md`，format 为 Markdown；required field 包含 Commands、Architecture、Code Style、Environment、Testing、Gotchas、Workflow 7 个章节；consumer 为项目成员、后续 agent 和用户健康审计；validation 通过章节计数、两文件正文 diff、audit 汇总行和只读 `git diff` replay。

**init 模式** — 产出项目根目录入口文档对（`CLAUDE.md` + `AGENTS.md`）：

```markdown
# {ENTRY_FILE}

## Commands
| 命令 | 用途 |
|------|------|

## Architecture
## Code Style
## Environment
## Testing
## Gotchas
## Workflow
```

每章节 3-10 行。`AGENTS.md` 仅首行标题替换为 `# AGENTS.md`，其余内容保持一致。

**audit 模式** — 终端格式化输出：

```
[ERROR] {入口文档}: {问题描述}
  → 建议：{修复建议}
[WARN]  {入口文档}: {问题描述}
  → 建议：{修复建议}
[OK]    {N} 个入口文档，{M}/7 章节覆盖，{E} 个错误，{W} 个警告
```

## 完成校验

- [ ] init：`CLAUDE.md` 与 `AGENTS.md` 已按用户选择写入项目根目录
- [ ] init：若同时生成两文件，`diff <(tail -n+2 CLAUDE.md) <(tail -n+2 AGENTS.md)` 无输出
- [ ] init：每个已生成文件都包含 7 个章节标题（`grep -c '^## ' CLAUDE.md` = 7；`AGENTS.md` 同理）
- [ ] audit：终端输出包含汇总行（`[OK]` 开头，含错误/警告计数）
- [ ] audit：未修改任何文件（`git diff` 无变更）
- [ ] Proof evidence 已记录：init 的用户确认、写入路径、章节计数和正文 diff；audit 的只读 `git diff` 与汇总行
