# 验证协议（Verification）

> 引用者：review SKILL.md（验证 / Verification 步骤）
> 适用范围：对 Critical/High findings 的交叉验证与 false positive 过滤

## 核心机制

对每轮审查产出的 Critical/High severity findings 逐条执行交叉验证，过滤 false positive，确保最终报告中的 findings 都是真实问题。

## 验证步骤（Verification）

对每条 Critical/High finding，执行以下验证：

### 1. 代码路径追踪
- 从 finding 指出的位置出发，沿调用链上下追踪
- 确认问题确实可达（非死代码路径）
- 确认问题在运行时确实会触发

### 2. 已有防护检查
- 检查是否已有防护措施（try-catch、校验、限流等）覆盖该问题
- 检查框架/库是否已内建相关防护
- 检查是否有上游校验使该问题不可触发

### 3. 上下文确认
- 检查变更的上下文（整个文件、相关模块）是否提供了额外信息
- 确认 finding 的严重度评估是否准确

## 验证状态标记

| 状态 | 含义 | 后续处理 |
|------|------|---------|
| 已验证（Verified） | 经验证确认是真实问题 | 计入最终判定 |
| 误报（False Positive） | 经验证为误报（已有防护/不可达/框架保障） | 不计入判定，移入已排除 |
| 待定（Inconclusive） | 无法确定，需更多上下文 | 标注原因，不计入判定 |

## 判定规则

- 仅 `已验证（Verified）` 状态的 findings 计入最终的 `REVIEW_X_OK/ISSUE` 判定
- `误报（False Positive）` 移入"已排除的潜在问题"表，附排除证据
- `待定（Inconclusive）` 保留在发现（Findings）表中但标注状态，不影响判定

## 输出格式

发现（Findings）表中增加"验证状态"列：

```
| # | 置信度 | 严重度 | 位置 | 维度 | 问题 | 修复方向 | 验证状态 |
|---|--------|--------|------|------|------|---------|---------|
| 1 | 95 | 严重（Critical） | file:line | CS-1 | ... | ... | 已验证（Verified） |
| 2 | 85 | 高（High） | file:line | CS-2 | ... | ... | 误报（False Positive） |
```

## 验证汇总（Verification）

每次 Verification 完成后，在报告末尾输出汇总：

```
## 验证汇总（Verification）

| 送检数 | 已验证（Verified） | 误报（False Positive） | 待定（Inconclusive） |
|--------|--------------------|-------------------------|--------------------|
| N | a | b | c |
```
