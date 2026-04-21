# Evidence Integrity Review

> 供 `/review` 在审查 skill、eval、validator、artifact、installer 或 runtime gate 改动时使用。

## 适用范围

当 diff 触达以下对象时，执行本专项：

- skill runtime：`SKILL.md`、`references/`、`templates/`、`agents/`
- eval 或 benchmark：`evals/`、fixture、runner、grader、结果聚合脚本
- runtime artifact：schema、validator、renderer、consumer matrix、状态机
- installer/runtime gate：安装器、hook、completion gate、runtime catalog
- 报告链路：会写出 `PASS`、`FAIL`、`verified`、`APPROVE`、`REQUEST_CHANGES`、`decision` 或 `status` 的脚本与模板

## 审查问题

| ID | 维度 | 审查问题 | 证据要求 |
| --- | --- | --- | --- |
| EI-1 | 自证检测 | `observed` 是否独立于 `expected`、`category`、fixture label | 改动 `expected` 或 `category` 时测试失败；runner 不从同一字段推导输入和输出 |
| EI-2 | 声称/证据一致 | `PASS`、`verified`、`APPROVE` 是否来自真实执行 | 结论只在 validator、runner、fresh command 或人工裁决证据完成后生成 |
| EI-3 | 负例驱动 | 破坏输入、schema、manifest 或 fixture 后测试是否失败 | 至少有一个反例或 mutation test 能击穿错误实现 |
| EI-4 | 过时材料清理 | 旧设计、旧目录、旧 skill 是否仍在有效 docs 或 runtime 路径 | 过时材料进入 `docs/archive/`；有效 docs 不保留相反结论 |
| EI-5 | 行为边界 | seed eval 是否冒充 live benchmark 或质量收益 | seed eval、smoke、fixture、live benchmark 的证明边界写清 |
| EI-6 | 消费者链路 | 字段、目录、报告、JSON artifact 是否有真实消费者 | consumer matrix、renderer、validator、下游脚本或 human review 能消费该字段 |
| EI-7 | 权限真实边界 | frontmatter、manifest、职责描述和脚本能力是否一致 | audit/review 类默认只读；写操作有授权、范围、输出目录和失败语义 |
| EI-8 | 计划/实现漂移 | plan、tasks、report 声明的文件和命令是否已交付 | 文件存在、命令可运行，未交付项在 plan 中移除或改为非目标 |
| EI-9 | 失败产物污染 | 失败时是否留下带 `PASS`、`verified` 或 final decision 的 artifact | 正式 artifact 只在最终校验通过后可见；失败清理临时文件或输出 blocked 状态 |
| EI-10 | 回归证明 | 修复是否有反例测试锁住 | 记录 RED/GREEN 命令；测试失败原因对准原始缺陷 |

## 裁决规则

- 任一适用维度缺证据时，至少输出 `COMMENT`。
- EI-1、EI-2、EI-3、EI-7、EI-9 命中真实缺陷时，输出 `REQUEST_CHANGES`。
- 非适用维度必须写明不适用原因，不能留空。
- 不把 seed eval、fixture smoke、schema 形状检查称为 live benchmark 或完整质量结论。

## 报告要求

在 `code-review-result.json` 中增加证据链完整性 finding 或 excluded 记录：

- `适用性`：适用或不适用。
- `触发依据`：列出触达的文件类型或路径。
- `Findings`：使用 `EI-*` 维度编号。
- `已排除项`：至少记录 2 个已调查但排除的问题；非适用场景可记录为何不触发专项。
