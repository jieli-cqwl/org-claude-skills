# Skill 重构裁决与执行需求

> 创建时间: 2026-04-06
> 上下文来源: 全链路测试（chain-test-report.md）+ zany-munching-stardust.md 计划对照
> 前置提交: abe914b（全链路测试 session-2 前端 + review + QA）

## 背景

标准 Skill 流程系统性重构计划（zany-munching-stardust.md）的 Phase 0-2 已完成并验证。全链路测试（weekly-report 项目，31/32 PASS）提供了 Phase 3/4 的判定证据。本文档记录裁决结论并定义剩余执行范围。

## 裁决结论

### Phase 3 模板精简：GO

**证据**: 全链路测试跳过所有模板产物（dev-report/code-review-report/qa-report/acceptance-summary），结果 31/32 PASS。模板的 PASS 维度叙述和 RED/GREEN 完整输出粘贴是不产生质量增量的 overhead。

| 项 | 裁决 | 具体改动 |
|----|------|---------|
| developer-report RED/GREEN 精简 | GO | RED/GREEN 完整输出粘贴 → commit SHA + 文件名索引 |
| code-review-report PASS 维度精简 | GO | PASS 维度详细分析 → 仅列维度名称和结论，FAIL 项保留完整证据 |
| qa-report PASS 项精简 | GO | PASS 项验证细节 → 仅列结论，FAIL 项保留完整复现命令和证据 |

### PM 裁决：角色保留，实现下轮重做

**角色定位（用户确认）**: (1) 安排所有人干活 (2) 检查活干完没有、有没有干好

**问题**: 当前实现太重（176 行 SKILL.md + 1400 行 completion_check.sh + 6 模板 + 熔断公式 + dispatch guide），全链路证明重量级实现无质量增量。

**本轮动作**: 仅记录裁决，不改 PM skill。PM 重新实现作为下一轮设计任务。

### Phase 4 重定义：原 3 项暂缓，替换为摩擦点修复

**暂缓项**（信息不足）:
- prompt/agent hook type（未测试）
- skill description 触发率优化（未触发自然语言匹配）
- skill 产出质量评测（n=1）

**新增项**（全链路证据充分）:
- F-5/F-13: test-design skill 标注自动化可行性
- F-9: 验证命令 shell 兼容性指导
- F-6: 接力文件粒度改进（developer skill handoff 机制）

## 执行范围

### 改动 1: developer-report 模板精简

**文件**: `shared/skills/developer/references/templates/developer-report-template.md`

**改动**:
- `### RED 阶段完整输出` → `### TDD 证据索引`，内容改为 commit SHA + 测试文件名表格
- `### GREEN 阶段完整输出` → 合并到上面的索引表（RED commit / GREEN commit）
- `### 自测结果 > 全量测试回归 > 完整输出` → 只保留命令和通过/失败计数，去掉粘贴完整输出
- 保留 TDD 记录表、测试完备性审视、静态分析、文件变更、自审发现（这些是行为脚手架）

### 改动 2: code-review-report 模板精简

**文件**（两处）:
- `shared/skills/review/references/templates/code-review-report-template.md`
- `shared/skills/project-manager/references/templates/code-review-report-template.md`

**改动**:
- 审查-A/B/C 详情：保留 Findings 表（只列 ISSUE 项）+ 已排除的潜在问题 + 结论
- 去掉 PASS 维度的详细正面评价叙述空间（当前模板结构已经是 findings-focused，改动较小）
- review skill 的模板增加说明注释："PASS 维度仅列结论，不展开正面分析"

### 改动 3: qa-report 模板精简

**文件**: `shared/skills/project-manager/references/templates/qa-report-template.md`

**改动**:
- 验证-A/B/C/D 各节：PASS 项只列 test_ref + 状态 + 一行结论，不展开验证过程
- FAIL 项保留完整：期望/实际/复现命令/证据
- 保留：验收汇总表、AC 追踪表、偏差自检、已排除潜在问题（行为脚手架）
- 去掉：PASS 项的详细操作步骤和输出粘贴

### 改动 4: test-design 自动化可行性标注

**文件**: `shared/skills/test-design/SKILL.md`（或其 references）

**改动**: 在测试用例模板中增加 `自动化可行性` 字段（API/UI-Playwright/手动），让 QA 阶段知道哪些 TC 需要特殊基础设施。

### 改动 5: 验证命令 shell 兼容性

**文件**: `shared/skills/test-design/SKILL.md`（或其 references）

**改动**: 在验证命令编写指导中增加 shell 兼容性提示：URL 用引号包裹、避免 zsh glob 敏感字符。

### 改动 6: 裁决文档本身

**文件**: 本文件（docs/skill-restructure-decision.md）作为裁决记录存档。

## 验收标准

1. 3 个模板文件已按上述规格修改
2. test-design skill 包含自动化可行性标注指导
3. `tests/run-all.sh` 全量通过（改动不破坏现有合同）
4. completion_check.sh 中引用模板字段的检查逻辑与新模板一致（无 false failure）
5. memory 更新：chain test 完成状态 + Phase 3 裁决结论

## 不做的事

- 不改 PM skill（下轮重新设计）
- 不改 Phase 4 原始 3 项（暂缓）
- 不改 HARD-GATE、方法论框架、不信任原则（Phase 0-1 已完成，不动）
- 不做第二轮全链路测试（下个 session）

## 环境信息

- 主 worktree: /Users/lijieli/org-claude-skills (main branch)
- 当前 worktree: /Users/lijieli/.superset/worktrees/org-claude-skills/false-emu (false-emu branch)
- Skill 文件在两个 worktree 中共享（同一 repo）
- 测试命令: `cd /Users/lijieli/org-claude-skills && bash tests/run-all.sh`
- Plan 文件: `~/.claude/plans/zany-munching-stardust.md`
