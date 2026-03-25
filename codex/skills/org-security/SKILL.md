---
name: security
description: 安全漏洞扫描与修复建议。Use when 需要安全检查、排查 SQL 注入/XSS/CSRF/密钥泄露、发布前安全审查。
argument-hint: "[项目路径]"
user-invocable: true
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash $HOME/.claude/skills/security/scripts/completion_check.sh
          timeout: 15
---

# /security -- 安全漏洞扫描

## HARD-GATE

1. NO security report without running at least one professional tool (Bandit/Semgrep/Gitleaks).
2. NO vulnerability reported without file_path:line_number AND fix code.
3. NO leaked production secrets left unreported — REQUIRED to immediately notify user for rotation.
4. NO report generated outside `docs/reports/security/` directory.

## 角色

你是安全工程师。工具扫描找表面漏洞，AI 语义分析找逻辑漏洞，两层覆盖 OWASP Top 10。发现严重漏洞必须立即报告，禁止淡化。

## 执行模式

`/security` 完整扫描 | `quick` 仅 Bandit+Gitleaks | `deps` 依赖审计 | `fix` 扫描+自动修复

## 流程

### 1. 环境检测

检测语言和工具可用性（详见 `references/security-rules.md`）。

### 2. 工具扫描

按顺序执行（可选并行，用户明确要求时启用）：
- SAST：Bandit (Python) / Semgrep (全栈)
- 密钥：Gitleaks
- 依赖：pip-audit / npm audit

### 3. AI 语义分析

- 复核工具结果，过滤误报
- 检查工具遗漏的逻辑漏洞（认证绕过、越权访问、业务逻辑缺陷），辅以 STRIDE 框架系统排查（见 `references/security-rules.md`）

### 4. 生成报告

按严重程度分级，每个漏洞附修复代码。

OWASP Top 10 规则清单、工具命令、误报处理详见 `references/security-rules.md`

### 5. 自动修复（/security fix 模式）

高置信度问题自动修复，展示 diff 预览后需用户确认才应用。

## 输出

输出到 `docs/reports/security/[YYYY-MM-DD]_安全扫描报告.md`（模板详见 `references/templates/security-scan-report-template.md`），包含：
- 安全评分（XX/100）
- 漏洞分级列表（严重/高危/中危/低危）
- 每个漏洞：CWE 编号 + file_path:line_number + 描述 + Before/After 修复代码
- 修复优先级排序

## 完成校验

- [ ] 至少一个专业工具已执行
- [ ] OWASP Top 10 已覆盖
- [ ] 每个漏洞附 file_path:line_number + 修复代码
- [ ] 报告已保存到 `docs/reports/security/`
- [ ] 严重漏洞已立即通知用户
