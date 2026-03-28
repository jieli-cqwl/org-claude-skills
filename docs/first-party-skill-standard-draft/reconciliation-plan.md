# First-Party Skill 标准对账与迁移方案

状态：Draft  
目标：在不直接覆盖 live 标准的前提下，把候选正式版收敛成可替换 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 的正式版本。

## 1. 当前状态判断

## 1.1 live 文件不是干净基线

当前 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 处于已修改未提交状态。

本次对账发现，现存改动不是结构性重写，而是局部术语更新，主要包括：

1. `description` 规则从固定句式，放宽为“清楚表达能力与触发场景”
2. `community-first` 表述改成 `community canonical`
3. Codex `openai.yaml` 的来源路径从 `community-adapters/` 改到 `community/superpowers/codex/skills/`
4. community 例外章节从“upstream 快照例外”改成“本地 canonical runtime 例外”

结论：

- live 文件当前已有你们正在推进的语义演进
- 这些改动方向与候选正式版并不冲突
- 因此不应直接把它当“旧标准”整体推翻

## 1.2 现有依赖点

当前直接依赖 live 标准的关键位置：

1. [shared/skills/new-skills/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/SKILL.md)
2. [shared/skills/scan/references/skills-scan-rules.md](/Users/lijieli/org-claude-skills/shared/skills/scan/references/skills-scan-rules.md)

影响方式：

- `new-skills` 依赖 live 标准的评级语义（L1/L2/L3）与结构模板
- `scan` 依赖 live 标准的 D1-D7 维度与评级方法

结论：

- 替换 live 标准不是“改一个文档”
- 必须连带迁移 `new-skills` 与 `scan`

## 2. live 标准 vs 候选正式版：差异分类

## 2.1 应保留项

这些内容不应丢：

1. `L1 / L2 / L3` 分级思想
2. `D1-D7` 维度化评估方式
3. Token 效率约束
4. 可机械校验导向
5. 双端兼容检查清单

原因：

- 这些是你们当前治理可执行性的核心
- `new-skills` 与 `scan` 也已经围绕这些语义建立依赖

## 2.2 应废弃或降级项

这些内容不应继续作为唯一标准：

1. “一套结构覆盖所有 first-party skill”
2. 对 `description` 固定句式的绝对化要求
3. 对所有 skill 统一 150 行上限
4. 把平台字段直接写成 canonical truth
5. 缺少结果指标、只看过程质量

原因：

- 已被前期研究和反方挑战证明作用域过宽或证据不足

## 2.3 应新增项

候选正式版里新增、且值得进入正式版的内容：

1. `内容强度 x 结构治理` 二维框架
2. 结果指标层
3. 运行时中立语义 + 平台映射
4. `Reference / Task / Workflow` 与 `Inline / Forked` 正交分轨
5. `template 主真源 + skill 最小保底结构`
6. canonical carrier：`skill-contract.yaml`
7. 证据等级（E0-E3）
8. 风险分级 eval
9. 强能力安全控制

## 3. 推荐迁移策略

不建议：

- 直接覆盖 live 文件
- 直接让 `new-skills`/`scan` 切到新标准
- 一次性重写所有 `shared/skills/*`

建议采用 3 阶段迁移。

## 3.1 Phase A：标准并存

目标：
- 不改 live 依赖关系
- 先把候选正式版作为平行标准稳定下来

动作：

1. 保留 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 作为 current live standard
2. 保留 [standard-draft.md](/Users/lijieli/org-claude-skills/docs/first-party-skill-standard-draft/standard-draft.md) 作为 candidate standard
3. 新增一份“标准映射表”，说明旧语义如何映射到新语义

退出条件：
- 完成旧标准到新标准的语义映射
- 明确哪些规则是兼容迁移，哪些是 breaking change

## 3.2 Phase B：依赖方迁移

目标：
- 先迁移依赖 live 标准的工具和流程，再迁移标准本身
- 明确承认这里是 breaking-change 改造，不是简单引用更新

动作：

1. 重写 `new-skills`
   - 从“套一套固定模板”改为“按 workload shape 选择模板，并单独判定 execution mode”
   - 保留 L1/L2/L3，但增加 `workload_shape` + `execution_mode` 判定
   - 新增 `skill-contract.yaml` 生成逻辑，包括 `interfaces` 声明

2. 重写 `scan`
   - 从固定 D1-D7 检查，升级为“旧标准兼容 + 新标准专项检查”双模式
   - 新增对 `skill-contract.yaml`、`interfaces` 声明、正交分类、结果/结构类指标的检查
   - 明确新旧标准混用期的判定规则

3. 新增最小评估资产与目录规范
   - 至少为 auto skill 预留 activation eval 目录和样本格式

退出条件：
- `new-skills` 不再依赖旧的固定模板假设
- `scan` 能识别新旧两套标准最小兼容集
- 当前已使用的 3 类组合至少各有一个试点跑通 `skill-contract.yaml` 生成、扫描、文档一致性链路：
  - `task + inline`
  - `task + forked`
  - `workflow + inline`

## 3.3 Phase C：live 切换

目标：
- 将候选正式版替换为新的 live standard

动作：

1. 将候选正式版整理为新的 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)
2. 将旧版迁移到：
   - `shared/reference/archive/` 或
   - `docs/history/`
3. 更新所有引用点
4. 增加回归验证

退出条件：
- `new-skills`
- `scan`
- 关键示例 skill
- 相关文档引用
全部通过

## 4. 旧标准到新标准的语义映射

| 旧标准 | 新标准中的去向 |
|---|---|
| D1 结构合规 | 内容标准 + workload template |
| D2 闭环自治 | Inline/Forked skill 要求 |
| D3 I/O 契约 | canonical 语义字段 `inputs/outputs/checks` + `skill-contract.yaml` |
| D4 角色与对抗 | 内容标准中的执行稳定性与角色要求 |
| D5 验证即证据 | 证据等级 + completion checks |
| D6 Token 效率 | 内容强度 / 上下文效率 + 行数预算 |
| D7 跨模型适配 | 结果指标 + 跨运行时映射 |
| L1/L2/L3 | 可保留，但需按 `workload_shape` / `execution_mode` 重定义门槛 |

## 5. 当前最需要先做的文件

推荐顺序：

1. [docs/first-party-skill-standard-draft/standard-draft.md](/Users/lijieli/org-claude-skills/docs/first-party-skill-standard-draft/standard-draft.md)
2. `skill-contract.yaml` 规范与示例
3. [shared/skills/new-skills/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/SKILL.md)
4. [shared/skills/scan/references/skills-scan-rules.md](/Users/lijieli/org-claude-skills/shared/skills/scan/references/skills-scan-rules.md)
5. [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)

原因：

- 先改标准候选
- 再补 canonical carrier
- 再改生成器
- 再改扫描器
- 最后切 live

## 6. 需要你拍板的决策

### 决策 1：是否接受双轨过渡

建议：接受。  
理由：风险最小。

### 决策 2：是否保留 L1/L2/L3

建议：保留。  
理由：当前引用链已依赖，完全取消迁移成本过高。

### 决策 3：是否接受“运行时中立语义”作为新标准主轴

建议：接受。  
理由：这是避免 Claude/Codex 单端锁定的关键。

### 决策 4：canonical carrier 是否接受 `skill-contract.yaml`

建议：接受。  
理由：否则“canonical 语义字段”没有机器可读落点。

### 决策 5：是否把 `eval-first` 设为全量强制

建议：不全量。  
改为：高风险/高频/高成本 skill 强制，其他轻量抽样。

## 7. 当前推荐结论

当前最稳妥的路径不是“立即替换 live 标准”，而是：

> 先并存、再迁移依赖方、最后切换 live。

这条路径的优点是：

1. 不会误覆盖当前 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 的现存未提交改动
2. 不会把 `new-skills` 和 `scan` 一次性打断
3. 可以先验证候选正式版是否真的更强，而不是只在文档上更好看
