# 复杂链路运行时 Prompt 去章节化实施计划

## 总目标

把复杂链路 `product -> design -> test-design -> tech-lead -> delivery-owner` 正式改造成 runtime prompt 去章节化：

- `Prompt` 保留判断语法
- `Harness` 只承接硬不变量
- `Router` 只基于显式条件触发
- `sub agent` 只负责可回收工序，只在使用点出现
- 现有跨职能评审继续作为最终质量门禁
- central truth 保留但引用说明收缩

## 总范围

### `SKILL.md`

- `/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md`

### `central truth / retained references`

- `/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml`
- `/Users/lijieli/org-claude-skills/shared/reference/subagent-recovery-contract.md`
- `/Users/lijieli/org-claude-skills/shared/reference/context-noise-metrics.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/references/runtime-fact-capture.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/references/decision-templates.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/references/adr-spec.md`
- `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md`
- `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/planning-modes.md`

说明：

- 这些文件保留为 central truth 或使用点参考，不再要求 runtime prompt 逐章复述。
- 本轮只收缩 runtime-facing 引用说明，不把 central truth 扩写成 prompt prose。

### `completion_check / tests`

- `/Users/lijieli/org-claude-skills/shared/skills/product/scripts/completion_check.sh`
- `/Users/lijieli/org-claude-skills/shared/skills/design/scripts/completion_check.sh`
- `/Users/lijieli/org-claude-skills/shared/skills/test-design/scripts/completion_check.sh`
- `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/scripts/completion_check.sh`
- `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh`
- `/Users/lijieli/org-claude-skills/tests/test-subagent-context-contract.sh`
- `/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh`

## 并行分组

### Group A: `Prompt / Skill`

目标：

- 5 个主 skill 只保留语义内核
- runtime prompt 去章节化，sub agent 只在使用点出现
- 保留不可下放责任、共创护栏、状态语义
- 去掉高噪音的 shared contract prose
- 去掉独立 sub agent 章节和主观触发表达

交付定义：

- 5 个 `SKILL.md` 改造完成
- 不再出现独立 `子代理边界` 章节
- 不再出现 `需要降噪时启用`、`必要时启用`、`复杂项目` 这类主观触发词

### Group B: `Reference / Contract`

目标：

- shared contract/reference 只保留硬不变量
- central truth 保留但引用说明收缩
- 显式触发条件落到 reference/contract
- 不新增第二套真源
- 不把高语义裁决翻译成更多控制字段

交付定义：

- `contract/reference` 与新边界一致
- 不再把 shared contract 写成 prompt prose 扩写器

### Group C: `Gate / Test`

目标：

- completion_check 和 tests 只检查硬边界
- 不再强制每个 skill 重复 shared contract prose
- 保留草稿泄漏、冻结边界、summary 文件存在性等硬检查
- gate 继续检查草稿不泄漏、冻结收敛

交付定义：

- 目标脚本与测试全部改造完成
- 相关验证命令通过

### Group D: `Review / Challenge`

目标：

- 独立检查是否削弱了主 Agent 判断力
- 独立检查是否让控制面继续膨胀
- 发现问题即回流修复，直到通过

交付定义：

- 至少一轮系统性 review
- 若有问题，完成修复并重新 review

## 总体验收标准

### Prompt 面

- 5 个主 skill 都不再有独立 sub agent 章节
- sub agent 只在使用点出现
- 不再重复 shared schema、模板列名、长篇 contract prose
- 主观触发表述被移除或改成显式触发
- runtime-facing reference 不再要求字面 contract 引用

### Harness 面

- shared contract 只表达硬边界
- central truth 保留但引用说明收缩
- reference 不继续扩写高语义控制
- 不新增第二套状态真源

### Router 面

- 所有 sub agent 派发都可回链到显式条件
- router 不代替主 Agent 做最终判断

### Gate / Test 面

- tests 不再要求 skill 重复 shared contract prose 或字面 contract 引用
- tests 改为检查责任边界、显式触发、草稿不泄漏、冻结收敛
- completion_check 继续保留硬门，不接管语义裁决

### 系统面

- 现有跨职能评审继续保留
- 不新增没有事故模型的控制层
- 所有目标验证通过后才算交付

## 完成条件

只有同时满足下面条件，才算本轮任务完成：

1. 目标文件全部完成改造。
2. 相关测试通过，但不把 tests GREEN 当成交付证明。
3. 至少完成一轮独立 review。
4. 若 review 有发现，修复后重新验证。
5. 至少完成一条完整工件链 replay 或等价强度的整链证明。
6. 最终结论为可交付。
