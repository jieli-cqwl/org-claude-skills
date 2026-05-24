# 审计检查清单

audit 模式的 3 项检查逻辑定义在此文件。

---

## 检查 1: 过时检测（ERROR）

检测入口文档中的内容是否与项目实际状态一致。深度 L2：路径存在性 + 命令/框架名称一致性，不做版本级检查。

### 路径检查

提取文档中所有反引号包裹的路径引用（如 `` `src/utils/` ``、`` `config/database.yml` ``），逐一验证：
- 目录路径：`test -d {path}`
- 文件路径：`test -f {path}`
- 路径不存在 → 报 ERROR，建议更新或移除引用

### 命令检查

提取文档 Commands 章节中表格内的命令，与实际配置对比：

| 配置源 | 对比方式 |
|--------|---------|
| `package.json` scripts | 文档命令是否对应存在的 script name |
| `Makefile` targets | 文档命令是否对应存在的 target name |
| `pyproject.toml` scripts | 文档命令是否对应存在的 entry point |

命令不匹配 → 报 ERROR，建议更新（附实际可用命令）。

### 框架名称检查

提取文档中提到的框架/工具名（如 jest、vitest、React、Vue），与实际依赖对比：
- JS/TS：读取 `package.json` dependencies + devDependencies
- Python：读取 `pyproject.toml` 或 `requirements.txt`
- Java：读取 `pom.xml` 或 `build.gradle` dependencies
- Go：读取 `go.mod` require

文档提到的框架在实际依赖中不存在 → 报 ERROR。

---

## 检查 2: 完整性检测（WARN）

扫描共享项目指令正文中的二级标题（`## ` 开头的行），与 7 个建议章节对比。默认检查 `AGENTS.md`；只有用户选择单文件 `CLAUDE.md` 且它不是 `@AGENTS.md` import 时，才检查 `CLAUDE.md` 的章节。

1. Commands
2. Architecture
3. Code Style
4. Environment
5. Testing
6. Gotchas
7. Workflow

缺失章节 → 报 WARN，建议补充（可通过重新运行 `/project-memory init` 补充，需先备份现有文件）。

额外章节（不在列表中的 `## ` 标题）不报错——用户可自由添加章节。

---

## 检查 3: 真源检测（ERROR / WARN）

入口文档真源固定为项目根目录 `CLAUDE.md` 和 `AGENTS.md`。审计时只检查这两个文件，禁止把其他 Markdown 文件识别为入口文档。

### 两文件都存在

检查 `CLAUDE.md` 是否只通过 import 载入共享项目指令：

```bash
grep -Fx '@AGENTS.md' CLAUDE.md
```

缺失 `@AGENTS.md` import，或 `CLAUDE.md` 复制了共享项目指令正文 → 报 ERROR，建议把共享指令迁回 `AGENTS.md`，让 `CLAUDE.md` 只保留 import。

### 只有 `AGENTS.md` 存在

报 WARN，建议新增 `CLAUDE.md` 并写入 `@AGENTS.md`，让 Claude Code 读取同一套项目指令。

### 只有 `CLAUDE.md` 存在

报 WARN。若 `CLAUDE.md` 已引用缺失的 `AGENTS.md`，升级为 ERROR；否则建议抽出共享项目指令到 `AGENTS.md`，再让 `CLAUDE.md` import。

### 两文件都不存在

提示运行 `/project-memory init`，不执行任何检查。

---

## 输出格式

按严重度排序：ERROR → WARN → OK。

每条检查结果格式：
```
[{严重度}] {文件名}: {问题描述}
  → 建议：{修复建议}
```

汇总行（固定在最后）：
```
[OK]    {N} 个入口文档（只统计 `CLAUDE.md` / `AGENTS.md`），{M}/7 章节覆盖，{E} 个错误，{W} 个警告
```
