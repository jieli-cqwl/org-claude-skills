# Agent5: Skills 质量扫描规则

> 引用者：scan（Agent 5）| 评估标准：`{{RUNTIME_HOME}}/reference/Skill质量标准.md`

## 前置条件

项目含自定义 Skills 目录。默认扫描 `.claude/skills/`；仓库若有更明确约定，按实际路径。缺失时输出"项目无自定义 Skills，跳过扫描"，不计入健康度评分。

## 扫描目标

项目级自定义 Skills 目录下所有 `SKILL.md`。默认扫描 `.claude/skills/`，按目录中的实际文件扫描。全局 `{{RUNTIME_HOME}}/skills/` 不作为项目级扫描目标。

## 扫描边界

scan 只消费 Skill 质量标准的静态可检测子集。scan 输出健康信号，不输出最终质量裁决。最终 PASS / FAIL / WARN 需要结合 runtime reachability、eval、runtime artifact、fresh proving command 和人工复核。

## 检测规则

### R0: 准入门禁（G0-G2）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| `SKILL.md` 缺失 | Skill 目录下无 `SKILL.md` | 严重 |
| frontmatter 缺失 | Grep `^---` 前 3 行无匹配 | 严重 |
| `name` 缺失 | frontmatter 无 `name:` | 严重 |
| `description` 缺失 | frontmatter 无 `description:` | 严重 |
| `name` 格式非法 | `name` 非 lowercase hyphen、超过 64 字符、以 hyphen 开头/结尾、含连续 hyphen、含 XML tag 或与父目录名不一致 | 严重 |
| `description` 格式非法 | `description` 为空、超过 1024 字符或含 XML tag | 严重 |
| 引用关键资源不存在 | `SKILL.md` 中引用的 repo-local `references/`、`resources/`、`scripts/`、`schemas/`、`evals/` 路径无法解析 | 严重 |
| runtime 可达性缺证据 | 声明 Codex 自动暴露但缺 `agents/openai.yaml`，或 manual-only/disabled/retired 暴露状态不一致 | 严重 |

### R1: Discovery & Trigger（S1）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 缺少 Use when 或等价触发说明 | frontmatter `description:` 不含触发场景 | 警告 |
| description 含会话身份词 | description 含 `我\|你\|I \|You ` | 警告 |
| description 过泛 | description 只写能力名，如 helper、tools、process data | 警告 |
| manual-only 暴露不一致 | Claude 声明 manual-only 但 Codex adapter 仍自动暴露 | 严重 |
| 邻近 Skill 路由不清 | description 与相邻 Skill 能力重叠且无分流说明 | 警告 |
| 多 Skill 仲裁缺失 | 同一目录下 3 个以上 description 命中同一任务关键词，且无 priority/mutual_exclusion/fallback/explicit invocation 规则 | 警告 |

### R2: Task Contract（S2）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 目标合同缺失 | Grep `目标\|Goal\|成功标准\|完成边界` 无匹配 | 警告 |
| 非目标/边界缺失 | 多能力或高风险 Skill 无 `不处理\|非目标\|边界\|Scope` | 警告 |
| 成功标准不可证明 | 声称完成但无产物、命令、eval、证据字段或消费者 | 警告 |
| 目标口号化 | 含 `提升质量\|完善\|合理处理\|充分考虑` 且无判据 | 警告 |

### R3: Professional Workflow（S3）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| HARD-GATE 缺失 | Grep `## HARD-GATE` 无匹配 | 严重 |
| 无流程骨架 | Grep `## 流程\|## Workflow\|Default Flow` 无匹配 | 严重 |
| SOP 动作不可定位 | 流程 section 内缺少 `读取\|判断\|执行\|输出\|验证\|停止\|Read\|Check\|Run\|Write\|Verify\|Stop` | 警告 |
| 无前置终止 | Grep `终止\|停止\|STOP\|缺失` 无匹配 | 警告 |
| 无失败路径 | 文档内无失败、异常、错误或阻塞处理描述 | 警告 |
| 步骤产物缺消费者 | 多阶段流程含 output/artifact 但无 consumer/next/handoff 说明 | 警告 |
| 高自由度步骤无边界 | 提及 explore/research/brainstorm/agent team 等高自由度步骤但无 freedom_level、最大轮次、停止条件或用户确认规则 | 警告 |
| 复杂流程无结构化表达 | 提及 SubAgent、pipeline、handoff、分支、状态或回退，但无流程图、流程表、状态表或 mermaid/digraph | 警告 |
| SubAgent/fork 无 handoff | 提及 SubAgent/fork 但无输入合同、输出合同或接受标准 | 警告 |

### R4: Resource Architecture（S4）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 行数预算超出 | 固定行数预算只产生 warning-level signal；需要人工判断是否造成 active path 噪音或加载边界问题 | 警告 |
| reference 嵌套引用 | `references/*.md` 内再引用 `references/` | 警告 |
| 大 reference 无目录 | reference 文件 `wc -l > 100` 且无 `## Contents` 或 `## 目录` | 提示 |
| 裸路径引用 | `SKILL.md` 只写路径，未写触发条件和内容预期 | 警告 |
| `resources/` 路由缺合同 | `resources/` 路由未说明加载时机、用途、产物、消费方和验证价值 | 警告 |
| plugin-level 资源无所有权 | 顶层 hooks/agents/assets/commands/adapter metadata 被 Skill 消费但无 owner、trigger、sync 或移除边界 | 警告 |
| 资源目录混用 | examples/rules/schemas/evals/scripts 内容混入 reference 且无消费者说明 | 提示 |
| 主体职责混杂 | 主流程中内嵌长方法论、长示例、评分细则或模板正文，且无资源分层说明 | 警告 |
| 渐进加载合同不完整 | `SKILL.md` 路由资源时缺少加载时机、用途、产物、消费方或验证价值 | 警告 |
| description 触发词未前置 | description 过长且关键触发词靠后，可能被 Skill 列表预算截断 | 提示 |

### R5: Runtime Fit & Safety（S5）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| `allowed-tools` 语义误用 | 文档把 `allowed-tools` 描述为完整安全边界、deny list 或权限限制，而非预授权/放行工具 | 严重 |
| `allowed-tools` 缺失 | frontmatter 无 `allowed-tools:` 且 Skill 涉及审计、验证、脚本或外部操作 | 警告 |
| review/audit 默认写权限 | review/audit/explain 类 Skill frontmatter 含 `Edit\|MultiEdit\|Write` | 严重 |
| scripts 无 manifest | 存在 `scripts/` 但无 manifest 或脚本准入说明 | 严重 |
| hook 无 adapter 合同 | 存在 `hooks/` 或 hook 字样但无 owner、failure state、rollback | 严重 |
| 删除/提交/迁移/外部写权限未隔离 | Skill 提及 delete/commit/deploy/migrate/迁移/external write API/POST/PUT/PATCH/curl/requests 写调用，但无本轮授权和精确范围说明 | 严重 |
| 裸 Bash 写入风险 | 审计、review、explain 类 Skill 暴露裸 `Bash`，且无 manifest runner 或只读命令边界 | 严重 |
| 来源锁定缺失 | community/canonical 来源无 source lock、license 或本地补丁边界 | 警告 |
| 外部内容信任策略缺失 | 提及 URL/fetch/download/curl/remote/community install 但无 fetch policy、版本锁定、内容校验、缓存锁或 untrusted-content 处理 | 严重 |
| 数据流声明缺失 | 涉及敏感路径、外部 API、日志、遥测、共享容器或上传下载，但无 data flow、ZDR/保留策略或清理边界 | 严重 |

### R6: Artifact Contract（S6）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 无输出路径 | Grep `输出到\|Output\|Artifact\|\\.md\|\\.json` 无匹配 | 警告 |
| 输出无消费者 | 输出格式有字段但未说明消费方 | 警告 |
| JSON artifact 无 schema | 声明 `.json` runtime/state/audit artifact 但无 `schemas/` 或 schema 引用 | 严重 |
| 派生视图无来源 | 声明 Markdown/HTML 报告但未说明来自 JSON 或上游源 | 警告 |
| 状态字段无 owner | 机器消费字段无 owner、validator、drop condition 或 failure state | 严重 |

### R7: Verification Loop（S7）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 完成校验缺失 | Grep `## 完成校验\|## Verification\|Completion Check` 无匹配 | 严重 |
| 校验项不足 | 完成校验 section 内 `- [ ]` 计数 < 3，且 Skill 非轻量 instruction-only | 警告 |
| 成功证据不可回放 | 声称 PASS/完成/通过，但无目标合同、产物路径、命令、eval 或证据字段 | 警告 |
| 结论缺少证据字段 | 审计/验证类 Skill 输出不含 file/evidence/impact/verification | 严重 |
| fresh command 缺失 | 声称验证结果但无 fresh proving command 字段 | 警告 |
| eval 无复跑口径 | 存在 `evals/` 但无 runner、assertions 或 pass/fail condition | 警告 |
| proof command 表演 | proof command 只证明文件存在或 grep 命中，未绑定成功标准 | 警告 |

### R8: Evolution & Integration（S8）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| retired Skill 仍暴露 | 已退役 Skill 仍存在于运行时安装路径或 adapter | 严重 |
| adapter 与 description 漂移 | `agents/openai.yaml` 的 default_prompt 与 description 能力不一致 | 警告 |
| runtime catalog 漂移 | catalog、install 暴露、adapter 和 Skill 本体状态不一致 | 严重 |
| 兼容入口无失效条件 | 保留旧入口、alias 或 compatibility 但无移除条件 | 警告 |
| 多 runtime adapter 漂移 | `.claude-plugin/`、`.codex-plugin/`、`.cursor-plugin/`、`.opencode/`、`gemini-extension.json` 或 `agents/openai.yaml` 中的 description/default_prompt/manual-only 策略不一致且无说明 | 警告 |
| 移除影响面缺失 | 退役、迁移或归档说明未覆盖 alias、catalog、install entry、adapter metadata、测试 fixture 和入站引用清理 | 警告 |
| 跨模型证据缺失 | L3/L4 申明无跨模型触发或格式遵循证据 | 警告 |

### R9: Behavioral Evidence（E1-E5）

| 检测项 | 方法 | 严重度 |
| --- | --- | --- |
| 最佳实践声明无 baseline | 声称 best practice、L3/L4、显著提升或 retain，但无 with/without 或 old/new 证据 | 警告 |
| assertions 不可验证 | eval assertions 含 `good\|better\|高质量` 等不可观察描述 | 警告 |
| 成本数据缺失 | benchmark 声称提效但无 token/time/failure-rate 记录 | 提示 |
| 反证样本缺失 | 只有成功样例，无误触发、失败、边界或无提升样例 | 提示 |

## 严重度映射

| 条件 | 严重度 |
| --- | --- |
| G0-G2 阻断、S5 安全边界失败、S7 完成门禁失败 | 严重 |
| 其他运行质量 FAIL | 警告 |
| E1-E5 缺证据但未声称 L3/L4/retain | 提示 |
| COMMENT 或表达口径问题 | 提示 |

## 评级输出

每个 Skill 输出静态健康信号：

| 输出 | 含义 |
| --- | --- |
| `static_pass` | 静态可检测项未发现阻塞 |
| `static_warn` | 存在警告或提示，需要人工复核 |
| `static_fail` | 存在严重问题，需要进入修复或 harness 审计 |

scan 不直接输出最终 L1/L2/L3/L4。完整评级按 `{{RUNTIME_HOME}}/reference/Skill质量标准.md`，结合 runtime evidence、eval、fresh command 和人工复核裁决。
