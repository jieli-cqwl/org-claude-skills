# fix-result projection

> 运行时真源为 `fix-result.json`；本文件只作为人类投影视图。

## 输入分析
[输入来源清单：report/log/stacktrace/failed command]
[work_dir 解析结果：{work_dir} 或 docs/hotfix--YYYYMMDD-HHMM]
[问题数量汇总]

差异说明（N > 1 时 REQUIRED）:
[与上轮修复方案的差异：上次方案回顾 + 本轮策略变化]

## 诊断阶段

### 环境快照
- 当前分支:
- 工作树状态:
- 最近 5 条提交:
- 最近改动文件:

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | ... | ... | ... |

当前环境复现结论:
- 可复现/不可复现:
- 不可复现时环境差异证据:

### 假设验证过程
记录 `systematic-debugging` 实际验证的 material hypotheses；不要为满足固定数量编造候选。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | ... | ... | ... | 排除/确认/未决 |

### 根因结论
| # | 问题 | diagnosis_status | failure_class | root_cause_ref | 因果链摘要 | 证据 |
|---|------|------------------|---------------|----------------|-----------|------|
| 1 | ... | CONFIRMED/UNRESOLVED | FIXABLE/DESIGN_ISSUE/ENV_ISSUE/REQUIREMENT_AMBIGUITY | 仅 CONFIRMED 填写与分类匹配的代码、runtime、设计、环境或需求锚点 | ... | ... |

## 处置阶段

### 决策
[处置策略选择 + 优先级排序]

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | ... | FIXABLE/DESIGN_ISSUE/ENV_ISSUE/REQUIREMENT_AMBIGUITY | ... |

### FAIL-1: [问题标题]

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | failure class 对应的 evidence anchor + 因果机制；未确认则写 unresolved |
| 2 | 修复是否完整？ | 受影响路径列表 + 覆盖确认 |
| 3 | 是否引入新问题？ | 影响范围 + 回归测试需求 |
| 4 | 是否需要补充测试覆盖？ | 覆盖状态 + 补充计划 |

RED: [仅 FIXABLE 必填]
GREEN: [仅 FIXABLE 必填]

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|

### 全量测试结果
TEST_CMD: <命令，仅 FIXABLE 必填>
通过: N / 失败: N / 跳过: N（仅 FIXABLE 必填）

### 阻断清单（全部/部分非 FIXABLE 时必填）
| # | 问题 | 阻断原因 | 下一步动作 | 责任归属 |
|---|------|---------|-----------|---------|
| 1 | ... | ... | ... | ... |

### 交接项清单
- 根因分析结论、failure class 与对应 evidence anchor
- 修复范围与回归测试清单
- 非 FIXABLE 问题的后续处理动作
