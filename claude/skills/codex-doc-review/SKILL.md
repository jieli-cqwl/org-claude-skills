---
name: codex-doc-review
user-invocable: true
description: Codex 跨模型文档审查。Use when 需要独立模型审查 PRD/Design/测试设计/实施计划文档。
argument-hint: "[file|files] [scope=product*|design*|test-design*|tech-lead*] [fp_exclusions=...] [work_dir=canonical_dir]"
allowed-tools: Read, Write, Bash, Glob, Grep
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/codex-doc-review/scripts/completion_check.sh
          timeout: 15
---

# /codex-doc-review -- Codex 跨模型文档审查

> ultrathink

## HARD-GATE

1. NO completion without writing `codex-doc-review-report.md` into work_dir.
2. NO DECEPTION auto-fix -- DECEPTION 发现 REQUIRED 原样展示 + 标记"需用户介入"。
3. NO repeated review rounds -- 单轮审查 + 输出，不含轮次管理。
4. NO code-level review -- 仅审查文档，不含代码层面审查。
5. NO silent skip -- 跳过审查 REQUIRED 标注原因 + 状态码。

## Red Flags

If you catch yourself thinking:

- "Codex 输出格式不对，我自己补全吧" → STOP. 降级为原文展示，不伪造结果。
- "这个 DECEPTION 不严重，降级为 WARNING" → STOP. DECEPTION 不可降级。
- "Codex 超时了，直接跳过审查" → STOP. 必须重试 1 次，仍失败才降级。
- "这个审查问题我能自动修复" → STOP. 只报告问题，不修复文档。

## 角色

你是跨模型文档审查协调者，调用 Codex CLI 引入独立于 Claude 的第二视角检测文档偏差。
你的锚点：每个发现必须引用原文作为证据。

## I/O 契约

输入：

| 参数 | 必选 | 默认值 | 说明 |
|------|------|--------|------|
| file | 是 | - | 待审查文档路径；支持单文档或同一 feature 下的多文档集合 |
| scope | 否 | 自动检测 | 支持 `product*` / `design*` / `test-design*` / `tech-lead*` |
| fp_exclusions | 否 | - | FP 排除列表，格式 `"位置: 描述"` |
| work_dir | 否 | 按 reviewed docs 自动推导 | 输出目录；若显式传入，必须与 canonical 目录完全一致 |

输出：`{work_dir}/codex-doc-review-report.md`
状态码：REVIEW_OK / REVIEW_ISSUE / CODEX_NOT_AVAILABLE / CODEX_OUTPUT_INVALID / DOCUMENT_TOO_LARGE / DOCUMENT_EMPTY（定义详见 references/execution-spec.md）

## 流程

### Step 1: 参数解析

解析 file / scope / fp_exclusions / work_dir。file 缺失则提示用户提供文档路径。
`work_dir` 默认不是当前目录，而是按 reviewed docs 推导 canonical 目录：
- `product*` → `docs/{feature}/`
- `design*` / `tech-lead*` → `docs/{feature}/phase-{N}/`
- `test-design*` → `docs/{feature}/phase-{N}/unit-{M}/`
- 多文档集合必须能归一到唯一合法目录；跨 feature 直接失败。

### Step 2: 阶段检测

scope 已指定则按族类匹配（如 `product-final-delta-recheck` 归入 `product`）；否则按文件路径关键词自动映射（映射规则详见 references/execution-spec.md）。

### Step 3: 前置检查

按顺序执行 5 项检查，命中即停止返回状态码（检查详情见 references/execution-spec.md）：

1. Codex CLI 可用性 → CODEX_NOT_AVAILABLE
2. 文档有效性（存在/非空/有内容）→ DOCUMENT_EMPTY
3. 文档大小上限（500KB）→ DOCUMENT_TOO_LARGE
4. reference 文件存在性（review-guide-base.md + review-guide-{stage}.md）
5. DECEPTION 定义检测（不阻断，影响报告标注）

### Step 4: stdin 构建

按分隔符协议拼接 DOCUMENT → FP_EXCLUSIONS（可选）→ REVIEW_GUIDE（协议详见 references/execution-spec.md）。

### Step 5: CLI 调用

通过 stdin 管道调用 `codex exec --json`，超时 300 秒（命令模板见 references/execution-spec.md）。

### Step 6: 输出解析

提取 4 个必需 section（Findings / DECEPTION / Dimensions / Summary），格式定义见 references/review-guide-base.md。
异常场景（空输出/格式错误/字段缺失）重试 1 次后降级为原文展示 + CODEX_OUTPUT_INVALID（解析规则见 references/execution-spec.md）。

### Step 7: 反馈分级

按 severity 分级处理（分级规则见 references/execution-spec.md）：
- DECEPTION → 原样展示 + "需用户介入"
- CRITICAL → "需用户介入" + 修复建议
- WARNING / INFO → 记录到报告

状态码判定：有 DECEPTION/CRITICAL → REVIEW_ISSUE，其余 → REVIEW_OK。

### Step 8: 报告生成

按 references/templates/codex-doc-review-report.md 模板生成报告，写入 canonical `work_dir` 下的 `{work_dir}/codex-doc-review-report.md`。

报告必含：元信息（文件/阶段/时间）+ Findings 表 + DECEPTION 表 + Dimensions 表 + Summary 段 + 处理建议。

## 输出

`{work_dir}/codex-doc-review-report.md`（模板见 references/templates/codex-doc-review-report.md）

## 完成校验

- [ ] codex-doc-review-report.md 已写入 canonical work_dir，且仓库内无 misplaced/duplicate 副本
- [ ] 报告包含 4 个必需 section（Findings / DECEPTION / Dimensions / Summary）
- [ ] 报告包含元信息（文件/阶段/时间）
- [ ] DECEPTION 发现已原样展示（未修改、未淡化）
- [ ] 所有错误均使用 `[状态码] 原因描述` 格式
- [ ] 输出状态码为 6 个定义状态之一
