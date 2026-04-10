# Design

## Why

当前 `shared/skills/research` 的核心能力是“证据化决策支持”，但它把审计、留档、说服、扫盲和对象定位这几类阅读目标默认混在同一套首页结构里，导致产物容易呈现为“证据很全，但阅读路径不顺”。这会削弱调研结果的可理解性与可行动性，尤其是在用户只想快速做判断时。

本次变更要保留 `research` 的证据硬门禁，同时把“调研模式”和“报告呈现模式”解耦，让同一套严谨研究过程可以产出更贴近发起目的的报告首屏与正文顺序。

## Scope

- In scope: 为 `research` 增加“呈现模式”概念，明确调研目的、受众与预期动作如何影响报告结构
- In scope: 重构 `research` 相关模板，使首屏默认遵循“答案优先、证据后置、按需展开”的阅读路径
- In scope: 为 `research` 新增机械化 completion check 与仓库回归测试，校验 profile 路由与模板结构
- In scope: 若 fresh proving command 暴露阻断交付的仓库级回归，允许做最小 blocker fix 并同步回工件
- Out of scope: 放松 `research` 对证据、反方挑战、失效边界和覆盖证明的硬约束
- Out of scope: 重写历史 `docs/**/research-report.md` 报告或统一全仓库所有 skill 的文档呈现标准
- Out of scope: 改造 `research` 之外的 skill 或上升修改全局 `Skill质量标准.md`

## Approach

本次变更分三层实施：

1. Contract 层：在 `shared/skills/research/SKILL.md` 中新增 `presentation_profile` 路由，要求 Step 1 明确调研目的、目标读者和读后动作，并将 `selection / analysis / discovery` 与 `decision / understanding / audit` 两组概念拆开。
2. Template 层：保留现有 mode 模板，但把共享头改成三档呈现模板，并补一个共享审计附录模板。`decision` 首屏优先回答“该怎么决策”，`understanding` 优先回答“这到底是什么/为什么重要”，`audit` 才把 challenge 表前置；所有 profile 都在后层统一补齐“独立挑战记录 / 检索路径与覆盖证明 / 项目上下文”。
3. Gate 层：新增 `research/scripts/completion_check.sh` 与专用测试，机械校验 profile 必填段落、共享审计附录存在性和关键章节顺序，防止后续又回到“所有内容都塞到首屏”或“模板/门禁互相打架”的状态。
4. Blocker fix 层：若最终 proving command 暴露与本次改动不直接相关、但会阻断交付的仓库级回归，则只做最小修复，并把修复点同步回 design/tasks/plan，避免“测试为了过而顺手改代码”却不留痕迹。

正文模板仍保留深度分析与证据索引，但默认改成“答案层 -> 判断层 -> 证据层 -> 审计层”的渐进披露顺序；共享审计附录用于承载所有 profile 都不能缺失的审计层信息。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| 只润色现有共享头文案，不改 contract | 成本低 | 无法解决“体裁错位”，很快回退成旧风格 | Rejected |
| 为每个 `research_mode` 复制一整套三档模板 | 结构最清晰 | 模板数量膨胀，维护成本高 | Rejected |
| 保留 mode 模板，新增少量 presentation header + 路由规则 | 改动集中、可演进、兼顾兼容性 | 需要额外门禁避免 profile 漂移 | Accepted |

## Key Decisions

- D1: 保留 `selection / analysis / discovery` 作为研究方法分类，同时新增 `decision / understanding / audit` 作为报告呈现分类，避免把“怎么研究”和“怎么展示”混为一谈
- D2: 默认首屏遵循“问题 -> 当前判断 -> 决定性理由 -> 最大风险 -> 建议动作”，把完整的 challenge 记录、覆盖证明和项目上下文后置到共享审计层；`audit` profile 只把最需要前置的挑战表前拉
- D3: 不改写历史报告，只通过模板和测试约束未来产物，控制本次变更范围
- D4: 使用专用 `completion_check.sh` + 仓库测试双重门禁，保证新结构不是提示词建议，而是可机械验证的 contract
- D5: fresh proving command 若暴露仓库现有 blocker，只允许做最小、可解释、可验证的修复；本轮对应两类 Codex hooks blocker：`hooks.json` 缺失标准空事件键，以及卸载后无法恢复用户原始 `hooks.json` baseline

## Success Criteria

- `shared/skills/research/SKILL.md` 明确要求识别 `presentation_profile`，并说明其与 `research_mode` 的关系
- `shared/skills/research/references/` 新增目的驱动的呈现框架文档，并被 `SKILL.md` 正式引用
- `research` 的模板支持至少 `decision / understanding / audit` 三种首屏结构，并通过共享审计附录补齐通用审计层
- `shared/skills/research/scripts/completion_check.sh` 能检查 profile 相关必填项、共享审计附录存在性与章节顺序
- 新增或扩展的测试能覆盖新 contract、模板存在性，以及 `decision / understanding / audit` 三种 completion check 通过/失败行为
- `tests/test-codex-skill-adapter.sh` 在当前工作树上通过，且 `hooks.json` 显式保留空的 `PostToolUse / PostCompact / TaskCompleted` 键
- `tests/test-install-systematic.sh` 在当前工作树上通过，且 Codex 卸载后能恢复安装前的非标准 `hooks.json` baseline
