# Skill 质量标准

被 `/new-skills` 流程和 `/scan` Agent5 引用。定义 SKILL.md 的质量评估维度和分级标准。

## 7 个质量维度

| 维度 | 定义 | L2 基线标准 | 反例 |
|------|------|------------|------|
| D1 结构合规 | 遵循 /new-skills 结构模板 | 五大节完整（HARD-GATE/角色/流程/输出/完成校验）+ 无建议性语言 + <=150 行 + 术语前后一致 | 用"模式选择"替代"流程"节；同一 Skill 混用"检测"和"扫描"指代同一动作 |
| D2 闭环自治 | 独立运行时有完整生命周期 | 前置检查（不满足时终止+提示）+ 执行有异常路径 + 输出有明确路径 + 验证可机械执行 | 无异常处理路径，无输出产物定义 |
| D3 I/O 契约 | 输入输出有明确契约 | 输入声明（前置文件/状态）+ 输出路径模板 + 输出格式含必填字段 | 无前置条件、无输出路径 |
| D4 角色与对抗 | 角色三要素 + 审查类有偏差对抗 | 角色含定位+驱动+锚点；审查/验证类有 "NO verdict without evidence" 门控 | "你是分支隔离专家"——一句话身份 |
| D5 验证即证据 | 完成判定基于客观证据 | 每项 checklist 可机械判定（Grep/Bash/文件存在性）+ 禁止模糊结论词 | "用户确认理解准确"——主观判定 |
| D6 Token 效率 | SKILL.md 精简，详情在 references/ | <=150 行 + 方法论拆到 references/ + 表格化 > 段落 + reference 一层深（SKILL.md 直接引用，禁止 reference 嵌套引用 reference）+ >100 行的 reference 文件需 TOC | 6 个 Scan 规则全部内嵌；reference 文件再引用子文件导致运行时只部分读取 |
| D7 跨模型适配 | Skill 在不同模型下均可正确执行 | *(仅 L3 要求，见下方分级)* | Opus 正确但 Haiku 因指令不够具体而偏离 |

> D7 来源：Anthropic 官方最佳实践——"Test with all models you plan to use"。D7 仅作为 L3 卓越标准，非 L2 基线，原因：当前 Skill 体系主要在 Opus/Sonnet 上运行，Haiku 场景有限。

## 3 级分级

| 级别 | 定位 | 核心要求 |
|------|------|---------|
| L1 基础 | 最低可用 | frontmatter 完整 + HARD-GATE 存在 + 有流程步骤 + 有输出格式 + 有完成校验(>=3项) + <=150 行 |
| L2 闭环 | 目标基线 | L1 + 五大节完整 + 前置检查有终止行为 + 异常处理路径 + 角色三要素 + 验证可机械执行 + 输入输出声明 + 术语一致 |
| L3 卓越 | 最佳实践 | L2 + 熔断/退出机制 + 竞争框架(审查类) + FORBIDDEN 覆盖已知借口 + SKILL.md <80 行 + 压力测试场景 + 跨模型测试验证(D7) + 评估场景(>=3 个 evaluation case) |

## 评估方法

逐维度打分（PASS/PARTIAL/FAIL），按最低维度定级：
- D1-D6 全 PASS → L2
- 任一 FAIL → L1（该维度不满足基础要求时）
- 满足 L3 附加条件（含 D7）→ L3

> D7 不参与 L1/L2 定级，仅作为 L3 的必要条件。

## 适用场景

| Skill 类型 | 目标级别 |
|-----------|---------|
| Pipeline skill（product/design/tech-lead/project-manager/check/qa/fix） | >= L2，冲 L3 |
| 独立 skill（commit/review/debug/refactor 等） | >= L1，冲 L2 |
| 工具类 skill（worktree/overview 等） | >= L1 |

## 表达优先级

- 优先级：`结构 > 编号 > checklist > 强调样式`
- 先用章节表达层级，再用编号表达顺序，再用 checklist 表达完成标准
- `**` 只做少量硬强调，不承担主要结构职责

### 强调用法

| 该用 `**` | 不该用 `**` |
|-----------|------------|
| 终止/警告条件：`**终止并提示**`、`**立即暂停**` | 流程步骤标题：编号本身已表达结构 |
| 角色锚点（每 skill 最多 1 处） | 前置条件/输入标签：dash + 标签已够 |
| 高风险词、硬约束 | 输出格式标签：用 `###` 或无标记 |

### 量化约束

- 全文加粗行数 ≤ 10%
- 单行最多 1 处 `**`
- 普通步骤标题默认不加粗

## 反模式

- 把作者规范整段复制进运行时 `SKILL.md`
- 每一步都加粗
- 用建议句代替硬约束
- 先写长解释，再给执行规则
- 模板、规范、运行时 Skill 各自维护不同章节名

## Codex 双端兼容检查清单

新增或修改 Skill 时需确认以下条件（确保 Claude Code 和 Codex CLI/App 双端可用）：

| 检查项 | 必需 | 说明 |
|--------|------|------|
| SKILL.md 有 `name` + `description` | 是 | 两端共用的触发依据 |
| `description` 遵循 `{能力陈述}。Use when {触发场景}。` | 是 | Codex 靠此判断何时触发 |
| `agents/openai.yaml` 存在（仅 Codex 侧） | 是 | Codex UI 展示所需，由统一仓库 `shared/skills/*/agents/openai.yaml` 提供，安装时覆盖到 `~/.codex/skills/` |
| `short_description` 25-64 字符 | 是 | Codex UI 约束 |
| `default_prompt` 包含 `$skill-name` | 是 | Codex 触发模板 |
| Claude 专用字段（`user-invocable`、`allowed-tools`、`hooks`）| 可选 | 不影响 Codex，Claude Code 侧保留 |

> `openai.yaml` 由统一仓库维护（`shared/skills/{name}/agents/openai.yaml`），通过 `install.sh` 安装到 Codex 侧（`~/.codex/skills/{name}/agents/openai.yaml`）。如需批量刷新可运行 `tools/install/generate-all-openai-yaml.sh`。

## 标准来源

| 维度/规则 | 来源 |
|----------|------|
| D1-D5 | 自建体系（经自评验证） |
| D6 引用层级 + TOC | 官方最佳实践 |
| D7 跨模型适配 | 官方最佳实践 |
| L3 评估场景 | 官方最佳实践 |
| D1 术语一致性 | 两者一致（官方 + 自评） |
| 表达优先级 + 强调用法 | 三源综合（官方 + spec-kit + superpowers） |
