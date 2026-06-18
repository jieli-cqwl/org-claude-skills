---
name: overview
user-invocable: true
disable-model-invocation: true
description: "项目全貌分析与架构概览。Use when 接手新项目、需要项目概览/架构概览、新人入门导览、了解项目结构、技术栈、核心模块协作或先看哪些关键文件。"
model: sonnet
argument-hint: "[项目路径]"
context: fork
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion, Agent
---

# /overview -- 项目概览

Goal: 基于真实代码扫描生成项目全貌与新手入门概览。Completion boundary: `docs/项目概览.md` 已写入，包含产品视角、架构图、模块说明、关键文件、技术栈和结构树，并由用户确认准确或反馈已同步。

## HARD-GATE

1. NO overview document without scanning actual code first (Glob/Grep/Read).
2. NO module description without identifying the key files that implement it.
3. NO completion without user confirming the understanding is accurate.
4. NO /overview completion without 项目概览.md written to docs/.
5. NO silent fallback when project path, scan script, write permission, or required confirmation is blocked.

## 角色

你是资深技术顾问，向新加入的 Staff Engineer 介绍项目。介绍完毕后他能回答：这个项目解决什么问题、核心模块如何协作、从哪里开始深入。

## 项目快照

根目录结构:
!`find . -maxdepth 2 -type d | grep -v node_modules | grep -v __pycache__ | grep -v .venv | grep -v .git | grep -v dist | grep -v build | grep -v target | head -40`

特征文件:
!`for f in pom.xml build.gradle package.json pyproject.toml go.mod vue.config.js vite.config.ts next.config.js; do test -f "$f" && echo "FOUND: $f"; done 2>/dev/null || echo "NO_PROJECT_FILE"`

README 摘要:
!`head -30 README.md 2>/dev/null || head -30 README.rst 2>/dev/null || echo "NO_README"`

## 输入与阻塞处理

- 项目路径：优先使用用户参数；未提供时使用当前工作目录，并在首条响应中复述操作对象与预期产物。
- 路径不存在或不可读：立即停止，报告具体路径与失败原因，要求用户提供正确路径或权限。
- 预扫描脚本失败：停止后续执行确认与文档生成；报告失败命令、错误摘要和已确认的前置条件。
- `{{SKILLS_HOME}}` 未解析或脚本缺失：停止执行，不手写替代扫描结果，不把聊天摘要当作 overview 文档。
- `docs/` 不存在时可创建；无写入权限时停止并报告，禁止只在聊天中输出后声称完成。
- 用户未确认正式执行或未确认最终理解准确：保持 blocked，不进入下一阶段或完成态。

## 流程

流程产物合同：每一步必须形成 output，并写清 consumer、acceptance、failure_state、proof。扫描脚本、执行确认、文档写入或用户确认任一缺失时，当前状态保持 blocked，不得声称 overview 完成。

1. 项目扫描 — 先按“输入与阻塞处理”确认项目路径，再执行 `bash {{SKILLS_HOME}}/overview/scripts/project-detect.sh <项目路径>` 和 `bash {{SKILLS_HOME}}/overview/scripts/dir-tree.sh <项目路径> 3` 获取基础数据；脚本通过后再识别项目类型（特征文件判断）+ 读取关键文件（README、配置、入口、路由/Controller）
2. 执行确认 — 基于预扫描结果说明项目规模、语言/框架数量、入口和文档完整度；明确 `分层 agent team 是唯一正式 /overview 执行方式`，给出成本和覆盖收益，AskUserQuestion 等待用户确认继续。未完成执行确认前禁止继续。
   → Trigger: 扫描脚本成功且需要确认正式概览执行；Read: `references/mode-selection.md`；Expect: 触发信号、确认话术、覆盖收益/成本和停止条件；Consume: 执行确认提示和用户确认；Evidence: 扫描摘要、推荐理由和用户确认；Sync: none for overview execution.
3. 按已确认的 agent team 执行概览 — 最多启用 8 个 agent；主代理负责合并 agent 返回结果、裁决冲突并标注缺口。
   → Trigger: 用户确认正式概览执行；Read: `references/agent-assignments.md`；Expect: 8 Agent 合同、输入边界、返回格式、主代理汇总协议和失败处理；Consume: 分层扫描任务与合并摘要；Evidence: agent 返回结果、缺口标注和主代理合并记录；Sync: none for overview execution.
4. 生成文档 — 输出到 `docs/项目概览.md`，包含：
   - 产品视角说明（核心用户 + 核心价值 + 主要功能，<= 5 句话）
   - 架构图（Mermaid，模块关系 + 数据流向）
   - 模块说明表（模块 | 职责 | 关键文件）
   - 新手入门指南（先看的 3 个文件 + 入手路径）
	   - 技术栈速查表 + 项目结构树（深度 2-3 层）
5. 用户确认 — 询问准确性，根据反馈更新

Step output contract:
- Step 1 output: project facts；Consumer: Step 2/3；Acceptance: 脚本成功、关键文件可读；Failure_state: 脚本/路径/权限失败则 blocked；Proof: 命令输出。
- Step 2 output: confirmed execution；Consumer: Step 3；Acceptance: 用户确认正式执行；Failure_state: 未确认则暂停；Proof: 用户选择。
- Step 3 output: module map and key files；Consumer: Step 4；Acceptance: 每个模块有关键文件；Failure_state: 关键文件无法定位则补扫；Proof: file refs。
- Step 4 output: `docs/项目概览.md`；Consumer: 用户和后续接手者；Acceptance: 模板字段完整；Failure_state: 写入失败则 blocked；Proof: 文件路径和 grep 检查。
- Step 5 output: confirmation or synced feedback；Consumer: completion check；Acceptance: 用户确认或反馈已更新；Failure_state: 未确认不得完成；Proof: 用户确认记录。

## 项目类型识别

| 特征文件 | 项目类型 |
|---------|---------|
| `pom.xml` / `build.gradle` | Java/Spring |
| `package.json` + `vue.config.js` / `vite.config.ts` | Vue 前端 |
| `package.json` + `next.config.js` | Next.js |
| `pyproject.toml` / `requirements.txt` | Python 后端 |
| `pages.json` + `manifest.json` | UniApp |

## 执行方式

- 分层 agent team 是唯一正式 /overview 执行方式。
- 每次都先做执行确认，不允许 `默认推荐自动继续`。
- 用户不确认 agent team 执行时，保持 blocked；不得生成 `docs/项目概览.md`，不得声称 /overview 完成。

## 输出

报告模板：`projections/project-overview-template.md`（产品视角、架构图、模块说明表、新手入门、技术栈速查、项目结构树）

输出到 `docs/项目概览.md`，包含：
- 产品视角说明（核心用户 + 核心价值 + 主要功能，<= 5 句话）
- 架构图（Mermaid，模块关系 + 数据流向）
- 模块说明表（模块 | 职责 | 关键文件）
- 新手入门指南（先看的 3 个文件 + 入手路径）
- 技术栈速查表 + 项目结构树（深度 2-3 层）

## 完成校验

- [ ] fresh 执行 `project-detect.sh <项目路径>` 与 `dir-tree.sh <项目路径> 3` 成功
- [ ] 用产品语言解释了项目用途
- [ ] 画出核心模块关系图（Mermaid）
- [ ] 指出新手先看的 3 个文件
- [ ] 文档保存到 `docs/项目概览.md`
- [ ] `docs/项目概览.md` 包含 Mermaid 架构图（Grep 验证含 ````mermaid`）
- [ ] 用户已确认理解准确，或反馈已同步更新到 `docs/项目概览.md`
- [ ] Proof evidence 已记录：扫描命令输出、执行确认、关键文件 refs、文档路径、Mermaid grep 和用户确认
