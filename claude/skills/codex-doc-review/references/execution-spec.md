# execution-spec -- codex-doc-review 执行规格

## 术语约定

| 术语 | 含义 | 使用场景 |
|------|------|---------|
| 原样展示 | 不修改、不淡化、不删除，保持发现内容原貌 | DECEPTION 发现的展示方式 |
| 原文展示 | 展示 Codex 原始输出文本（未经解析） | 降级路径：解析失败时兜底展示 |

## TOC

- [可配置项](#可配置项)
- [状态码定义](#状态码定义)
- [阶段检测映射](#阶段检测映射)
- [输出目录解析](#输出目录解析)
- [前置检查详情](#前置检查详情)
- [stdin 协议](#stdin-协议)
- [CLI 命令模板](#cli-命令模板)
- [输出解析规则](#输出解析规则)
- [反馈分级表](#反馈分级表)

## 可配置项

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| model_reasoning_effort | medium | Codex CLI reasoning effort，可调整为 low/medium/high |
| DOC_SIZE_LIMIT | 512000 | 文档大小上限（字节），约 500KB |
| CODEX_TIMEOUT | 300 | Codex CLI 调用超时（秒） |
| MAX_RAW_LINES | 2000 | 降级原文展示最大行数 |

## 状态码定义

| 状态码 | 含义 | 分级 | 处理 |
|--------|------|------|------|
| REVIEW_OK | 审查通过，无 CRITICAL/DECEPTION | 正常 | 输出"审查通过" |
| REVIEW_ISSUE | 存在 CRITICAL 或 DECEPTION | 用户介入型 | 展示问题详情 + 标记"需用户介入" |
| CODEX_NOT_AVAILABLE | Codex CLI 未安装或目录未信任 | 用户介入型 | 报告原因，不产出审查报告 |
| CODEX_OUTPUT_INVALID | 输出为空/不可解析（重试 1 次后仍失败） | 重试型 | 降级为原文展示 + 报告异常详情 |
| DOCUMENT_TOO_LARGE | 文档超过大小上限（500KB） | 配置修复型 | 提示拆分或调整上限 |
| DOCUMENT_EMPTY | 文档为空、不存在或仅含空白 | 配置修复型 | 提示检查文档路径和内容 |

错误消息格式：`[状态码] 原因描述`

示例：
- `[CODEX_NOT_AVAILABLE] codex 命令未找到，请先安装 Codex CLI`
- `[DOCUMENT_EMPTY] 文档为空，无法审查`
- `[DOCUMENT_TOO_LARGE] 文档大小 650KB 超过上限 500KB，请拆分后重试`

## 阶段检测映射

用户已指定 scope 时按族类匹配（如 `product-final-delta-recheck` 归入 `product`），否则按文件路径关键词匹配：

| 文件路径关键词 | 映射阶段 |
|--------------|---------|
| `prd` | product |
| `design` | design |
| `test-cases` / `test-design` | test-design |
| `plan` / `tech-lead` | tech-lead |
| 无匹配 | 提示用户指定 scope |

多关键词消歧：文件名优先（最靠近文件名的关键词优先）。

示例：
- `docs/design/test-cases.md` → 文件名 `test-cases.md` → `test-design`
- `docs/prd/design.md` → 文件名 `design.md` → `design`

## 输出目录解析

`work_dir` 的 canonical 规则固定如下：

| scope 族类 | canonical work_dir |
|-----------|--------------------|
| `product*` | `docs/{feature}/` |
| `design*` | `docs/{feature}/phase-{N}/` |
| `tech-lead*` | `docs/{feature}/phase-{N}/` |
| `test-design*` | `docs/{feature}/phase-{N}/unit-{M}/` |

约束：
- 多文档集合必须全部归属于同一 feature。
- `product*` 允许 feature 根文档和 `units/UNIT-*.md`，不允许混入 `phase/unit` 级文档。
- `design*` / `tech-lead*` 必须归一到唯一 phase。
- `test-design*` 必须归一到唯一 unit。
- 显式传入 `work_dir` 时，若与 canonical 目录不一致，直接失败。

## 前置检查详情

按顺序执行，命中即停止：

### 3a. Codex CLI 可用性

```bash
which codex
```

- `which codex` 失败 → `[CODEX_NOT_AVAILABLE] codex 命令未找到，请先安装 Codex CLI`
- 报 "Not inside a trusted directory" → `[CODEX_NOT_AVAILABLE] 当前目录未信任，请运行 codex 进入交互模式信任该目录`

### 3b. 文档有效性

- 文件不存在 → `[DOCUMENT_EMPTY] 文档不存在: {path}`
- 文件 0 字节 → `[DOCUMENT_EMPTY] 文档为空，无法审查`
- 仅含空白字符 → `[DOCUMENT_EMPTY] 文档仅含空白字符，无法审查`

### 3c. 文档大小上限

- 超过 512000 字节 → `[DOCUMENT_TOO_LARGE] 文档大小 {size}KB 超过上限 500KB，请拆分后重试`

### 3d. reference 文件存在性

```bash
SKILL_DIR="$(dirname "$0")/.."
test -f "$SKILL_DIR/references/review-guide-base.md"
test -f "$SKILL_DIR/references/review-guide-${stage}.md"
```

- 缺失 → 报错终止：`review-guide-{file}.md 缺失，无法执行审查`

### 3e. DECEPTION 定义检测

```bash
grep -q "DEC-BASE-01" "$SKILL_DIR/references/review-guide-base.md"
```

- DECEPTION 段为空/缺失 → 不阻断，报告标注"DECEPTION 维度未覆盖"

## stdin 协议

分隔符格式：`===CODEX_DOC_REVIEW:{SECTION}===`

段顺序：DOCUMENT → FP_EXCLUSIONS（可选） → REVIEW_GUIDE

FP 解析规则：
- 每条格式 `"位置: 描述"`，必须含 `:` 且描述非空
- 格式异常 → 忽略并记录 `[FP 格式异常，已忽略: {原文}]`

```
===CODEX_DOC_REVIEW:DOCUMENT===
{文档完整内容}
===CODEX_DOC_REVIEW:FP_EXCLUSIONS===        # 可选段
- {位置}: {描述}
===CODEX_DOC_REVIEW:REVIEW_GUIDE===
{review-guide-base.md 内容}
{review-guide-{stage}.md 内容}
```

## CLI 命令模板

```bash
{ echo '===CODEX_DOC_REVIEW:DOCUMENT==='; cat "$doc_file"; \
  [[ -n "$fp_list" ]] && { echo '===CODEX_DOC_REVIEW:FP_EXCLUSIONS==='; echo "$fp_list"; }; \
  echo '===CODEX_DOC_REVIEW:REVIEW_GUIDE==='; \
  cat "$SKILL_DIR/references/review-guide-base.md"; \
  cat "$SKILL_DIR/references/review-guide-${stage}.md"; \
} | codex exec --json -c model_reasoning_effort="medium" -
```

- Bash 超时：300 秒（timeout: 300000）
- `model_reasoning_effort` 使用可配置项中定义的值

## 输出解析规则

### 表格解析

从 Codex 输出提取 4 个必需 section，按 `|` 分隔符映射：
- Findings：severity / location / description / recommendation（4 列）
- DECEPTION：severity / location / description / evidence（4 列）
- Dimensions：dimension / verdict / evidence（3 列）
- Summary：total_findings / deception_count / status

### 降级路径

3 种异常统一降级为原文展示 + `CODEX_OUTPUT_INVALID`：
1. 输出不完整：缺 Summary 或表格行数为 0 → 标注"输出不完整"
2. 格式异常：列数不匹配（Findings/DECEPTION 非 4 列，Dimensions 非 3 列）→ 标注"格式异常"
3. 字段缺失：4 个必需 section 任一缺失 → 标注"缺少 {section} 章节"

原文展示规则：超 2000 行截断，标注 `[输出已截断，完整内容 {N} 行]`

### 重试机制

- 空输出或 JSONL 解析失败 → 相同命令重试 1 次
- 重试仍失败 → 降级（原文展示 + CODEX_OUTPUT_INVALID）
- 超时 300 秒 → 视为空输出，触发重试

## 反馈分级表

| 级别 | 处理方式 |
|------|---------|
| DECEPTION | 原样展示 + 标记"需用户介入" + 禁止自动修复/淡化/删除 |
| CRITICAL | 标记"需用户介入" + 问题详情 + 修复建议 |
| WARNING | findings + 修复建议 + 提示"修复后重新提交审查" |
| INFO | 记录到报告 |
| PASS | 输出 REVIEW_OK + "审查通过" |

状态码判定：
- 存在 DECEPTION 或 CRITICAL → `REVIEW_ISSUE`
- 仅 WARNING/INFO 或无问题 → `REVIEW_OK`

DECEPTION 维度未覆盖（Step 3e 触发）：审查继续，报告标注"DECEPTION 维度未覆盖"，其他维度正常审查。
