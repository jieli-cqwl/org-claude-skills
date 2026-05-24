# Standard Chain Harness Audit

Date: 2026-05-24

## 结论

`herness` 不是可稳定定位的社区对象；按公开证据和语境，应归一化为 `harness / harness engineering`，另一个相近但不同的候选是 `Hermes Agent`。本仓库和 `harness engineering` 强相关：当前 `standard-chain/v1` 已经是一个面向 Claude Code 与 Codex 的 agent harness 控制平面。

当前建议：不直接引入 Hermes，不复活历史 `skill-harness`，不让社区 meta-harness 生成器改写本仓结构。先做一个最小试点：把 `standard-chain` 的 harness 能力显性化为 condition sheet，并为 `developer` 或 `skill-refiner` 定义一次 run 的 episode package 证据包。

## 范围

本报告只回答四件事：

1. `herness` 到底应解析成什么对象。
2. 社区讨论中的 harness 核心机制是什么。
3. 当前仓库已有能力与 harness engineering 的对应关系。
4. 下一步怎样学习并最小落地。

不做的事：

- 不修改 runtime 行为。
- 不新增 skill、hook、agent 或测试。
- 不把 `docs/reports` 报告登记为 active `standard-chain` scope。
- 不重新启用历史 `skill-harness` 承载。

## 名称归一化与候选排除

| 原始/变体 | 类型 | 状态 | 证据与判断 |
| --- | --- | --- | --- |
| `herness` | 拼写原词 | 排除为正式对象 | 搜索未发现稳定 AI agent 社区对象；更像误拼或听写。 |
| `harness` / `agent harness` / `harness engineering` | 概念/方法 | 命中 | Anthropic 与 2026 年多篇论文都将 harness 作为模型外运行控制平面。 |
| `Hermes Agent` | 开源 agent 产品 | 部分命中 | NousResearch/hermes-agent 是具体 self-improving agent，和 harness 讨论相邻，但不是同一概念。 |
| Harness CI/CD | DevOps 平台 | 排除 | 语义是 CI/CD 与开发平台，不是本次 agent harness。 |
| `harness.lol` | 跨 agent CLI 适配层 | 部分命中 | 统一 Claude Code、Codex、OpenCode、Cursor 的 CLI 与事件流，属于 adapter 层。 |
| `revfactory/harness` | Claude Code meta-skill/plugin | 部分命中 | 生成 agent team 与 skills，属于 team-architecture factory。 |

## 外部证据摘要

| 来源 | 时间 | 可验证论点 | 对本仓启发 |
| --- | --- | --- | --- |
| Anthropic, Effective harnesses for long-running agents | 2025-11-26 | 长任务失败核心是跨 context window 状态断裂、过早完成、缺少 E2E 验证；解决方式包括 initializer、feature list、progress file、git history、单 feature 增量推进、测试。 | 本仓已有 canonical JSON、worklog、completion gate，应继续走结构化状态与证据，而不是扩大提示词。 |
| Anthropic, Harness design for long-running application development | 2026-03-24 | planner / generator / evaluator 分离能缓解自评偏乐观；evaluator 需要独立上下文、可操作工具和明确评分标准。 | 本仓 review / verify / qa 已分层，但 fresh evaluator 和 score/rubric 需要更显性地进入 episode package。 |
| AI Harness Engineering: A Runtime Substrate for Foundation-Model Software Agents | 2026-05-13 | harness 负责 task specification、context selection、tool access、project memory、task state、observability、failure attribution、verification、permissions、entropy auditing、intervention recording。 | 可用这 11 项作为本仓 condition sheet 的盘点维度。 |
| Code as Agent Harness | 2026-05-18 | 代码从输出物变成 agent 推理、行动、记忆、验证、协作的执行基底；未来挑战包括不完整反馈下验证、无回归改进、多 agent 共享状态、人类监督。 | 本仓应把脚本、schema、hook、canonical artifact 当成 harness 主体，而不是 Markdown 附属物。 |
| NousResearch/hermes-agent | 2026-05 当前 | Hermes 主打内建学习循环、技能生成、跨会话记忆、调度、子代理、远程运行。 | 学习“记忆与技能改进闭环”，但必须隔离自改进写入权限，避免破坏本仓第三方镜像和 first-party 边界。 |
| harness.lol docs | 2026-05 当前 | 通过统一 CLI 与 NDJSON event stream 适配 Claude Code、Codex、OpenCode、Cursor。 | 可作为未来跨 harness 轨迹归一化参考，不是当前第一优先级。 |
| revfactory/harness | 2026-05 当前 | 自动生成 Claude Code agent team 与 skills，支持 pipeline、fan-out/fan-in、expert pool、producer-reviewer 等模式。 | 可借鉴团队拓扑词汇；不要让生成器覆盖本仓已测试锁定的 standard-chain。 |

## 当前仓库的 Harness 映射

| Harness 职责 | 当前承载 | 现状 | 主要证据 |
| --- | --- | --- | --- |
| Task specification | `contracts/standard-chain.yaml`、各 phase/task artifact schema | 强 | `standard-chain` 明确各角色输入、输出、消费者和 terminal artifact。 |
| Context selection | `contracts/active-doc-scope.yaml`、`worklog.md`、canonical ref grammar | 中强 | README 定义接手恢复顺序：scope registry -> worklog -> canonical active artifact。 |
| Tool access | `shared/hooks/registry.json`、`shared/agents/{claude,codex}`、runtime surface | 中 | hooks、agent definitions 与 skill mode 控制了哪些能力自动/手动触发。 |
| Project memory | canonical JSON、co-creation ledgers、artifact registry | 中强 | 记忆不是聊天记忆，而是受管 artifact 与导航字段。 |
| Task state | `delivery-state.json`、`artifact-registry.json`、`signoff-package.json` | 强 | delivery-owner 产物记录 current_stage、status、control_action、active revisions。 |
| Observability | `developer-report.json`、`verify-result.json`、`qa-result.json`、eval results | 中 | 有结果证据，但还缺统一 episode package。 |
| Failure attribution | `fix-result.json`、completion gates、validator failure states | 中 | 有失败字段与 gates；跨 run 根因归类尚未统一。 |
| Verification | completion gates、`tests/run-all.sh`、skill evals、fresh proving command 规则 | 强 | hooks registry 绑定 skill completion scripts；AGENTS 要求 fresh proving command。 |
| Permissions | auto/manual/off runtime surface、hook trust 说明、sandbox/approval 规则 | 中强 | skill-runtime-surface 明确 manual-only 与 owner；README 说明 hooks trust 不自动写入。 |
| Entropy auditing | eval lifecycle review、quality dimensions、test signal checks | 弱中 | 有局部质量审计，但缺少对 agent run 漂移、工具循环、上下文污染的统一指标。 |
| Intervention recording | `user-decision.json`、signoff package、co-creation ledger | 中 | 有用户决策 artifact；普通运行中的人类打断/重定向记录不统一。 |

## 关键差距

1. Episode package 缺失：当前有很多结果文件，但没有统一描述“一次 agent run 发生了什么”的证据包。
2. Harness condition sheet 缺失：没有一张表持续回答当前 harness 到 H0-H3 或 11 职责的覆盖等级。
3. Fresh evaluator 边界未统一：review / verify / qa 存在，但是否 fresh context、是否 default-fail、是否先读证据再判定，没有被跨链路抽象成一条通用合同。
4. 运行轨迹未归一化：Claude/Codex hooks、shell 输出、developer-report、eval result 之间还不是同一套 trace/event vocabulary。
5. 自改进入口风险高：Hermes 式“技能自生成/自改进”如果直接引入，会和 `community/*` 纯镜像、manual-only、first-party 优先冲突。
6. 历史命名有反证：测试明确阻止 `skill-harness` 残留，说明不能用“复活旧目录”当落地方式。

## 最小试点方案

### 试点名称

`standard-chain harness audit`

### 试点目标

把现有 `standard-chain` 作为 harness 显性建模，证明我们能用结构化证据判断它哪里强、哪里弱、下一步补什么，而不是靠社区热词驱动改造。

### 建议切入点

优先选择 `developer` 或 `skill-refiner`。

选择理由：

- 两者都有明确输入、输出、completion gate 与 eval 证据。
- 两者都容易暴露“自评偏乐观、证据不足、上下文漂移、完成口径不稳”的 harness 问题。
- 两者都不需要先动产品链路全局合同。

### Episode package 草案

先作为设计草案，不立即落代码：

```json
{
  "schema_version": "0.1.0",
  "chain_version": "standard-chain/v1",
  "episode_id": "developer:TASK-ID:attempt-1",
  "task_spec_refs": [],
  "context_refs_read": [],
  "tool_events": [],
  "state_before_refs": [],
  "state_after_refs": [],
  "failure_attribution": {
    "status": "none|observed|blocked",
    "category": "input_gap|test_failure|tool_failure|scope_drift|verification_gap|unknown",
    "evidence_refs": []
  },
  "verification": {
    "default_fail": true,
    "proving_commands": [],
    "result": "pass|fail|blocked",
    "evidence_refs": []
  },
  "human_interventions": [],
  "residual_risks": []
}
```

### Condition sheet 草案

先用 Markdown 或 JSON 做 read-only 盘点：

| 维度 | 等级 | 证据 | 缺口 | 下一步 |
| --- | --- | --- | --- | --- |
| task_specification | strong | `contracts/standard-chain.yaml` | 无统一 condition sheet | 首次填表 |
| observability | partial | report/eval artifacts | 缺 run-level episode | 为一个 developer run 试填 |
| entropy_auditing | weak | lifecycle review | 缺 drift 指标 | 先定义 2-3 个低成本指标 |
| intervention_recording | partial | user-decision/signoff | 缺普通打断记录 | 先只登记人工裁决，不登记所有聊天 |

### 验证口径

第一阶段只验证报告与设计，不跑 runtime：

```bash
test -s docs/reports/standard-chain-harness-audit-2026-05-24.md
grep -q "当前仓库的 Harness 映射" docs/reports/standard-chain-harness-audit-2026-05-24.md
grep -q "Episode package 草案" docs/reports/standard-chain-harness-audit-2026-05-24.md
git status --short -- docs/reports/standard-chain-harness-audit-2026-05-24.md
git diff --no-index --stat -- /dev/null docs/reports/standard-chain-harness-audit-2026-05-24.md || test $? -eq 1
```

第二阶段若要落地，再补可失败测试：

- 新增 fixture：一个最小 `developer-report.json` + task input。
- 新增 validator：校验 episode package 必填字段、default-fail、evidence_refs。
- 新增 golden：证明缺少 verification evidence 时必须 fail。
- 只通过后再生成真实 episode package。

## 采纳建议

| 动作 | 判定 | 原因 |
| --- | --- | --- |
| 学习 harness engineering 概念 | 采纳 | 与本仓目标完全同向，能解释现有 standard-chain 的价值。 |
| 直接安装 Hermes 替换当前流程 | 不采纳 | Hermes 是完整 agent runtime，本仓是 Claude/Codex skill/rule/hook runtime 管理仓；边界不同。 |
| 借鉴 Hermes 记忆/技能闭环 | 改写后吸收 | 只学习“经验如何沉淀为可审计技能改进”，不得开放自动写 third-party mirror 或 runtime rules。 |
| 使用 revfactory/harness 生成本仓 agents/skills | 暂不采纳 | 本仓已有 standard-chain 合同和测试锁定，生成器会引入不可控漂移。 |
| 用 harness.lol/OpenHarness 做跨 CLI event adapter | 观察 | 等 episode package 需要跨 Claude/Codex 轨迹统一时再试。 |
| 新建 `skill-harness` | 不采纳 | 当前测试明确要求 retired `skill-harness` 不得 active。 |
| 新建 `harness-audit` 报告与后续 condition sheet | 采纳 | 小范围、可回退、和现有证据体系一致。 |

## 反方挑战

最强反方：这可能只是把已有 standard-chain 换个名词包装，增加文档和 schema 负担，不能真实提升 agent 成功率。

回应：成立一半。只写概念文档没有价值，所以落地必须绑定一个可验证 episode package 试点，并要求缺证据时失败。若试点不能暴露实际缺口，或不能减少 review/verify 复验成本，应停止。

最强反方：Hermes 发展很快，直接接入或许能获得记忆、自改进、调度收益。

回应：短期不成立。本仓核心约束是 deterministic contracts、third-party mirror purity、manual-only 边界和 first-party 优先。Hermes 的自改进写入和 multi-channel autonomous runtime 会先破坏治理边界，再谈收益。

最强反方：episode package 会重复 developer-report、verify-result、qa-result。

回应：风险真实。episode package 不能复制下游报告正文，只能做索引和运行级元数据。它的职责是串联“一次运行”的上下文、工具、状态、失败归因和验证证据，不替代已有 artifact。

## 失效条件

出现任一情况，应停止本方向：

- condition sheet 只产生主观评分，没有可点击证据路径。
- episode package 复制 artifact 正文，变成第二事实源。
- 新增验证无法构造红灯，或者红灯只检查 Markdown 词句。
- 为了追社区趋势，引入自动自改进写入 third-party mirror、runtime rules 或 active docs。
- 试点后 review/verify/qa 复验成本没有下降，也没有新增可定位缺口。

## 下一步

建议下一步不是改代码，而是开一个明确任务：

1. 为 `developer` 设计 `episode-package.schema.json` 和一个失败 fixture。
2. 写一个只读 validator，先让缺少 `verification.evidence_refs` 的 fixture 失败。
3. 再用真实 `developer-report.json` 试填一个 episode package。
4. 验证通过后，再考虑是否把 condition sheet 纳入 `docs/reports` 或 `contracts`。

## 落地记录

本轮已完成第一步最小落地：

- `contracts/episode-package.schema.json`：定义 run-level episode package。它只索引 canonical artifact 与执行证据，不复制 artifact 正文，不成为第二事实源。
- `tools/community/validate_episode_package.py`：只读 validator，执行 schema validation 和关键语义检查。
- `tests/fixtures/standard-chain-harness/developer-episode-package.valid.json`：developer 正例 package。
- `tests/fixtures/standard-chain-harness/developer-episode-package.missing-verification-evidence.json`：缺少 `verification.evidence_refs` 的红灯 fixture。
- `tests/test-standard-chain-episode-package.sh`：证明正例通过，缺 verification evidence、`default_fail=false`、proving command 缺 `current_output_ref` 均失败。
- `tests/run-all.sh` 与 `tests/test-run-all-runner-contract.sh`：把 episode package 测试纳入 quick/full 门禁。

仍未做：自动生成真实 run episode package、condition sheet 入库、跨 Claude/Codex event adapter。原因是这些会引入新的运行时写入面，应等当前只读 validator 试点稳定后再推进。

## 证据索引

- Anthropic, Effective harnesses for long-running agents: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic, Harness design for long-running application development: https://www.anthropic.com/engineering/harness-design-long-running-apps
- Anthropic, Multi-agent research system: https://www.anthropic.com/engineering/multi-agent-research-system
- AI Harness Engineering: https://arxiv.org/abs/2605.13357
- Code as Agent Harness: https://arxiv.org/abs/2605.18747
- NousResearch/hermes-agent: https://github.com/NousResearch/hermes-agent
- harness.lol docs: https://www.harness.lol/docs
- revfactory/harness: https://github.com/revfactory/harness
- 当前仓库 README: `README.md`
- 当前仓库 standard-chain contract: `contracts/standard-chain.yaml`
- 当前仓库 runtime surface: `contracts/skill-runtime-surface.json`
- 当前仓库 hooks registry: `shared/hooks/registry.json`
- 历史 `skill-harness` 反证: `tests/test-skill-refiner-no-harness-dependency.sh`, `tests/test-skill-effectiveness-eval-framework.sh`

## 复检记录

### Round 1

目标复盘：产出 read-only harness audit，回答对象解析、仓库关系、差距和最小试点。

范围复盘：只允许修改本报告；不改 runtime、不改 tests、不登记 active scope。

证据复盘：对象解析已有外部来源；仓库映射已有 `README.md`、`contracts/standard-chain.yaml`、`contracts/skill-runtime-surface.json`、`shared/hooks/registry.json` 与退役 `skill-harness` 测试反证。

风险复盘：原验证命令 `git diff --check -- <file>` 对新建未跟踪文件无效，已改为 `git status --short` + `git diff --no-index --stat` 口径；另将 `Claude/Codex adapter` 改成当前可见承载 `shared/agents/{claude,codex}`，避免引用不存在的根 `codex/` 目录。

### Round 2

目标复盘：仍以 read-only harness audit 为目标，不扩大到 schema、hook 或 validator 实现。

范围复盘：本轮只复核报告自身；无新增文件、无运行时配置改动、无 active scope 变更。

证据复盘：名称归一化、外部来源、仓库承载映射、历史 `skill-harness` 反证、试点建议和失效条件均已覆盖。

风险复盘：未发现新增目标内问题。剩余风险是下一阶段若真正落地 episode package，必须先补失败 fixture 和 validator 红灯，不能用本报告替代实现验收。
