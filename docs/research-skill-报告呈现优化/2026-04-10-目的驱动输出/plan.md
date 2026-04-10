# Research Purpose-Driven Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 让 `shared/skills/research` 在保留证据严谨性的前提下，按调研发起目的输出更容易理解和决策的报告结构。

**Architecture:** 通过“研究模式”和“呈现模式”解耦来重构 `research`。`SKILL.md` 负责识别 `presentation_profile`，新的呈现框架文档定义 profile 路由规则，模板负责实际章节排序，新增的共享审计附录统一承载所有 profile 都不能缺失的审计层，`completion_check.sh` 与测试负责把新结构固化成可机械验证的 contract；若最终 fresh proving command 暴露仓库级 blocker，则做最小 blocker fix 并同步回计划。

**Tech Stack:** Markdown, Bash, ripgrep, shell tests

---

### Task 1: research 呈现模式 contract [T1]

Files:
- Modify: `shared/skills/research/SKILL.md`
- Modify: `shared/skills/research/references/analysis-frameworks.md`
- Create: `shared/skills/research/references/report-presentation-framework.md`

1. [T1] 先写失败测试，断言 `research` 要显式确认调研目的、目标读者和读后动作，并区分 `research_mode` 与 `presentation_profile`。
2. [T1] 运行测试确认失败，证明当前 contract 还不支持目的驱动呈现。
3. [T1] 修改 `shared/skills/research/SKILL.md`，在 Step 1 和 Step 2 中加入呈现模式澄清、默认路由规则与模板选择说明。
4. [T1] 修改 `shared/skills/research/references/analysis-frameworks.md`，补充 `presentation_profile` 的适用场景与推荐映射。
5. [T1] 新建 `shared/skills/research/references/report-presentation-framework.md`，写清三档 profile 的目标、首屏重点、适用问题与禁止误用。
6. [T1] 运行测试确认通过，并检查相关引用路径与术语一致性。

### Task 2: research 模板重构 [T2]

Files:
- Create: `shared/skills/research/references/templates/research-decision-header-template.md`
- Create: `shared/skills/research/references/templates/research-understanding-header-template.md`
- Create: `shared/skills/research/references/templates/research-audit-header-template.md`
- Create: `shared/skills/research/references/templates/research-shared-audit-appendix-template.md`
- Modify: `shared/skills/research/references/templates/research-shared-header-template.md`
- Modify: `shared/skills/research/references/templates/research-tech-selection-template.md`
- Modify: `shared/skills/research/references/templates/research-analysis-template.md`
- Modify: `shared/skills/research/references/templates/research-discovery-template.md`

1. [T2] 先补失败测试，断言三档 header 模板存在，并校验 `decision` 首屏必须先出现问题、当前判断、决定性理由、最大风险、建议动作。
2. [T2] 运行测试确认失败，证明现有模板仍是旧的共享首屏结构。
3. [T2] 新建三档 header 模板和共享审计附录模板，并将 `research-shared-header-template.md` 调整为兼容入口说明，避免旧路径默认落到 `audit`。
4. [T2] 修改三个 mode 模板，把正文顺序调整为“答案层 -> 判断层 -> 证据层 -> 审计层”，避免与首屏重复堆叠。
5. [T2] 运行测试确认模板结构通过，并人工抽查模板章节是否保持 mode 语义与共享审计层分工。

### Task 3: research 机械校验 [T3]

Files:
- Create: `shared/skills/research/scripts/completion_check.sh`

1. [T3] 先写失败测试，构造最小 `research-report.md` fixture，断言 `decision / understanding / audit` 在共享审计附录缺失或章节顺序错误时必须失败。
2. [T3] 运行测试确认失败，证明门禁有效。
3. [T3] 新建 `shared/skills/research/scripts/completion_check.sh`，按现有 skill-local 脚本风格实现：定位报告、识别 profile、检查必填段落、共享审计附录和关键章节顺序。
4. [T3] 运行测试确认通过，并执行 `bash -n` 与 `shellcheck` 语法/静态检查。

### Task 4: research 回归测试 [T4]

Files:
- Create: `tests/test-research-skill-contract.sh`
- Modify: `tests/run-all.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T4] 先写失败测试，覆盖 contract 文案、模板存在性，以及 `decision / understanding / audit` 三类 completion check 通过/失败场景。
2. [T4] 运行测试确认失败，证明新门禁能拦住旧结构。
3. [T4] 实现 `tests/test-research-skill-contract.sh`，并在 `tests/test-skill-output-and-gate-contract.sh` 中补充 `research` script 存在性与关键字段检查。
4. [T4] 修改 `tests/run-all.sh`，把新测试接入 syntax / shellcheck / 执行序列。
5. [T4] 运行新增测试和相关回归，确认全部通过。

### Task 5: Codex hooks blocker fixes [T5]

Files:
- Modify: `tools/community/render_hook_registry.py`
- Modify: `install.sh`

1. [T5] 先复现 `tests/test-codex-skill-adapter.sh` 与 `tests/test-install-systematic.sh` 的相关失败，分别确认“标准空事件缺失”和“卸载无法恢复用户 hooks baseline”两类 blocker。
2. [T5] 运行失败测试并观察生成的 `hooks.json` 与安装状态，确认问题分别来自 Codex hooks 渲染器，以及安装流程未为用户原始 `hooks.json` 建恢复基线。
3. [T5] 在 `tools/community/render_hook_registry.py` 中做最小修复，为 Codex 显式补齐标准空事件键，不改已有事件合并逻辑。
4. [T5] 在 `install.sh` 中做最小修复，为安装前的 `~/.codex/hooks.json` 建 baseline 备份/恢复路径，保证卸载后恢复用户原始非标准事件。
5. [T5] 重新运行相关 adapter / systematic 测试，确认 blocker 消失。
