# Review 迭代协议

> 类型：skill-specific 协议（非通用按需知识）。
> 本文件定义内层审查递增协议（R1→R2→R3 三轮递增，控制单次审查的深度）。外层修复循环协议（控制"审完→修→重审"的循环次数，最多 10 轮）见 `protocols/review-fix-loop-protocol.md`。两层正交：外层控制循环次数，内层控制每次审查深度。

> 引用者：product/design/test-design SKILL.md（跨职能迭代审查步骤）
> 适用范围：/product、/design、/test-design 审查步骤

## 核心机制

3 轮递增审查，每轮注入上一轮的发现和覆盖盲区，范围递增直到收敛。

```
Round 1（广度扫描）：标准审查 + 输出覆盖自评
  -> 产出 product-cross-review.md（产品视角/架构视角/测试视角，含 findings + coverage_gaps）

Round 2（深度聚焦）：注入 R1 的 findings + coverage_gaps
  -> 聚焦 R1 盲区，输出 delta_findings，合并到对应 review 文件

Round 3（对抗审查，仅 R2 有新 FAIL 时触发）：注入 R1+R2 全部 findings
  -> 从对抗视角审查，找遗漏，合并到 review 文件

收敛 -> 合并所有轮次 findings 到最终 review 文件
```

## 收敛判定

| 条件 | 判定 | 结果 |
|------|------|------|
| R1 全 PASS 且无 coverage_gaps | shallow_pass，强制 Round 2 | 继续 |
| R2 delta_findings = 0 | 正常收敛 | 合并 R1+R2，输出 |
| R2 有新 FAIL -> R3 执行 -> R3 delta=0 | 对抗收敛 | 合并 R1+R2+R3 |
| R3 仍有新发现 | 强制终止 | 合并全部，标注"未完全收敛" |
| 硬上限 3 轮 | -- | 无论如何合并输出 |

## Round 2 注入模板

在 Round 1 的标准 prompt 之后追加以下内容：

```
## 上一轮审查结果（Round 1）

### 已发现的问题（不需要重复报告）
{R1 findings 表}

### 上一轮覆盖盲区（本轮聚焦）
{R1 coverage_gaps}

### 本轮指令
1. 聚焦上述覆盖盲区，深入检查
2. 对上一轮发现进行交叉验证（确认/推翻）
3. 从上一轮发现出发，追踪关联影响
4. 报告时使用 Delta 声明格式
```

## Round 3 对抗 prompt

在 Round 1 的标准 prompt 之后追加以下内容：

```
## 前两轮审查结果汇总
{R1+R2 全部 findings}

### 对抗审查指令
假设前两轮审查都有盲区。你的任务是找到遗漏。
检查策略：
1. 反向推理：从最坏后果倒推，哪些失败场景没被审到？
2. 交叉影响：findings 之间是否有组合效应？
3. 隐含假设：文档中有哪些隐含假设没被质疑？
4. 至少产出 1 个新发现，或声明"经对抗审查确认前两轮已充分覆盖"并给出 3 条具体证据
```

## 合并规则

1. 去重：相同维度 + 相同发现内容视为重复，保留最早轮次的 Issue ID
2. Round 溯源：每条 finding 标注首次发现的轮次（如 `[R1]`、`[R2]`、`[R3]`）
3. Verdict 重新计算：合并后按最严格的 Severity 决定最终 Verdict
   - 任何 FAIL -> 最终 FAIL
   - 无 FAIL 但有 WARN -> 最终 WARN
   - 全部无问题 -> 最终 PASS
4. Issue Count 重新计算：去重后的总 finding 数量

## 最终 review 文件格式

合并后的 review 文件保持原有格式，额外增加：

```
## 审查轮次

| 轮次 | 类型 | 新增发现数 | 收敛状态 |
|------|------|-----------|---------|
| Round 1 | 广度扫描 | N | - |
| Round 2 | 深度聚焦 | M | 收敛/未收敛 |
| Round 3 | 对抗审查 | K | 收敛/未完全收敛 |

### Delta 声明（Round 2+ 必填，Round 1 写"首轮审查"）
- 新增发现: N 条
- 确认上一轮: [issue ids]
- 推翻上一轮: [issue ids + 理由]
```
