# Codex Doc Review Report

- 审查文件 (file): /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md
- 审查阶段 (stage): design
- 审查时间 (timestamp): 2026-04-03
- 状态码: REVIEW_ISSUE

---

## Findings

| severity | location | description | recommendation |
|----------|----------|-------------|----------------|
| high | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:60-62,100-121,167-173,210-213 | 方向正确，但外部评审引擎的机器契约没有闭合。设计假设 `codex:adversarial-review` 和 `codex exec --json` 都能稳定产出可驱动修复循环的结构化 findings，但没有定义必填字段、空结果语义、字段缺失/格式损坏处理、超时/不可用处理、以及 parse 失败后的 fail-close 行为。D7 还把 JSON 校验表述为“由 codex 插件或 LLM 自然处理”，这不足以支撑自动修复循环。这个缺口会直接影响自动修复、重审比较和终止判定。 | 在实现前补一份外部依赖契约：输入、输出 schema、字段必填性、定位精度要求、空 findings 语义、超时与不可用状态码、解析失败的终止动作；禁止在契约不满足时静默降级到继续修复。 |
| high | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:42-45,81-82,135,173 | 状态机只有主路径，没有异常/退出闭环。文档定义了 dirty tree 时 `git stash`，也在最终报告里记录 stash SHA，但没有规定成功、失败、不收敛、用户中止、验证失败、stash pop 冲突时分别怎么处理 baseline。对会改 working tree 的 skill，这是阻塞级缺口。 | 把循环补成显式状态机，至少覆盖：进入前快照、评审、修复、验证、重审、终止、恢复/保留 baseline；并写清 staged changes、stash 冲突、用户中止时的处理策略和用户可见提示。 |
| medium | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:70-74,123-127 | 收敛标准目前主要依赖“high+ 数量归零 / 连续两轮零 findings / 连续两轮数量不减少”。这能表达基本方向，但不足以判断真实收敛：数量减少不代表风险下降，finding 可能换维度、换位置、换 severity；文档双零也可能只是同一 prompt 的重复浅通过。 | 为 findings 增加跨轮比较语义，例如稳定标识或去重规则；把不收敛判定从“只看数量”升级为“看未解决高风险问题、重开问题和维度漂移”；文档路径至少定义第二轮零 findings 必须基于更新后的全文和上一轮修复结果。 |
| medium | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:176-183 | 验收条件偏 happy path。当前 Success Criteria 只要求每个 skill 跑通“至少一轮”，不足以证明这次重设计最关键的 orchestration 安全性已经成立。缺少 dirty tree、codex 不可用、JSON 非法、非收敛、stash 恢复、引用清理完整性等负路径验收。 | 增加场景化验收矩阵，至少覆盖：clean/dirty tree、codex/self-review 两路径、结构化输出损坏、达到最大轮次、判定不收敛、baseline 恢复、旧引用清理证明。 |
| medium | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:15-18,24-34,184-205 | 迁移策略有删除清单，但缺切换契约。文档说明旧共享协议不动、新 skill 也不复用旧协议，同时要删除旧 skill 与 agent；这解决了文件层迁移，但没有说明调用方、文档入口、归档策略、以及剩余协议文档如何避免继续误导后续实现。 | 补一份迁移映射：谁从旧入口切到新入口、哪些文档归档、哪些共享协议继续有效但不再承接新功能、如何验证不存在悬空入口和误导性文档。 |

## DECEPTION

| severity | location | description | evidence |
|----------|----------|-------------|----------|
| medium | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:206-213 | 存在把核心可行性前提降格为“实现后调优”的表述风险。`focus` 传递有效性、自评审发现能力、JSON 输出稳定性并不是纯调优问题，而是决定循环能否可靠成立的前置条件。 | 这些风险一旦不成立，修复循环就无法稳定比较 findings、无法可靠驱动修改或无法做终止判定，应前置为设计契约或 spike 验证，而不是只在实现后观察。 |

## Dimensions

| dimension | verdict | evidence |
|-----------|---------|----------|
| 架构拆分 | 方向正确 | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:4,24-34,89-105 明确承认代码评审与文档评审的目标、验证方式、收敛逻辑不同，拆成两个 skill 是清晰且自洽的。 |
| Leader 模式与用户确认 | 方向正确 | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:40-42,63-64,106-108 先推断目标再 AskUserQuestion 让用户确认，符合以 leader 为中心的评审流程。 |
| 状态机 | 不足 | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:42-45,70-83,123-137 有主路径，但缺异常分支、baseline 恢复和终止动作定义。 |
| 外部依赖契约 | 阻塞 | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:60-62,100-121,167-173,210-213 对 codex/agent 输出的结构化稳定性依赖很强，但契约未写实。 |
| 收敛标准 | 部分成立 | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:70-74,123-127 已区分代码与文档场景，但判定过度依赖 finding 数量。 |
| 验收条件 | 不足 | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:176-183 覆盖了正向目标，未覆盖关键负路径。 |
| 迁移策略 | 部分成立 | /Users/lijieli/org-claude-skills/docs/review-fix-loop/2026-04-03-redesign/design.md:184-205 文件删除和引用清理有方向，但行为切换与文档归档策略未明确。 |

## Summary

- total_findings: 5
- deception_count: 1
- status: REVIEW_ISSUE
- 结论: 方案方向正确，尤其是“代码/文档分拆 + leader 动态推断”这条主线成立；但当前稿件仍属于“方向正确、契约不完整”。其中外部依赖契约未闭合、状态机缺异常/恢复分支，是按现稿直接实现前必须补齐的阻塞项。
- 主要优点: 拆分边界清晰；代码与文档的评审/收敛标准做了场景化区分；删除旧 skill 与引用清理有明确动作清单。
- 主要阻塞项: codex/agent 结构化输出契约缺失；baseline stash 与退出恢复策略缺失。
- 建议项: 先补契约与状态机，再补负路径验收矩阵和迁移映射，然后再进入实现。

---

## 处理建议

1. 先补“外部评审引擎契约 + fail-close 规则”，否则修复循环没有可靠输入边界。
2. 先补“状态机 + baseline 恢复语义”，否则 working tree 安全性没有设计保证。
3. 把 Success Criteria 从“一轮跑通”升级为“关键负路径覆盖”。
4. 为迁移增加入口切换、文档归档和残留协议处理说明，避免删除后留下误导性文档。