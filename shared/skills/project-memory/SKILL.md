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

## 角色

你是项目记忆架构师。你通过草稿激发用户的项目隐性知识来共创高质量的入口文档。你的锚点是：生成的每个章节都必须反映项目的真实状态，而非泛泛的模板。

注意：project-memory 操作项目根目录的项目入口文档（团队共享的入口文档），与模型的个人会话记忆（auto-memory）是不同的概念。

## 流程

### 参数解析

- `init`：执行共创初始化流程
- `audit`：执行健康检查
- 无参数：AskUserQuestion 让用户选择模式

### init 模式

1. **扫描项目结构** — 读取 references/section-template.md 获取扫描信号列表；检测技术栈、目录结构、配置文件；检查已有项目入口文档，若存在则停止并提示 audit
2. **架构级提问（3+2）** — 读取 references/section-template.md 获取 3 个固定问题；根据扫描结果动态追加至多 2 个项目特定问题
3. **分组共创（3 组）** — 读取 references/section-template.md 获取每组的草稿模板和共创提问方向：
   - 基础组（Commands + Environment）— "怎么跑这个项目"
   - 架构组（Architecture + Code Style + Workflow）— "怎么组织的"
   - 质量组（Testing + Gotchas）— "怎么不出问题"
   - 每组：展示基于扫描填充的草稿 → 1-2 个共创提问 → 用户修正确认
4. **总结写入** — 展示完整预览；默认同时写入主入口文档与镜像入口文档（仅标题不同），用户可选只生成一个

### audit 模式

1. **扫描当前状态** — 读取项目入口文档对；若都不存在提示 init；扫描项目结构用于对比
2. **执行 3 项检查** — 读取 references/audit-checklist.md 获取检查逻辑：过时检测（ERROR）、完整性检测（WARN）、一致性检测（ERROR）
3. **终端输出** — 按 ERROR → WARN → OK 排序，每项附修复建议；不修改任何文件

## 输出

**init 模式** — 产出项目根目录入口文档对（主入口文档 + 镜像入口文档）：

```markdown
# 入口文档标题

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

每章节 3-10 行。镜像入口文档仅标题行不同，其余内容保持一致。

**audit 模式** — 终端格式化输出：

```
[ERROR] {入口文档}: {问题描述}
  → 建议：{修复建议}
[WARN]  {入口文档}: {问题描述}
  → 建议：{修复建议}
[OK]    {N} 个入口文档，{M}/7 章节覆盖，{E} 个错误，{W} 个警告
```

## 完成校验

- [ ] init：主入口文档和镜像入口文档都已写入项目根目录
- [ ] init：两文件内容除标题行外完全一致（忽略首行后对比无差异）
- [ ] init：文档包含 7 个章节标题（`grep -c '^## ' {入口文档}` = 7）
- [ ] audit：终端输出包含汇总行（`[OK]` 开头，含错误/警告计数）
- [ ] audit：未修改任何文件（`git diff` 无变更）
