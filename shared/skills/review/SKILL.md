---
name: review
user-invocable: true
disable-model-invocation: true
description: 深度代码审查与改进建议。Use when 需要审查代码变更、PR review、代码质量评估或想要第二双眼睛检查实现。
eval-type: mixed
argument-hint: "[scope: 审查-A|审查-B|审查-C|full]"
allowed-tools: Read, Write, Bash, Glob, Grep, LSP, Agent
---

# /review -- 深度代码审查

## HARD-GATE

1. NO approval without checking all 10 dimensions (正确性, 安全性, 错误处理, 并发/状态, 设计, 测试覆盖, 注释准确性, 向后兼容, 性能, 可观测性).
   - Why: 跳过任何维度会产生审查盲区，该维度的缺陷直接逃逸到生产环境。
2. NO partial review: 无论改动大小，都必须完成十维全覆盖。
   - Why: 小改动常被误判为"不需要全面审查"，但单行变更也会引入安全漏洞或破坏向后兼容。
3. NO finding without file_path:line_number evidence.
   - Why: 无定位的 finding 无法被开发者复现和修复，沦为不可操作的意见而非可追踪的缺陷。
4. NO finding without confidence score; confidence < 80 不得计入正式结论。
   - Why: 低置信度 finding 混入正式结论会稀释审查信号，开发者在噪音中遗漏真正的高危问题。
5. NO report without >= 2 excluded potential issues with evidence.
   - Why: 不记录排除项会导致审查深度不可验证——无法区分"确认无问题"和"根本没查"。
6. NO /review completion without writing `code-review-result.json` into当前 Phase 工作区。
   - Why: 审查结论不落盘会导致下游 QA、delivery-owner 和 readiness gate 无法引用 canonical 审查证据，质量链断裂。
7. NO Critical/High finding without Verification 状态（Verified/False Positive/Inconclusive）。
   - Why: 未验证的高危 finding 存在误报风险，直接阻断交付会造成无谓延期；真实缺陷也会被忽略。

## Why

这一层说明 Review 的存在理由：用对抗性视角发现实现风险，并把可复现证据交给下游质量链路。

## How

先收口审查判断，再让脚本验证运行入口和交付出口；正文只保留评审维度、证据要求和结论合并规则。

## Protocol

按 HARD-GATE、流程、Scope、输出和完成校验推进。准入或交付不成立时，停止当前输出，读取 Failure Routing 层和脚本 emitted `failure_code` 后再处理。

## Script Contract

- Preflight: `shared/skills/review/scripts/check_preflight.sh` uses argv-only core checks; `shared/skills/review/scripts/preflight_check.sh` adapts hook payloads.
- Completion: `shared/skills/review/scripts/check_completion.sh` uses argv-only core checks; `shared/skills/review/scripts/completion_check.sh` preserves the legacy hook entry.
- Routing JSON follows `contracts/standard-chain-failure-routing.yaml`.

## Failure Routing

Use the owner and next action emitted by the registered `failure_code`. The current role repairs only code-review-result artifacts; verify-result or upstream implementation blockers return to the recorded owner.

## Reference Link

Reference routes live in the review references named by the active scope. Trigger: a review dimension needs method guidance; Read: only the named reference; Expect: the applicable review rule; Consume: code-review-result fields; Evidence: file:line findings, excluded investigations, and verification status; Sync: update this section when a referenced review protocol changes.

## Output Contract

Canonical output follows the code-review-result artifact contract; the response may summarize status, but downstream control reads canonical artifacts and gate results.

## 角色

你是对抗性代码审查者。定位：发现风险而非证明安全。驱动：按损害程度排序并输出可修复证据链。锚点：每条 finding 都要可定位、可验证、可复现。

目标边界：只审查已给定范围内的实现风险、证据完整性和交付阻断；完成边界是写出可由下游读取的 `code-review-result.json`，并用十维结论、file:line evidence、excluded investigations 和 verification status 支撑最终 gate。

## 前置条件

1. 必须获取有效审查范围（`git diff`、commit range 或用户指定文件列表）。
2. 必须定位当前 feature 与 UNIT 工作区路径（依据 `brief.json` 的 delivery plan / active registry）。
3. 必须读取 `{phase_dir}/plan.json`、`{phase_dir}/tasks.json`、相关 `developer-report.json` 与 `artifact-registry.json`。
4. 范围为空或路径无法定位时，终止并说明阻断原因。
5. 若范围触达 skill、eval、validator、artifact、installer、runtime gate 或会输出 PASS/decision/status 的脚本，必须执行证据链完整性专项，读取 `references/evidence-integrity-review.md`。

## 流程

### Step 1: 范围与基线

- 收集变更文件、变更统计、最近提交，确认本轮审查边界。
- 判定证据链完整性专项是否适用；触达 skill、eval、validator、artifact、installer、runtime gate 时标记为适用。
- 固化本轮输入包：
  - `review_scope`：`审查-A` / `审查-B` / `审查-C` / `full`
  - `phase_work_dir`：`docs/{feature}/phase-{N}`
  - `canonical_target`：`{phase_work_dir}/code-review-result.json`
  - `diff_refs`：git diff、commit range 或用户指定文件列表
  - `evidence_integrity`：`applicable` / `not_applicable` + 触发依据
- 任一输入缺失时输出阻断原因并停止；不得猜测 feature、Phase 或审查范围。

### Step 2: 并行评审

- 按 scope 创建对应 reviewer agents 并行执行（`full` 时 A+B+C 三个并行）：
  - A 组 prompt：`references/code-safety-reviewer-prompt.md`（正确性+安全性+错误处理+并发/状态，含置信度评分和排除调查）
  - B 组 prompt：`references/code-maintainability-reviewer-prompt.md`（设计+测试覆盖+注释准确性+向后兼容，含置信度评分和排除调查）
  - C 组 prompt：`references/code-performance-reviewer-prompt.md`（性能+可观测性，含置信度评分和排除调查）
- 每个 reviewer 必须返回中间包：
  - `review_group`：`A` / `B` / `C`
  - `dimension_verdicts`：本组覆盖维度的 `OK` / `ISSUE`
  - `findings`：仅含 `confidence >= 80` 的正式 finding，字段含 `file_path`、`line_number`、`severity`、`dimension`、`summary`、`recommendation`
  - `excluded`：至少 1 个已排除潜在问题，含证据引用
  - `notes`：只放合并时需要的人类阅读补充，不进入 canonical 必填字段
- reviewer agent 失败、超时或中间包缺字段时，本轮结论为 `COMMENT`，并在 `excluded` 或 findings 中记录阻断证据；不得补造该组结论。
- 首轮全 PASS 时强制做一次确认轮（防浅层通过）。

### Step 3: Verification

当验证 Critical/High findings 时：
→ 读取 `references/verification-protocol.md` 获取代码路径追踪、已有防护检查、上下文确认三步流程和 Verified/False Positive/Inconclusive 状态标记规则
- 输出每条 finding 的验证状态，未验证项不得作为最终阻断依据。
- `severity` 为 `S0` / `S1` 或文字严重度为 Critical / High 的 finding，`verification_status` 只能是 `Verified` / `False Positive` / `Inconclusive`。
- 非 Critical/High finding 若未进入专项验证，`verification_status` 写 `NOT_REQUIRED`。

### Step 4: 合并输出

- 汇总十维结论：`REVIEW_A_*`、`REVIEW_B_*`、`REVIEW_C_*`。
- 若证据链完整性专项适用，必须在报告中输出专项适用性、触发依据、EI-1 到 EI-10 的逐项状态表（`FINDING` / `EXCLUDED` / `NOT_OBSERVED` / `BLOCKED`）和已排除项；`ei_findings: []` 只能表示没有正式缺陷，不能替代逐项检查记录。
- 最终结论仅允许：`APPROVE` / `REQUEST_CHANGES` / `COMMENT`。
- 写入 `code-review-result.json` 前按模板组装：
  - `dimension_verdicts.review_a/b/c` 来自 A/B/C 中间包结论。
  - 十维字段全部写入 `OK` / `ISSUE`，缺失维度视为阻断并输出 `COMMENT`。
  - `findings` 只接收正式 finding；每条必须含 `file_path`、`line_number`、`confidence`、`verification_status`。
  - `excluded` 合并各组已排除项，总数不得少于 2。
  - `review_conclusion`：存在 Verified Critical/High 或证据链硬缺陷时为 `REQUEST_CHANGES`；存在阻断、缺证据或 Inconclusive 高危项时为 `COMMENT`；全部维度 OK 且排除项达标时为 `APPROVE`。
  - `gate_result` 与 `review_conclusion` 对齐：`APPROVE` 为 `PASS`，其余为 `FAIL`。

## Scope

| scope | 维度 |
|---|---|
| 审查-A | 正确性 + 安全性 + 错误处理 + 并发/状态 |
| 审查-B | 设计 + 测试覆盖 + 注释准确性 + 向后兼容 |
| 审查-C | 性能 + 可观测性 |
| full | 审查-A + 审查-B + 审查-C |

## 输出

- 输出文件：`docs/{feature}/phase-{N}/code-review-result.json`
- Runtime schema/template owns the JSON shape and required fields; SKILL.md only states review intent and evidence requirements.
- 人类投影视图由 projection contract 渲染，不作为 runtime 输出模板。

## FORBIDDEN

- Do NOT modify any source code file.
- Write tool ONLY for review report and related评审文件。

## 完成校验

- [ ] 十维审查全部覆盖，且有 `REVIEW_A/B/C` 结论
- [ ] 每条 finding 含 file_path:line_number + 置信度
- [ ] 报告中不存在置信度 < 80 的正式 finding
- [ ] 已排除潜在问题 >= 2，且有证据
- [ ] Critical/High findings 具备 Verification 状态
- [ ] 结论为 APPROVE / REQUEST_CHANGES / COMMENT 三选一
- [ ] skill/eval/validator/artifact/installer/runtime gate 改动已完成证据链完整性专项或写明不适用原因
