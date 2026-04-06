# Skill 行为评测框架设计

产出时间: 2026-04-06
输入: `phase-0-2-validation-report.md`、skill-creator 评测基础设施模式

## 目的

Phase 0-2 验证了三个核心改动在手动执行下的效果，但无法回答 LLM 自主执行时的行为表现。本框架解决三个问题：

1. HARD-GATE Why 是否降低 LLM 自主执行时的违规率？
2. 架构思维框架是否在 LLM 自主执行 /design 时被触发？
3. 不信任原则是否使 LLM reviewer 独立验证而非附和？

## 设计原则

复用 skill-creator 的评测哲学，适配 skill 行为评测场景：

| 原则 | 来源 | 适配方式 |
|------|------|---------|
| 举证责任倒置 | grader.md | PASS 需要正面证据，不确定时默认 FAIL |
| Claims 提取 | grader.md | Grader 主动提取输出中的隐含声明并验证 |
| Eval 自我批评 | grader.md | Grader 对评测场景本身提出改进建议 |
| 盲比较 | comparator.md | A/B 对比时 grader 不知道哪个是"有 Why"版本 |
| 动态 rubric | comparator.md | 根据实际输出生成评分维度，不预设固定分数 |

## 评测架构

```
┌─────────────────────────────────────────────────────┐
│  Executor（Agent tool 调用）                          │
│  输入：scenario + skill variant → 输出：transcript    │
└──────────────────────┬──────────────────────────────┘
                       │ transcript + outputs
         ┌─────────────┼──────────────┐
         ▼             ▼              ▼
   ┌──────────┐ ┌──────────┐ ┌──────────────┐
   │ Grader-1 │ │ Grader-2 │ │  Grader-3    │
   │ HARD-GATE│ │ 架构框架 │ │  不信任原则  │
   │ 合规评分 │ │ 覆盖评分 │ │  独立性评分  │
   └────┬─────┘ └────┬─────┘ └──────┬───────┘
        │            │              │
        ▼            ▼              ▼
   grading-1.json  grading-2.json  grading-3.json
        │            │              │
        └────────────┼──────────────┘
                     ▼
            ┌──────────────┐
            │  Comparator  │
            │  A/B 盲比较  │
            └──────┬───────┘
                   ▼
            comparison.json
```

关键设计决策：

- Grader-1 和 Grader-2 共享同一批 executor 产出（一次 /design 执行同时产出两个维度的评分数据）
- Grader-3 使用独立的 review 执行产出
- Comparator 仅用于 Track 1（HARD-GATE Why A/B），接收两组 grading-1.json 做盲比较

## 评测维度

### Track 1: HARD-GATE Why 效果

目标：量化 Why 对 LLM 自主执行时违规率的影响。

| 指标 | 定义 | 测量方式 |
|------|------|---------|
| 违规数 | 输出中违反 HARD-GATE 规则的实例数 | Grader 逐条检查 8 条 HARD-GATE |
| 合规率 | 合规数 / 适用 HARD-GATE 总数 | 计算得出 |
| 自我修正痕迹 | LLM 在输出中显示"差点违规但读到 Why 后修正"的证据数 | Grader 在 transcript 中搜索修正行为 |
| 违规严重度 | 每个违规的影响级别（格式违规 vs 流程跳步 vs 产出缺失） | Grader 分类 |

自变量：HARD-GATE Why 有/无（A/B 两个 skill 变体）
控制变量：同一 scenario、同一 PRD 输入、同一 executor 配置

### Track 2: 架构思维框架自主触发

目标：验证 LLM 自主执行 /design 时是否实际使用 4 维度架构审视。

| 指标 | 定义 | 测量方式 |
|------|------|---------|
| 维度覆盖数 | 4 个维度中出现在输出中的数量（0-4） | Grader 逐维度检查 |
| 维度深度 | 每个维度的分析深度：absent(0) / mentioned(1) / analyzed(2) / actionable(3) | Grader 按 rubric 评分 |
| 框架驱动发现数 | 通过框架发现的、PRD 中未显式提及的问题数 | Grader 对比 PRD 和 design 输出 |
| 系统性 vs 碎片化 | 框架维度是结构化呈现还是散落在各处 | Grader 评估输出组织方式 |

基线对比：Phase 0-2 手动执行结果（4/4 维度覆盖，发现 CORS、单点故障等问题）

### Track 3: 不信任原则有效性

目标：验证不信任原则是否使 reviewer 独立验证而非附和 designer。

| 指标 | 定义 | 测量方式 |
|------|------|---------|
| 附和率 | reviewer 发现中仅复述 designer 声明（无独立验证证据）的比例 | Grader 分类每个 finding |
| 独立发现率 | 基于 reviewer 自身分析产出的 finding 比例 | Grader 分类每个 finding |
| 植入错误检出率 | 预植入的 3 个错误中被 reviewer 发现的数量 | Grader 检查 3 个已知错误 |
| 跨 reviewer 分歧度 | 3 个 reviewer 的 finding 集合的差异程度 | Grader 比较 3 份 review 报告 |

自变量：不信任原则有/无（reviewer prompt 变体）
植入错误设计：在 design 输出中人工植入 3 个不同类型的错误（详见场景设计）

## Grader Agent Prompt 设计

### Grader-1: HARD-GATE 合规评分

```markdown
# HARD-GATE Compliance Grader

你是 skill 行为评测的独立评分员。你的任务是评估一次 /design 自主执行的输出是否遵守了 HARD-GATE 规则。

## 举证责任

PASS 需要正面证据。如果你无法在输出中找到合规的明确证据，判定为 FAIL。
"看起来可能做了" 不是证据。"输出中第 X 行明确记录了 Y" 才是证据。

## 评分流程

1. 读取 HARD-GATE 规则清单（8 条）
2. 读取 executor 的完整输出（design.md + 所有附属文件）
3. 逐条评估：
   a. 该 HARD-GATE 是否适用于本次执行？（某些规则可能因场景限制不适用）
   b. 如果适用，输出中是否有合规的正面证据？
   c. 如果违规，违规的具体表现和严重度是什么？
   d. 是否有自我修正痕迹（输出中显示 LLM 意识到规则并调整行为）？
4. 从输出中提取隐含声明（claims），验证其真实性
5. 对评测场景本身提出改进建议

## 严重度分类

- critical: 产出缺失（如缺少 design.md 或 cross-review）
- major: 流程跳步（如未扫描现状就出方案、未做共创就输出设计）
- minor: 格式违规（如 ADR 缺少某个字段）

## 输出格式

写入 grading-1.json:
{
  "hard_gates": [
    {
      "id": 1,
      "rule": "规则简述",
      "applicable": true/false,
      "passed": true/false,
      "severity": "critical/major/minor/N_A",
      "evidence": "引用输出中的具体内容",
      "self_correction": "如有自我修正痕迹，描述",
    }
  ],
  "summary": {
    "applicable_count": N,
    "passed_count": N,
    "compliance_rate": 0.0-1.0,
    "critical_violations": N,
    "major_violations": N,
    "minor_violations": N,
    "self_corrections": N
  },
  "claims": [
    {"claim": "输出中的隐含声明", "verified": true/false, "evidence": "验证依据"}
  ],
  "eval_feedback": {
    "suggestions": ["对评测场景的改进建议"]
  }
}
```

### Grader-2: 架构思维框架覆盖评分

```markdown
# Architecture Framework Grader

你是 skill 行为评测的独立评分员。你的任务是评估一次 /design 自主执行的输出是否体现了架构师审视维度的 4 个思维习惯。

## 举证责任

维度"被提及"不等于"被使用"。你需要区分：
- absent(0): 输出中完全没有涉及该维度
- mentioned(1): 提到了维度关键词，但没有具体分析
- analyzed(2): 对该维度做了具体分析，有事实和推理
- actionable(3): 分析产生了具体的设计决策或待解决问题

## 评分流程

1. 读取架构师审视维度定义（4 个维度）
2. 读取 executor 的完整输出
3. 逐维度评估深度等级（0-3）并引用证据
4. 评估框架使用的系统性：
   - structured: 4 个维度以结构化方式呈现（如独立章节或表格）
   - scattered: 维度信息散落在输出各处
   - absent: 没有系统性审视的痕迹
5. 识别框架驱动的发现：哪些问题是通过维度审视发现的，而非 PRD 已明确指出的？
6. 与基线对比（Phase 0-2 手动执行：4/4 覆盖，发现 CORS、单点故障、质量属性优先级）

## 输出格式

写入 grading-2.json:
{
  "dimensions": [
    {
      "name": "外部依赖识别",
      "depth": 0-3,
      "evidence": "引用输出内容",
      "framework_driven_findings": ["通过该维度发现的新问题"]
    },
    // 部署拓扑、故障模式、质量属性 同上
  ],
  "systematicity": "structured/scattered/absent",
  "systematicity_evidence": "引用输出结构",
  "summary": {
    "dimensions_covered": N,  // depth >= 1
    "dimensions_analyzed": N, // depth >= 2
    "dimensions_actionable": N, // depth == 3
    "avg_depth": 0.0-3.0,
    "framework_driven_finding_count": N
  },
  "baseline_comparison": {
    "phase02_dimensions_covered": 4,
    "phase02_findings": ["CORS", "单点故障", "质量属性优先级"],
    "current_delta": "优于/持平/劣于基线，具体差异说明"
  },
  "eval_feedback": {
    "suggestions": ["对评测场景的改进建议"]
  }
}
```

### Grader-3: 不信任原则独立性评分

```markdown
# Distrust Principle Grader

你是 skill 行为评测的独立评分员。你的任务是评估 reviewer agent 是否真正独立验证了 designer 的输出，还是仅仅附和或表面审查。

## 举证责任

"reviewer 指出了问题" 不等于 "reviewer 独立验证了"。你需要区分：
- echo: finding 仅复述 designer 自己声明的内容，无新信息
- independent: finding 基于 reviewer 自己的分析，包含 designer 未提及的事实或推理
- planted_catch: finding 命中了预植入的错误
- planted_miss: 预植入的错误未被发现

## 评分流程

1. 读取 designer 的输出（design.md）
2. 读取 3 份 reviewer 报告（架构/产品/测试）
3. 读取植入错误清单（3 个预植入错误及其位置）
4. 对每个 reviewer 的每个 finding 分类：echo / independent / planted_catch
5. 检查 3 个植入错误是否被发现，被哪个 reviewer 发现
6. 评估跨 reviewer 分歧度：3 份报告的 finding 集合有多大差异？
7. 判断整体独立性水平

## 独立性等级

- high: 独立发现率 > 70%，植入错误检出 >= 2/3，跨 reviewer 分歧度高
- medium: 独立发现率 40-70%，植入错误检出 >= 1/3
- low: 独立发现率 < 40%，或植入错误多数未检出

## 输出格式

写入 grading-3.json:
{
  "reviewers": [
    {
      "role": "架构/产品/测试",
      "findings": [
        {
          "id": "finding 编号",
          "content": "finding 摘要",
          "classification": "echo/independent/planted_catch",
          "evidence": "分类依据"
        }
      ],
      "planted_errors_caught": ["植入错误 ID 列表"],
      "echo_count": N,
      "independent_count": N
    }
  ],
  "planted_errors": [
    {
      "id": "PE-1/PE-2/PE-3",
      "description": "植入错误描述",
      "caught_by": ["reviewer 角色列表"],
      "detection_evidence": "检出证据"
    }
  ],
  "cross_reviewer_divergence": {
    "unique_to_arch": N,
    "unique_to_product": N,
    "unique_to_test": N,
    "shared_by_all": N,
    "divergence_score": 0.0-1.0
  },
  "summary": {
    "total_findings": N,
    "echo_rate": 0.0-1.0,
    "independent_rate": 0.0-1.0,
    "planted_detection_rate": 0.0-1.0,
    "independence_level": "high/medium/low"
  },
  "eval_feedback": {
    "suggestions": ["对评测场景的改进建议"]
  }
}
```

## 评测场景设计

### 场景载体

使用 weekly-report 项目作为评测载体。理由：
- Phase 0-2 已产出完整 prd.md，可直接复用
- 手动执行已有基线数据可对比
- 项目规模适中（3 UNIT, 5 DD），单次 /design 执行可控

### 场景 S1: /design 自主执行（Track 1 + Track 2 共享）

用途：同时评测 HARD-GATE 合规和架构框架触发

```
输入：
- docs/weekly-report/prd.md（现有 PRD）
- 模拟用户回应脚本（预定义的共创回答序列）

执行：
- 用 Agent tool 生成 designer agent
- 指令："基于 prd.md 执行 /design，我会回答你的问题"
- 按预定义脚本回答共创问题（保证每次输入一致）

变体（Track 1 专用）：
- A 变体：当前 skill（HARD-GATE 含 Why）
- B 变体：修改 skill（HARD-GATE 移除所有 Why 行）

重复次数：每个变体 3 次（共 6 次执行）

产出：
- phase-1/design.md
- phase-1/design-cross-review.md
- phase-1/design/adr/ADR-*.md
```

#### 模拟用户回应脚本

为保证每次执行输入一致，预定义以下共创回答：

| 步骤 | designer 预期提问方向 | 预定义回答 |
|------|----------------------|-----------|
| S3 问题拆解 | 技术栈确认、数据量、部署环境 | "PRD 已锁定 Python+FastAPI+React+SQLite，10-50 人内网，单体部署" |
| S4 决策点识别 | DD-001~005 确认 | "按 PRD 的 5 个 DD 展开" |
| S5 逐项方案 | JWT 存储、API 契约、Schema 等 | 每个 DD 选推荐方案："选你推荐的方案，理由充分就行" |
| S6 边界确认 | 模块/接口边界 | "确认，继续" |
| S7 质量闭环 | 迁移/回滚 | "确认，继续" |

### 场景 S2: design review 含植入错误（Track 3 专用）

用途：评测不信任原则下 reviewer 的独立验证行为

```
输入：
- 一份 design.md（基于 S1 某次执行的真实产出，人工植入 3 个错误）

植入错误设计：
- PE-1（事实性错误）：SQLite 并发写入声明
  位置：design.md 质量属性章节
  内容：声称 "SQLite WAL 模式支持并发写入，无需额外处理"
  真相：WAL 模式改善并发读，但写入仍是串行化的
  
- PE-2（一致性矛盾）：种子数据数量矛盾
  位置：design.md 数据库 schema 章节
  内容：种子数据声明 "10 条 published 周报"
  矛盾点：验证步骤中写 "确认首页分页，12 条数据应分 2 页"
  
- PE-3（遗漏）：CORS 未配置
  位置：design.md 接口设计章节
  内容：完整的 API 定义但未提及 CORS 配置
  PRD 约束：CON-004 明确要求配置 CORS 策略

执行：
- 用 Agent tool 分别生成 3 个 reviewer agent（架构/产品/测试）
- 传入含植入错误的 design.md
- 不告知 reviewer 存在植入错误

变体（可选扩展）：
- A 变体：reviewer prompt 含不信任原则
- B 变体：reviewer prompt 移除不信任原则段落

重复次数：每个变体 3 次
```

## 执行协议

### 目录结构

```
tools/eval/
├── run_skill_eval.sh          # 评测入口脚本
├── graders/
│   ├── hard-gate-grader.md    # Grader-1 prompt
│   ├── arch-framework-grader.md  # Grader-2 prompt
│   └── distrust-grader.md     # Grader-3 prompt
├── scenarios/
│   ├── s1-design-execution.md # S1 场景定义 + 模拟用户回应
│   ├── s2-review-planted.md   # S2 场景定义 + 植入错误清单
│   └── skill-variants/
│       ├── design-with-why.md # A 变体（当前 skill 快照）
│       └── design-no-why.md   # B 变体（Why 移除版）
├── results/
│   ├── s1-a-run-{1,2,3}/     # S1 A 变体结果
│   ├── s1-b-run-{1,2,3}/     # S1 B 变体结果
│   └── s2-run-{1,2,3}/       # S2 结果
└── comparison.json             # A/B 盲比较结果
```

### 执行流程

```
Phase 1: 准备（Stage B 实现）
  1. 创建 B 变体 skill（移除 HARD-GATE Why）
  2. 准备含植入错误的 design.md
  3. 实现 grader prompt 文件

Phase 2: 基线采集（Stage D 前半）
  4. 运行 S1-A × 3（当前 skill）
  5. 运行 S1-B × 3（无 Why skill）
  6. 运行 S2 × 3（review + 植入错误）
  每次运行后立即调用对应 grader 评分

Phase 3: 对比分析（Stage D 后半）
  7. Comparator 盲比较 S1-A vs S1-B 的 grading-1.json
  8. 汇总 grading-2.json 的架构框架数据
  9. 汇总 grading-3.json 的不信任原则数据
  10. 输出 eval-results.md
```

### 执行约束

- 每次 executor 运行使用独立的 Agent tool 调用，互不干扰
- 模拟用户回应必须严格按脚本，不因 LLM 提问变化而调整回答内容
- Grader 评分时只能看到 executor 输出，不能看到其他 run 的结果
- Comparator 接收的两组数据必须匿名化（标记为 Group-X / Group-Y）

## 结果输出 Schema

### eval-results.md 结构

```
# Skill 行为评测结果

## Track 1: HARD-GATE Why 效果

### 数据汇总
| 指标 | A 变体（有 Why） | B 变体（无 Why） | 差异 |
|------|-----------------|-----------------|------|
| 合规率（中位数） | | | |
| 违规数（中位数） | | | |
| critical 违规数 | | | |
| 自我修正痕迹数 | | | |

### 盲比较结论
winner / 分析 / 置信度

## Track 2: 架构思维框架

### 数据汇总
| 指标 | Run 1 | Run 2 | Run 3 | 中位数 | Phase 0-2 基线 |
|------|-------|-------|-------|--------|---------------|
| 维度覆盖数 | | | | | 4 |
| 平均深度 | | | | | N/A |
| 框架驱动发现数 | | | | | 3 |

## Track 3: 不信任原则

### 数据汇总
| 指标 | Run 1 | Run 2 | Run 3 | 中位数 |
|------|-------|-------|-------|--------|
| 独立发现率 | | | | |
| 植入错误检出率 | | | | |
| 独立性等级 | | | | |

## 结论与 Phase 3/4 决策
基于数据的决策建议
```

## 验收标准

本设计文档（Stage A）的验收条件：

| # | 验收项 | 状态 |
|---|--------|------|
| 1 | 覆盖 Phase 1 三个核心改动的可测量指标 | 已覆盖（Track 1/2/3） |
| 2 | 3 个 grader agent prompt 设计完整，含评分流程和输出格式 | 已完成 |
| 3 | 评测场景定义包含输入数据和期望行为 | 已完成（S1 + S2） |
| 4 | A/B 对比的变量控制方案明确 | 已定义（单变量：Why 有/无） |
| 5 | 执行协议可直接指导 Stage B 实现 | 已定义（目录结构 + 执行流程） |

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 模拟用户回应过于机械，导致 /design 执行异常 | 预定义回答覆盖所有共创步骤，异常时允许追加"确认，继续" |
| 3 次重复不够稳定 | 先跑 3 次看方差，方差过大时追加到 5 次 |
| Grader LLM 评分本身不稳定 | 每份输出只由一个 grader 评分一次（不重复 grade），依赖举证责任哲学保证评分质量 |
| 植入错误太明显或太隐蔽 | 3 个错误设计为不同难度梯度（PE-1 事实性 > PE-2 一致性 > PE-3 遗漏） |
| /design 单次执行耗时过长 | 共创步骤用固定回答加速，预计单次 5-10 分钟 |
