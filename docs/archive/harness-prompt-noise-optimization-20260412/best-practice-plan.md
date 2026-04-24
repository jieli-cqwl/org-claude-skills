# 复杂链路上下文治理最佳实践

## 目标

这份文档只保留当前仍然有效的结论：

- runtime prompt 去章节化
- sub agent 只在使用点出现
- 主 Agent 保留确认、裁决、回退、Gate、sign-off
- central truth 保留但引用说明收缩
- 现有跨职能评审继续做最终质量门禁

## 核心原则

### 1. Prompt 只保留判断语法

复杂链路 `product -> design -> test-design -> tech-lead -> delivery-owner` 的运行时 prompt 只保留：

- 当前阶段目标
- 主 Agent 不可下放的责任边界
- 用户共创/暂停/回退触发器
- 关键反偏置提醒
- 使用点内联的一句 sub agent 约束

不再保留：

- 独立 `sub agent` 章节
- 共享 contract 说明文
- 模板字段清单
- 长篇治理解释
- 主观触发词

### 2. Sub Agent 只做局部工序

sub agent 不是一个需要在 prompt 里单独讲解的对象，而是步骤里的一个动作。

保留原则：

- 只在真正调用的步骤里出现
- 只写 3 件事：何时用、产出什么、不能越权什么
- 只产出候选事实、候选草稿、结构草稿、汇总结果

禁止越权：

- 不得冻结最终结论
- 不得代替主 Agent 做 Gate 判定
- 不得代替用户确认或业务 sign-off

### 3. Harness 只承接硬边界

应该留给 Harness 的是：

- 文件存在性
- 固定字段
- 草稿不泄漏
- fresh proof / evidence anchor / 真实依赖

不应该继续写回 prompt 的是：

- schema 解释
- 模板正文
- 合同说明文
- 评估用 metrics
- 过程元数据

### 4. 不为“防漂移”增加运行时噪音

判断标准只有一条：

**如果一段信息不是主 Agent 当前决策必需，也不能证明会被当前运行时直接消费，就不应保留在运行时表面。**

## 分阶段落点

### `product`

- 只在问题理解步骤内联扫描/假设类 sub agent
- 主 Agent 继续负责根问题确认和 PRD 收口

### `design`

- 只在事实采集、方案探索、ADR 生成三个使用点内联
- 主 Agent 继续负责方案收敛和最终裁决

### `test-design`

- 只在 coverage、equivalence、QA handoff 三处内联
- 主 Agent 继续负责 `DESIGN-GAP(EQ)` 判定

### `tech-lead`

- 不保留专门的草稿派发环节；复杂映射由主 Agent 在当前步骤内直接收敛
- 最终 `plan.json / tasks.json` 不保留过程草稿、候选字段或未收敛多版本痕迹
- 主 Agent 继续负责 `DESIGN_OK`、计划模式、Task 冻结和用户确认

### `delivery-owner`

- 只在状态/证据汇总真正发生的位置内联
- 主 Agent 继续负责 Gate、回退、sign-off 与风险接受

## 验收口径

满足下面条件，才算这条最佳实践落地：

1. 5 个主 skill 都没有独立 sub agent 章节。
2. sub agent 只在使用点出现。
3. runtime prompt 不再重复 shared contract prose。
4. 主 Agent 的裁决语义没有被“去噪”误删。
5. gate/test 检查的是硬边界，不是说明文案。
