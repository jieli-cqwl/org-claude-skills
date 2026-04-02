# Anthropic Skills 引入与替换调研报告

日期基线：`2026-04-02`
调研对象：`anthropics/skills`、本地 `new-skills` / `mcp-builder`
报告模式：`analysis`

## 1. 当前结论

### 1.1 一句话结论

**当前已收口到统一方案：官方 17 个 skills 全量 vendor 到 `community/anthropic/skills`，当前仓库继续作为唯一安装入口与运行时真源；`new-skills` 保留，`mcp-builder` 改由官方版本接管。**

### 1.2 最终结构

- first-party skills 继续维护在 `shared/skills/`
- 官方 Anthropic skills 统一维护在 `community/anthropic/skills/`
- 官方所有 Codex adapters 统一维护在 `community/anthropic/codex/skills/`
- `install.sh` 继续负责安装到 `~/.claude` 与 `~/.codex`
- 官方技能正文保持 upstream 原文，不做中文化

### 1.3 命名与覆盖规则

- 默认冲突策略：first-party 优先，不被官方覆盖
- 当前唯一白名单特例：`mcp-builder`
- `mcp-builder` 保留原名称，但运行面来自 `community/anthropic/skills/mcp-builder`
- 旧的 `shared/skills/mcp-builder` 退出 first-party 真源

## 2. 为什么这样落地

### 2.1 保留本地真源，而不是直接依赖官方安装

你们仓库已经承载了几个必须本地持有的职责：

- 统一安装入口
- Claude / Codex 双运行时适配
- source pin 与回滚能力
- quick check / runtime acceptance / 全量测试

所以正确的做法不是“直接删本地然后跟官方跑”，而是：

- 官方内容做上游镜像真源
- 当前仓库继续做安装、适配、验证与治理壳

### 2.2 `skill-creator` 与 `new-skills` 不是替代关系

- 官方 `skill-creator`：通用创作、测试、benchmark、优化工作台
- 本地 `new-skills`：你们自己的创建入口、模板、组织门禁、Codex 暴露层

结论：

- 官方 `skill-creator` 可以纳管并安装
- 本地 `new-skills` 不删除

### 2.3 `mcp-builder` 允许官方接管

`mcp-builder` 是当前唯一明确适合切官方正文的同名 skill，因为：

- 官方版本更完整，包含 `reference/` 与 `scripts/`
- 你已经明确希望统一管理但用官方版本
- 现有安装链可以通过白名单规则安全接管该名称

结论：

- `mcp-builder` 名称保留
- 内容迁入 `community/anthropic/skills/mcp-builder`
- Codex 适配改放 `community/anthropic/codex/skills/mcp-builder/agents/openai.yaml`

## 3. 当前落地方案

### 3.1 目录分层

- `shared/skills/`：只放 first-party skills
- `community/superpowers/skills/`：本地 runtime 基线与 overlay
- `community/anthropic/skills/`：全量官方 17 个 skills 镜像
- `community/anthropic/codex/skills/`：全量官方 skills 的 Codex adapters

### 3.2 安装顺序

运行时合成顺序固定为：

1. `shared/skills`
2. `community/superpowers/skills`
3. `community/anthropic/skills`

含义是：

- first-party 默认优先
- 官方 skills 默认只补充，不覆盖同名 first-party
- 只有 `mcp-builder` 例外，允许官方覆盖

### 3.3 来源锁定

官方来源统一锁在 `[community/SOURCES.yaml](/Users/lijieli/org-claude-skills/community/SOURCES.yaml)`：

- repo：`https://github.com/anthropics/skills`
- ref：`98669c1133fd06cc4c5eccefc81933756d71d26d`
- captured_at：`2026-04-02`

## 4. 对原始观点的保留挑战

### 4.1 工程治理挑战

被挑战观点：

- “官方看起来常用，所以直接删本地就行”
- “统一管理和直接跟官方不会冲突”

反方结论：

**如果没有本地 vendoring、适配和安装链，复杂度不会消失，只会转移成版本漂移、冲突排查和双运行时缺口。**

### 4.2 组织落地挑战

被挑战观点：

- “删掉本地重复技能一定更省维护”

反方结论：

**真正昂贵的不是 skill 文本本身，而是 owner、pin 版本、验收、回滚、培训和冲突治理。**

因此本次只删除一个明确可切换的对象：

- 删除旧 first-party `mcp-builder`

而不会删掉：

- `new-skills`

## 5. 变更后的帮助与收益

### 5.1 对你们的直接收益

- 当前仓库继续统一管理，心智模型不变
- 官方 skills 可以本地直接安装到 Claude / Codex
- 官方技能保持原文，减少二次维护成本
- 所有官方技能都有 Codex 适配，不再只服务 Claude

### 5.2 可学习的最佳实践

- upstream 镜像目录与 first-party 真源分层
- source lock 固定 commit，不追默认分支
- 安装时显式处理冲突优先级
- 适配层与正文分离，便于后续重生成
- 同步脚本只负责同步与生成，不混入业务改写

## 6. 主要来源

- Anthropic 官方仓库：<https://github.com/anthropics/skills>
- 当前仓库安装入口：[`install.sh`](/Users/lijieli/org-claude-skills/install.sh)
- 当前仓库来源锁：[`community/SOURCES.yaml`](/Users/lijieli/org-claude-skills/community/SOURCES.yaml)
- 当前仓库运行验收：[`docs/runtime-acceptance-sop.md`](/Users/lijieli/org-claude-skills/docs/runtime-acceptance-sop.md)
