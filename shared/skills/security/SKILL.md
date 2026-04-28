---
name: security
description: 安全漏洞扫描与修复建议。Use when 需要安全检查、排查 SQL 注入/XSS/CSRF/密钥泄露、发布前安全审查。
argument-hint: "[项目路径]"
user-invocable: true
---

# /security -- 安全漏洞扫描

Goal: 对目标项目执行工具扫描 + AI 语义复核，输出含证据和修复建议的安全报告。Completion boundary: `docs/reports/security/[YYYY-MM-DD]_安全扫描报告.md` 已生成，至少一个专业工具已执行，每个漏洞有 file_path:line_number、CWE、严重级别和修复代码；严重秘密泄露已立即通知用户。

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

状态表：

| 状态 | 动作 | 停止/转移 |
| --- | --- | --- |
| Detect | 检测语言、依赖和工具可用性 | 无工具可运行则报告阻塞 |
| Tool Scan | run Bandit/Semgrep/Gitleaks/pip-audit/npm audit | 工具失败需记录命令和原因 |
| Semantic Review | 复核误报并补查 OWASP/STRIDE 逻辑风险 | 无 file:line 证据不得报漏洞 |
| Report | 写安全报告和修复优先级 | 严重秘密泄露必须先通知用户 |
| Fix Mode | 用户确认后应用高置信修复 | 未确认不得改代码 |

流程产物合同：每一步 output 都必须被下一步 consumer 消费，并满足 acceptance、failure_state、proof。缺工具输出、file:line、修复代码或报告路径时，不得声明扫描完成。

### 1. 环境检测

当检测语言和工具可用性时：
→ Trigger: 环境检测、语义分析或 OWASP/STRIDE 覆盖判断；Read: `references/security-rules.md`；Expect: 语言检测标识文件表、推荐工具映射、OWASP Top 10、STRIDE 六维度和误报处理规则；Consume: 扫描计划、漏洞分类和报告字段；Evidence: 工具命令、file:line、CWE、严重级别和误报依据；Sync: 更新安全规则、报告模板和 fixtures。

### 2. 工具扫描

按顺序执行（可选并行，用户明确要求时启用）：
- SAST：Bandit (Python) / Semgrep (全栈)
- 密钥：Gitleaks
- 依赖：pip-audit / npm audit

### 3. AI 语义分析

- 复核工具结果，过滤误报
- 检查工具遗漏的逻辑漏洞（认证绕过、越权访问、业务逻辑缺陷），辅以 S1 已读取的 STRIDE 框架章节系统排查。

### 4. 生成报告

按严重程度分级，每个漏洞附修复代码。

OWASP Top 10 规则清单、工具命令、误报处理按 S1 安全规则资源执行。

### 5. 自动修复（/security fix 模式）

高置信度问题自动修复，展示 diff 预览后需用户确认才应用。

## 输出

输出到 `docs/reports/security/[YYYY-MM-DD]_安全扫描报告.md`。
报告模板：`projections/security-scan-report-template.md`（必填：安全评分、漏洞分级列表、每个漏洞含CWE编号+file:line+Before/After代码、修复优先级表）

包含：
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
- [ ] Proof evidence 已记录：工具命令输出、语义复核证据、报告路径、严重漏洞通知和 fix 模式用户确认
