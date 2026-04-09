# 规范文档循环引用与重复上下文分析调研报告

## 一页判断

- 当前结论：改写后采纳
- 强论点判断：`文档循环引用会自动导致运行时重复加载正文并污染上下文`，当前证据不成立
- 弱论点判断：`文档循环引用和多入口挂载会造成重复暴露、重复读取机会增加、认知权重偏移`，当前证据成立
- 风险等级：轻到中
- 风险性质：以信息架构和运行时提示重复暴露为主，不是已证实的运行时递归加载 bug
- 一句话判断：当前系统更像“按需读取的路径化引用系统”，不是“沿文档引用自动递归展开的加载系统”；真正的问题不是自动重复注入，而是同一知识在入口、rules、reference、skill 指令中被多次暴露

## 关键论点挑战表

| 论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|---|---|---|---|---|
| 文档循环引用会自动导致运行时重复加载正文 | `代码规范.md` 与 `硬编码治理规范.md`、`代码质量.md`、`铁律.md` 间存在真实往返引用 | `render_runtime_contract.py` 只渲染“摘要 + 绝对路径”，`install.sh` 只复制与渲染，不做递归展开 | 不成立 | 高 |
| 同一 reference 会被多处重复暴露 | `runtime-catalog.json` 将同一 reference 同时挂到入口层和规则层，例如 `测试规范.md`、`代码质量.md`、`硬编码治理规范.md` | 多入口暴露不等于正文自动重复注入；是否形成重复上下文仍取决于后续是否再次读取 | 成立 | 高 |
| reference 的双向回指会带来上下文重复风险 | `代码规范 -> 硬编码治理规范 -> 代码规范`、`代码规范 -> 代码质量 -> 代码规范`、`铁律 -> 测试规范 -> 铁律` 已构成环 | 当前仓库没有发现“沿引用链自动跟读”的加载器，环本身只是文档图的环 | 条件成立 | 高 |
| 真正更高的重复风险来自 skill 指令层 | `developer/SKILL.md` 明写“自动加载（不展开）”同一批规则/参考文档，和入口层存在重叠暴露 | “自动加载（不展开）”仍不等于正文重复注入，更多是注意力和提示权重问题 | 成立 | 中高 |
| 只要没有 literal duplicate load，就说明完全没问题 | 运行时当前更接近按需读取 | challenger 指出多入口摘要、双向回指、重复挂载仍会带来认知重复、边界模糊和维护漂移 | 不成立 | 高 |

## 核心证据

- 运行时拼装不是正文递归展开：
  - [tools/community/render_runtime_contract.py](/Users/lijieli/org-claude-skills/tools/community/render_runtime_contract.py) 对 `runtime_link` 只生成“摘要 + 绝对路径”
  - [install.sh](/Users/lijieli/org-claude-skills/install.sh) 只是复制 `shared/` 源文件，再渲染占位符和 runtime contract
- 临时安装后的真实运行时也证明没有内联展开：
  - 临时 `.codex/AGENTS.md` 只出现摘要和路径
  - 临时 `.codex/rules/代码规范.md` 中 `代码质量.md`、`硬编码治理规范.md` 是链接形式，不是正文拷贝
- 已确认的文档图环：
  - `rules/代码规范.md -> reference/硬编码治理规范.md -> rules/代码规范.md`
  - `rules/代码规范.md -> reference/代码质量.md -> rules/代码规范.md`
  - `rules/铁律.md -> reference/测试规范.md -> rules/铁律.md`
  - `rules/代码规范.md -> reference/代码质量.md -> rules/铁律.md -> rules/代码规范.md`
- 运行时确实支持“按需读取外部 reference”，但这不等于自动加载：
  - [tools/dev/probe-codex-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-codex-capabilities.sh)
  - [tools/dev/probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh)
  - [tests/test-runtime-reference-activation.sh](/Users/lijieli/org-claude-skills/tests/test-runtime-reference-activation.sh)
- 仓库本身已经把“噪音”和“reference 嵌套风险”视为真实问题：
  - [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 明确将“reference 嵌套 reference”视为 token/运行时风险
  - [tests/test-platform-runtime-noise.sh](/Users/lijieli/org-claude-skills/tests/test-platform-runtime-noise.sh) 将平台无关噪音视为失败

## 引用图谱与分层判断

### 1. 文档源层

这里确实存在环，但主要是“边界声明 + 回指真源/补充”的文档图环。

- `代码规范.md` 多次回指 `代码质量.md`、`硬编码治理规范.md`
- `代码质量.md` 多次回指 `代码规范.md`
- `硬编码治理规范.md` 两次回指 `代码规范.md`
- `测试规范.md` 回指 `铁律.md`
- `铁律.md` 回指 `测试规范.md`

判断：
- 文档源层存在真实双向引用
- 这说明会有维护冗余和跳读成本
- 但它本身不构成运行时递归加载证据

### 2. 运行时拼装层

当前实现是“复制源文件 + 渲染最小 runtime contract”，不是“递归内联”。

- `runtime-catalog.json` 决定哪些 reference 被挂到入口或规则文档
- `render_runtime_contract.py` 没有读取被引用文件正文并插入目标文档
- 运行时的 reference 文件以独立文件存在，等待后续显式读取

判断：
- 这一层存在“多入口重复挂载”
- 但不存在“拼装期自动重复加载正文”的证据

### 3. 任务执行层

真正可能出现重复上下文的是任务中的重复读取行为，而不是安装器。

- agent 先读入口文档
- 再读 rule 文档
- 再沿 `补充细则` 打开 reference
- skill 又再次声明“自动加载（不展开）”同一批文档

判断：
- 这里的风险是“同一知识多次暴露后被重复读取”
- 这是行为层和提示层风险，不是底层加载器 bug

## 独立挑战记录

| 领域 | challenger 结论 | 对主结论的影响 |
|---|---|---|
| 系统实现 / 代码审查 | 反对把“文档图上的环”直接等同于“运行时自动重复加载”；认为最可能的问题是后续 agent 朴素地沿链接反复读取同一文件 | 采纳。主结论改为“自动重复加载未证实，重复读取机会增加已成立” |
| 信息架构 / 认知负载 | 反对“只要没有 literal duplicate load 就没问题”；认为多入口摘要、双向回指和重复挂载仍会造成显著性放大、边界模糊和维护漂移 | 采纳。结论加入“认知重复和权重偏移”风险 |

## 更精确的最终结论

### 不成立的说法

- “循环引用会自动让内容重复加载到上下文里”
- “`代码规范.md` 和 `硬编码治理规范.md` 互相引用，运行时就会无限套娃式展开”

### 成立的说法

- “同一 reference 会在入口层和 rules 层被多次挂载”
- “双向回指会增加来回跳读和重复读取的机会”
- “即使没有正文重复注入，也可能出现认知层面的重复暴露和权重偏移”

### 我对当前仓库的判断

- 运行时机制：安全，未发现递归展开
- 信息架构：有改进空间
- 实际危害：中低，主要体现在理解成本、维护漂移和上下文预算浪费

## 建议动作

1. 保留当前“rules 为真源、reference 为补充、按需读取”的总体机制，不建议为了消除文档环而重做运行时加载链
2. 对 `rules <-> reference` 的双向回指做减法，优先把 reference 中重复出现的“规则源回指”压缩成一次，避免同一文件多次点名同一 rule
3. 为高频重复挂载的 reference 建一个“唯一主入口”策略：
   - 入口文档保留发现性摘要
   - rules 文档只在确有必要时保留补充链接
4. 对 skill 中“自动加载（不展开）”的重复声明做盘点，减少和入口层完全重叠的重复提示
5. 如果后续要继续深挖，下一步最有价值的是做 live 行为采证：
   - 设计一次多跳引用 probe
   - 观察模型是否会重复读取已读文件
   - 再决定是否需要去重缓存或 read-memory 约束

## 检索路径与覆盖证明

- 已扫描文档：
  - `shared/rules/*.md`
  - `shared/reference/*.md`
  - `shared/runtime/runtime-catalog.json`
  - `shared/assistant.md`
  - `shared/skills/developer/SKILL.md`
- 已扫描实现与验证：
  - `install.sh`
  - `tools/community/render_runtime_contract.py`
  - `tools/dev/probe-codex-capabilities.sh`
  - `tools/dev/probe-claude-capabilities.sh`
  - `tests/test-runtime-contract-catalog.sh`
  - `tests/test-runtime-integrity.sh`
  - `tests/test-runtime-reference-activation.sh`
  - `tests/test-doc-reference-integrity.sh`
  - `tests/test-platform-runtime-noise.sh`
- 已补充真实运行态采证：
  - 临时安装到独立 `HOME`
  - 检查生成后的 `AGENTS.md` 与 `rules/代码规范.md`
  - 统计 `代码质量.md`、`硬编码治理规范.md`、`代码规范.md` 在最终运行时中的出现次数

## 项目上下文

- 当前仓库通过 `shared/rules + shared/reference + shared/runtime + install.sh` 生成 Claude/Codex 运行时知识面
- 本次调研保持只读分析，并新增本报告文件用于沉淀结论与证据
