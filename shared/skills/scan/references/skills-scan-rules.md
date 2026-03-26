# Agent5: Skills 质量扫描规则

> 引用者：scan（Agent 5）| 评估标准：`{{RUNTIME_HOME}}/reference/Skill质量标准.md`

## 前置条件

项目含自定义 Skills 目录。默认扫描 `.claude/skills/`；仓库若有更明确约定，按实际路径。缺失时输出"项目无自定义 Skills，跳过扫描"，不计入健康度评分。

## 扫描目标

项目级自定义 Skills 目录下所有 `SKILL.md`（不含全局 `{{RUNTIME_HOME}}/skills/`）。默认扫描 `.claude/skills/`，按目录中的实际文件扫描。

## 检测规则

### R1: 结构合规（D1）

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| frontmatter 缺失 | Grep `^---` 前 3 行无匹配 | 严重 |
| HARD-GATE 缺失 | Grep `## HARD-GATE` 无匹配 | 严重 |
| 五大节不完整 | Grep `## 角色` / `## 流程` / `## 输出` / `## 完成校验` | 警告 |
| 行数超标 | `wc -l > 120`（hook-only: > 60） | 严重 |
| 建议性语言 | Grep `应该\|推荐\|考虑\|should\|recommend\|consider`（排除 references/ 引用和输出字段名） | 警告 |
| SKILL.md 为空 | `wc -l == 0` | 严重 |

### R2: 闭环自治（D2）

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| 无前置检查 | Grep `终止\|提示\|STOP\|缺失` 无匹配 | 警告 |
| 无异常路径 | 文档内无异常/错误处理描述 | 建议 |

### R3: I/O 契约（D3）

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| 无输入声明 | Grep `输入\|前置条件\|Input\|## 输入` 无匹配 | 警告 |
| 无输出路径 | Grep `输出到\|Output\|\.md` 无匹配 | 警告 |

### R4: 角色（D4）

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| 角色单薄 | `## 角色` section < 2 行 | 建议 |

### R5: 验证（D5）

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| 校验项不足 | `## 完成校验` section 内 `- [ ]` 计数 < 3 | 警告 |

### R6: Token 效率（D6）

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| 引用文件不存在 | SKILL.md 内 `references/X.md` 路径 → 检查文件存在性 | 严重 |
| reference 嵌套引用 | references/*.md 内再引用 references/ | 警告 |
| >100 行 reference 无 TOC | reference 文件 `wc -l > 100` 且无 `## Contents` / `##目录` | 建议 |

### R7: Description 合规

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| 缺少 Use when | Grep frontmatter `description:` 不含 `Use when` | 警告 |
| 非第三人称 | description 含 `我\|你\|I \|You ` | 警告 |

### R8: 功能重复检测

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| description 高度相似 | 两个 skill 的 description 能力陈述部分语义重叠 | 建议 |

> 功能重复为启发式判断，需 Agent 读取两个 skill 后对比确认。

### R9: 目录完整性

| 检测项 | 方法 | 严重度 |
|--------|------|--------|
| skill 目录无 SKILL.md | `ls skills/*/` 存在目录但无 SKILL.md | 严重 |

## 评级输出

每个 skill 输出 L1/L2/L3 评级（按 `reference/Skill质量标准.md` 方法）。

## 严重度映射

| 条件 | 严重度 |
|------|--------|
| D1 FAIL（结构合规失败） | 严重 |
| 其他维度 FAIL | 警告 |
| PARTIAL | 建议 |
