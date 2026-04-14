## Task-N: {标题}

### 权威证据工件
- authoritative_evidence_artifact: `developer-report-Task-N.md`
- evidence_bundle_ref: `{指向 RED/GREEN/Fresh proving 的锚点集合}`
- reviewable_anchor: `{供 verify / delivery-owner 抽查的一手证据锚点}`

### 执行拆解

#### 代码探索结论
- {框架/库}: {具体版本或来源} ({发现于 文件:行号})
- {模式名}: {描述} ({发现于 文件:行号})

#### 复用候选
- {文件路径} — {说明，如"统一错误处理，直接复用"}
- 或：无可复用候选

#### 实现步骤
1. [RED/GREEN] {描述} — AC: {AC-ID}, 文件: {path}, 模式: {参照}
2. ...

#### 风险与发现
- {风险描述} → {处理方式}
- 波及文件: {developer 在探索中发现的受影响文件}
- 或：无风险项

#### 拆解深度
{轻量 / 标准 / 完整} — 理由: {为什么选择此深度}

### TDD 记录
| AC | 测试描述 | RED 证据 | GREEN 证据 |
|----|---------|---------|-----------|

### TDD 证据索引
<!-- 这是 TDD 原始证据的唯一权威索引；PM/verify 应引用这里，而不是在下游报告重复搬运整段输出。 -->
| 阶段 | Commit SHA | 测试文件 | 结果 |
|------|-----------|---------|------|
| RED | {SHA} | {test_file} | FAIL (expected) |
| GREEN | {SHA} | {test_file} | PASS |

### 自测结果

#### 测试完备性审视
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 驱动源 | AC/用例 | 对应测试 | 覆盖状态 |
|--------|---------|---------|---------|
| test-cases.md / AC 推导 | AC-001 | test_xxx | {COVERED, GAP} | <!-- HOOK-CONTRACT:ENUM 填 COVERED, GAP 之一 -->

> 缺口处理：{补充了哪些测试, 无缺口}

#### 全量测试回归
- 命令: `{实际执行的命令}`
- 结果: 通过 N / 失败 N / 跳过 N

#### 静态分析
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 工具 | 命令 | 结果 |
|------|------|------|
| Lint | `{命令}` | {PASS, FAIL} | <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 -->
| 类型检查 | `{命令}` | {PASS, FAIL} |
| 构建 | `{命令}` | {PASS, FAIL} |

#### 功能集成冒烟
{结果描述}
或：不适用——{理由}

#### E2E 端到端
{结果描述}
或：不适用——{理由}

### 文件变更
| 文件 | 操作 | 涉及 AC | 在范围内 |
|------|------|---------|---------|

### 接口变更记录
| 接口 | 变更内容 | 变更原因 | 变更级别 | design.md 已同步 |
|------|---------|---------|---------|-----------------|
> 无变更时填写：无

### 自审发现
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 维度 | 结果 | 备注 |
|------|------|------|
| AC 完整性 | {PASS, FAIL} | {说明} | <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 -->
| TDD 完整性 | {PASS, FAIL} | {说明} |
| 自测证据 | {PASS, FAIL} | {说明} |
| 范围合规 | {PASS, FAIL} | {说明} |
| 代码规范 | {PASS, FAIL} | {说明} |
| 报告完整性 | {PASS, FAIL} | {说明} |
| 执行拆解遵循度 | {PASS, FAIL} | {说明} | <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 -->
