# Agent5: Skills 质量扫描规则 v2

> 引用者：scan（Agent 5）| 评估标准：`{{RUNTIME_HOME}}/reference/Skill质量标准.md`

## 前置条件

项目含自定义 Skills 目录。默认扫描 `.claude/skills/`；仓库若有更明确约定，按实际路径。缺失时输出"项目无自定义 Skills，跳过扫描"，不计入健康度评分。

## 扫描目标

项目级自定义 Skills 目录下所有 `SKILL.md`。默认扫描 `.claude/skills/`，按目录中的实际文件扫描。全局 `{{RUNTIME_HOME}}/skills/` 不作为项目级扫描目标。

## 扫描边界

scan 只消费 Skill 质量标准 v2 的静态可检测子集。scan 输出健康信号，不输出最终质量裁决。最终 PASS/PARTIAL/FAIL 需要结合上下文、eval、runtime artifact、fresh proving command 和人工复核。

## 检测规则

### R1: 触发与路由合同（D1）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| frontmatter 缺失 | Grep `^---` 前 3 行无匹配 | 严重 |
| `name` 缺失 | frontmatter 无 `name:` | 严重 |
| `description` 缺失 | frontmatter 无 `description:` | 严重 |
| 缺少 Use when | frontmatter `description:` 不含 `Use when` | 警告 |
| description 含会话身份词 | description 含 `我\|你\|I \|You ` | 警告 |
| manual-only 暴露不一致 | Claude 声明 manual-only 但 Codex adapter 仍自动暴露 | 严重 |
| 邻近 Skill 路由不清 | description 与相邻 Skill 能力重叠且无分流说明 | 警告 |

### R2: 渐进加载与上下文预算（D2）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 行数超标 | 按 `Skill质量标准.md` 的类型分档检查 `SKILL.md` 行数 | 严重 |
| reference 文件不存在 | SKILL.md 内 `references/X.md` 路径无法解析 | 严重 |
| reference 嵌套引用 | `references/*.md` 内再引用 `references/` | 警告 |
| 大 reference 无目录 | reference 文件 `wc -l > 100` 且无 `## Contents` 或 `## 目录` | 提示 |
| 裸路径引用 | SKILL.md 只写路径，未写触发条件和内容预期 | 警告 |
| 资源目录混用 | examples/rules/schemas/evals/scripts 内容混入 reference 且无消费者说明 | 提示 |

### R3: 输入输出与 artifact 合同（D3）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 无输入声明 | Grep `输入\|前置条件\|Input\|## 输入` 无匹配 | 警告 |
| 无输出路径 | Grep `输出到\|Output\|\\.md\|\\.json` 无匹配 | 警告 |
| JSON artifact 无 schema | 声明 `.json` runtime artifact 但无 `schemas/` 或 schema 引用 | 严重 |
| 派生视图无来源 | 声明 Markdown/HTML 报告但未说明来自 JSON 或上游源 | 警告 |
| 输出无消费者 | 输出格式有字段但未说明消费方 | 警告 |

### R4: 执行安全与权限边界（D4）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| `allowed-tools` 缺失 | frontmatter 无 `allowed-tools:` 且 Skill 涉及审计、验证、脚本或外部操作 | 警告 |
| review/audit 默认写权限 | review/audit/explain 类 Skill frontmatter 含 `Edit\|MultiEdit\|Write` | 严重 |
| scripts 无 manifest | 存在 `scripts/` 但无 manifest 或脚本准入说明 | 严重 |
| hook 无 adapter 合同 | 存在 `hooks/` 或 hook 字样但无 owner、failure state、rollback | 严重 |
| 删除/提交/迁移/外部写权限未隔离 | Skill 提及 delete/commit/deploy/migrate/迁移/external write API/POST/PUT/PATCH/curl/requests 写调用，但无本轮授权和精确范围说明 | 严重 |
| 裸 Bash 写入风险 | 审计、review、explain 类 Skill 暴露裸 `Bash`，且无 manifest runner 或只读命令边界 | 严重 |

### R5: 流程自治与异常控制（D5）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| HARD-GATE 缺失 | Grep `## HARD-GATE` 无匹配 | 严重 |
| 无流程骨架 | Grep `## 流程\|## Workflow` 无匹配 | 严重 |
| 无前置终止 | Grep `终止\|停止\|STOP\|缺失` 无匹配 | 警告 |
| 无失败路径 | 文档内无失败、异常、错误或阻塞处理描述 | 警告 |
| SubAgent/fork 无 handoff | 提及 SubAgent/fork 但无输入合同、输出合同或接受标准 | 警告 |

### R6: 验证与证据（D6）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 完成校验缺失 | Grep `## 完成校验\|## Verification` 无匹配 | 严重 |
| 校验项不足 | 完成校验 section 内 `- [ ]` 计数 < 3 | 警告 |
| 结论缺少证据字段 | 审计/验证类 Skill 输出不含 file/evidence/impact/verification | 严重 |
| fresh command 缺失 | 声称验证结果但无 fresh proving command 字段 | 警告 |
| eval 无复跑口径 | 存在 `evals/` 但无 runner、assertions 或 pass/fail condition | 警告 |

### R7: 人类可读与组织复用（D8）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| examples 无消费者 | 存在 `examples/` 但文件内无 Consumer 字段或消费说明 | 提示 |
| 术语不一致 | 同一 Skill 混用多个词指代同一动作 | 提示 |
| 报告视图不可追溯 | 声明报告模板但无 source/ref/hash/renderer 信息 | 提示 |

### R8: 演化与兼容性（D7）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| retired Skill 仍暴露 | 已退役 Skill 仍存在于运行时安装路径或 adapter | 严重 |
| Codex adapter 缺失 | 目标为 Codex 自动暴露但缺少 `agents/openai.yaml` | 严重 |
| adapter 与 description 漂移 | `agents/openai.yaml` 的 default_prompt 与 description 能力不一致 | 警告 |
| 来源锁定缺失 | community/canonical 来源无 source lock 或本地补丁边界 | 警告 |
| 跨模型证据缺失 | L3 申明无跨模型触发或格式遵循证据 | 警告 |

## 严重度映射

| 条件 | 严重度 |
| --- | --- |
| D1、D4、D6 硬失败 | 严重 |
| 其他维度 FAIL | 警告 |
| PARTIAL 或可读性问题 | 提示 |

## 评级输出

每个 Skill 输出 v2 静态健康信号：

| 输出 | 含义 |
| --- | --- |
| `static_pass` | 静态可检测项未发现阻塞 |
| `static_warn` | 存在警告或提示，需要人工复核 |
| `static_fail` | 存在严重问题，需要进入修复或 optimizer 审计 |

scan 不直接输出最终 L1/L2/L3。完整评级按 `{{RUNTIME_HOME}}/reference/Skill质量标准.md`，结合 runtime evidence、eval、fresh command 和人工复核裁决。
