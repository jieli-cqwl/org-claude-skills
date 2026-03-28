# First-Party Skill 标准（候选正式版）

状态：Candidate v1  
适用范围：`shared/skills/*` 下的 first-party skill  
不适用范围：
- `third_party/community/*`
- `community-adapters/*`
- `opsx:*` / OpenSpec process command
- 纯平台 adapter 文件

## 1. 这份草案要解决什么问题

现有 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 有价值，但作用域过宽，把不同类型对象放进了同一套要求里。

这份草案的目标不是“推翻现有体系”，而是把 first-party skill 标准重写成：

1. 内容更强
2. 结构更清晰
3. 跨运行时语义更可映射
4. 证据门槛更明确
5. 不迷信官方，也不忽略官方机制优势

## 2. “更强”的正式定义

本标准采用二维定义：

### 2.1 内容强度

回答：

> 同样上下文预算下，这份 skill 内容能不能让模型更容易选对、读对、做对。

评价点：
- 信息密度
- 歧义控制
- 路由可判定性
- 执行稳定性
- 上下文效率

### 2.2 结构治理

回答：

> 这些内容是否被放在正确的位置，并且未来不会因为重复定义而漂移。

评价点：
- 职责边界
- 单一真源
- 层级正确
- 局部可演进
- 可验证性

### 2.3 结果导向补充

前两项只是过程质量，不足以证明“更强”。

所以本标准额外要求结果指标：
- 触发准确率
- 一次通过率
- 返工率
- 人工介入率
- 误报/漏报率
- 变更连锁成本

没有结果指标，只能称为“更整齐”或“更可解释”，不能称为“更强”。

## 3. 设计原则

### 3.1 一层一职责

| 层 | 负责什么 | 不负责什么 |
|---|---|---|
| `AGENTS.md` / `assistant.md` | always-on 行为边界 | 具体任务工作流 |
| `rules/` | 长期稳定红线 | 单次任务步骤 |
| `SKILL.md` | 技能触发、运行骨架、条件规则 | 完整模板结构真源 |
| `references/` | 长方法论、参考、说明 | 全局规则 |
| `templates/` | artifact 结构真源 | skill 触发语义 |
| `scripts/` / checks | 机械校验、动态上下文、自动化 | 业务判断真源 |
| OpenSpec / `opsx:*` | 变更状态机与工件流转 | first-party skill 定义 |

### 3.2 一类一模板

first-party skill 不再用“一套结构覆盖所有 skill”，而是按类型建模。

### 3.3 一处一真源

同一件事只能有一个 authority：
- 触发语义：frontmatter / metadata
- 文档结构：template
- 条件规则：`SKILL.md`
- 机械校验：script / tests

### 3.4 运行时中立，平台映射

本标准不直接把某个平台字段当 canonical truth。  
canonical truth 是“语义”，Claude Code / Codex 只是映射目标。

这条是为了避免“单端真源，另一端追赶”的架构锁定。

## 4. Skill 分类模型

本标准不再把“任务形态”和“执行方式”绑成一个字段。  
更强的做法是拆成两个正交维度：

1. `workload_shape`：skill 解决的工作形态
2. `execution_mode`：skill 在运行时如何执行

原因：

1. 当前仓库同时存在 `task + forked` 与 `workflow + inline`
2. 如果把两者绑死，会制造伪冲突和误分类
3. `new-skills`、`scan`、运行时映射更容易做组合校验

### 4.1 Workload Shape

#### Reference

定位：
- 主要提供背景知识、方法论、导航
- 默认低副作用
- 可自动触发，也可隐藏为 background knowledge

典型对象：
- 某些只读导航型 skill

#### Task

定位：
- 单目标任务
- 有明确输入、输出和完成条件
- 不要求跨多阶段工件流转

典型对象：
- `review`
- `verify`
- `commit`
- `research`
- `scan`
- `overview`

#### Workflow

定位：
- 多阶段
- 往往带强门禁和交付物
- 常与 OpenSpec / 工件链路或阶段性交付绑定

典型对象：
- `product`
- `design`
- `test-design`
- `tech-lead`
- `project-manager`

### 4.2 Execution Mode

#### Inline

定位：
- 在主上下文中执行
- 不依赖额外隔离上下文
- 适合上下文压力可控的任务

典型对象：
- `review`
- `verify`
- `commit`
- 当前仓库中的大多数 workflow skill

#### Forked

定位：
- 使用隔离上下文、子代理或独立运行面
- 适合高上下文压力、长探索、独立证据链任务

典型对象：
- `research`
- `scan`
- `overview`

### 4.3 推荐组合

| `workload_shape` | `execution_mode` | 典型含义 |
|---|---|---|
| `reference` | `inline` | 轻量知识/导航 |
| `task` | `inline` | 主上下文直接完成的任务 |
| `task` | `forked` | 高上下文压力但非多阶段的任务 |
| `workflow` | `inline` | 当前仓库主流的阶段型 skill |
| `workflow` | `forked` | 未来可选的高隔离 workflow |

规则：
- `reference + forked` 默认不推荐，除非有明确证据说明 inline 不足
- `workflow` 不等于 `forked`
- `forked` 只是执行方式，不自动等于 workflow

## 5. Canonical 语义模型

first-party skill 统一先定义语义，再映射到平台。

### 5.1 必备语义字段

每个 skill 必须先明确以下语义：

| 语义字段 | 含义 |
|---|---|
| `intent` | 这个 skill 解决什么问题 |
| `workload_shape` | `reference / task / workflow` |
| `invocation_mode` | `auto / manual / background` |
| `execution_mode` | `inline / forked` |
| `side_effect_level` | `none / low / medium / high` |
| `tool_scope` | 可用工具范围 |
| `path_scope` | 自动触发或适用的文件/目录范围 |
| `inputs` | 前置输入 |
| `outputs` | 产物或结果 |
| `checks` | 完成校验方式 |
| `interfaces` | 层间接口声明；不适用时写 `n/a` |

### 5.2 Canonical carrier

上述 canonical 语义字段必须落在可机器读取的 carrier 中。

候选正式版当前建议：

- 每个 first-party skill 目录新增 `skill-contract.yaml`
- `skill-contract.yaml` 是 canonical 语义真源
- `SKILL.md` frontmatter 与 `agents/openai.yaml` 视为运行时映射面

原因：

1. 避免把平台字段直接当 canonical truth
2. 便于 `new-skills`、`scan`、安装器、后续 eval 工具统一读取
3. 让“语义”和“运行时适配”分层

最小字段集合：

```yaml
intent:
workload_shape: reference | task | workflow
invocation_mode: auto | manual | background
execution_mode: inline | forked
side_effect_level: none | low | medium | high
tool_scope: []
path_scope: []
inputs: []
outputs: []
checks: []
interfaces:
  template_ref:
  completion_check:
  runtime_adapters: []
  workflow_state: n/a
```

要求：

- `new-skills` 负责生成该文件
- `scan` 负责校验该文件与 `SKILL.md` / runtime metadata 是否一致
- 没有 `skill-contract.yaml` 的 first-party skill，不得宣称已完成迁移到新标准

### 5.3 平台映射原则

#### Claude Code

优先映射到：
- `disable-model-invocation`
- `user-invocable`
- `allowed-tools`
- `context`
- `agent`
- `paths`

#### Codex

优先映射到：
- `agents/openai.yaml`
- `short_description`
- `default_prompt`
- manual-only 的安装期移除策略

#### 规则

- 先定义 canonical 语义，再做平台映射
- 没有等价映射的能力，不得直接宣称“双端统一”
- 所有平台特有能力都要标注“等价 / 降级 / 不支持”

## 6. 内容标准

## 6.1 通用要求

### MUST

1. `description` 必须可判定触发边界。
2. `SKILL.md` 只保留主骨架和关键条件，不承载长方法论。
3. 详细说明默认外移到 `references/`。
4. 动态能力优先通过 script/output 注入，而不是内嵌长上下文。
5. 每个 skill 必须声明副作用级别。

### SHOULD

1. 默认使用能力陈述 + 触发场景的 description 结构。
2. 支持文件命名要能被模型直接导航。
3. 同类 skill 的章节名保持一致。

### MUST NOT

1. 不得把模板完整结构复制进 `SKILL.md`。
2. 不得把平台 adapter 规则写成 canonical skill 定义。
3. 不得把无法机械校验的主观口号写成 MUST。

## 6.2 Description 规则

当前默认格式仍保留为：

```text
{能力陈述}。Use when {触发场景}。
```

但这只是 **当前默认策略**，不是永恒真理。

例外规则：
- 如果 activation eval 证明其它写法更优，可以偏离默认格式
- 任何偏离必须附证据

这条规则的意思是：
- description 受评估结果约束
- 不是凭风格偏好永远固定

## 6.3 `SKILL.md` 与 template 的关系

### template 是结构真源

template 负责：
- 章节结构
- 字段顺序
- 占位格式
- 结构示例

### `SKILL.md` 是执行骨架

`SKILL.md` 负责：
- 产物路径
- 哪个 template 是 authority
- 哪些条件规则必须额外满足
- 失败时如何处理

### 保底结构原则

为防止模型未加载 template，`SKILL.md` 可以保留最小保底结构提示，但只能保留：
- 条件性 section
- 容易漏掉的关键 section
- 与 completion check 强绑定的 section

不得把 template 总表完整复制回 `SKILL.md`。

## 6.4 行数预算

不同 workload shape / execution mode 用不同预算，不再统一上限。

| `workload_shape` | `execution_mode` | 目标预算 |
|---|---|---|
| `reference` | `inline` | `< 120` 行 |
| `task` | `inline` | `< 180` 行 |
| `task` | `forked` | `< 220` 行 |
| `workflow` | `inline` | `< 240` 行 |
| `workflow` | `forked` | `< 280` 行 |

说明：
- 预算是目标，不是唯一评价标准
- 超预算必须说明为什么不能外移

## 6.5 图与示意

图语法不作为能力级要求，只作为一致性要求。

当前建议：
- first-party 默认用 Mermaid
- flowchart 用 `flowchart TD`
- 这属于风格统一收益，不宣称有能力级优势

## 7. 结构治理标准

## 7.1 first-party 标准的边界

本标准只约束：
- `shared/skills/*`
- 其 `references/`、`templates/`、`scripts/`

本标准不约束：
- community upstream 正文
- OpenSpec 状态机正文
- 平台安装器逻辑本身

## 7.2 单一真源规则

### Rule A
模板结构只在 template 中维护。

### Rule B
完成条件只在 completion checks / tests 中做机械真源。

### Rule C
平台差异只在 adapter / install / runtime note 中维护。

### Rule D
canonical skill 只表达运行语义，不表达平台补丁细节。

## 7.3 层间接口必须可测

以下接口在“适用时”必须显式定义并可测试：

1. `skill -> template`
   - 当 skill 产出结构化 artifact 时必填
2. `skill -> completion_check`
   - 当存在机械完成校验时必填
3. `skill -> runtime adapter`
   - 当 skill 需要跨运行时映射时必填
4. `skill -> OpenSpec / workflow state`
   - 仅对与 workflow state 或工件链路显式耦合的 workflow skill 必填

不适用时必须在 `skill-contract.yaml.interfaces` 中显式标记 `n/a`，不得省略。

没有接口定义，只写原则，不算完成。

## 8. 评估与证据门槛

## 8.1 证据等级

所有重要 MUST 语句应能追溯到证据等级：

| 等级 | 含义 |
|---|---|
| `E3` | 实测 / 对照实验 / A/B / 运行数据 |
| `E2` | 仓库内 contracts / tests / runtime evidence |
| `E1` | 官方文档 / 一手资料 / 上游源码 |
| `E0` | 推理 / 经验判断 / 待验证假设 |

规则：
- 可以引用 `E1`
- 不能把 `E1` 当成“已证最优”
- 宣称“最强”“最佳”“必须”时，优先要求 `E2/E3`

## 8.2 Activation Eval

仅对 `auto` skill 强制要求。

当前草案门槛：
- 至少 30 条样本
- 覆盖 正例 / 负例 / 边界
- 记录 Precision / Recall / FPR / FNR
- 明确回滚线

资产位置：
- 样本：`shared/skills/<skill>/evals/activation-cases.yaml`
- 结果：`shared/skills/<skill>/evals/results/activation-<runtime>.json`

责任：
- skill owner 维护样本
- runtime 验证流程写入结果

门禁：
- 高风险 / 高频 / 高成本 skill：BLOCK
- 其余：WARN

说明：
- 这是当前 draft 阈值，不是假装精确的最终数值
- 后续应按成本与收益再调

## 8.3 Execution Eval

对关键 workflow skill，及高成本 `task + forked` skill，需要比较：
- 一次通过率
- 平均返工轮次
- 平均 token 成本
- 人工介入时长
- completion check 失败率

如果新标准在这些指标上没有改善，不得宣称“更强”。

资产位置：
- 基线与对照说明：`docs/reports/skill-evals/<skill>/execution-baseline.md`
- 执行结果：`docs/reports/skill-evals/<skill>/execution-<date>.md`

责任：
- 提案 owner 负责给出对照任务集
- 审查/验收流程负责记录结果

门禁：
- 候选阶段可先记为观察项
- 进入正式切换 live 前，关键 workflow skill 与高成本 `task + forked` skill 必须至少有一轮记录

## 8.4 风险分级评估

`eval-first` 不是所有 skill 一刀切。

当前草案：
- 高风险 / 高频 / 高成本 skill：P0，必须 eval-first
- 低频 / 低风险 skill：允许轻量抽样评估

默认判定：
- `auto` + 中高副作用：高风险
- `workflow` + `forked`：高成本
- `workflow` + 强门禁 artifact：至少中成本
- 高频由实际调用统计或团队经验确认

无数据时：
- 候选阶段：WARN
- 正式切换 live 前：必须明确标注“无数据”并说明原因

## 9. 副作用与安全

以下能力视为强能力：
- `!command`
- `context: fork`
- 子代理执行
- 动态命令注入

使用强能力时必须补充：
- 工具范围限制
- 命令白名单或约束
- 输出净化策略
- 审计记录
- 失败回退路径

没有这些控制项，不得把强能力写进推荐基线。

## 10. 当前仓库的迁移方向

## 10.1 先做什么

1. 保留现有 `Skill质量标准.md` 作为 live standard
2. 将本文件作为 candidate standard 并行演进
3. 优先为当前已使用的 3 类组合做试点：
   - 一个 `task + inline`
   - 一个 `task + forked`
   - 一个 `workflow + inline`
4. 如果后续引入 `reference + inline` 或 `workflow + forked`，再补对应试点

## 10.2 暂不做什么

1. 不直接重写全部 `shared/skills/*`
2. 不把 community upstream 强行套进新模板
3. 不在没有跨运行时等价映射前宣称“双端统一基线”
4. 不在 `new-skills` / `scan` 未迁移前替换 live 标准

## 11. 当前草案吸收的反方挑战

这版草案已经显式吸收两个独立 agent 的核心挑战：

1. 不直接把 Claude 官方写成唯一 canonical truth
2. 增加结果指标，而不只看内容/结构
3. 把 `description` 默认格式降级为“当前默认策略”，不是永恒真理
4. 把 template-only 规则改成“template 为主真源 + skill 最小保底结构”
5. 把 eval-first 改成风险分级，而不是一刀切
6. 把强能力纳入安全控制，不只写成优点

## 12. 仍待决策的问题

1. 我们是否接受“Claude 主运行时，Codex 兼容运行时”？
2. 是否要建立跨运行时等价语义最小集合？
3. activation eval 的样本量和阈值是否采用仓库统一默认值？
4. 哪些结果指标进入发布门禁，哪些只进入观察面板？

## 13. 当前结论

这份草案的核心立场是：

> first-party skill 标准应当吸收 Claude Code 官方在 discoverability、progressive disclosure、invocation control、subagent execution 上的机制优势，但 canonical 标准必须保持运行时中立，并由本地 templates / checks / contracts / workflow state 来补足治理能力。

如果这条做不到，最容易出现两种失败：

1. 只学官方形式，失去本地治理强项
2. 只守本地旧规范，失去上下文效率和调用治理优势
