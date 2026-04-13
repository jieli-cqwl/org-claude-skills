# 复杂链路运行时 Prompt 去章节化实施计划

## 当前状态

本轮实施已经完成，并按当前仓库状态收敛为下面这组最小事实：

- 5 个主 skill 已完成 runtime prompt 去章节化
- sub agent 只在使用点出现
- central truth 保留但引用说明收缩
- 非运行时的共享 subagent 资产已删除
- gate/test 已改为检查硬边界，而不是检查说明文案

## 实际改动范围

### Runtime Prompt

- `/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md`

### 仍保留的参考文件

- `/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml`
- `/Users/lijieli/org-claude-skills/shared/skills/design/references/runtime-fact-capture.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/references/decision-templates.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/references/adr-spec.md`
- `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md`
- `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/planning-modes.md`

这些文件仍然保留，是因为它们还在承接当前使用点需要的最小说明；它们不再充当共享 contract 扩写器。

### Gate / Test

- `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh`
- `/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh`
- `/Users/lijieli/org-claude-skills/tests/test-subagent-context-contract.sh`
- `/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh`
- `/Users/lijieli/org-claude-skills/tests/test-closeout-routing.sh`

## 验收口径

当前实现的验收标准只有这几条：

1. `SKILL.md` 没有独立 sub agent 章节。
2. sub agent 只在使用点出现。
3. runtime prompt 不再重复共享 contract prose。
4. 最终主工件不保留草稿 agent 过程痕迹。
5. gate/test 只检查硬边界、显式触发、草稿不泄漏和冻结收敛。
6. delivery-owner hook 失败时必须输出可读失败原因和 decision JSON。

## 交付证明

交付结论必须同时满足：

1. fresh proving commands 全部通过。
2. 对抗性 review 没有残留阻断问题。
3. 搜索面里不再保留会误导后续维护者恢复旧方案的现行文档。
