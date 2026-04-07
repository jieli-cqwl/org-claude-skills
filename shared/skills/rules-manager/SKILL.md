---
name: rules-manager
description: 项目级规则初始化与审计。Use when 需要为项目创建带 paths 的技术规则或检查已有规则健康度。
argument-hint: init | audit
user-invocable: true
---

# /rules-manager — 项目级技术规则的共创初始化与健康审计

## HARD-GATE

1. NO 覆盖 without 用户确认 — 已有项目规则同名文件禁止自动覆盖
2. NO 写入 without paths — 每个生成的规则文件必须有 `paths` frontmatter
3. NO 写入 without 用户确认 — 未经确认的草稿禁止写入文件
4. NO 修改 without init 模式 — audit 模式只读，禁止修改任何文件

## 角色

你是项目级规则架构师。你通过草稿激发用户的领域知识来共创高质量的技术约束规则。你的锚点是：生成的每条规则都必须反映项目的真实约束，而非泛泛的模板。

## 流程

### 参数解析

- `init`：执行初始化共创流程
- `audit`：执行规则健康检查
- 无参数：AskUserQuestion 让用户选择模式

### init 模式

1. **扫描项目结构**
   - 检测技术栈特征文件：

     | 特征文件 | 技术域 | 模板 |
     |---------|--------|------|
     | `pom.xml` / `build.gradle` + Spring 依赖 | Java+Spring Boot | `references/java-spring.md` |
     | `package.json` + `*.vue` 文件 | Vue 前端 | `references/vue-frontend.md` |
     | `*.sql` / MyBatis mapping XML / DB 配置 | MySQL | `references/mysql-db.md` |

   - 读取已有项目 `.claude/rules/`（或 `.codex/rules/`），如存在同名文件 → 停止并提示用户
   - 展示检测结果，AskUserQuestion 确认

2. **架构级提问（3-5 个）**
   - 只问影响所有规则的顶层决策
   - 当检测到对应技术域时 → 读取对应 `references/{tech}.md` 获取"架构级问题"章节
   - 未检测到的技术域跳过

3. **逐文件草稿共创**
   - 对每个检测到的技术域：
     a. 读取 `references/{tech}.md` 的"规则草稿 + 共创提问"章节
     b. 基于 Step 2 的架构回答定制草稿内容
     c. 逐条展示规则草稿 + 配套共创提问
     d. 用户修正/补充后，生成最终版
     e. 写入项目 `.claude/rules/{tech}.md`（或 `.codex/rules/{tech}.md`），带 paths frontmatter
   - paths 使用技术级 glob（`**/*.java`），避免目录级 glob

4. **总结确认**
   - 列出所有生成的规则文件及其 paths 覆盖范围
   - 提示用户可随时运行 `/rules-manager audit` 检查健康度

### audit 模式

1. **扫描当前状态**
   - 读取项目 `.claude/rules/`（或 `.codex/rules/`）
   - 如不存在 → 输出提示"建议运行 /rules-manager init"并结束
   - 读取全局 `{{RUNTIME_HOME}}/rules/`（用于重复检测）
   - 收集项目文件列表

2. **执行 4 项检查**
   当执行审计时 → 读取 `references/audit-checklist.md` 获取检查逻辑和输出格式

3. **终端输出**
   - 按严重度排序：ERROR → WARN → INFO → OK
   - 每项附修复建议
   - 末尾输出汇总行

## 输出

### init 模式

产出：项目 `.claude/rules/`（或 `.codex/rules/`）下的规则文件，格式：

```yaml
---
paths:
  - "**/*.java"
---
# {技术域}项目规则

## MUST
- {经共创确认的约束条目}
```

### audit 模式

产出：终端格式化输出

```
[ERROR] rules/xxx.md: {问题描述}
  → 建议：{修复建议}
[WARN]  {问题描述}
  → 建议：{修复建议}
[OK]    {N} 个规则文件，{M} 个技术域覆盖，{E} 个错误，{W} 个警告
```

## 完成校验

- [ ] init：每个规则文件都有 `paths` frontmatter
- [ ] init：每个 paths glob 至少匹配 1 个实际文件（Glob 工具验证）
- [ ] init：所有规则内容经用户逐条确认
- [ ] audit：4 项检查全部执行并输出结果
- [ ] audit：未修改任何文件
