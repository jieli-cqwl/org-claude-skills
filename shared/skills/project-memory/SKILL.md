---
name: project-memory
description: 项目级入口文档共创初始化与健康审计。Use when 需要为项目创建入口文档或检查已有入口文档健康度。
argument-hint: init | audit
user-invocable: true
---

# /project-memory — 项目级入口文档的共创初始化与健康审计

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

### 参数解析

- `init`：执行共创初始化流程
- `audit`：执行健康检查
- 无参数：AskUserQuestion 让用户选择模式

### init 模式

1. **扫描项目结构** — 读取 references/section-template.md 获取扫描信号列表；检测技术栈、目录结构、配置文件；只检查项目根目录 `CLAUDE.md` / `AGENTS.md` 是否存在；任一存在即视为已有项目入口文档并停止，提示先用 audit；若用户口头声明已有入口文档但扫描未命中这两个文件，视为冲突：不得直接继续 init，必须先说明当前真源定义、要求用户指出现有文件，并提示若用户指的是 `CLAUDE.md` / `AGENTS.md` 则改用 audit
2. **架构级提问（3+2）** — 读取 references/section-template.md 获取 3 个固定问题；根据扫描结果动态追加至多 2 个项目特定问题
3. **分组共创（3 组）** — 读取 references/section-template.md 获取每组的草稿模板和共创提问方向：
   - 基础组（Commands + Environment）— "怎么跑这个项目"
   - 架构组（Architecture + Code Style + Workflow）— "怎么组织的"
   - 质量组（Testing + Gotchas）— "怎么不出问题"
   - 每组：展示基于扫描填充的草稿 → 1-2 个共创提问 → 用户修正确认
4. **总结写入** — 展示完整预览；默认同时写入 `CLAUDE.md` 与 `AGENTS.md`（标题行分别为 `# CLAUDE.md` / `# AGENTS.md`，正文完全一致）；用户可选只生成其中一个

### audit 模式

1. **扫描当前状态** — 只读取项目根目录 `CLAUDE.md` / `AGENTS.md`；若都不存在提示 init；禁止把其他 Markdown 识别为入口文档；扫描项目结构用于对比
2. **执行 3 项检查** — 读取 references/audit-checklist.md 获取检查逻辑：过时检测（ERROR）、完整性检测（WARN）、一致性检测（ERROR）
3. **终端输出** — 按 ERROR → WARN → OK 排序，每项附修复建议；不修改任何文件

## 输出

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
