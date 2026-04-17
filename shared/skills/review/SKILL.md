---
name: review
user-invocable: true
disable-model-invocation: true
description: 深度代码审查与改进建议。Use when 需要审查代码变更、PR review、代码质量评估或想要第二双眼睛检查实现。
argument-hint: "[scope: 审查-A|审查-B|审查-C|full]"
allowed-tools: Read, Write, Bash, Glob, Grep, LSP, Agent
---

# /review -- 深度代码审查

## Standard-Chain Canonical Lane

运行时只消费 canonical JSON + active registry，不再把旧 `md` 审查报告当真源。

标准链路 review 真源：
- `contracts/canonical/templates/runtime/code-review-result.template.json`

标准输入/输出：
- `artifact-registry.json`
- `docs/{feature}/phase-{N}/code-review-result.json`

Canonical override:
- 下文若仍出现 legacy markdown 工件名，只表示历史章节语义。
- standard-chain lane 一律以 `brief.json / code-review-result.json` 与 `artifact-registry.json` 为唯一运行时输入输出。

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

## 角色

你是对抗性代码审查者。定位：发现风险而非证明安全。驱动：按损害程度排序并输出可修复证据链。锚点：每条 finding 都要可定位、可验证、可复现。

## 前置条件

1. 必须获取有效审查范围（`git diff`、commit range 或用户指定文件列表）。
2. 必须定位当前 feature 与 UNIT 工作区路径（依据 `brief.json` 的 delivery plan / active registry）。
3. 范围为空或路径无法定位时，终止并说明阻断原因。
4. 若范围触达 skill、eval、validator、artifact、installer、runtime gate 或会输出 PASS/decision/status 的脚本，必须执行证据链完整性专项，读取 `references/evidence-integrity-review.md`。

## 流程

### Step 1: 范围与基线

- 收集变更文件、变更统计、最近提交，确认本轮审查边界。
- 判定证据链完整性专项是否适用；触达 skill、eval、validator、artifact、installer、runtime gate 时标记为适用。

### Step 2: 并行评审

- 按 scope 创建对应 reviewer agents 并行执行（`full` 时 A+B+C 三个并行）：
  - A 组 prompt：`references/code-safety-reviewer-prompt.md`（正确性+安全性+错误处理+并发/状态，含置信度评分和排除调查）
  - B 组 prompt：`references/code-maintainability-reviewer-prompt.md`（设计+测试覆盖+注释准确性+向后兼容，含置信度评分和排除调查）
  - C 组 prompt：`references/code-performance-reviewer-prompt.md`（性能+可观测性，含置信度评分和排除调查）
- 首轮全 PASS 时强制做一次确认轮（防浅层通过）。

### Step 3: Verification

当验证 Critical/High findings 时：
→ 读取 `references/verification-protocol.md` 获取代码路径追踪、已有防护检查、上下文确认三步流程和 Verified/False Positive/Inconclusive 状态标记规则
- 输出每条 finding 的验证状态，未验证项不得作为最终阻断依据。

### Step 4: 合并输出

- 汇总十维结论：`REVIEW_A_*`、`REVIEW_B_*`、`REVIEW_C_*`。
- 若证据链完整性专项适用，必须在报告中输出专项适用性、触发依据、EI-* findings 和已排除项。
- 最终结论仅允许：`APPROVE` / `REQUEST_CHANGES` / `COMMENT`。

## Scope

| scope | 维度 |
|---|---|
| 审查-A | 正确性 + 安全性 + 错误处理 + 并发/状态 |
| 审查-B | 设计 + 测试覆盖 + 注释准确性 + 向后兼容 |
| 审查-C | 性能 + 可观测性 |
| full | 审查-A + 审查-B + 审查-C |

## 输出

- 输出文件：`docs/{feature}/phase-{N}/code-review-result.json`
- 运行时模板：`contracts/canonical/templates/runtime/code-review-result.template.json`
- 必填内容：`dimension_verdicts`（十维 + `REVIEW_A/B/C`）、`findings[].file_path/line_number/confidence/verification_status`、`excluded`、`review_conclusion`
- 人工投影视图可使用：`references/templates/code-review-report-template.md`（轮次记录、审查-A/B/C Findings 表、证据链完整性专项、已排除问题表、验证状态列、最终结论）

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
