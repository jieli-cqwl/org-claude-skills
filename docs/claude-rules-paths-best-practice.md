# Claude Code rules `paths` 调研结论与最佳实践实施计划

## 1. 文档目的

本文系统整理本次关于 Claude Code `.claude/rules/*.md` 的 `paths` 能力调研、对当前仓库实现方式的评估结论，以及基于当前仓库结构可直接执行的实施计划，供外部 Claude 评审使用。

## 2. 问题定义

本次要回答三个问题：

1. Claude Code rules 的 `paths` 官方语义与最佳实践是什么。
2. 当前仓库“core rules 全量加载、reference 按语义触发”的方式是不是最佳实践。
3. 结合当前仓库真实实现，应该怎样落地更好的目标态。

## 3. 调研范围与证据来源

### 3.1 官方能力层证据

本次调研确认：Claude Code 官方支持 `.claude/rules/*.md` 使用 frontmatter `paths`。

结论级事实：
- 无 `paths` 的 rules 会无条件加载。
- 带 `paths` 的 rules 会在读取匹配文件时懒加载。
- `paths` 支持 glob、多 pattern、brace expansion。
- `InstructionsLoaded` hook 可观测规则加载事件，并区分 `load_reason`，包括 `session_start`、`path_glob_match`、`nested_traversal`、`include`、`compact`。

这意味着 `paths` 是真实可用的平台能力，不是猜测，也不是民间技巧。

### 3.2 当前仓库实现层证据

本次判断主要基于以下真实文件：

- `shared/assistant.md`
- `install.sh`
- `shared/rules/铁律.md`
- `shared/rules/执行纪律.md`
- `shared/rules/代码规范.md`
- `shared/rules/文档管理.md`
- `claude/settings/hooks-fragment.json`
- `shared/skills/developer/SKILL.md`
- `shared/skills/fix/SKILL.md`
- `shared/skills/scan/references/docs-scan-rules.md`

这些文件共同说明：当前仓库并不是“忘了用 paths”，而是已经形成了清晰的治理分层。

## 4. 当前仓库现状梳理

### 4.1 当前入口真源

`shared/assistant.md` 当前明确定义：

- `rules/`：行为红线，始终加载。
- `reference/`：技术规范，按语义触发读取。
- `hooks/`：自动化保障。
- `skills/`：开发流程技能。

关键证据见 `shared/assistant.md:16-40`。

这说明当前体系的设计中心是：

- 全局 rules 负责会话级行为底线。
- reference 负责场景化知识补充。
- hooks 负责自动化保障。
- skills 负责流程路由。

### 4.2 安装链的真实行为

`install.sh` 会把共享面物化到运行时目录：

- `shared/assistant.md` → runtime `CLAUDE.md` / `AGENTS.md`
- `shared/rules` 整体复制到 runtime `rules/`
- `shared/reference` 整体复制到 runtime `reference/`
- `shared/hooks` 整体复制到 runtime `hooks/`

关键证据见：
- `install.sh:563-591`
- `install.sh:593-621`

因此当前“rules 全量加载”的来源，是入口协作基线与安装链共同决定的，不是遗漏。

### 4.3 当前 hooks 现状

`claude/settings/hooks-fragment.json` 当前只包含：

- `PreToolUse`
- `PostToolUse`
- `PostCompact`
- `TaskCompleted`

关键证据见 `claude/settings/hooks-fragment.json:0-56`。

当前没有 `InstructionsLoaded`，因此缺少 rules 实际加载轨迹的运行时观测。

### 4.4 当前 skill 层已有场景化加载设计

现有 skill 已经在语义层做了场景化绑定，而不是把所有事情都塞给 `paths`：

- `shared/skills/developer/SKILL.md:96-99`
  - 自动加载：`rules/铁律.md` + `rules/代码规范.md` + `reference/测试规范.md`
- `shared/skills/fix/SKILL.md:44-46`
  - 诊断阶段读取 `reference/系统调试.md`
- `shared/skills/scan/references/docs-scan-rules.md:0-3`
  - 文档扫描场景显式引用 `rules/文档管理.md`

这说明当前仓库已经在使用“全局规则 + 场景 reference/规则引用”的混合模型。

## 5. 对 `paths` 的最佳实践判断

## 5.1 `paths` 适合解决什么问题

`paths` 适合把规则绑定到“文件工作面”，例如：

- 文档文件
- skill 文件
- hooks/settings 文件
- 特定子目录下的模板或协议文件

也就是说，`paths` 擅长回答：

> 我现在读的是哪类文件？

它不擅长回答：

> 我现在在做什么任务？

## 5.2 `paths` 不适合替代什么

`paths` 不适合替代：

- 会话级行为宪法
- 任务语义判断
- skill 状态机
- reference 的语义触发

原因是 `paths` 匹配的是文件，不是意图。

例如：
- “先复述再 AskUserQuestion 确认后执行”发生在很多读文件之前。
- “失败即停止、禁止降级”是会话级底线，不应只在某些文件被读到后才生效。
- “写测试时读 `reference/测试规范.md`”是任务语义，不是路径语义。

## 5.3 当前仓库是不是最佳实践

结论：**当前仓库不是错误实践，但还不是最佳落点。**

更准确地说：

- 当前“4 个 core rules 全局加载 + reference 按语义触发”的大方向是对的。
- 问题不在于“没把所有 rules 都 paths 化”。
- 真正缺的是：
  1. 对明显局部工作面的 path-local rules。
  2. 对 rules 实际加载行为的运行时观测。

所以当前仓库应优化成“混合模型”，而不是“全部 rules 改成 paths”。

## 6. 最佳实践裁决

最终裁决如下。

### 6.1 必须保留全局加载的 core rules

以下 4 个文件继续保持全局加载，不加 `paths`：

- `shared/rules/铁律.md`
- `shared/rules/执行纪律.md`
- `shared/rules/代码规范.md`
- `shared/rules/文档管理.md`

原因：
- 它们承担的是会话级或跨工作面的底线约束。
- 其中很多要求必须在读取目标文件前就已生效。
- 把它们 path-local 化会削弱 MUST/零容忍规则的生效边界。

### 6.2 应新增 path-local rules 的工作面

最适合新增 path-local rules 的 3 类工作面：

1. 文档面
2. skills 面
3. hooks/settings 面

原因：
- 这些约束天然依赖文件类型和目录上下文。
- 属于局部工作面规则，不应污染全局会话基线。
- 用 `paths` 绑定后更符合平台原生语义。

### 6.3 reference 继续保持语义触发

`reference` 不应用 `paths` 取代。

原因：
- `reference` 服务的是任务语义。
- 同一个文件可以在不同任务下需要不同 reference。
- `paths` 只能看文件，不理解“当前是在做测试 / 调试 / 设计 / 验证”。

### 6.4 hooks 负责观测与门禁，不承担规则语义

hooks 的职责应保持为：

- 阻断危险动作
- 自动化格式化或校验
- 记录运行轨迹

hooks 不应代替 rules 本身的语义表达。

## 7. 目标态设计

目标态采用四层模型：

1. **Core rules**：全局加载，负责行为宪法与 MUST 底线。
2. **Path-local rules**：按文件工作面懒加载，补充局部约束。
3. **Reference**：按任务语义触发读取，提供技术指南。
4. **Hooks**：负责门禁与观测，验证规则是否按预期工作。

这个目标态与当前仓库的已有设计兼容，不需要推翻重建。

## 8. 可直接执行的实施计划

下面是基于当前仓库结构的一次性实施计划。

### 8.1 本次改动范围

一次性改动 6 个文件：

1. 新增 `shared/rules/docs-local.md`
2. 新增 `shared/rules/skills-local.md`
3. 新增 `shared/rules/hooks-local.md`
4. 新增 `shared/hooks/instructions_loaded_audit.sh`
5. 修改 `claude/settings/hooks-fragment.json`
6. 修改 `shared/assistant.md`

### 8.2 本次明确不改的文件

以下文件本次不改：

- `shared/rules/铁律.md`
- `shared/rules/执行纪律.md`
- `shared/rules/代码规范.md`
- `shared/rules/文档管理.md`
- `install.sh`
- 各现有 `shared/skills/*/SKILL.md`
- `.claude/settings.local.json`

原因：
- 本次目标是补齐 path-local rules 与观测链路。
- 不是重写 core rules，也不是重写 skill 体系。

## 9. 逐文件实施说明

### 9.1 新增 `shared/rules/docs-local.md`

**目的**：把文档工作面的局部约束从全局规则中剥离出来，按文档文件工作面懒加载。

建议内容：

```md
---
paths:
  - docs/**/*.md
  - README.md
  - shared/reference/**/*.md
  - shared/protocols/**/*.md
  - shared/commands/**/*.md
---

# 文档工作面局部规则

## 适用范围
本文件只约束文档工作面，不替代全局 `rules/文档管理.md`。

## 工作面要求
- 修改路径、命名、目录结构时，同步更新入链和出链引用
- 同主题文档优先更新现有文件，禁止平行新增重复文档
- 已完成任务目录必须归档到 `docs/archive/`
- design 文档只写“是什么 / 为什么”，不写 checklist、阶段状态、待办列表
- README 中出现的命令、路径、入口名必须与当前仓库一致

## 验证要求
- 相对链接可达
- 文档中显式引用的路径存在
- README 中命令与真实入口一致
```

设计理由：
- 当前仓库文档量大，文档面约束有明显局部性。
- `docs-scan-rules.md` 已经体现出文档工作面扫描逻辑，适合补一个 path-local rule。
- 不替代 `rules/文档管理.md`，只补充工作面规则。

### 9.2 新增 `shared/rules/skills-local.md`

**目的**：把 skill 文件工作面的局部约束绑定到 `shared/skills/**`。

建议内容：

```md
---
paths:
  - shared/skills/**
---

# Skill 工作面局部规则

## 适用范围
本文件只约束 skill 工作面，不替代全局 `rules/执行纪律.md`。

## 编写要求
- skill 只定义本流程的入口、步骤、出口，禁止跨流程偷切换
- 依赖其他 skill 时，写显式 transition，不写隐式流程跳转
- 引用运行时路径时统一使用 `{{RUNTIME_HOME}}`
- skill 的补充说明、模板、参考资料优先就近放在 skill 自己目录下
- 不在 skill 文档里重复抄写全局 rules/reference 正文，直接引用路径
- 不把进度跟踪、实施 checklist 写进 design 类文档

## 验证要求
- skill 的入口条件、终止状态、交接对象明确
- 引用的本地 reference 文件存在
- 不出现用户机器绝对路径
```

设计理由：
- 当前 skill 数量多，工作面稳定。
- 很多约束只对 skill 目录有意义，不适合常驻全局上下文。

### 9.3 新增 `shared/rules/hooks-local.md`

**目的**：把 hooks 与 settings 的局部约束绑定到 hooks/settings 工作面。

建议内容：

```md
---
paths:
  - shared/hooks/**
  - claude/settings/**/*.json
---

# Hooks 工作面局部规则

## 适用范围
本文件只约束 hooks 与 hook settings 工作面。

## 编写要求
- hook 分为阻断型和观测型；观测型必须 `exit 0`
- matcher、command、timeout 必须显式声明
- hook 命令统一指向运行时 `$HOME/.claude/hooks/...`
- hook 不得放宽全局 MUST 规则
- 自动修正类 hook 只做可预期、幂等的格式化动作
- 观测日志单独落盘，不与业务输出混写

## 验证要求
- settings 中引用的 hook 文件都存在
- timeout 已配置
- 观测型 hook 不阻断主流程
```

设计理由：
- 当前 hooks-fragment 已具备明确工作面边界。
- hook 约束属于典型目录局部规则。

### 9.4 新增 `shared/hooks/instructions_loaded_audit.sh`

**目的**：记录 `InstructionsLoaded` 事件，观察 core rules 与 path-local rules 的真实加载行为。

建议脚本：

```bash
#!/usr/bin/env bash
set -euo pipefail

log_dir="$HOME/.claude/logs"
log_file="$log_dir/instructions_loaded.jsonl"

mkdir -p "$log_dir"
payload="$(cat)"
printf '%s\n' "$payload" >> "$log_file"
exit 0
```

设计理由：
- 只做观测，不做阻断。
- 不依赖 `jq`。
- 能直接沉淀原始 JSON 事件，后续再分析。

### 9.5 修改 `claude/settings/hooks-fragment.json`

**目的**：注册 `InstructionsLoaded` hook。

只新增一个顶层 block，其他现有 hook 保持不变：

```json
"InstructionsLoaded": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash $HOME/.claude/hooks/instructions_loaded_audit.sh",
        "timeout": 10
      }
    ]
  }
]
```

放置原则：
- 与 `PreToolUse`、`PostToolUse`、`PostCompact`、`TaskCompleted` 同级。
- 不修改现有 matcher、command、timeout。

### 9.6 修改 `shared/assistant.md`

**目的**：把当前 rules 的分层模型显式写出来。

只做两处修改。

#### 修改一：更新配置导航中的 `rules/` 说明

把：

```md
- `rules/` — 行为红线（始终加载）
```

改成：

```md
- `rules/` — 核心规则始终加载；带 paths 的局部规则按文件工作面加载
```

#### 修改二：新增“规则分层”小节

建议新增：

```md
## 规则分层

- Core rules：`rules/铁律.md`、`rules/执行纪律.md`、`rules/代码规范.md`、`rules/文档管理.md`，始终加载
- Path-local rules：`rules/*-local.md`，通过 frontmatter `paths` 在读取匹配文件时加载
- reference：按任务语义触发读取，不用 `paths` 替代意图判断
- hooks：负责阻断和观测，不承担规则语义本身
```

边界要求：
- 不修改 `reference 触发映射` 表。
- 不把 `reference` 改造成 path-local 体系。
- 不把 core rules 改成按路径加载。

## 10. 执行顺序

按以下顺序执行，不换序：

1. 新增 `shared/rules/docs-local.md`
2. 新增 `shared/rules/skills-local.md`
3. 新增 `shared/rules/hooks-local.md`
4. 新增 `shared/hooks/instructions_loaded_audit.sh`
5. 修改 `claude/settings/hooks-fragment.json`
6. 修改 `shared/assistant.md`
7. 运行真实验证
8. 验证通过后再决定是否提交

## 11. 验证标准

必须满足以下 5 条。

### 11.1 Core rules 仍然全局生效

新开 session 后，在未读取任何具体工作面文件前，core rules 仍然已生效。

### 11.2 docs-local 只在文档面触发

读取 `docs/**/*.md` 或 `README.md` 后，`instructions_loaded.jsonl` 中应出现 `docs-local.md`，且 `load_reason=path_glob_match`。

### 11.3 skills-local 只在 skill 面触发

读取 `shared/skills/**` 下任一文件后，日志中应出现 `skills-local.md`。

### 11.4 hooks-local 只在 hooks/settings 面触发

读取 `shared/hooks/**` 或 `claude/settings/**/*.json` 后，日志中应出现 `hooks-local.md`。

### 11.5 安装链不需要改

执行现有安装链后，运行时目录中应能看到：

- `rules/docs-local.md`
- `rules/skills-local.md`
- `rules/hooks-local.md`
- `hooks/instructions_loaded_audit.sh`

这里之所以不改 `install.sh`，是因为 `install.sh` 已经对 `shared/rules` 和 `shared/hooks` 做整体复制，见 `install.sh:563-591`。

## 12. 失败即停止的条件

出现任一情况，本次实施直接停止：

- `InstructionsLoaded` 事件未进入日志
- 任一 `*-local.md` 未按预期工作面触发
- core rules 被意外改成 path-local 才生效
- 安装链没有把新增 rules / hook 带入运行时目录

## 13. 回滚方案

回滚只做以下动作：

1. 删除 `shared/rules/docs-local.md`
2. 删除 `shared/rules/skills-local.md`
3. 删除 `shared/rules/hooks-local.md`
4. 删除 `shared/hooks/instructions_loaded_audit.sh`
5. 从 `claude/settings/hooks-fragment.json` 移除 `InstructionsLoaded` block
6. 把 `shared/assistant.md` 的 rules 分层说明恢复到原文

## 14. 最终结论

本次调研的最终结论不是“把所有 rules 都改成 paths”，而是：

- **保留 4 个 core rules 全局加载**
- **新增 3 个 path-local rules 绑定明确工作面**
- **新增 1 个 `InstructionsLoaded` 观测 hook**
- **保留 reference 的语义触发模型**
- **不修改现有 core rules 语义，不推翻当前 skill/reference 架构**

这才是当前仓库基于真实实现的最佳实践升级路径。
