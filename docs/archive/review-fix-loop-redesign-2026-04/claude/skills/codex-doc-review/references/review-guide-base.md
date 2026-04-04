# 审查指引 — 共享基础维度

> 本文件定义所有文档阶段共享的 3 个基础审查维度、DECEPTION 诚实性检测正例定义、以及 Codex 输出格式约束。
> 阶段特异维度由对应的 `review-guide-{stage}.md` 文件定义，与本文件拼接后传给 Codex。

## TOC

- [基础审查维度](#基础审查维度)
- [DECEPTION 正例定义](#deception-正例定义)
- [Codex 输出格式约束](#codex-输出格式约束)

---

## 基础审查维度

以下 3 个维度适用于所有文档阶段（product / design / test-design / tech-lead）。

### 维度 1: 一致性

- 审查焦点: 术语统一、跨章节约束无矛盾、与上下游文档对齐
- 判定标准:
  - PASS: 文档内术语一致，跨章节约束无矛盾，与上下游文档对齐
  - WARN: 存在轻微不一致（如同一概念使用不同表述，但不影响理解）
  - FAIL: 存在关键矛盾（如同一字段在不同章节定义冲突，或与上游 PRD/Design 描述矛盾）

### 维度 2: 完整性

- 审查焦点: 该阶段必须包含的结构/内容是否齐全
- 判定标准:
  - PASS: 所有必需结构和内容齐全
  - WARN: 存在非关键遗漏（如缺少可选章节或辅助说明）
  - FAIL: 关键内容缺失（如 PRD 缺少 AC 列表、Design 缺少接口定义、Plan 缺少 Task 清单）

### 维度 3: DECEPTION（诚实性检测）

- 审查焦点: 虚假完成、占位符伪装、注释矛盾、模糊表述掩盖缺失
- 判定标准: 发现即报告，severity 固定为 DECEPTION，不使用 PASS/WARN/FAIL 三级判定
- 特殊规则: 有明确 TODO/FIXME/placeholder 标记的不完整内容不算 DECEPTION（诚实的不完整不是欺骗）

---

## DECEPTION 正例定义

### 判定原则

DECEPTION 的核心判定标准是「意图掩盖」：内容表面看起来完整或合格，但实际上隐藏了缺失、不完整或未验证的事实。

排除规则: 以下情况明确不属于 DECEPTION，不应判定为 DECEPTION：
- 标注了 `TODO`、`FIXME`、`placeholder`、`TBD`、`待定` 等明确标记的不完整内容
- 明确声明"尚未完成"、"待补充"、"需后续确认"等诚实的不确定性表述
- 这些标记表示作者已知且已标注不完整状态，属于诚实的不完整，不构成欺骗

### 跨阶段通用模式（4 个）

| 编号 | 模式名称 | 正例（算 DECEPTION） | 反例（不算 DECEPTION） |
|------|---------|---------------------|---------------------|
| DEC-BASE-01 | 占位符伪装完成 | "系统正确处理"、"详见后续设计"（无 TODO 标记，看起来像完成了） | `TODO: 待定义处理逻辑`（有明确标记，诚实的不完整） |
| DEC-BASE-02 | 模糊表述掩盖缺失 | "基本上完成"、"应该可以"、"大概率没问题"（用模糊词回避精确描述） | "不确定是否支持并发，需实测验证"（明确的不确定性声明） |
| DEC-BASE-03 | 量化伪装 | "经过充分测试"（无测试证据）、"性能满足要求"（无数据支撑） | "已通过 100 条用例测试，覆盖率 85%"（有数据支撑的量化声明） |
| DEC-BASE-04 | 注释矛盾 | 标题写"完整接口定义"但内容只有 2 个参数（标题与内容不符） | 标题"接口定义（核心参数）"且内容与标题一致 |

### 阶段特异模式（8 个）

| 阶段 | 编号 | 模式名称 | 正例（算 DECEPTION） | 反例（不算 DECEPTION） |
|------|------|---------|---------------------|---------------------|
| product | DEC-P-01 | AC 无行为定义 | AC 写"系统处理请求"但不说怎么处理、处理后什么结果 | AC 写"系统返回 200 + 用户列表 JSON"（有具体行为和结果） |
| product | DEC-P-02 | 成功标准不可度量 | "用户满意度提升"但无度量方式和基线 | "用户满意度从 3.5 提升到 4.0（NPS 调研）"（有度量方式） |
| design | DEC-DES-01 | 接口声称完整但缺失 | "接口完整"但缺错误码/超时/边界条件定义 | 接口定义包含入参/出参/错误码/超时/边界（确实完整） |
| design | DEC-DES-02 | 风险声称可控无措施 | "风险可控"但无缓解措施或应急方案 | "风险可控，缓解措施: 限流 + 熔断 + 回滚预案"（有具体措施） |
| test-design | DEC-TST-01 | 覆盖声称完整但片面 | "覆盖完整"但只有正常路径用例，缺异常/边界/并发 | 覆盖包含正常路径 + 异常路径 + 边界条件（确实完整） |
| test-design | DEC-TST-02 | 预期结果模糊 | 预期结果写"正常运行"、"功能正常"而非可观察的具体结果 | 预期结果写"返回 HTTP 200 + body 含 user_id 字段"（可观察） |
| tech-lead | DEC-TL-01 | Task 无验收条件 | "实现 XX 功能"但不说完成标准和验证方法 | "实现 XX 功能，验收: 运行 `npm test` 全部通过 + API 返回 200" |
| tech-lead | DEC-TL-02 | 依赖声称无但实有 | 依赖标"无"但实际需要其他 Task 的接口或数据 | 依赖列出"Task-1 的 API 端点必须先部署"（诚实声明） |

### 审查执行要求

1. 逐段扫描文档，对照上述 12 个模式检查
2. 发现疑似 DECEPTION 时，引用原文作为证据（evidence 列）
3. 判定时区分"诚实的不完整"（有 TODO/FIXME/placeholder 标记）与"伪装的完整"（无标记，看起来像完成了）
4. DECEPTION 发现的 severity 固定为 DECEPTION，不降级为 WARNING

---

## Codex 输出格式约束

你必须严格按以下格式输出审查结果。每个 section 必须存在（即使为空也要保留 section 标题）。

### 格式模板

```markdown
## Findings

| severity | location | description | recommendation |
|----------|----------|-------------|----------------|
| WARNING  | 文件名:行号 | 问题描述 | 修复建议 |
| CRITICAL | 文件名:行号 | 问题描述 | 修复建议 |

## DECEPTION

| severity | location | description | evidence |
|----------|----------|-------------|----------|
| DECEPTION | 文件名:行号 | DECEPTION 模式描述 | 原文引用 |

## Dimensions

| dimension | verdict | evidence |
|-----------|---------|----------|
| 一致性 | PASS/WARN/FAIL | 判定依据 |
| 完整性 | PASS/WARN/FAIL | 判定依据 |
| DECEPTION | 见 DECEPTION 表 | - |

## Summary
- total_findings: N
- deception_count: N
- status: REVIEW_OK / REVIEW_ISSUE
```

### 格式规则

1. Findings 表: 记录 WARNING 和 CRITICAL 级别问题，4 列（severity / location / description / recommendation）
2. DECEPTION 表: 记录 DECEPTION 发现，4 列（severity / location / description / evidence）；无 DECEPTION 时保留表头并标注"无"
3. Dimensions 表: 记录每个维度的审查结论，3 列（dimension / verdict / evidence）；阶段特异维度也需在此表中列出
4. Summary 段: 汇总统计，3 个必需字段（total_findings / deception_count / status）
5. status 判定: 存在 CRITICAL 或 DECEPTION → `REVIEW_ISSUE`；仅 WARNING 或无问题 → `REVIEW_OK`
6. location 格式: 使用 `文件名:行号` 或 `文件名:章节名` 格式定位问题位置
