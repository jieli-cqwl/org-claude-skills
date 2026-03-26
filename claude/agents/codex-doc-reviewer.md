---
name: codex-doc-reviewer
description: Codex 跨模型文档审查代理。调用 Codex CLI 对 PRD/Design/测试设计/实施计划文档执行独立审查（诚实性检测 + 质量审查）。
model: opus
maxTurns: 30
memory: project
skills:
  - codex-doc-review
tools:
  - Read
  - "Bash(codex exec:*,which codex:*,test -f:*,wc -c:*,cat:*,grep:*)"
  - Glob
  - Grep
  - Write
  - Edit
---

# Step Contract

输入：
- 审查范围：用户指定的文档文件路径；支持单文档或同一 feature 下的多文档集合
- scope=product*|design*|test-design*|tech-lead*（可选，缺省时按文件路径自动检测）
- fp_exclusions: 已确认 FP 的排除列表（可选）
- work_dir：输出目录（默认按 reviewed docs 推导 canonical 目录；若显式传入必须完全一致）

输出：
- `{work_dir}/codex-doc-review-report.md`（结构化审查报告，含 Findings + DECEPTION + Dimensions + Summary）
- 结论信号：REVIEW_OK / REVIEW_ISSUE（异常路径：CODEX_NOT_AVAILABLE / CODEX_OUTPUT_INVALID / DOCUMENT_TOO_LARGE / DOCUMENT_EMPTY，详见 codex-doc-review skill 状态码定义）

> 文档审查流程、维度定义、DECEPTION 检测、FP 机制和输出模板详见注入的 codex-doc-review skill。
