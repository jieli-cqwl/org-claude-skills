# Skill 能力有效性评审与生命周期闭环

## 问题陈述

当前 skill 生命周期只有"设计→实现→上线"的前半段，缺少"度量→评审→决策（保留/优化/退役）"的后半段。skill 上线后永远在线，没有反馈回路告知 skill 是否仍在产生正向价值。具体表现：

1. **Skill 只增不减**——建 skill 有流程（brainstorming → writing-plans → 实现），退 skill 无流程、无触发条件、无数据支撑
2. **价值判断凭感觉**——无法量化一个 skill 比裸模型好多少、偏好是否被忠实执行
3. **基线在移动**——模型从 Opus 4.5 升级到 4.7，skill 的 Uplift 增益可能已被模型能力吃掉，但从未重新验证
4. **隐性成本不可见**——每个 skill 消耗上下文 token、增加维护负担、可能与其他 skill 冲突，但成本从未量化

## 目标与成功标准

**目标：** 为标准流程链的 12 个 skill 建立可重复的能力评审框架和生命周期闭环，使每个 skill 的存在都有证据支撑。

**成功标准：**

1. 每个标准流程链 skill 有明确的类型声明（Capability Uplift / Encoded Preference / 混合）
2. 每个 skill 有 ≥3 个 eval 场景和对应的评审数据
3. 每个 skill 有"保留/优化/退役"的结论，附可追溯的证据
4. 评审框架可重复执行——下次模型升级后，同一流程能重新产出结论

## 方案

### 核心模型：两类 Skill，两种评审协议

Skill 按价值来源分为两类，类型决定评审协议：

| 类型 | 定义 | 核心评审问题 | 评审协议 |
|------|------|-------------|---------|
| **Capability Uplift** | 补能力——让 Claude 做原本不稳定、不会做、容易做错的事 | 这个 skill 还带来真实增益吗？ | with/without baseline 对比 |
| **Encoded Preference** | 固化偏好——固化用户的流程、判断标准、方法论 | 它还在按用户的方式工作吗？ | 偏好锚点保真度检测 |
| **混合型** | 两者兼有 | 分别回答上面两个问题 | 两套协议都跑（共享 eval 运行） |

### 交付物 1：Skill 能力有效性标准（D9 维度）

位置：`shared/reference/Skill能力有效性标准.md`

与现有 D1-D8 工程质量标准并列，新增 D9 维度。同时在 `shared/reference/Skill质量标准.md` 中注册 D9。

**D9: 存在合理性**

| 保护的风险 | 核心消费者 |
|-----------|-----------|
| Skill 价值衰减未被发现、偏好漂移未被检测、退役延迟导致上下文浪费 | skill-harness、skill 维护者、用户 |

L2 基线：

- SKILL.md frontmatter 声明 `eval-type`（capability_uplift / encoded_preference / mixed）
- skill 有 eval 场景（`evals/evals.json` 中 `eval_type` 与声明匹配）
- 有最近一次评审记录和结论
- Capability Uplift 部分有 baseline 对比数据
- Encoded Preference 部分有偏好锚点定义和保真度数据

#### Capability Uplift 评审协议

```
输入：N 个典型场景 prompt（≥3，来自 evals/evals.json）

流程：
  1. 每个 prompt 分别跑 with-skill 和 without-skill
     （使用 skill-creator 的并行 subagent 基础设施）
  2. 用预定义 grader 按维度打分（每维度 0-5 分）
     维度由每个 skill 自行定义（如 developer: tdd_evidence, code_quality, error_handling）
  3. 计算 with_avg 和 without_avg（所有场景、所有维度的平均分）
  4. 计算增益 = with_avg - without_avg
  5. 报告上下文成本 = SKILL.md 行数 + 加载的 reference 行数

结论规则（从上到下优先匹配）：
  - 增益 < 0.5 → 退役候选（需人工确认后执行退役协议）
  - with_avg ≥ 4.0 且增益 ≥ 1.0 → 保留
  - 其余（增益 ≥ 0.5 但绝对分或增益未达保留线）→ 优化
    （聚焦低分维度、缩减上下文成本、或改进 skill 实现质量）
```

#### Encoded Preference 评审协议

```
偏好锚点定义：
  每个 Encoded Preference skill 声明 5-10 个偏好锚点
  锚点 = 用户期望 skill 在输出中一定体现的行为特征
  锚点提取来源：SKILL.md 的 HARD-GATE、流程步骤、输出合同
  锚点清单由用户确认

流程：
  1. 每个 prompt 用 skill 跑一遍
  2. 用偏好锚点 checklist 作为 grader 的评分标准（每个锚点：命中/未命中）
  3. 计算保真度 = 命中锚点数 / 总锚点数（所有场景平均）

结论规则：
  - 保真度 ≥ 80% → 保留
  - 保真度 60%-80% → 优化（找出系统性丢失的锚点，强化 SKILL.md 对应段落）
  - 保真度 < 60% → skill 失效，需要重写或退役
```

#### 混合型处理

共享 eval 运行以控制成本：
- with-skill 的输出同时评 grader 分数（Uplift）和锚点命中率（Preference）
- 只额外跑 without-skill 做 Uplift 对比
- 两套协议分别产出结论

### 交付物 2：标准 eval 模板

位置：各 skill 的 `evals/` 目录，遵循 skill-creator 的 `evals.json` 格式。

**Uplift 模板（新增 `eval_type` 和 `grader_dimensions` 字段）：**

```json
{
  "skill_name": "developer",
  "eval_type": "capability_uplift",
  "evals": [
    {
      "id": "uplift-tdd-discipline",
      "prompt": "实现一个用户登录接口...",
      "grader_dimensions": ["tdd_evidence", "code_quality", "error_handling"],
      "run_modes": ["with_skill", "without_skill"]
    }
  ]
}
```

**Preference 模板（新增 `preference_anchors` 字段）：**

```json
{
  "skill_name": "product-director",
  "eval_type": "encoded_preference",
  "preference_anchors": [
    {"id": "PA-1", "anchor": "先定义根问题再谈方案", "weight": 1},
    {"id": "PA-2", "anchor": "产出 Phase 拆分", "weight": 1},
    {"id": "PA-3", "anchor": "冻结 Director baseline 后才交接", "weight": 1}
  ],
  "evals": [
    {
      "id": "fidelity-weekly-report",
      "prompt": "我们要做一个周报自动生成功能",
      "expected_anchors": ["PA-1", "PA-2", "PA-3"]
    }
  ]
}
```

**混合型模板：同时包含 `grader_dimensions` 和 `preference_anchors`，`eval_type` 为 `mixed`。**

每个标准链 skill 需要补充：
- SKILL.md frontmatter 加 `eval-type` 字段
- Encoded Preference 和混合型定义偏好锚点清单
- ≥3 个 eval 场景

### 交付物 3：生命周期闭环规则

位置：`shared/reference/Skill生命周期管理.md`

四个门禁点：

| 门禁 | 触发条件 | 检查内容 | 不通过后果 |
|------|---------|---------|-----------|
| **Gate 1: 上线门禁** | 新 skill 上线前 | 类型声明、≥3 eval 场景、首次评审达标 | 不允许上线 |
| **Gate 2: 模型升级触发** | Claude 大版本升级后（如 Opus 4.N → 4.N+1） | Capability Uplift 和混合型 skill 重跑 baseline | 不达标 → 进入优化或退役流程 |
| **Gate 3: 定期复审** | 按季度 | Encoded Preference 型跑保真度检测 + 用户确认锚点是否仍反映当前意图 | 不达标 → 进入优化或退役流程 |
| **Gate 4: 退役协议** | 同一门禁类型连续两次评审不达标 | 人工确认 | 执行退役操作 |

**退役操作清单：**

1. SKILL.md frontmatter 标记 `deprecated: true`
2. 从 `contracts/standard-chain.yaml` 摘除
3. skill 目录移至 `shared/skills/archive/`
4. 更新 `shared/reference/Skill质量标准.md` 和 `Skill能力有效性标准.md` 中的 skill 清单
5. 在标准流程链文档中记录退役原因和日期

### 集成点

**skill-harness D9 维度：**

在 skill-harness 审计流程中新增 D9 检查项：

- skill 声明了 `eval-type`
- skill 有匹配类型的 eval 场景
- 有最近一次评审记录和结论
- Capability Uplift 型有 baseline 对比数据
- Encoded Preference 型有偏好锚点定义和保真度数据
- 退役候选 skill 有人工确认记录

**Skill质量标准.md 更新：**

在 D8 之后增加 D9 维度定义，格式与 D1-D8 一致。

**skill-creator 使用方式：**

不修改 skill-creator 本身，仅使用其已有能力：
- 并行 subagent 跑 with/without 对比
- grader 打分（`agents/grader.md`）
- 盲评对比（`agents/comparator.md` + `agents/analyzer.md`）
- benchmark 聚合（`scripts/aggregate_benchmark.py`）
- eval 结果查看器（`eval-viewer/`）

## 备选方案

| 方案 | 描述 | 未选原因 |
|------|------|---------|
| 建一个独立的 skill-eval skill | 一键完成存在性评审 + 能力评测 | 与 skill-harness/skill-creator 能力重叠，增加 skill 碎片化 |
| 全自动化生命周期 | 模型升级自动触发 eval、结果自动聚合、退役自动建议 | 当前 12 个标准链 skill 的规模不需要全自动化，ROI 不足 |
| 只写评审框架文档不建闭环 | 手工参考文档评审 | 一次性的，不可重复，下次模型升级又从头来 |

## 变更范围

| 变更对象 | 变更类型 | 影响范围 |
|---------|---------|---------|
| `shared/reference/Skill能力有效性标准.md` | 新增 | 新文件，被 skill-harness 和 skill 维护者消费 |
| `shared/reference/Skill生命周期管理.md` | 新增 | 新文件，定义 4 个门禁点 |
| `shared/reference/Skill质量标准.md` | 修改 | 增加 D9 维度定义 |
| `shared/skills/skill-harness/SKILL.md` | 修改 | 增加 D9 审计检查项 |
| 12 个标准链 skill 的 `SKILL.md` | 修改 | 增加 `eval-type` frontmatter 字段 |
| 12 个标准链 skill 的 `evals/` | 新增/修改 | 补充 eval 场景和偏好锚点 |

## 不变量

- 现有 D1-D8 工程质量标准不变，D9 是追加不是替换
- skill-creator 不做任何修改，只使用其已有能力
- skill-harness 的只读审计性质不变，D9 也是只读检查
- 阈值（增益 ≥ 1.0/0.5、保真度 ≥ 80%/60%）是初始值，首轮评审后根据实际数据校准
- 退役决策始终需要人工确认，不自动执行

## 下游影响

| 下游消费者 | 影响 |
|-----------|------|
| skill-harness | 新增 D9 维度审计项——已有审计流程不变，仅追加 |
| 标准流程链 skill | 需补充 frontmatter 字段和 eval 场景——不影响 skill 本身的运行时行为 |
| Skill质量标准.md | 新增 D9 段落——对已有 D1-D8 内容无修改 |
| skill-creator | 无修改——仅被调用执行 eval |
| standard-chain.yaml | 当前不修改——仅当 skill 退役时才需更新 |

## 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 阈值设定不合理导致误判 | 可能误退役有价值的 skill 或保留无价值的 | 首轮评审仅产出建议，不执行退役；根据首轮数据校准阈值 |
| 偏好锚点定义不完整导致保真度偏低 | Encoded Preference skill 被错判为"失效" | 锚点清单由用户确认，评审时锚点覆盖不足属于锚点定义问题而非 skill 问题 |
| eval 场景不够典型导致结论不可信 | 评审结论不能代表真实使用场景 | 每 skill ≥3 个场景，覆盖核心使用场景；eval 场景需用户确认代表性 |
| 模型升级后 eval 结果不稳定（方差大） | 单次 eval 不足以得出可靠结论 | 每场景跑 3 次取平均（skill-creator 已支持多次运行） |

## 执行计划

### 阶段 1：框架搭建

1. 撰写 `shared/reference/Skill能力有效性标准.md`
2. 撰写 `shared/reference/Skill生命周期管理.md`
3. 更新 `shared/reference/Skill质量标准.md` 增加 D9
4. 更新 `shared/skills/skill-harness/SKILL.md` 增加 D9 审计项

### 阶段 2：试点验证

5. product-director 评审（纯 Encoded Preference，验证偏好保真度协议）
6. developer 评审（混合型，验证 with/without 对比协议 + 偏好保真度协议）
7. 根据试点结果校准阈值

### 阶段 3：批量推广

8. 按链路顺序完成剩余 10 个 skill 的评审
9. 产出 12 个 skill 的完整评审报告

### 标准流程链 Skill 分类与评审计划

| # | Skill | 位置 | 类型 | 评审协议 |
|---|-------|------|------|---------|
| 1 | product-director | main | Encoded Preference | 偏好锚点保真度 |
| 2 | product-manager | main | Encoded Preference | 偏好锚点保真度 |
| 3 | design | main | 混合 | 两套都跑 |
| 4 | test-design | main | 混合 | 两套都跑 |
| 5 | tech-lead | main | Encoded Preference | 偏好锚点保真度 |
| 6 | developer | main | 混合 | 两套都跑 |
| 7 | review | main | 混合 | 两套都跑 |
| 8 | verify | main | 混合 | 两套都跑 |
| 9 | qa | main | 混合偏 Preference | 两套都跑 |
| 10 | delivery-owner | main | Encoded Preference | 偏好锚点保真度 |
| 11 | fix | sidecar | 混合 | 两套都跑 |
| 12 | consistency-audit | sidecar | 混合 | 两套都跑 |

## scope 边界

**不做：**

- 不建新 skill——评审能力分布在标准文档、eval 模板和 skill-harness D9 中
- 不做全自动化调度——闭环规则由人工按触发条件执行
- 不评审 community skill——只评审 `shared/skills/` 下的 first-party 标准链 skill
- 不改 skill-creator 本身——只使用其已有的 eval 基础设施
- 不修改 skill 的运行时行为——只在 frontmatter 加元数据、在 evals/ 加评审场景
