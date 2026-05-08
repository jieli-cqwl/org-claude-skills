# Loop Diagnosis & Strategy

## 目标

每一轮循环要么关闭 gap、要么改变策略、要么暴露真正的阻塞。

暂停给用户时，用户拿到的不是"卡住了"，而是"卡在哪、为什么卡、尝试过什么、有哪些选项、推荐哪个"。

## 进展信号

有效进展只认这些信号：

| 信号 | 含义 |
| --- | --- |
| `gap_closed` | gap 完全解决，可推进下一步 |
| `gap_narrowed` | gap 缩小但未完全解决，方向正确 |
| `new_evidence` | 产出了新的测试结果、报告或分析，推进了对问题的理解 |
| `new_blocker` | 发现了之前不知道的阻塞，改变了问题的性质 |
| `new_risk` | 发现了新的风险，需要评估是否调整策略 |
| `owner_changed` | 换了执行者或角色，尝试新的方法 |

**无进展**：remaining gap 未缩小、evidence refs 未更新、没有新阻塞/风险、owner 未变化。"继续处理"、"已优化"、"基本完成"等自报不算进展信号。

## 判断框架

### 根因分类

Gap 没有关闭时，先判断属于哪一类，再选择对应的调整杠杆。不同根因需要不同的应对——盲目重试或随机换 owner 不会收敛。

| 根因类型 | 识别特征 | 首选杠杆 |
| --- | --- | --- |
| 信息缺口 | 执行者缺少必要输入：规格不清、上下文丢失、依赖输出缺失、前序证据未传递 | **补信息**：收窄 packet，把缺失的具体输入写入 input_refs |
| 能力/方法错配 | 执行者反复尝试同一策略无效、报告偏离目标、产出和预期差距大 | **换 owner** 或改 packet 策略，给出不同的方法指引 |
| Scope 模糊 | 执行者和验证者对同一 AC 给出不同理解、verifier 反复 FAIL 但 developer 认为已完成 | **暂停给用户**澄清 scope/AC 定义 |
| 环境阻塞 | 工具、权限、依赖服务、测试环境不可用，执行者无法运行必要的验证 | 标记 **NEEDS_RESOURCE**，说明缺什么和影响什么 |
| 技术方案不可行 | 设计本身有问题，当前架构无法满足需求，需要重新设计 | **升级回 tech-lead** |

### 策略调整杠杆

根因确定后，选择对应的调整方式。每次调整只动一个杠杆，这样能清楚观察效果：

1. **补信息** — 找到执行者缺少的具体输入，不是再催一遍"请完成"。收窄 packet，把缺失的 verify-result、spec、上游输出、失败证据写入 input_refs，让执行者清楚看到自己还缺什么。

2. **换 owner** — 同角色换不同 executor（如果可用），或在角色间重新路由。典型场景：developer 反复未能满足 AC，可能需要换一个 developer 或升级为 fixer 处理特定问题。

3. **收窄 scope** — 把一个大 gap 拆成可独立验证的子 gap，先关闭能关闭的部分。这能产出 `gap_narrowed` 信号，推动循环前进。

4. **改验证方式** — 当 expected_evidence 或 stop_condition 描述不够具体时，执行者不知道"完成"长什么样。和用户确认具体验收口径，重写 packet 的 expected_evidence。

### 回派决策

| 信号 | 下一步 |
| --- | --- |
| PASS evidence | 推进到下一阶段 |
| clear missing gap | 带收窄 packet 返回同一角色 |
| wrong owner | 重新路由到正确角色 |
| fixer 修改了代码 | 重跑受影响的 verifier / qa |
| 第 1 轮无进展 | 诊断根因，调整一个杠杆，重派 |
| 同一 gap 连续第 2 轮无进展 | 暂停给用户，带诊断和选项 |
| 达到第 10 轮 | 暂停给用户 |
| scope/AC/risk/authorization 不清 | 暂停给用户 |

**关键区分**：第 1 轮无进展时，你还有一次主动调整策略的机会——诊断根因后动一个杠杆。第 2 轮同一 gap 仍无进展时，说明你的调整也未解决问题，必须升级给用户。

## 质量标准

- 每次回派都收窄了 packet — goal 更具体、input_refs 更精确、expected_evidence 更明确。不允许复制上一轮的 packet 原样重派。
- 策略调整有明确的根因依据。能说清"判断根因是 X，所以调整了 Y"，不是"再试一次看看"。
- 暂停给用户时，决策包包含：根因分析、已尝试的策略及其效果、当前 gap 状态、可选项和推荐路径。

## 常见模式

| 场景 | 通常根因 | 处理 |
| --- | --- | --- |
| 执行者反复说"还在处理" | scope 不清或信息缺口——不是时间不够 | 检查 packet 的 goal 和 input_refs 是否足够具体 |
| Verifier 反复 FAIL 同一个 gap | AC 定义有歧义，或执行者和验证者对 scope 理解不一致 | 暂停给用户澄清 AC，不是继续让 developer 猜 |
| Fixer 修了但 verifier 又发现新问题 | 修复影响面评估不足，修了 A 坏了 B | 要求 fixer 在 fix-result 中声明影响面，收窄 verifier 验证范围 |
| Developer 声称完成但证据不足 | expected_evidence 描述不够具体，执行者不知道要交什么 | 收窄 packet 的 expected_evidence，写明需要什么具体输出 |
| 连续两轮都换了 owner 但 gap 没变 | 可能不是 owner 问题，而是 scope/AC/方案本身有问题 | 停止换 owner，暂停给用户审视 scope/AC |
| Gap 在缩小但速度很慢 | 正常收敛，不需要干预——只要有 `gap_narrowed` 信号就继续 | 监控但不打断，确保不超过 10 轮 |

## 边界

- 技术方案本身需要重新设计 → 循环诊断不够，需要升级回 tech-lead。
- 需求/目标本身有歧义 → 不是执行问题，暂停给用户。
- 达到 10 轮 → 强制暂停，无论根因是什么。
- 暂停时使用 `templates/user-decision-package.template.md`；状态卡使用 `templates/status-card.template.md`。
