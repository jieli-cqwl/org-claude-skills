# Anthropic skill-creator 调研报告

## 答案层

- 调研模式：analysis
- 呈现模式：decision
- 调研日期：2026-04-22
- 操作对象：Anthropic `skill-creator`、官方 `Agent Skills` 方法、本仓库 `/Users/lijieli/org-claude-skills` 的 skill 与 eval 体系。
- 预期结果：判断它是什么、截图中“两类 skill”是否成立、咱们能否用起来、如何落地为可迭代资产。

结论：可以用，而且本仓库已经具备 70% 左右的底座。`skill-creator` 不是“写 SKILL.md 的模板”，而是把 skill 当成可测试、可比较、可回归、可退役的工程资产。截图里的两类成立，但它不是目录分类法，而是评估策略分类法：

- `Capability Uplift`：补模型短板，例如 PDF、PPTX、Excel、文档生成、复杂文件操作。评估重点是“有 skill 是否显著优于无 skill”，以及“新模型裸跑是否追上 skill”。
- `Encoded Preference`：固化流程、偏好、判断标准，例如本仓库的 `product-director`、`developer`、`delivery-owner`。评估重点是“是否忠实执行咱们的流程、门禁、边界和输出合同”。

建议路线：不要直接把官方 `skill-creator` 全流程照搬成主入口。先把它拆成三件本地能力：

1. 输出质量 eval：沿用 `shared/skills/*/evals/evals.json` 与 `tools/eval/scripts/run_standard_chain_local_eval.py`。
2. 触发率 eval：把 `tools/eval/scenarios/c4-trigger-rate-baseline.md` 升级为官方 `trigger-eval.json` 格式，并用 `community/anthropic/skills/skill-creator/scripts/run_eval.py` 跑。
3. 人审 viewer：复用 `community/anthropic/skills/skill-creator/eval-viewer/generate_review.py --static`，把每轮输出、grading、benchmark 放进一个可审阅 HTML。

## 判断层

### 1. 它到底是什么

Anthropic 在 2026-03-03 发布的《Improving skill-creator》把 `skill-creator` 升级成 skill 生命周期工具。官方目标是让作者能验证 skill 是否工作、捕获回归、优化 description 触发精度。它覆盖四个环节：

- 创建：访谈意图，写 `SKILL.md`，设计测试 prompt。
- 评测：同一 prompt 跑 with-skill 与 baseline/no-skill。
- 度量：汇总 pass rate、耗时、token、失败项。
- 迭代：基于人审、grader 和 benchmark 改 skill，再复跑。

官方仓库里的 `skill-creator/SKILL.md` 明确要求：写 2-3 个真实测试 prompt，执行 with-skill 与 baseline，生成 `grading.json`、`benchmark.json`，再用 `eval-viewer/generate_review.py` 让人审阅，最后继续迭代。

### 2. 两类 skill 怎么理解

`Capability Uplift` 解决“模型裸能力不稳定或做不到”的问题。它更像能力补丁。验证方式是 A/B：有 skill、无 skill、旧模型、新模型，谁输出更好。

`Encoded Preference` 解决“模型能做，但要按我的组织方式做”的问题。它更像流程合同。验证方式是 fidelity：是否按 hard gate、输入输出合同、权限边界、文档同步、验证证据执行。

本仓库主要资产属于 `Encoded Preference`，尤其是 `shared/skills/product-director`、`product-manager`、`developer`、`qa`、`delivery-owner`、`review`。`community/anthropic/skills/pdf`、`docx`、`pptx`、`xlsx`、`canvas-design` 更接近 `Capability Uplift`。

### 3. 本仓库能不能用

能用，且不从零开始。

本地已具备：

- 官方 `skill-creator` 已 vendored：`community/anthropic/skills/skill-creator/SKILL.md`。
- 官方脚本可运行：`quick_validate.py` 校验通过；`aggregate_benchmark.py`、`generate_review.py`、`run_eval.py`、`run_loop.py` 均存在。
- 本地已有 eval 资产：`shared/skills/*/evals/evals.json` 覆盖 14 个 first-party skill。
- 本地已有 runner：`tools/eval/scripts/run_standard_chain_local_eval.py` 能 dry-run 选出 `product-director` 与 `developer` eval。
- 本地已有触发率基线：`tools/eval/scenarios/c4-trigger-rate-baseline.md`，当前 dry-run 可解析 5 个 skill、25 个查询。
- 本地已有质量标准：`shared/reference/Skill质量标准.md` 已把 D1-D8、触发、渐进加载、artifact、权限、验证、演化纳入判断。

限制也明确：

- 官方 `run_loop.py` 需在 `skill-creator` 目录下用 `python -m scripts.run_loop` 执行，从仓库根按文件路径直接跑会因 `scripts` 模块导入失败。
- 官方 trigger eval 依赖 `claude -p` 与 skill 触发观测；Codex 运行面需要 wrapper 或替换为 Codex 可观测日志。
- 官方并行 subagent 工作流不能直接当成当前 Codex 会话里的默认动作；本仓库更适合用已有 local eval runner 或单独的评测任务执行。

## 证据层

### 官方证据

- Anthropic 官方博文《Improving skill-creator》，发布日期 2026-03-03：说明 skill 作者现在能写 eval、跑 benchmark、优化 description，并把 skill 分成 `Capability Uplift` 与 `Encoded Preference` 两类。
- Anthropic 官方 `skills` 仓库：`skill-creator` 目录包含 `SKILL.md`、`agents/`、`assets/`、`eval-viewer/`、`references/`、`scripts/`。
- Agent Skills 官方说明：skill 是包含说明、脚本和资源的文件夹，通过渐进披露让 agent 按需加载上下文。
- Agent Skills description 优化文档：description 是触发主机制，需用 should-trigger 与 should-not-trigger 查询测试，避免过宽或过窄。

### 本地证据

执行过的本地检查：

```bash
python3 community/anthropic/skills/skill-creator/scripts/quick_validate.py community/anthropic/skills/skill-creator
```

结果：`Skill is valid!`

```bash
bash tools/eval/run_trigger_eval.sh --dry-run
```

结果：解析 5 个 skill、25 个触发查询。

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills product-director,developer --dry-run
```

结果：选出 `product-director` 3 个 eval、`developer` 3 个 eval。

```bash
python3 -m scripts.run_eval --help
python3 -m scripts.run_loop --help
```

执行目录：`community/anthropic/skills/skill-creator`。结果：官方 trigger eval 与 description optimize 参数完整可见。

### 项目上下文

本仓库不是普通 skill 集合，而是统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`。README 明确：

- `shared/skills/` 是 first-party 真源。
- `community/anthropic/skills/` 是官方 `anthropics/skills` 镜像目录。
- `tools/eval/` 已有 grader、scenario、results、local eval runner。
- `shared/reference/Skill质量标准.md` 已定义 D1-D8 质量维度。

这意味着最佳落点不是“安装一个 skill-creator 玩玩”，而是把它纳入本仓库的 skill harness 与 standard-chain eval。

## 审计层

### 检索路径与覆盖证明

名称归一化：

| 变体 | 类型 | 处理 |
| --- | --- | --- |
| `skill-creator` | Anthropic 官方 skill 目录 | 命中 |
| `skills/skill-creator` | GitHub 仓库路径 | 命中 |
| `Improving skill-creator` | 官方博文标题 | 命中 |
| `Agent Skills` | 开放标准/概念 | 命中 |
| `Claude skill creator v2` | 第三方解读 | 仅作线索，不作核心证据 |

候选排除：

| 候选 | 排除原因 |
| --- | --- |
| B 站、CSDN、第三方博客解读 | 可帮助理解传播语境，但不作为权威结论来源 |
| `skillsmp.com` 等 marketplace 镜像 | 属于再分发或展示平台，不能替代上游仓库 |
| OpenClaw/ClawHub 改写版本 | 属于适配案例，不代表 Anthropic 官方实现 |

### 关键判断对抗表

| 判断 | 最强支持证据 | 最强反方挑战 | 失效边界 |
| --- | --- | --- | --- |
| 可以用起来 | 官方 skill 已在本仓库 vendored，本地 eval runner 和 evals 已存在，dry-run 证明入口可用 | 官方流程依赖 Claude/Cowork subagent 与 `claude -p`，Codex 运行面不完全等价 | 若无法稳定观测 skill 是否触发，description 自动优化只能先做离线/人工版 |
| 两类 skill 成立 | Anthropic 官方博文明确给出两类定义和不同测试理由 | 实际 skill 会混合两类，例如 `developer` 既固化 TDD 偏好，也弥补模型执行纪律短板 | 分类只用于评估策略，不用于强制目录拆分 |
| 本仓库优先做 Encoded Preference eval | first-party skill 都有流程、门禁、artifact、权限合同，本地质量标准 D1-D8 与之匹配 | 文档类官方 skill 也有现成价值，忽略会损失能力补丁收益 | 当目标是 PDF/PPTX/Excel 等产物质量时，应切到 Capability Uplift A/B 评测 |
| 先集成 viewer 和 trigger eval | 已有质量 eval，短板在触发率观测和人审视图 | 先做 viewer 不会自动提高 skill 质量 | 若 reviewer 没有稳定反馈机制，viewer 只能当报告，不能形成闭环 |

### 独立挑战记录

挑战结论：不要把 `skill-creator` 包装成万能“自动优化 skill”系统。它真正有价值的部分是把“感觉好用”变成“有样本、有基线、有评分、有人工反馈、有复跑记录”。本仓库已经有严格 rules、small-chain、standard-chain 与 D1-D8 质量标准，若照搬官方长流程，会增加噪音。正确做法是复用官方三件套：eval schema、description trigger loop、review viewer，再保留本地 hard gate 和 canonical artifact 体系。

### 落地计划

第一阶段：一周内做最小闭环。

- 选 2 个 `Encoded Preference` skill：`developer`、`delivery-owner`。
- 选 1 个 `Capability Uplift` skill：`pdf` 或 `docx`。
- 为每个 skill 固化 5-10 个 eval：正向、反向、邻近冲突、缺参、失败路径。
- 给 `run_trigger_eval.sh` 增加导出官方 JSON 的能力。
- 给 `generate_review.py --static` 增加本仓库 wrapper，把 local eval 输出转成 viewer 工作区。

第二阶段：形成资产化标准。

- 每个 first-party skill 必须有 `evals/evals.json`。
- 每个会自动触发的 skill 必须有 trigger eval。
- 每次改 `description` 或 `SKILL.md` 主流程，跑对应 eval。
- 模型升级后，对 `Capability Uplift` skill 跑 no-skill baseline，判断保留、瘦身或退役。
- 对 `Encoded Preference` skill 跑 fidelity eval，验证流程合同没有漂移。

第三阶段：纳入质量门禁。

- 将 `shared/reference/Skill质量标准.md` 的 D1-D8 与 eval summary 对齐。
- 将 `summary.json`、`benchmark.json` 作为机器事实源，HTML/Markdown 只做派生视图。
- CI 或本地 `tests/run-all.sh --quick` 增加轻量 eval 子集。

### 未验证项

- 尚未在本轮执行真实 `claude -p` trigger eval，因为这会调用外部模型并产生运行成本。
- 尚未对官方 `run_loop.py` 做 Codex wrapper。
- 尚未把 local eval 输出转换为 `skill-creator` viewer 的完整 workspace 结构。
- 尚未验证中文 trigger eval 在 Claude Code 与 Codex 两端的触发一致性。

## 来源

- [Anthropic: Improving skill-creator](https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills)
- [Anthropic GitHub: skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator)
- [Anthropic GitHub: skills repository](https://github.com/anthropics/skills)
- [Agent Skills overview](https://agentskills.io/)
- [Agent Skills: optimizing descriptions](https://agentskills.io/skill-creation/optimizing-descriptions)
