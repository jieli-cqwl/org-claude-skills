# Skill 治理体系精简方案：new-skills 与 skill-creator 共存设计

## Context

用户维护了一套完整的本地 skill 治理体系（25 个自定义 skill + 4 rules + 15 references + 质量标准 + 工具链），同时官方有 `skill-creator` skill。核心困扰：无法确定本地维护的方向是否正确，缺乏数据验证。

### 诊断结论

- **方向正确性**：官方架构（`~/.claude/rules/`、`~/.claude/skills/`）明确支持用户定制，社区（superpowers、vercel-labs）也在做类似的事。独立维护是预期用法，不是偏离正道。
- **具体实现有效性**：目前是"信念驱动"而非"数据驱动"。7 维度 L1/L2/L3、14 项反模式等标准缺乏 eval 数据支撑。
- **两套工具不是竞争关系**：skill-creator 管"创建和验证"（eval 基础设施），本地体系管"质量标准和工作流编排"（rules/references/contracts）。

### 本地体系与官方的层次关系

```
Layer 3: 工作流编排    ← contracts/small-chain, 25 个自定义 skill（官方无替代）
Layer 2: 质量标准      ← rules/(4), reference/(15), Skill质量标准（官方无替代）
Layer 1: Skill 创建    ← new-skills vs skill-creator（重叠区域）
```

官方 skill-creator 只覆盖 Layer 1 + 运行时验证（eval）。Layer 2 和 Layer 3 是本地体系的独特价值。

## 方案：精简后共存

### 核心决策

| 领域 | 决策 | 原因 |
|------|------|------|
| Skill 创建流程 | 用官方 skill-creator | 工程更成熟：并行 eval、benchmark 统计、description 自动优化（20 queries + 5 轮迭代）、打包分发 |
| Skill 质量标准 | 保留本地（7 维度、L1/L2/L3、反模式） | 官方无等价物；官方设计哲学是"不定标准，只提供验证工具" |
| 全局行为约束 | 保留本地（rules/ + reference/） | 个人工程标准，官方完全不涉及 |
| 工作流编排 | 保留本地（contracts/ + 自定义 skill） | 官方无替代品 |

### new-skills 角色转变

**现状**：独立的 skill 创建工具，和 skill-creator 平行
**目标**：skill 质量审计工具，专注结构合规检查和反模式扫描

职能拆解：

| new-skills 子能力 | 决策 | 去向 |
|---|---|---|
| 创建流程（访谈 + 草稿） | 替换 | skill-creator 接管 |
| 5 节结构模板 + HARD-GATE | 保留 | 作为审计标准 |
| TDD RED-GREEN 验证 | 替换 | skill-creator eval 管线更强 |
| L1/L2/L3 质量分级 | 保留 | 从"创建时评级"移到"审计时评级" |
| 14 项反模式 | 保留 | 审计 checklist |
| description-spec.md | 归档 | skill-creator 有自动化优化 |
| init_skill.sh 骨架脚本 | 保留 | 轻量工具，与 skill-creator 不冲突 |

### 文件变更清单

| 文件 | 操作 | 原因 |
|------|------|------|
| `shared/skills/new-skills/SKILL.md` | 重写 | 从"创建 skill"改为"质量审计" |
| `shared/skills/new-skills/references/description-spec.md` | 归档到 docs/archive/ | skill-creator 有自动化 description 优化 |
| `shared/skills/new-skills/references/anti-patterns.md` | 保留 | 审计 checklist，官方无等价物 |
| `shared/skills/new-skills/references/prompt-engineering.md` | 保留 | 提示词技巧参考 |
| `shared/skills/new-skills/references/resource-planning.md` | 保留 | 资源规划框架 |
| `shared/skills/new-skills/scripts/init_skill.sh` | 保留 | 骨架脚本 |
| `shared/reference/Skill质量标准.md` | 保留 | 7 维度 L1/L2/L3，作为 eval grading 标准注入 |

### 新工作流

**创建新 skill：**
1. `/skill-creator` → 访谈 + 草稿 + eval 迭代 + description 优化
2. `/new-skills`（审计模式）→ 结构合规检查 + 反模式扫描 + 质量评级
3. 不通过 → 回到 skill-creator 修改

**验证已有 skill：**
1. `/skill-creator` eval → with/without 对比 + benchmark
2. `/new-skills`（审计模式）→ 质量审计
3. 结合两者数据做保留/裁减决策

### 维护策略：overlay 不 fork

- 官方 skill-creator 存放在 `community/anthropic/skills/skill-creator/`，sync 时整体替换
- 本地质量叠加层存放在 `shared/skills/new-skills/` 和 `shared/reference/`
- 官方更新时只需检查 eval grading 接口是否变化，本地层不受直接影响

## 待验证的开放问题

以下问题不能靠分析回答，需要通过实验确认：

1. **质量标准有效性**：7 维度 L1/L2/L3 是否真的和 skill 的实际 eval 表现相关？
2. **四个评估入口是否过多**：new-skills（L1/L2/L3）、tools/eval/（7 track graders）、scan（Skill 质量扫描）、skill-creator eval — 是否需要合并？
3. **eval 注入机制**：本地质量标准如何具体转化为 skill-creator 的 grading assertions？
4. **new-skills 最终形态**：审计职能是否应该合并进 scan skill 而非独立存在？

## 第一步行动：eval 对比实验

**在做任何代码变更前**，先用 skill-creator 的 eval 管线做验证实验：

1. 选 3 个不同类型的现有 skill（pipeline / 独立 / 工具类各 1 个）
2. 对每个 skill 做 with/without 质量标准约束的 eval 对比
3. 记录：pass rate、token 消耗、benchmark 差异
4. 用数据回答"质量标准是否有效"和"评估入口是否需要合并"

实验结果将指导后续的具体实施决策。

## 验证计划

1. eval 对比实验完成后，验证质量标准和 eval 表现是否相关
2. 用 skill-creator 从零创建 1 个新 skill，走新流程（skill-creator 创建 → new-skills 审计）
3. 模拟官方 skill-creator 更新，验证 overlay 模型是否不受影响
