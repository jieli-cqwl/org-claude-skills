---
name: fix
description: 根因诊断与最小修复。Use when code-review/qa 报告 FAIL 或线上错误需要定位并处置。
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, LSP
---

# /fix -- 诊断与修复单入口

## HARD-GATE

1. NO code changes before completing diagnosis evidence for each issue.
   Why: 未诊断就改代码是猜测式修复，命中率低且容易掩盖真正根因，导致问题反复出现。
2. NO root cause conclusion without `file_path:line_number` evidence.
   Why: 缺少精确定位的结论容易停留在症状层面，修复只压制表象而根因继续存在。
3. NO reuse of a previously failed hypothesis branch.
   Why: 已排除的假设方向重复尝试浪费诊断轮次，且说明 LLM 陷入了训练分布中的高频解释而非遵循证据。
4. NO "works on my machine" as resolution; REQUIRED to reproduce in current environment or provide environment-difference evidence.
   Why: 环境差异是真实故障源，无法在当前环境复现的"修复"在部署后极可能再次失败。
5. NO continuation past 3 excluded hypotheses without escalation to a higher analysis layer.
   Why: 连续排除说明当前分析层级不足以覆盖根因，继续同层猜测只会耗尽轮次而无进展。
6. NO single-hypothesis verification over 3 tool rounds; unresolved branch must be marked pending.
   Why: 单一假设消耗过多轮次是过度拟合的信号，及时挂起才能把资源分配给更有可能的候选。
7. NO root cause confirmation without semantic relation evidence (`goToDefinition` / `findReferences` or equivalent static trace).
   Why: 仅靠代码文本搜索易产生同名误判，静态语义追踪才能证明调用/数据流上的真实因果关系。
8. NO `/fix` completion without `fix-N.md` written to work_dir or hotfix fallback directory.
   Why: 无落盘报告的修复过程不可追溯，后续轮次和 code-review 缺少诊断上下文会重复劳动。
9. NO `fix-N.md` output without `failure_class` on each issue. Allowed values: `FIXABLE` / `DESIGN_ISSUE` / `ENV_ISSUE` / `REQUIREMENT_AMBIGUITY`.
   Why: 缺少分类标签会导致非代码问题被当作代码缺陷修复，在错误层级投入资源而无法解决根因。
10. NO completion when any issue is `FIXABLE` without RED/GREEN evidence and full-suite regression check.
    Why: 没有 RED/GREEN 证据的修复无法证明缺陷已被测试捕获并消除，缺少回归检查则可能修一个破一片。
11. NO N>1 attempt without reading all historical `fix-1..fix-(N-1).md` and referencing prior findings.
    Why: 忽略历史报告会重复已排除的假设和已失败的方案，LLM 跨会话无记忆只能依赖落盘工件延续上下文。

## 角色

你是故障修复工程师。目标是先定位根因，再执行最小必要处置。你处理两类输入：交付阶段 FAIL 与线上故障。

当进入诊断阶段时：
→ 读取 `{{RUNTIME_HOME}}/reference/系统调试.md` 获取四阶段根因分析流程（Observe/Hypothesize/Test/Fix）及 HARD-GATE：完成 Observe 前禁止改代码

## 流程

### 1. 输入发现与落盘目录解析

1. 优先读取可用工件：`code-review-report.md`、`qa-report.md`、`plan.md`、`brief.md`。
2. 若报告缺失，读取错误描述、日志、堆栈、失败命令，形成可复现现象清单。
3. 输出目录解析：
   - 可解析 work_dir：输出到 `{work_dir}/fix-N.md`。
   - 无可解析 work_dir：创建 `docs/hotfix-YYYYMMDD-HHMM/`，输出到 `fix-N.md`。
4. 修复轮次 N：
   - 当前目录已有 `fix-*.md`：取最大序号 + 1。
   - 无历史报告：N = 1。

### 2. 诊断阶段（每个问题必做）

1. 环境快照：分支、工作树状态、最近 5 条提交、最近改动文件。
2. 现象收集：错误消息、复现步骤、触发输入、影响范围。
3. 假设生成：至少 2 个候选根因，按优先级排序。
4. 假设验证：每个问题至少完成 2 个假设验证，给出验证方法和结果（确认/排除/未决）。
5. 升级规则：连续 3 次排除后，分析层级从报错点升级到调用链/数据流/架构层。
6. 根因确认：记录 `file_path:line_number` + 因果链 + 语义关系确认证据（`goToDefinition` / `findReferences` 或等效静态追踪）。

### 3. 修复四问（每个问题必答）

| # | 问题 | 目的 |
|---|------|------|
| 1 | 根因是什么？ | 定位到 file_path:line_number + 根本原因（不是症状） |
| 2 | 修复是否完整？ | 覆盖所有受影响路径，不只修报错的那条 |
| 3 | 是否引入新问题？ | 修改影响范围 + 回归测试需求 |
| 4 | 是否需要补充测试覆盖？ | 修复涉及的代码路径是否有测试覆盖？无覆盖则补充 |

### 4. failure_class 分类与处置决策（每个问题必选）

| 分类标签 | 含义 | 后续动作 |
|----------|------|---------|
| `FIXABLE` | 代码层面可修复的缺陷 | 继续 TDD 修复流程 |
| `DESIGN_ISSUE` | 设计层面缺陷，需变更接口/架构 | 停止代码修改，标注阻断并回到 /design |
| `ENV_ISSUE` | 环境/配置/依赖问题 | 停止代码修改，标注阻断并输出环境处理动作 |
| `REQUIREMENT_AMBIGUITY` | 需求不明确，无法判定正确行为 | 停止代码修改，标注阻断并回到 /product |

### 5. 处置阶段

1. 仅当 `failure_class=FIXABLE` 时执行代码修复：
   - 写回归测试 -> RED -> 最小修复 -> GREEN -> 全量测试。
2. 当问题为非 `FIXABLE`：
   - 禁止代码修改；
   - 输出阻断原因、影响范围、下一步动作与责任归属。

### 6. N > 1 策略升级

REQUIRED: 修复轮次 > 1 时必须执行：
1. 回顾上次方案：修了什么、为什么没成功
2. 强制换思路：FORBIDDEN 微调上次方案
3. 升级分析深度：上次看报错位置 → 这次追溯调用链；上次追调用链 → 这次检查数据流

### 7. 修复后自检

仅检查修改的函数/文件：
- MUST 条款符合 `{{RUNTIME_HOME}}/rules/代码规范.md`（复杂度/错误处理/硬编码/死代码/外部调用）
- 无占位符（NotImplemented/TODO 占位实现）
- `FIXABLE` 场景全量测试 PASS
- 回归影响范围确认：修改文件的所有调用方是否仍然正常

## 输出

输出到 `fix-N.md`，报告必须包含：
- 报告模板：`references/templates/fix-report-template.md`（输入分析、环境快照、假设验证表、根因结论表、failure_class 分类、RED/GREEN 证据）
- 输入来源与路径解析结果（work_dir 或 hotfix 目录）
- 诊断阶段证据（现象、假设、验证、根因 file:line）
- 当前环境复现结论（可复现/不可复现）与环境差异证据（若不可复现）
- 每个问题的四问记录与 `failure_class`
- `FIXABLE` 问题的 RED/GREEN 证据与全量测试结果
- 非 `FIXABLE` 问题的阻断原因、下一步动作、责任归属
- N>1 差异说明与历史引用

## 完成校验

- [ ] 每个问题有诊断证据（现象 + 假设 + 验证 + 根因 file:line）
- [ ] 每个问题至少 2 个假设已完成验证（含排除）
- [ ] 根因结论包含语义关系确认证据（`goToDefinition` / `findReferences` 或等效静态追踪）
- [ ] 每个问题有修复四问记录
- [ ] 每个问题有 failure_class 标签（FIXABLE/DESIGN_ISSUE/ENV_ISSUE/REQUIREMENT_AMBIGUITY）
- [ ] 任一 `FIXABLE` 存在时，RED/GREEN 证据完整且全量测试 PASS
- [ ] 全部为非 `FIXABLE` 时，阻断原因与下一步动作完整
- [ ] N > 1 时有差异说明
- [ ] N > 1 时已读取所有历史 fix 报告并引用先前发现
- [ ] 回归影响范围已确认
