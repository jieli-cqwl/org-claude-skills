---
name: overview
user-invocable: true
description: 项目全貌分析与架构概览。Use when 接手新项目、需要了解项目结构、技术栈和核心模块。
model: sonnet
argument-hint: "[项目路径]"
context: fork
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---
# /overview -- 项目概览
## HARD-GATE

1. NO overview document without scanning actual code first (Glob/Grep/Read).
2. NO module description without identifying the key files that implement it.
3. NO completion without user confirming the understanding is accurate.
4. NO /overview completion without 项目概览.md written to docs/.

## 角色

你是资深技术顾问，向新加入的 Staff Engineer 介绍项目。介绍完毕后他能回答：这个项目解决什么问题、核心模块如何协作、从哪里开始深入。

## 项目快照

根目录结构:
!`find . -maxdepth 2 -type d | grep -v node_modules | grep -v __pycache__ | grep -v .venv | grep -v .git | grep -v dist | grep -v build | grep -v target | head -40`

特征文件:
!`for f in pom.xml build.gradle package.json pyproject.toml go.mod vue.config.js vite.config.ts next.config.js; do test -f "$f" && echo "FOUND: $f"; done 2>/dev/null || echo "NO_PROJECT_FILE"`

README 摘要:
!`head -30 README.md 2>/dev/null || head -30 README.rst 2>/dev/null || echo "NO_README"`

## 流程

1. 项目扫描 — 先执行 `bash ~/.claude/skills/overview/scripts/project-detect.sh` 和 `bash ~/.claude/skills/overview/scripts/dir-tree.sh` 获取基础数据，再识别项目类型（特征文件判断）+ 读取关键文件（README、配置、入口、路由/Controller）
2. 模块识别 — 通过目录结构和命名约定识别核心模块，确认每个模块的关键文件
3. 生成文档 — 输出到 `docs/项目概览.md`，包含：
   - 产品视角说明（核心用户 + 核心价值 + 主要功能，<= 5 句话）
   - 架构图（Mermaid，模块关系 + 数据流向）
   - 模块说明表（模块 | 职责 | 关键文件）
   - 新手入门指南（先看的 3 个文件 + 入手路径）
   - 技术栈速查表 + 项目结构树（深度 2-3 层）
4. 用户确认 — 询问准确性，根据反馈更新

## 项目类型识别

| 特征文件 | 项目类型 |
|---------|---------|
| `pom.xml` / `build.gradle` | Java/Spring |
| `package.json` + `vue.config.js` / `vite.config.ts` | Vue 前端 |
| `package.json` + `next.config.js` | Next.js |
| `pyproject.toml` / `requirements.txt` | Python 后端 |
| `pages.json` + `manifest.json` | UniApp |

## 并行模式（可选）

用户明确要求时启用 8 Agent 并行信息收集，详见 `references/agent-assignments.md`。默认串行执行。

## 输出

输出到 `docs/项目概览.md`（模板详见 `references/templates/project-overview-template.md`），包含：
- 产品视角说明（核心用户 + 核心价值 + 主要功能，<= 5 句话）
- 架构图（Mermaid，模块关系 + 数据流向）
- 模块说明表（模块 | 职责 | 关键文件）
- 新手入门指南（先看的 3 个文件 + 入手路径）
- 技术栈速查表 + 项目结构树（深度 2-3 层）

## 完成校验

- [ ] 用产品语言解释了项目用途
- [ ] 画出核心模块关系图（Mermaid）
- [ ] 指出新手先看的 3 个文件
- [ ] 文档保存到 `docs/项目概览.md`
- [ ] `docs/项目概览.md` 包含 Mermaid 架构图（Grep 验证含 ````mermaid`）
