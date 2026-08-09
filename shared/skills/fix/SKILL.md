---
name: fix
user-invocable: true
description: "根因诊断与最小修复。Use when code-review/qa 报告 FAIL 或线上错误需要定位并处置。"
eval-type: mixed
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, LSP
---

# /fix -- 诊断与修复单入口

## HARD-GATE

1. REQUIRED: invoke `systematic-debugging` before classification or code changes; it is the sole owner of the diagnostic method.
   Why: `fix` consumes diagnosis results. Forking the investigation method here creates competing root-cause standards.
2. NO `/fix` completion without canonical `fix-result.json` written to work_dir or hotfix fallback directory.
   Why: 无落盘报告的修复过程不可追溯，后续轮次和 code-review 缺少诊断上下文会重复劳动。
3. NO `fix-result.json` output until each issue has a valid `failure_class` and owner-level disposition.
   Why: 缺少分类标签会导致非代码问题被当作代码缺陷修复，在错误层级投入资源而无法解决根因。
4. For `FIXABLE`, root-cause evidence must anchor the causal code or runtime boundary and prove the relevant call, data, state, or protocol relationship. Non-code classes use evidence appropriate to their boundary; they do not fabricate `file_path:line_number` or LSP traces.
   Why: 证据必须匹配故障机制，不能把代码定位模板硬套到环境、设计或需求问题。
5. NO completion when any issue is `FIXABLE` without RED/GREEN evidence and full-suite regression check.
    Why: 没有 RED/GREEN 证据的修复无法证明缺陷已被测试捕获并消除，缺少回归检查则可能修一个破一片。
6. NO N>1 attempt without reading all historical `fix-result.json` revisions and referencing prior findings.
    Why: 忽略历史报告会重复已排除的假设和已失败的方案，LLM 跨会话无记忆只能依赖落盘工件延续上下文。


## 角色

你是故障修复工程师。目标是先定位根因，再执行最小必要处置。你处理两类输入：交付阶段 FAIL 与线上故障。

诊断阶段调用 `systematic-debugging`，本 Skill 不复制或改写其阶段、假设和实验规则。`fix` 只负责把诊断结果映射为 failure classification、处置、规范工件和验证证据。

## 流程

状态表：

| 状态 | 动作 | 停止/转移 |
| --- | --- | --- |
| Input Discovery | 读取失败报告、日志、命令和历史 `fix-result.json` | 输入不足则补采；N>1 必须引用历史发现 |
| Diagnosis | 调用 `systematic-debugging` 并记录其诊断结果与证据 | 根因未确认则保持 unresolved，不进入代码修复 |
| Classification | 为每个 issue 写 `failure_class` 与 owner | 非 `FIXABLE` 停止代码修改并输出阻断动作 |
| Minimal Fix | 仅对 `FIXABLE` 做 RED → GREEN → regression | RED/GREEN 或全量回归缺失则不得完成 |
| Report | 写 `fix-result.json` 与证据摘要 | 缺 `diagnosis_status`、failure_class、CONFIRMED 对应的 `root_cause_ref` 或 proof command 则回到 Diagnosis |

### 1. 输入发现与落盘目录解析

1. 优先读取可用工件：`code-review-result.json`、`qa-result.json`、`plan.json`、`tasks.json`、`artifact-registry.json`、`brief.json`。
2. 若报告缺失，读取错误描述、日志、堆栈、失败命令，形成可复现现象清单。
3. 输出目录解析：
   - 可解析 work_dir：输出到 `{work_dir}/fix-result.json`。
   - 无可解析 work_dir：创建 `docs/hotfix--YYYYMMDD-HHMM/`，输出到 `fix-result.json`。
4. 修复轮次 N：
   - 当前目录已有 `fix-result.json` 历史 revision：取最大序号 + 1。
   - 无历史报告：N = 1。

### 2. 诊断阶段（每个问题必做）

1. 调用 `systematic-debugging` 完成根因调查；不得在本 Skill 中另起一套调试流程。
2. 把诊断结果写入报告：观察事实、复现或直接发生证据、实验结果、确认或 unresolved 状态、环境差异和剩余 blocker。
3. 为已确认根因记录与 failure class 匹配的 `root_cause_ref`：
   - `FIXABLE`：代码或 runtime boundary 锚点，以及调用、数据、状态或协议关系证据；
   - `DESIGN_ISSUE`：接口、架构或设计决策锚点；
   - `ENV_ISSUE`：配置、依赖、权限、命令或环境探针证据；
   - `REQUIREMENT_AMBIGUITY`：需求、AC、业务语义或决策缺口锚点。
4. 根因未确认时，不伪造 `root_cause_ref`；记录 unresolved 状态、现有证据、阻断项和下一步 owner。

### 3. 修复四问（每个问题必答）

| # | 问题 | 目的 |
|---|------|------|
| 1 | 根因是什么？ | failure class 对应的 evidence anchor + 因果机制；未确认则明确 unresolved |
| 2 | 修复是否完整？ | 覆盖所有受影响路径，不只修报错的那条 |
| 3 | 是否引入新问题？ | 修改影响范围 + 回归测试需求 |
| 4 | 是否需要补充测试覆盖？ | 修复涉及的代码路径是否有测试覆盖？无覆盖则补充 |

### 4. failure_class 分类与处置决策（每个问题必选）

| 分类标签 | 含义 | 后续动作 |
|----------|------|---------|
| `FIXABLE` | 代码层面可修复的缺陷 | 继续 TDD 修复流程 |
| `DESIGN_ISSUE` | 设计层面缺陷，需变更接口/架构 | 停止代码修改，标注阻断并回到 /design |
| `ENV_ISSUE` | 环境/配置/依赖问题 | 停止代码修改，标注阻断并输出环境处理动作 |
| `REQUIREMENT_AMBIGUITY` | 需求不明确，无法判定正确行为 | 停止代码修改，标注阻断并回到 /product-director（若涉及根问题/范围）或 /product-manager（若涉及 UNIT/AC 细化） |

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
- Code Changes rule satisfied: `{{RUNTIME_HOME}}/rules/code-changes.md`（scope, reuse, complexity, errors, configuration, dead code, external calls）
- 无占位符（NotImplemented/TODO 占位实现）
- `FIXABLE` 场景全量测试 PASS
- 回归影响范围确认：修改文件的所有调用方是否仍然正常

## 输出

输出到 `fix-result.json`，报告必须包含：
- 报告模板：`projections/fix-report-template.md`（输入分析、环境快照、假设验证表、根因结论表、failure_class 分类、RED/GREEN 证据）
- 输入来源与路径解析结果（work_dir 或 hotfix 目录）
- `systematic-debugging` 产出的诊断证据和确认/unresolved 状态
- 当前环境复现结论（可复现/不可复现）与环境差异证据（若不可复现）
- 每个问题的四问记录、`diagnosis_status`、`failure_class`；仅 CONFIRMED 写匹配故障边界的 `root_cause_ref`
- `FIXABLE` 问题的 RED/GREEN 证据与全量测试结果
- 非 `FIXABLE` 问题的阻断原因、下一步动作、责任归属
- N>1 差异说明与历史引用

## 完成校验

- [ ] 每个问题已调用 `systematic-debugging`，并记录诊断证据与确认/unresolved 状态
- [ ] 每个问题有修复四问记录
- [ ] 每个问题有 `diagnosis_status`（CONFIRMED/UNRESOLVED）；UNRESOLVED 不伪造 `root_cause_ref`
- [ ] 每个问题有 failure_class 标签（FIXABLE/DESIGN_ISSUE/ENV_ISSUE/REQUIREMENT_AMBIGUITY）
- [ ] `FIXABLE` 的 `root_cause_ref` 和关系证据指向实际代码或 runtime boundary；非代码分类使用对应边界证据
- [ ] 任一 `FIXABLE` 存在时，RED/GREEN 证据完整且全量测试 PASS
- [ ] 全部为非 `FIXABLE` 时，阻断原因与下一步动作完整
- [ ] N > 1 时有差异说明
- [ ] N > 1 时已读取所有历史 fix-result revision 并引用先前发现
- [ ] 回归影响范围已确认
