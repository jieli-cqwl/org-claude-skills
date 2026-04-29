# Skill 质量标准

> 触发条件：创建新 Skill、评估 Skill 质量、优化已有 Skill、执行 `/scan` Skill 质量扫描时读取。

本文是 first-party Skill 运行质量审计标准真源。标准目标不是指导作者写出“看起来完整”的 `SKILL.md`，而是让审计者判断一个 Skill 能否在目标 runtime 中被发现、触发、执行、产出、验证，并在必要时证明其相对 baseline 的行为收益。

本标准分三层使用，审计时必须先声明当前裁决落在哪一层：

| 层级 | 适用范围 | 裁决口径 |
| --- | --- | --- |
| Portable core | 面向支持 `SKILL.md` 的 Claude / Codex / Copilot / Agent Skills 生态 | 目录化本体、frontmatter、触发描述、progressive disclosure、脚本/资源按需加载 |
| First-party hardening | 本仓库 `shared/` first-party Skill、adapter、scan、harness、catalog 和 installer | JSON 事实源、资源合同、runtime 暴露、权限/脚本边界、fresh proving command、同步测试 |
| Production evidence | 声称最佳实践、长期保留、生产级维护或跨模型/跨 runtime 稳定 | with-skill/baseline、old/new 对比、成本收益、稳定性、反证样本和退役/回滚证据 |

禁止把 first-party hardening 冒充为跨生态官方最低标准；也禁止用 portable core 通过来替代本仓 first-party 的运行门禁。

质量裁决必须可被证据支持。每条 finding 必须绑定文件位置、影响、证据、建议和复验方式。

- 机器消费者需要阻断、比较、状态转移、发布判定或派生报告时，必须输出 JSON artifact，并以该 JSON 作为机器事实源。
- 仅供人工阅读且无机器消费者时，输出结构化 Markdown；Markdown 和 HTML 必须声明派生来源，不反向成为机器事实源。
- 本标准不保留旧维度对照表；历史口径只可存在于 archive、fixture 或迁移证据中，不能作为 active 审计入口。
- progressive disclosure、runtime truth、gate 与 canonical contract 的职责边界在本标准的 S4/S6/S7/S8 中直接裁决；不得依赖额外的运行面分层标准作为 active 审计入口。

## 审计对象

Skill 质量审计的对象不是单篇说明文，而是一个可运行能力包：

- `SKILL.md` 的 frontmatter、主体指令和完成边界。
- `agents/openai.yaml`、runtime catalog、安装暴露、manual-only/disabled/retired 状态，以及 `.claude-plugin/`、`.codex-plugin/`、`.cursor-plugin/`、`.opencode/`、`gemini-extension.json` 等目标 runtime adapter。
- `references/`、`resources/`、`examples/`、`rules/`、`schemas/`、`evals/`、`scripts/`、`templates/`、`hooks/`、`assets/` 等 skill-local 或 plugin-level 资源。
- 代表性任务 prompt、行为 eval、baseline 对比、proof command 和下游消费者。

审计结论必须回答四个问题：

| 问题 | 含义 |
| --- | --- |
| 能否审计 | 本体、运行可达性和证据包是否足以支持裁决 |
| 能否运行 | Skill 是否能被正确触发、加载、执行、产出并验证 |
| 是否更好 | Skill 是否有 with-skill / without-skill 或 old/new baseline 行为证据 |
| 能否维护 | Skill 是否能随 runtime、adapter、模型、依赖和生命周期变化保持一致 |

## 分层模型

本标准采用三层裁决模型。

### 准入门禁

准入门禁判断目标是否是可审计对象。门禁失败时，审计应停止在缺失项，不得继续脑补语义或给出运行质量 PASS。

| 门禁 | 名称 | 裁决问题 |
| --- | --- | --- |
| G0 | Skill 本体存在 | 是否存在合法 `SKILL.md`、必填 frontmatter 和可定位目录 |
| G1 | 运行可达 | 目标 runtime 是否能发现、启用或按 manual-only 策略显式调用该 Skill |
| G2 | 审计证据包完整 | 审计所需的资源、脚本、schema、eval 或消费者证据是否可读 |

### 运行质量维度

运行质量维度判断 Skill 能否安全、稳定、正确地完成其声明任务。

| 维度 | 名称 | 裁决问题 |
| --- | --- | --- |
| S1 | Discovery & Trigger | 是否在正确任务触发，并避开误触发、漏触发和邻近 Skill 冲突 |
| S2 | Task Contract | 目标、非目标、适用边界、成功标准和完成证据是否清楚 |
| S3 | Execution Protocol | 步骤是否能从输入稳定转成定义对等的产物或状态 |
| S4 | Resource Architecture | 主体、reference、script、schema、example、asset 是否按需加载且不丢关键上下文 |
| S5 | Runtime & Safety Boundary | 运行环境、工具预授权、脚本边界、外部写入、网络、来源安全和数据流是否受控 |
| S6 | Artifact Contract | 任务产物、审计产物、状态产物是否有格式、路径、消费者和验证方式 |
| S7 | Verification Loop | 验证是否直接证明成功标准，失败是否停在正确状态或回到修复步骤 |
| S8 | Evolution & Integration | adapter、catalog、安装暴露、退役、跨模型和版本变化是否一致 |

### 效果证明维度

效果证明不替代运行质量。缺少效果证明时，Skill 可达到 L1/L2，但不能宣称最佳实践或长期保留价值。

E1-E5 只裁决证据是否足以支撑 L3/L4、最佳实践或 retain 声明；具体 uplift、fidelity、成本收益和生命周期决策输入按 `Skill能力有效性标准.md` 执行。

| 维度 | 名称 | 裁决问题 |
| --- | --- | --- |
| E1 | Baseline 对比 | 是否有 with-skill / without-skill 或 old/new skill 对比 |
| E2 | 任务成功率 | 代表性 eval/assertions 是否证明任务完成质量 |
| E3 | 成本收益 | token、时间、失败率、返工次数与质量收益是否匹配 |
| E4 | 稳定性 | 不同任务、输入规模、模型或 runtime 下是否仍然有效 |
| E5 | 反证样本 | 哪些场景无提升、误导、过度流程化或不应触发 |

## Finding 规则

每条 finding 必须使用可复核字段：

```json
{
  "severity": "FAIL|WARN|INFO",
  "dimension": "G0|G1|G2|S1|S2|S3|S4|S5|S6|S7|S8|E1|E2|E3|E4|E5",
  "priority": "P0|P1|P2|P3",
  "skill_id": "skill-name-or-path",
  "runtime_target": "claude-code|codex|copilot|api|multi|repo-static",
  "scope": "frontmatter|body|resource|script|adapter|catalog|artifact|eval|lifecycle",
  "owner": "skill-author|runtime-owner|security-owner|consumer-owner|unknown",
  "file_ref": "path:line",
  "evidence_refs": ["command-or-file-ref"],
  "impact": "runtime or user-visible effect",
  "recommendation": "specific contract change",
  "verification": "fresh proving command or replay method",
  "false_positive_guard": "when this should not fail"
}
```

定位字段统一口径：JSON artifact 使用 `file_ref`；skill-harness Markdown/人工投影视图使用 `file:line`；field-consumers 使用 `file_line` 作为机器字段名。三者语义等同，均必须是单一 repo-local `path:line`；范围、多位置或上下文只能放入 `evidence` / `evidence_refs`。

裁决口径：

| 结果 | 含义 |
| --- | --- |
| PASS | 该裁决项合同完整，有证据和验证方式 |
| FAIL | 阻断 Skill 被可靠发现、运行、验证、安全使用或审计的问题 |
| WARN | 有风险但证据不足以阻断，或只影响 L3/L4 最佳实践等级 |
| INFO | 说明性观察、后续优化建议或人工复核提示 |

优先级口径：

| 优先级 | 含义 |
| --- | --- |
| P0 | 会误判安全、数据暴露、验证完成或运行可达性的阻断问题 |
| P1 | 会造成错误触发、错误产物、错误分级或关键消费者漂移的问题 |
| P2 | 会降低可维护性、可复验性或跨 runtime 稳定性的中风险问题 |
| P3 | 说明、改进建议或不影响当前等级的观察 |

WARN 累积规则：

- 同一维度出现 3 个及以上 WARN，且共同影响同一成功标准、消费者或安全边界时，按 1 个 FAIL 处理。
- 跨维度出现 6 个及以上 WARN，且没有 owner、承接记录或复验方式时，最终等级下调一级。
- WARN 已有明确 owner、承接位置、失效条件和复验命令时，不自动降级；但不得宣称 L3/L4 已无风险。

禁止事项：

- 禁止用“看起来符合”作为 PASS 证据。
- 禁止只引用固定行数、历史标签或表达偏好作为 FAIL。
- 禁止用局部 grep 绿灯替代运行时 artifact、消费者或 fresh proving command。
- 禁止把 Markdown/HTML 派生视图当作机器事实源。
- 禁止把行为收益、retain/retire 或生命周期结论覆盖运行质量 FAIL。

## 维度缺陷模型

### G0 Skill 本体存在

Required Evidence：

- 目标 Skill 目录。
- `SKILL.md` frontmatter。
- `name`、`description`、可选 `license`、`compatibility`、`metadata`、`allowed-tools` 和目录名。

FAIL Conditions：

- 缺少 `SKILL.md`。
- frontmatter 不存在、未闭合，或缺 `name` / `description`。
- `name` 为空、长度超过 64、含大写/下划线/XML tag、以 hyphen 开头或结尾、含连续 hyphen，或与父目录名不一致。
- `description` 为空、超过 1024 字符、含 XML tag，或完全没有 what + when 信息。
- 面向 Claude API / Claude.ai 的 Skill `name` 含目标平台保留词；面向其他 runtime 时未声明保留词差异。

PASS Conditions：

- Skill 本体可定位，frontmatter 合法，必填字段可被 runtime 消费。

False Positive Guard：

- 不因缺少可选目录、可选 metadata 或 UI 展示字段判 G0 FAIL。
- Claude Code 文档中 `name` 可由 slash command 继承；但进入跨 runtime 或 API 分发时，仍按 Agent Skills open standard 的 strict name 规则裁决。

### G1 运行可达

Required Evidence：

- Skill 安装路径、runtime 搜索路径或 catalog。
- `agents/openai.yaml`、manual-only/disabled/retired 暴露策略。
- `/skills info`、安装脚本、配置或等价证据。

FAIL Conditions：

- Skill 存在但目标 runtime 无法发现。
- manual-only/disabled/retired 状态与 adapter、catalog 或安装暴露不一致。
- 退役 Skill 仍作为 active alias、default prompt 或兼容入口暴露。

PASS Conditions：

- 目标 runtime 可发现或按声明策略显式调用该 Skill，暴露状态一致。

False Positive Guard：

- 只面向某一 runtime 的 Skill 不因另一个 runtime 缺 adapter 自动失败；必须先确认目标 runtime。

### G2 审计证据包完整

Required Evidence：

- `SKILL.md` 引用的资源路径。
- scripts manifest、schema、eval、examples、fixtures 或消费者说明。
- 缺失资源的停机说明。

FAIL Conditions：

- `SKILL.md` 路由到不存在的关键资源。
- 声称使用脚本、schema、validator、eval 或 renderer，但审计无法定位。
- 缺关键证据时仍要求审计继续给出 PASS。

PASS Conditions：

- 所有关键资源可读，或缺失项被声明为可选且不影响当前任务路径。

False Positive Guard：

- 轻量 instruction-only Skill 不强制拥有 scripts、schemas 或 evals；但不能声称拥有不存在的资源。

### S1 Discovery & Trigger

Required Evidence：

- `description`。
- 邻近 Skill 的 `description` 或 invocation 策略。
- 正触发、反触发、邻近冲突样例。
- 多 Skill 同时命中时的仲裁策略，包含 priority、mutual_exclusion、fallback 或 explicit invocation 规则。

FAIL Conditions：

- `description` 只有能力名，没有用户意图或触发场景。
- 与邻近 Skill 触发范围重叠，且无分流规则。
- 3 个及以上 Skill description 会同时命中同一常见用户请求，且无仲裁、优先级或互斥规则。
- manual-only Skill 在目标 runtime 中仍允许隐式触发。
- 创建、优化、审计、验证、迁移等相邻场景会被路由到错误 Skill。

WARN Conditions：

- 触发样例不足，只能人工推断触发边界。
- description 可触发但过宽，可能抢占邻近 Skill。

PASS Conditions：

- 能说清何时触发、何时不触发、与邻近 Skill 如何分流，并有样例或 eval 支持。

False Positive Guard：

- 不要求所有 description 都包含固定短语；关键是 runtime 能稳定识别能力和边界。

### S2 Task Contract

Required Evidence：

- 目标、非目标、输入边界、成功标准、完成证据。
- 用户任务类型或 Skill 类型画像。

FAIL Conditions：

- 目标只写“提升质量”“帮助处理”等口号，无法判断成功。
- 没有非目标或适用边界，导致 Skill 抢占不该处理的任务。
- 成功标准无法被产物、命令、eval、用户确认或消费者证明。

WARN Conditions：

- 目标清楚但边界较弱，可能造成过度触发。
- 成功标准只适合人工判断，缺少可观察锚点。

PASS Conditions：

- 审计者能回答：这个 Skill 做什么、不做什么、何时完成、用什么证据证明。

False Positive Guard：

- SMART 只是审视助记，不是必写章节；不能因为没有 SMART 标题判 FAIL。

### S3 Execution Protocol

Required Evidence：

- 主流程、步骤表、流程图或状态表。
- 相关 references/scripts/handoff 合同。
- 步骤产物、下一步消费者和失败状态。

关键步骤应能回答：

| 字段 | 含义 |
| --- | --- |
| step_id | 步骤标识 |
| purpose | 为什么需要这一步 |
| input | 读取什么文件、状态、用户输入或上游产物 |
| action | 执行什么判断、命令、编辑、生成或调用 |
| output | 产生什么产物、状态或结论 |
| consumer | 谁消费该产物或结论 |
| acceptance | 什么条件允许进入下一步 |
| failure_state | 缺参、验证失败、工具失败或权限不足时停在哪里 |
| next_step | 通过或失败后的下一步 |
| proof | 如何证明该步骤执行正确 |
| freedom_level | 该步骤是低自由度确定性执行、中自由度判断，还是高自由度探索 |

FAIL Conditions：

- 多阶段任务没有步骤边界，agent 不知道下一步做什么。
- 关键步骤缺输入、动作、输出或消费方。
- 失败后继续推进下游交付。
- 关键步骤依赖隐含会话记忆或未传入子代理的上下文。
- 声称执行脚本但没有参数、路径、退出码语义或失败处理。
- sub-skill、subagent、fork 或 agent team 编排没有输入合同、输出合同、接受标准、失败状态和回传格式。

WARN Conditions：

- 简单任务流程较粗，但仍可从上下文完成。
- 有流程图但缺少失败路径或回退动作。
- 步骤有产物但 acceptance 弱，只能人工判断。
- 高自由度探索步骤没有完成边界、最大轮次、停止条件或回到用户确认的规则。

PASS Conditions：

- 关键步骤能顺序执行，产物与下一步定义对等，失败会停在正确状态或回到修复步骤。

False Positive Guard：

- instruction-only、单步、无外部产物的轻量 Skill 不强制步骤表或流程图。
- 不能因为没有 Mermaid 图判 FAIL；只有复杂分支、handoff、状态流转或回退缺结构化表达时才阻断。

### S4 Resource Architecture

Required Evidence：

- `SKILL.md` 主体内容。
- `references/`、`resources/`、`examples/`、`rules/`、`schemas/`、`evals/`、`scripts/`、`templates/`、`assets/` 路由说明。
- plugin-level `hooks/`、`agents/`、`assets/`、`commands/`、adapter metadata 和资源的消费边界。
- 资源合同和读取条件。
- token budget 或等价上下文预算信号：metadata 触发列表、`SKILL.md` 主体、按需资源、脚本输出限制。

FAIL Conditions：

- 关键规则隐藏在多层 reference，运行时容易只读到部分内容。
- `SKILL.md` 引用资源但未说明何时读、读什么、期望得到什么。
- 低频方法论、长示例、模板正文或评分细则污染主执行路径，造成触发或执行混淆。
- plugin-level 资源被 Skill 消费但没有所有权、触发条件、同步对象或退役边界。

WARN Conditions：

- `SKILL.md` 接近或超过 500 行 / 5000 tokens，且未说明拆分或豁免理由。
- 超过本地审视信号 250 行，需要检查职责数量、读取频率、低频内容比例和工程化替代空间。
- reference 文件较大但无目录或 grep 指引。
- description 过长导致安装 Skill 较多时初始 Skill 列表被截断，且关键触发词未前置。

PASS Conditions：

- 主体承载高频入口、硬门禁、主流程和输出合同；低频细节按需加载，资源路由可被审计。

False Positive Guard：

- 行数预算只能作为 warning-level signal；没有运行时影响证据时不能单独判 FAIL。
- 不为了压缩行数删除硬门禁、失败路径、完成边界或安全约束。
- 公开生态中的 `resources/` 命名与本仓 `references/` 命名都可接受；裁决对象是按需加载合同，不是目录名偏好。

### S5 Runtime & Safety Boundary

Required Evidence：

- `allowed-tools`、依赖、脚本 manifest、hook adapter、外部 API 或 shell 命令边界；`allowed-tools` 只表示预授权/放行，不表示完整安全沙箱或 deny list。
- community/canonical source lock、本地补丁边界和许可说明。
- 安装、启用、网络、写入、删除、commit、deploy、migrate 等授权证据。
- 外部 URL、动态 fetch、第三方 Skill、插件资源和脚本依赖的来源信任策略。
- data flow disclosure：本地敏感路径、上传/下载、外部 API、日志、遥测、缓存、ZDR/数据驻留适用性。

FAIL Conditions：

- 审计、review、explain 类 Skill 默认暴露 `Edit`、`Write` 或 `MultiEdit`。
- 把 `allowed-tools` 描述成限制工具访问的安全边界，或用它替代权限设置、sandbox、代码审计、脚本准入和人工授权。
- `allowed-tools` 预授权与职责不匹配，或要求执行未授权写入、删除、提交、部署、迁移或外部写 API。
- 裸 `Bash` 允许写入、删除、网络变更、进程管理或环境变更，且无准入边界。
- scripts 无 owner、allowed args、timeout、路径限制、退出码语义、输出边界或失败状态。
- hook 接入无 adapter contract、owner、failure state 或 rollback。
- 外部下载、community Skill 或脚本来源不可追溯。
- 外部 URL、动态 fetch 或远程资源直接进入指令路径，且无 fetch policy、内容校验、版本锁定、缓存锁或 untrusted-content 处理。
- Skill 处理敏感数据、外发 API、日志/遥测或共享容器数据，却未声明 data flow、ZDR 不适用/适用范围、数据驻留和清理策略。

WARN Conditions：

- 依赖存在但安装/版本要求弱，可能导致运行时漂移。
- 只读 Bash 诊断命令未列准入说明，但当前任务风险较低。
- `allowed-tools` 缺失但职责可能需要预授权工具；需由目标 runtime 权限模型和实际指令共同裁决。

PASS Conditions：

- 所需工具、环境、权限、脚本和来源边界与职责一致，且失败会阻断或请求人工授权。
- 外部内容被当作不可信输入处理，脚本和网络行为有可复验边界，敏感数据流向被声明并可清理。

False Positive Guard：

- 不因缺 `allowed-tools` 自动 FAIL；只有职责需要预授权工具、实际指令要求工具执行、或声明了目标 runtime 的预授权体验时才裁决。
- Claude API Skills 的代码执行容器与 Claude Code/Codex 本地运行环境不同；网络、安装和数据保留规则必须按目标 runtime 裁决。

### S6 Artifact Contract

Required Evidence：

- 任务产物、审计产物和状态产物的路径、格式、字段、消费者。
- schema、semantic validator、renderer、hook、runner 或 downstream consumer。

产物类型：

| 类型 | 含义 | JSON 要求 |
| --- | --- | --- |
| task artifact | 用户真正要的输出，如文档、代码、图片、报告 | 按任务需要决定 |
| audit artifact | findings、review、verification、benchmark 等审计产物 | 有机器消费者时需要 schema |
| state artifact | 跨轮次、hook、CI、runner、release gate 消费的状态 | 必须有 schema/validator |

FAIL Conditions：

- 输出只写“生成报告”或“完成任务”，没有路径、格式、必填字段或消费者。
- 声称 JSON 是机器事实源，但无 schema、validator 或消费者。
- Markdown/HTML 派生视图被反向当作机器事实源。
- 状态产物无法流转到下游，或字段无 owner/drop condition。

WARN Conditions：

- 人工阅读产物可用，但缺少来源声明或复验路径。
- JSON 字段存在但消费者不明确，暂未进入机器门禁。

PASS Conditions：

- 产物类型清楚，消费者明确，机器事实源有 schema/validator，派生视图可追溯。

False Positive Guard：

- 仅供人工阅读且无机器消费者的 Skill 不强制 JSON。

### S7 Verification Loop

Required Evidence：

- 完成校验、fresh proving command、eval/assertions、validator、人工 review 记录。
- 成功标准与验证命令的对应关系。
- 失败后的停机或回路修复动作。

FAIL Conditions：

- 声称完成但没有验证方式。
- proof command 只证明文件存在、grep 命中或脚本能运行，不能证明成功标准。
- 验证失败后继续下游交付。
- 用 Mock 或跳过外部交互伪造验收信心。
- 人工审查覆盖了应由 validator、schema、命令或真实依赖证明的硬门禁。

WARN Conditions：

- 有验证但只覆盖 happy path。
- eval 覆盖不足，缺反触发、缺参、权限不足、格式诱导或失败路径。

PASS Conditions：

- 每个完成声明都能回放到成功标准、产物、命令、eval 或消费者；失败会阻断或回到修复步骤。

False Positive Guard：

- 主观质量、写作风格或设计品味可由人工 review 补充，但必须声明哪些项是人工判断。

### S8 Evolution & Integration

Required Evidence：

- `agents/openai.yaml`、runtime catalog、install 暴露、retired skill 规则。
- 目标 runtime adapter 矩阵：`.claude-plugin/`、`.codex-plugin/`、`.cursor-plugin/`、`.opencode/`、`gemini-extension.json` 或等价配置中与该 Skill 有关的暴露策略。
- source lock、本地补丁、迁移、退役、跨模型或跨 runtime 测试。
- 旧入口、别名、兼容目录和 archive 边界。
- retire_runbook：alias 摘除、metadata 删除、catalog/install 清理、文档迁移、archive_ref 和回滚边界。

FAIL Conditions：

- 旧 Skill 入口退役后仍被安装或自动暴露。
- adapter、catalog、default prompt 与 `SKILL.md` 描述漂移。
- community canonical 被改写后无法追溯来源或本地补丁边界。
- 迁移、退役或 runtime 暴露变更无验证命令。
- 目标 runtime adapter 中仍暴露旧 description、default prompt、manual-only 策略或依赖声明，导致同名 Skill 在不同入口行为不同。
- 退役只删除 `SKILL.md`，未清理 alias、catalog、install entry、adapter metadata、测试 fixture 或文档入站引用。

WARN Conditions：

- L3/L4 声明缺跨模型、跨 runtime 或版本变化证据。
- 兼容入口有保留理由但缺失效条件。
- 多 runtime 只做了单点验证，且未说明不支持范围或用户可见差异。

PASS Conditions：

- Skill 在目标 runtime、adapter、安装和生命周期状态中保持一致，迁移和退役有回滚路径。
- L3/L4 声明覆盖 fast/balanced/reasoning 三档模型或显式声明单模型范围，并有触发、格式和验证证据。

False Positive Guard：

- 单 runtime Skill 不因缺其他 runtime adapter 失败；但必须写明目标 runtime 和不支持范围。

### E1-E5 效果证明

Required Evidence：

- `evals/evals.json`、with-skill / without-skill 或 old/new baseline 输出。
- grader/assertions、timing、token、人工 review、反证样本。
- 结果分析说明哪些 assertion 有区分度，哪些场景无提升。
- 跨模型、跨 runtime、不同输入规模和多 Skill 组合时的稳定性证据；无法覆盖时声明适用范围。

FAIL Conditions：

- 声称“最佳实践”“显著提升”“应 retain”，但没有 baseline 或经验 eval。
- assertion 过弱，裸模型也总能通过，却被用作增益证据。
- 只展示成功样例，忽略失败、误触发或过度流程化场景。

WARN Conditions：

- 初始上线只有 eval 框架，无经验数据。
- 有 baseline 但样本代表性不足、方差大或成本收益不明确。

PASS Conditions：

- 代表性任务证明 Skill 在质量、稳定性、成本或偏好保真上有明确收益，并记录失效边界。

False Positive Guard：

- 新 Skill 可在缺少经验数据时达到 L1/L2；缺效果证明只阻断 L3/L4 或 retain 结论。

## 资源合同

Skill 资源拆成可消费对象，而不是把所有内容都塞进 `references/`。

| 目录 | 角色 | 合同要求 |
| --- | --- | --- |
| `references/` | 方法论、规则细则、决策依据 | 完整 Trigger/Read/Expect/Consume/Evidence/Sync |
| `resources/` | 公开生态常见资源目录，语义等同于按需读取资料 | 与 `references/` 同等裁决；迁入本仓时可保留原名或声明映射 |
| `examples/` | 正例、反例、触发样例、失败样例 | 声明消费者，优先被 eval 或报告使用 |
| `rules/` | skill-local 硬约束或权限 profile | 不覆盖全局 rules；只承载当前 Skill 的局部约束 |
| `schemas/` | JSON artifact 形状、枚举、状态词表 | 有 validator 和消费者 |
| `evals/` | 测试输入、assertions、benchmark input | 有复跑命令和评分口径 |
| `scripts/` | 确定性检查、转换、渲染、验证 | 有 manifest、边界、超时和退出码语义 |
| `templates/` | Markdown/HTML 派生视图模板 | 只由 renderer 消费，不承载事实真源 |
| `hooks/` | 拦截和状态控制 adapter | 有 owner、failure state、rollback 和接入门禁 |
| `assets/` | 模板资产、图片、字体、示例文件 | 有输出消费者和许可边界 |
| plugin-level resources | 插件级 hooks、agents、assets、commands、adapter metadata | 声明哪个 Skill 消费、何时同步、何时删除 |

资源合同字段：

| 字段 | 含义 |
| --- | --- |
| Trigger | 何时读取或执行该资源 |
| Read | 读取哪个路径或对象 |
| Expect | 从中获得什么信息或能力 |
| Consume | 谁消费该结果 |
| Evidence | 如何证明资源被正确消费 |
| Sync | 资源变化时同步哪些入口、schema、测试或报告 |

## 分级

| 等级 | 定位 | 判定含义 |
| --- | --- | --- |
| L0 不可审计 | 缺本体、不可达或证据包缺失 | G0-G2 存在阻断 |
| L1 可运行 | 能被发现、触发并完成单次任务 | G0-G2 通过；S1/S2/S3/S6/S7 有最小合同 |
| L2 可审计闭环 | 能稳定独立运行并被审计 | S1-S8 无阻断；finding 可复验 |
| L3 最佳实践候选 | 能证明跨场景质量 | L2 通过；E1-E5 有代表性证据 |
| L4 生产级维护 | 能长期维护与演化 | L3 通过；跨模型、跨 runtime、迁移、退役和生命周期证据齐全 |

评级按最低阻塞项收敛。G0-G2 任一 FAIL 时为 L0。S5 或 S7 存在影响权限、安全、验证证据、数据流或完成门禁的 FAIL 时，评级最高只能为 L1；相关 FAIL 修复并由复验方式证明后，才能评为 L2 或更高。缺少 E1-E5 经验数据时，最高只能评为 L2，不能宣称 L3/L4 或 retain。WARN 累积命中降级规则时，先按降级后的等级汇报，再列出承接 owner 和复验命令。

## Skill 类型画像

画像可叠加，强约束取并集；画像不会豁免 G0-G2 与 L1 最小合同。instruction-only Skill 无机器 artifact 时，S6 可判 NOT_APPLICABLE，但不能伪造 JSON、schema 或 eval 证据。

| 类型 | 目标等级 | 强约束维度 | 说明 |
| --- | --- | --- | --- |
| Pipeline skill | L2 起，冲 L3 | S1-S8 | 涉及阶段流转、handoff、验证闭环 |
| 审计/验证 skill | L2 起，冲 L3 | S1、S5、S6、S7、S8 | 结论必须证据化，默认只读 |
| 创建/改造 skill | L2 起，冲 L3 | S1、S2、S4、S5、S7 | 与 `skill-creator`、`skill-harness` 边界清晰 |
| 工具类 skill | L1 起，冲 L2 | S1、S5、S6、S7 | 输入输出、工具和权限边界优先 |
| manual-only skill | L1 起，按职责提升 | G1、S1、S5、S8 | 两端暴露策略需要一致 |
| 轻量 instruction-only skill | L1 起，按风险提升 | S1、S2、S7 | 不强制脚本/schema/eval，但不能伪造证据 |
| meta-skill | L1 起，按风险提升 | S1、S2、S4、S8 | 用于发现、安装、创建或路由其他 Skill，必须防止抢占具体任务 |
| slash-command-only skill | L1 起，按风险提升 | G1、S1、S5、S8 | 只允许显式调用时，隐式触发必须关闭或在 description 中明确 |
| multi-runtime adapter skill | L2 起，冲 L3 | G1、S1、S5、S8、E4 | 多 runtime 暴露、权限和默认 prompt 必须一致或声明差异 |

## 审计完成边界

声称质量审计完成前，必须逐项汇报：

- 目标 Skill 与目标 runtime。
- G0-G2 是否通过；阻断项必须停止。
- 当前裁决层级：Portable core / First-party hardening / Production evidence。
- S1-S8 的 PASS / FAIL / WARN finding。
- E1-E5 的证据状态：已证明、缺经验数据或不适用。
- WARN 累积是否触发降级；未降级时说明 owner、承接位置和复验方式。
- fresh proving command 或可回放证据。
- 剩余风险、false positive guard 和下一步动作。
